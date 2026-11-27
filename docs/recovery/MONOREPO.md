# Reference monorepo — agent entry point

Status: scaffold committed; source materialization and runtime verification pending. This branch is a historical reference, not the new Java product.

## Layout after materialization

- application/ — 2022 application, frontend, original Docker recipes, docs and lockfile.
- framework/ — latest recovered framework candidate (2025, NetworkBundle, Symfony 5.4).
- reference/framework-original/ — exact 3.2.0 source tree.
- reference/framework-2022/ — exact 2022 framework matching application lock.
- Root legacy application — preserved original snapshot; do not confuse with application/.
- docs/recovery/ — source provenance, runbooks and evidence.
- scripts/materialize-reference.sh — imports exact trees as ordinary tracked files, no submodules.

See SOURCE-RECOVERY.md for SHA provenance and RUNTIME-RUNBOOK.md for recovery sequence.

## Materialize once

On a workstation with Git access, after license review:

    git clone --branch reference/monorepo https://github.com/nomed/openloyalty.git
    cd openloyalty
    bash scripts/materialize-reference.sh
    git diff --cached --stat
    git commit -m "recovery: vendor pinned application and framework source trees"
    git push origin reference/monorepo

The script verifies all staged subtree hashes against original Git trees. Subsequent agents clone the branch without the script; no external source checkout is needed once the trees are committed. Do not rerun on an already materialized branch.

## Runtime contract

Build three separate profiles, never use the same database or event store:
1. Original application at root + reference/framework-original.
2. application/ + reference/framework-2022 (coherent locked pair).
3. application/ + framework/ (2025 candidate; compatibility not established).

Use local Composer path repositories pointing to the matching checked-in framework, preserving original composer manifests/locks as evidence and generating profile-specific manifests and locks. Verify package identity: 2022 app expects dataworksbi/open-loyalty-framework while its lock pins f16735eb...; inspect the local package manifest and resolve name mismatch explicitly. Do not claim lock compatibility until checked. 2025 declares sskur/open-loyalty-framework and has no upstream lock.

Create runtime/ with separate Dockerfiles and compose profiles, pinned dependency versions and image digests, local-only HTTP ports, no published DB/search/FPM ports, disposable credentials, synthetic fixtures and scripts for build, setup, smoke, test and teardown. Inspect upstream lifecycle hooks and package scripts first. Legacy runtimes must run in an isolated disposable VM. Never use real customer data.

Target agent interface (not implemented yet): make doctor, make up PROFILE=original|2022|latest, make smoke PROFILE=..., make test PROFILE=..., make down PROFILE=....
A profile is ready only after build, migrations, all three cockpit logins, API and sale/points/reward/return scenario, test logs and exact dependency manifest. Offline rebuild requires additional artifact caching; source vendoring alone does not guarantee offline dependency installation.

## Agent rules
- Preserve archive branches and original source directories; modifications go into recovery overlays.
- Record observed behavior and deviations; do not suppress failing tests.
- No private company material in this public repository.
- Review license and redistribution rights before importing or using sources commercially.
- No production deployment or Java implementation here.
