#!/usr/bin/env bash
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
profile=${1:-2022}
case "$profile" in original|2022|latest) ;; *) echo "Invalid profile" >&2; exit 2;; esac
failed=0
for cmd in git docker make; do
  command -v "$cmd" >/dev/null && echo "OK $cmd" || { echo "MISSING $cmd"; failed=1; }
done
docker compose version 2>/dev/null || { echo "MISSING Docker Compose"; failed=1; }
server_arch=$(docker info --format '{{.Architecture}}' 2>/dev/null) || { echo "Docker daemon unavailable"; failed=1; }
if [[ -n "${server_arch:-}" ]]; then
  echo "Docker daemon architecture: $server_arch"
  [[ "$server_arch" == amd64 || "$server_arch" == x86_64 ]] || echo "NOTE profiles request linux/amd64 emulation on this daemon"
fi
bash scripts/verify-reference.sh || failed=1
for path in "runtime/$profile/compose.yaml" "runtime/$profile/manifest.env"; do
  [[ -f "$path" ]] && echo "OK $path" || { echo "MISSING $path"; failed=1; }
done
if [[ -f "runtime/$profile/compose.yaml" && -f "runtime/$profile/manifest.env" ]]; then
  docker compose --project-name "ol-reference-${profile}" --env-file "runtime/$profile/manifest.env" -f runtime/common/compose.yaml -f "runtime/$profile/compose.yaml" config --quiet \
    && echo "OK compose configuration: $profile" || { echo "INVALID compose configuration: $profile"; failed=1; }
fi
echo "doctor checks local prerequisites and configuration, not runtime correctness"
exit "$failed"
