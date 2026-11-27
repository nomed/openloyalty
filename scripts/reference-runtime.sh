#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
action=${1:?action required}
profile=${2:?profile required}
case "$profile" in original|2022|latest) ;; *) exit 2;; esac
case "$action" in up|setup|smoke|test|down) ;; *) exit 2;; esac
dir="runtime/$profile"
if [[ ! -f "$dir/compose.yaml" || ! -f "$dir/manifest.env" ]]; then
  echo "Profile $profile not implemented; see docs/recovery/MONOREPO.md" >&2
  exit 1
fi
# Require reviewed, profile-specific implementation rather than starting legacy defaults.
exec bash "$dir/run.sh" "$action"
