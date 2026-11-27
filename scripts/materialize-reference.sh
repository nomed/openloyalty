#!/usr/bin/env bash
set -euo pipefail
# Run from a clean checkout of reference/monorepo. Fetch immutable source objects,
# then stage real trees (not submodules or symlinks). Review license before running.
cd "$(git rev-parse --show-toplevel)"
test "$(git branch --show-current)" = reference/monorepo
test -z "$(git status --porcelain)" || { echo "Working tree must be clean" >&2; exit 1; }
app=37329751578bb2f2ce1cf03c2928344aad8ed2c9
framework=119b6154f622258a62588d3d6ee09864f3d6478c
original=7acfdff043f9606e9fbb240f45c080dcc03f7dc6
fixes=f16735eb1d1215f3454bf6244b0abb636112077b
git fetch --no-tags https://github.com/dataworksbi/open-loyalty.git refs/heads/dev:refs/remotes/reference-app/dev
git fetch --no-tags https://github.com/nomed/open-loyalty-framework.git refs/heads/archive/sskurs-2025:refs/remotes/reference-framework/latest refs/heads/archive/original-3.2.0:refs/remotes/reference-framework/original refs/heads/archive/dataworksbi-dev-2022:refs/remotes/reference-framework/fixes
for sha in "$app" "$framework" "$original" "$fixes"; do
  git cat-file -e "${sha}^{commit}"
done
for dir in application framework reference/framework-original reference/framework-2022; do
  test ! -e "$dir" || { echo "Existing path: $dir; refusing overwrite" >&2; exit 1; }
done
git read-tree --prefix=application/ -u "${app}^{tree}"
git read-tree --prefix=framework/ -u "${framework}^{tree}"
git read-tree --prefix=reference/framework-original/ -u "${original}^{tree}"
git read-tree --prefix=reference/framework-2022/ -u "${fixes}^{tree}"
tree=$(git write-tree)
for entry in "application:$app" "framework:$framework" "reference/framework-original:$original" "reference/framework-2022:$fixes"; do
  path=${entry%%:*}; sha=${entry#*:}
  test "$(git rev-parse "$tree:$path")" = "$(git rev-parse "$sha^{tree}")"
done
echo "Exact source trees staged and verified. Review license and git diff --cached --stat."
echo "Commit staged trees, then push reference/monorepo (no force)."
echo "Runtime is not yet validated. Follow docs/recovery/MONOREPO.md."
