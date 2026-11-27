#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
profile=original
action=${1:?action required}
exec bash scripts/run-reference-profile.sh "$profile" "$action"
