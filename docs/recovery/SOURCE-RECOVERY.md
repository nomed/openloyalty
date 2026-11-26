# Open Loyalty source recovery

Status: source recovery in progress; no successful runtime build or functional parity claim yet.

## Pinned sources

| Role | Repository | Commit |
|---|---|---|
| Application baseline | https://github.com/nomed/openloyalty | 6a2bf8c37476b6c140e777e9b60be71f9afa8e5a |
| Original framework 3.2.0 | https://github.com/nomed/open-loyalty-framework/tree/archive/original-3.2.0 | 7acfdff043f9606e9fbb240f45c080dcc03f7dc6 |
| Network extension | https://github.com/nomed/open-loyalty-framework/tree/archive/dataworksbi-2022 | 0e5fff474c3a149138853f2e3c4bc508cb13b159 |
| Runtime fixes | https://github.com/nomed/open-loyalty-framework/tree/archive/dataworksbi-dev-2022 | f16735eb1d1215f3454bf6244b0abb636112077b |
| Latest framework candidate | https://github.com/nomed/open-loyalty-framework/tree/archive/sskurs-2025 | 119b6154f622258a62588d3d6ee09864f3d6478c |
| Alternative application master | https://github.com/dataworksbi/open-loyalty | 672c13170be8c4862e69ff3bff0988e16e204900 |
| Alternative application dev | https://github.com/dataworksbi/open-loyalty/tree/dev | 37329751578bb2f2ce1cf03c2928344aad8ed2c9 |

The 3.3.x-dev alias already exists in original 3.2.0 composer.json; it is not evidence of a later upstream release.

## Recovery sequence

1. Preserve original refs; never rewrite archive branches. Fetch alternative application histories locally and compare before importing them (remote branch creation failed because the commit objects are absent from this repository).
2. Reproduce original application and framework 3.2.0 in an isolated disposable environment; use synthetic data only. Inspect license terms before use and redistribution. Do not expose legacy services to the internet.
3. Build from pinned sources, not mutable image tags. Original compose uses PostgreSQL 9, Elasticsearch image divante/open-loyalty-elasticsearch:2.2.0, PHP-FPM, nginx and MailHog; framework requires Elasticsearch client ^5.0. Verify actual Elasticsearch server compatibility and image manifests.
4. Resolve original lockfile and legacy frontend AngularJS 1.6.6, webpack 2 and node-sass 4.5.2 with compatible pinned toolchain. Record actual versions and image digests.
5. On separate recovery branches, test the 2022 dev event-store fixes against original and the 2025 candidate. Do not blindly merge.
6. The 2025 candidate declares PHP >=7.4, Symfony 5.4 and upgraded Doctrine/Broadway, but removed the original composer.lock and retains scripts invoking legacy Sensio DistributionBundle. Treat dependency resolution, bootstrapping, migrations and application integration as unverified. Package name changes to sskur/open-loyalty-framework; align application dependency explicitly and use a local Composer path or pinned VCS source.
7. Run framework unit/integration tests, application setup, API and three cockpit smoke tests; capture logs and exact versions. Compare NetworkBundle behavior and event-store concurrency. Check original versus candidate on identical fixtures.
8. Publish a reproducibility manifest with commit hashes, lockfiles, container digests, test results, known failures and documented capability deltas. A latest-stack claim requires passing acceptance criteria, not merely newer dependencies.

## Acceptance

- Original and candidate can be built independently from pinned inputs.
- Database, search projections, migrations, admin/member/merchant login and synthetic purchase/points/reward/return flows work.
- Original test inventory and failures are reported; no silent removal of failing tests.
- Functional regressions and new functionality are explicitly catalogued.
- License provenance and allowed usage are reviewed; no production deployment authorized.

No application or framework build has been executed by the author of this inventory.
