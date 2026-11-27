# Runtime recovery runbook

## Status and strategy
No runtime has been executed. GitHub API inspection confirms that application 2022 dev pins framework 2022 dev in its Composer lock. Recover this coherent pair before attempting the 2025 modernization; retain original 3.2.0 as parity oracle. Use a disposable Linux/amd64 VM, Docker Engine and Compose, synthetic data only, no production networks or credentials, and review applicable license terms first.

## 1. Acquire sources (operator workstation)
```sh
git clone https://github.com/nomed/openloyalty.git
cd openloyalty
git remote add dataworksbi https://github.com/dataworksbi/open-loyalty.git
git fetch dataworksbi refs/heads/master:refs/remotes/dataworksbi/master refs/heads/dev:refs/remotes/dataworksbi/dev
git cat-file -e 37329751578bb2f2ce1cf03c2928344aad8ed2c9^{commit}
git cat-file -e 672c13170be8c4862e69ff3bff0988e16e204900^{commit}
# Preserve exact observed revisions, not floating tips.
git push origin 37329751578bb2f2ce1cf03c2928344aad8ed2c9:refs/heads/archive/dataworksbi-dev
git push origin 672c13170be8c4862e69ff3bff0988e16e204900:refs/heads/archive/dataworksbi-master
git worktree add --detach ../ol-original 6a2bf8c37476b6c140e777e9b60be71f9afa8e5a
git worktree add --detach ../ol-2022 37329751578bb2f2ce1cf03c2928344aad8ed2c9
git clone https://github.com/nomed/open-loyalty-framework.git ../ol-framework
git -C ../ol-framework cat-file -e f16735eb1d1215f3454bf6244b0abb636112077b^{commit}
```
Stop if any check fails; do not force-push. The API cannot create refs for commit objects absent from the target repo.

## 2. Record exact dependencies
2022 application lock pins dataworksbi/open-loyalty-framework dev-dev at f16735eb1d1215f3454bf6244b0abb636112077b; Symfony v3.4.49, Doctrine ORM 2.7.5, Broadway 2.0.0 and Broadway Bundle 0.4.2. Original app pins framework 3.2.0 at 7acfdff043f9606e9fbb240f45c080dcc03f7dc6. 2025 framework candidate 119b6154f622258a62588d3d6ee09864f3d6478c has no lockfile. Record source hashes and image digests before executing. Do not use composer update on baseline locks.

## 3. Preflight and legacy isolation
Inspect every Dockerfile, script and Composer lifecycle hook before execution. Verify registry availability and architecture; do not assume legacy image tags still exist. Inspect .env and replace defaults with disposable credentials. Create a recovery-only Compose override that removes published database/search/FPM ports, binds HTTP/UI/mail to loopback only, and pins images by digest. Run docker compose config and inspect the merged result before up. Avoid privileged containers and host secrets. Build on a disposable VM; network access for package downloads only where needed. Record any obsolete apt repositories, PECL extensions, Phing downloads and npm native builds as blockers; pin compatible artifacts rather than using latest.

## 4. Build candidate 2022
The upstream README uses docker/base/build_dev.sh from docker/base, then docker/docker-compose.dev.yml from root. The PHP base is php:7.1-fpm and dev Dockerfile uses composer:2.2. Upstream downloads unpinned phing-latest.phar and APCu; fix and pin them before building. The app dev Compose publishes database, search and FPM; use the isolation override from step 3. Check PHP extensions, composer validate and composer install from the existing lock. Capture build logs and resolved package versions. Verify framework commit in installed.lock/vendor metadata. Ensure lock is not silently rewritten. Run setup on a new database only; inspect phing setup first. Run backend/framework tests in an isolated test database, then frontend build and tests.

## 5. Smoke and parity gates
- API authentication and admin, customer, merchant cockpit login.
- Register synthetic member, assign POS/merchant, import purchase, award points, list transfers, redeem reward, return purchase, reconcile.
- Verify idempotency, concurrent point consumption, expiry, P2P, audit and reindexing.
- Capture HTTP responses, database/search versions, test counts, errors, logs, image digests and source refs. Do not store JWTs or secrets in logs.
- Repeat on original and latest candidates using identical synthetic inputs. Differences are findings, not automatically bugs.

## 6. Latest candidate
Use framework recovery/latest-stack (2025) with a separate application worktree. Resolve package rename and Symfony bootstrap differences; retain original locks, generate a new candidate lock with explicit provenance. Compare the 2022 dev event-store patch and test before incorporating it. Verify NetworkBundle and access control; no assumption of complete multitenancy. A successful composer solve is not a successful application build.

## Exit criteria
Reproducible build from pinned sources, isolated runtime, setup and all three portals reachable, test evidence and known failures recorded, no unreviewed license changes, no production deployment. Mark each baseline independently.
