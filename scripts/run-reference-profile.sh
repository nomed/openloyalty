#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
profile=${1:?profile required}
action=${2:?action required}
case "$profile" in original|2022|latest) ;; *) echo "Invalid profile: $profile" >&2; exit 2;; esac
case "$action" in up|setup|smoke|test|down) ;; *) echo "Invalid action: $action" >&2; exit 2;; esac
set -a
source "runtime/$profile/manifest.env"
set +a
project="ol-reference-${profile}"
compose=(docker compose --project-name "$project" --env-file "runtime/$profile/manifest.env" -f runtime/common/compose.yaml -f "runtime/$profile/compose.yaml")
mkdir -p "runtime/$profile/logs" "runtime/$profile/generated"
case "$action" in
  up)
    "${compose[@]}" config --quiet
    "${compose[@]}" build --pull 2>&1 | tee "runtime/$profile/logs/build.log"
    "${compose[@]}" up -d --remove-orphans 2>&1 | tee "runtime/$profile/logs/up.log"
    ;;
  setup)
    ready=0
    # Elasticsearch 2.2 can take several minutes to open HTTP under AMD64
    # emulation on an ARM host. Keep polling rather than failing after 2 min.
    for ((attempt=0; attempt<300; attempt++)); do
      if "${compose[@]}" exec -T php php -r '$s=@fsockopen("search",9200,$e,$m,2); if ($s) { fclose($s); exit(0); } exit(1);'; then
        ready=1
        break
      fi
      sleep 2
    done
    [[ "$ready" == 1 ]] || { echo "Search service did not become ready" >&2; exit 1; }
    # Setup must leave writable cache and JWT files owned by PHP-FPM's user.
    "${compose[@]}" exec -T --user root php sh -c 'mkdir -p app/uploads && chown -R www-data:www-data var app/var app/uploads'
    "${compose[@]}" exec -T --user www-data php php bin/phing.phar setup 2>&1 | tee "runtime/$profile/logs/setup.log"
    "${compose[@]}" cp php:/var/www/openloyalty/composer.json "runtime/$profile/generated/composer.json"
    "${compose[@]}" cp php:/var/www/openloyalty/composer.lock "runtime/$profile/generated/composer.lock"
    "${compose[@]}" exec -T php composer show --no-interaction > "runtime/$profile/generated/packages.txt"
    ;;
  smoke)
    command -v curl >/dev/null || { echo "curl required for local smoke checks" >&2; exit 1; }
    for cockpit in admin client pos; do
    curl --fail --silent --show-error "http://127.0.0.1:${HTTP_PORT:-8080}/${cockpit}/index.html" -o /dev/null 2>&1 | tee "runtime/$profile/logs/smoke.log"
      echo "OK ${cockpit} cockpit page" | tee -a "runtime/$profile/logs/smoke.log"
      case "$cockpit" in admin) bundle=admin.app.js;; client) bundle=client.app.js;; pos) bundle=pos.app.js;; esac
      for asset in assets/styles/commons.bundle.css assets/js/commons.js config.js "$bundle"; do
        curl --fail --silent --show-error "http://127.0.0.1:${HTTP_PORT:-8080}/${cockpit}/${asset}" -o /dev/null
        echo "OK ${cockpit}/${asset}" | tee -a "runtime/$profile/logs/smoke.log"
      done
    done
    python3 scripts/smoke-reference-api.py "$API_URL" 2>&1 | tee -a "runtime/$profile/logs/smoke.log"
    ;;
  test)
    test_status=0
    {
      "${compose[@]}" exec -T php test -x var/bin/phpunit
      "${compose[@]}" exec -T --user www-data php php bin/phing.phar prepare-for-tests
      "${compose[@]}" exec -T --user www-data php php bin/console doctrine:schema:validate --env=test --skip-sync
      "${compose[@]}" exec -T php sh -c 'php -d memory_limit=-1 var/bin/phpunit -c phpunit.xml.dist "vendor/${APP_FRAMEWORK_PACKAGE}/src" > /tmp/reference-phpunit.log 2>&1; status=$?; cat /tmp/reference-phpunit.log; exit "$status"'
    } 2>&1 | tee "runtime/$profile/logs/test.log" || test_status=1
    "${compose[@]}" --profile tests run --rm --no-deps frontend-test 2>&1 | tee -a "runtime/$profile/logs/test.log" || test_status=1
    exit "$test_status"
    ;;
  down)
    "${compose[@]}" down --volumes --remove-orphans
    ;;
esac
