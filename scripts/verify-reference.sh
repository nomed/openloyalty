#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# Validate the committed source trees; no network required.
check() {
  local path="$1" expected="$2" actual
  actual=$(git rev-parse "HEAD:$path" 2>/dev/null) || { echo "MISSING committed tree: $path" >&2; return 1; }
  if [[ "$actual" != "$expected" ]]; then
    echo "Tree mismatch: $path expected=$expected actual=$actual" >&2
    return 1
  fi
  echo "OK $path $actual"
}
failed=0
while read -r path tree; do
  [[ -n "$path" && "$path" != \#* ]] || continue
  check "$path" "$tree" || failed=1
done < docs/recovery/source-trees.tsv
exit "$failed"
