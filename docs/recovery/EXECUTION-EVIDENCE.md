# Recovery execution evidence

This record distinguishes source materialization, completed runtime checks, and
work still in progress. The recovery is **not complete** until all three
profiles have recorded build, database setup, smoke, and test results.

## Source identity and materialization

`scripts/materialize-reference.sh` materialized the pinned sources as tracked
files; no source checkout is needed at runtime. The script verified these Git
tree IDs before the source-only checkpoint was committed to
`reference/monorepo` (`0a1e6122`).

| Source | Commit | Verified tree |
|---|---|---|
| Original application | `6a2bf8c37476b6c140e777e9b60be71f9afa8e5a` | backend `b5bdd4119a064b104431ee508c5c7f799bd77a00`; frontend `a2a553ff4f002ea4f4bf698c59f8fb966b5fe420` |
| Application 2022 | `37329751578bb2f2ce1cf03c2928344aad8ed2c9` | `833e94e58864a2bb6b333f9720c3cb9ed85affce` |
| Framework 3.2.0 | `7acfdff043f9606e9fbb240f45c080dcc03f7dc6` | `361fe82afe0acc093d2e02209130ca71e4de618e` |
| Framework 2022 | `f16735eb1d1215f3454bf6244b0abb636112077b` | `37b8af812dd7a95147ac29d3b7f965517d645923` |
| Framework 2025 | `119b6154f622258a62588d3d6ee09864f3d6478c` | `f4b697d94040e46e64c9b2298fbfa0a3d24bb122` |

## License review

The current application and 2025 framework carry the repository's Open Loyalty
License based on MIT. It permits free use for non-commercial use or commercial
use with at most 200 customers, subject to retaining notices. The text requires
separately agreed fees for commercial use above that threshold. The imported
3.2.0 and 2022 framework roots have no `LICENSE` file; their `doc/_exts`
directories contain their own documentation license. A neighboring
application license is provenance, not a substitute for a missing framework
license. This recovery records the terms found and does not determine any
specific commercial entitlement.

## Profile definitions

The containers run as isolated Docker Compose projects. PostgreSQL and
Elasticsearch are internal-only services; HTTP and MailHog publish on loopback.
Databases use disposable storage, and all fixture accounts are synthetic.
The Docker daemon is ARM64, so the pinned `linux/amd64` images run under
emulation. This affects build and test duration.

| Profile | Application / framework | PHP / Composer | Frontend / data services |
|---|---|---|---|
| `original` | Original app + framework 3.2.0 | PHP 7.1 / Composer 1.10.26; lockfile PHPUnit 7.1.5 | Node 6, nginx 1.15, PostgreSQL 9, Elasticsearch 2.2 |
| `2022` | Application 2022 + framework 2022 | PHP 7.1 / Composer 2.2.0; PHPUnit 7.5.20 | Node 6, nginx 1.15, PostgreSQL 9, Elasticsearch 2.2 |
| `latest` | Application 2022 + unmodified framework 2025 source | PHP 7.4 / Composer 2.2.0; PHPUnit 7.5.20 | Node 6, nginx 1.15, PostgreSQL 9, Elasticsearch 2.2 |

`latest` is the pure 2025 framework candidate: source code is copied from the
verified `framework/` tree and no local framework patch is layered over it.
The application is still the 2022 application because no corresponding 2025
application source is among the pinned sources.

## Current execution results

| Check | Original 3.2.0 | 2022 | 2025 framework |
|---|---|---|---|
| Image build | **Passed** after using the locked PHPUnit 7.1.5; PHP extension compilation took about 19 minutes under emulation. | **Passed in the 2026-11-28 rerun**; PHP 7.1 and frontend images built under ARM64 emulation. | **Passed**; rebuilt after adding runtime compatibility changes. |
| Database migrations and setup | **Passed** on a fresh disposable database; 116 schema queries, Broadway event and snapshot schemas, and synthetic fixtures. | **Passed in the 2026-11-28 rerun**; 116 schema queries, Broadway event and snapshot schemas, and synthetic fixtures loaded. | **Failed**; Symfony container compilation still stops on framework/application service incompatibilities. |
| Browser page and static resources | **Passed in headless Chrome:** all three pages and their CSS, JavaScript, config, and cockpit bundles load; customer, administrator, and seller can each sign in through the UI. | **Passed for admin on 2026-11-28:** after restoring default logo files and Elasticsearch projection indices, the browser rendered the dashboard and synthetic levels with zeroed analytics. Customer and seller cockpit pages and assets load; their API logins pass, but their UI logins were not repeated in this check. | **Partial:** all three pages and static assets returned successfully in the first smoke run. Latest setup did not complete, so a current authenticated browser result is unavailable. |
| Synthetic API login | **Passed** for admin, customer, and seller. The first login exceeded a 15-second timeout under emulation; the check now allows 60 seconds. | **Passed on 2026-11-28:** `make smoke PROFILE=2022` authenticated admin, customer, and seller. The four authenticated dashboard analytics endpoints also returned HTTP 200 after search indices were restored. | **Failed in the first smoke run** with HTTP 500 for all roles; that image logged a call to removed `AppKernel::loadClassCache()`. After removing that call, setup advanced further but remains blocked during service compilation; login was not re-verified. |
| Backend test suite | **Passed:** PHPUnit 7.1.5, 1,135 tests and 5,783 assertions. | **Running in the 2026-11-28 rerun:** test preparation reported a temporary PostgreSQL connection loss while loading fixtures; schema validation then passed and PHPUnit 7.5.20 began. The latest saved console checkpoint is 122 of 1,135, with errors, failures, and skips visible; final totals are pending. | **Not run:** setup has not passed. |
| Frontend tests | **Failed in the upstream test:** `frontend/test/HelloWorldTest.js` imports the absent `src/assets/js/hello-world.js`; frontend build itself passes. | Build passes; test fails for the same absent `src/assets/js/hello-world.js`. | Pending |

The test target now runs the upstream `prepare-for-tests` target, validates the
test schema, runs the full framework test directory with unlimited PHP memory,
and runs the frontend tests separately. The original profile uses PHPUnit
7.1.5 from its pinned lockfile because Composer 1 cannot fetch a new PHPUnit
version: Packagist reports that Composer 1 support ended in September 2025.

### Browser access for the active 2022 profile

- Admin: `http://127.0.0.1:8081/admin/index.html`
- Customer: `http://127.0.0.1:8081/client/index.html`
- Seller / POS: `http://127.0.0.1:8081/pos/index.html`

The 2026-11-28 browser check signed into the admin cockpit with the synthetic
account and rendered the dashboard. Its analytics show zero values because the
synthetic event table is empty. The API smoke check also authenticated the
synthetic customer and seller accounts. The `latest` containers were stopped
after the failed setup; only their isolated synthetic volumes were removed.

Synthetic accounts: `admin` / `open`, `user@oloy.com` / `loyalty`, and
`john@doe.com` / `open`. The Nginx configuration now maps cockpit-relative
assets and templates to the built frontend files; the smoke target checks those
resources, not only the HTML shell.

## Runtime issues found and addressed

- The old Elasticsearch image's Go 1.5 `gosu` helper cannot start its runtime
  threads under ARM64 emulation. Compose runs the service as its existing
  image user (`105:108`) and gives its temporary data directory matching
  ownership. Elasticsearch 2.2.2 then starts.
- Passing the literal string `[]` as Elasticsearch 2.2's unicast host list
  left a fresh profile without an HTTP listener. The isolated network already
  prevents cross-profile discovery, so the runtime now omits that setting,
  disables multicast, sets the single-node master count, and enables HTTP on
  port 9200. The 2022 profile then opened the HTTP port and completed setup.
- The first setup revealed that APCu is required by the application. The
  runtime pins APCu 5.1.21.
- The original tree has no `app/uploads` directory. Setup creates an empty
  writable directory in the disposable container.
- The frontend's application and shared files are relative to each cockpit
  URL. Initially Nginx returned 404 for those files while the HTML returned
  200. The recovery Nginx configuration now maps them to the built assets.
- A real headless Chrome load then exposed a frontend dependency mismatch:
  Angular 1.6.6 was paired with `angular-sanitize` 1.7.2, which requires the
  removed `angular.$$lowercase` helper. The runtime now pins and verifies the
  matching `angular-sanitize` 1.6.6. Browser sign-in succeeded in all three
  cockpits after rebuilding the original profile.
- Under emulation, the first PHP login may take longer than 15 seconds. The
  synthetic API check now uses a 60-second timeout and does not print tokens.
- In the 2022 profile, successful authentication dispatched the customer-login
  event for admins and sellers too. That ran customer earning-rule work
  synchronously and made the login request stall. The runtime patch now
  dispatches that event only for actual customer accounts; admin login then
  returned promptly and reached the browser dashboard. The running container
  received this patch directly; a clean profile rebuild is still required to
  prove it is reproduced from the checked-in runtime script.
- The same 2022 run found the pinned Elasticsearch 2.2 JVM terminate with
  `guarantee(PageArmed == 0) failed: invariant` under AMD64 emulation.
  Restarting this service restores its HTTP listener but clears its configured
  temporary data directory. That removed projection indices and made dashboard
  analytics return HTTP 500. Recreating the projection indices and replaying
  the current event store restored HTTP 200 responses and rendered the admin
  dashboard; the event table contained zero events. The JVM crash under
  emulation remains a reliability issue.
- Replacing the PHP container also removed fixture logo files referenced by
  synthetic settings, causing image requests to return HTTP 500. Copying the
  framework's bundled default logo into the disposable upload directory
  restored all seven logo routes to HTTP 200. Runtime startup now includes
  logic to restore missing defaults, but that latest entrypoint edit has not
  yet been rebuilt into and tested from a fresh image.
- The PHP entrypoint generates a synthetic JWT key pair when the container is
  recreated without keys. A clean container replacement verified the key
  files and permissions, and the all-role API smoke then passed.
- Nginx logs `io_setup() failed (38: Function not implemented)` under this
  emulation, but continues serving the site.
- Legacy Phing reports a malformed numeric value; Symfony reports timezone
  and private-service deprecations. These are warnings, not setup blockers.
- Composer 1 warns that Packagist has ended its support. The original profile
  nevertheless installs the dependencies from its historical lockfile.

## Framework comparison

The 2025 framework source includes a NetworkBundle with network entities,
location models, persistence mappings, API controllers, voters, and fixtures.
It also moves the framework package to `sskur/open-loyalty-framework`, requires
PHP 7.4 and Symfony 5.4, and has no upstream lockfile.

The parallel 2022 change to `ConcurrencyDBALEventStore::visitEvents` adds a
`void` return declaration and removes a `return`, but both 2022 and 2025 still
call `visitEvents` on `$this` recursively. It is not a valid fix to carry
forward. A delegation to the wrapped event store would be a separate proposed
correction and is not silently applied to the pure 2025 candidate.

## Completion gate

Do not call this recovery complete while any profile lacks actual build,
setup, smoke, and test evidence. Replace all `Pending` and `Running` cells
above with observed outcomes, record test totals and failures, rerun the smoke
checks on all profiles after the Nginx route fix, and keep only synthetic data.
