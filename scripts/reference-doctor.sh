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
docker info >/dev/null 2>&1 || { echo "Docker daemon unavailable"; failed=1; }
bash scripts/verify-reference.sh || failed=1
for path in "runtime/$profile/compose.yaml" "runtime/$profile/manifest.env"; do
  [[ -f "$path" ]] && echo "OK $path" || { echo "MISSING $path"; failed=1; }
done
echo "doctor checks prerequisites only, not runtime correctness"
exit "$failed"
