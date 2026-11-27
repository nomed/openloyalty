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
| Image build | **Passed** after using the locked PHPUnit 7.1.5; PHP extension compilation took about 19 minutes under emulation. | **Passed**; frontend and PHP images built. | Pending |
| Database migrations and setup | **Passed** on a fresh disposable database; 116 schema queries, Broadway event and snapshot schemas, and synthetic fixtures. | **Passed**; 116 schema queries and synthetic fixtures. | Pending |
| Browser page and static resources | **Passed** after fixing Nginx routes: all three pages and each cockpit's CSS, shared JavaScript, config, and app bundle return HTTP 200. | Pages and synthetic API logins passed before the shared route fix; repeat smoke after rebuilding with the fixed Nginx configuration. | Pending |
| Synthetic API login | **Passed** for admin, customer, and seller. The first login exceeded a 15-second timeout under emulation; the check now allows 60 seconds. | **Passed** for admin, customer, and seller. | Pending |
| Backend test suite | Running: PHPUnit 7.1.5, 1,135 tests; most recent recorded progress 549/1,135 (48%), with errors already reported. | Initial diagnostic run without `prepare-for-tests`: 1,135 tests, 31 errors, 46 failures, 2 skipped. Not a final result. Rerun using the completed test-preparation step. | Pending |
| Frontend tests | Pending | Build passes; test fails because `frontend/test/HelloWorldTest.js` imports missing `src/assets/js/hello-world.js`. | Pending |

The test target now runs the upstream `prepare-for-tests` target, validates the
test schema, runs the full framework test directory with unlimited PHP memory,
and runs the frontend tests separately. The original profile uses PHPUnit
7.1.5 from its pinned lockfile because Composer 1 cannot fetch a new PHPUnit
version: Packagist reports that Composer 1 support ended in September 2025.

### Browser access for the active original profile

- Admin: `http://127.0.0.1:8080/admin/index.html`
- Customer: `http://127.0.0.1:8080/client/index.html`
- Seller / POS: `http://127.0.0.1:8080/pos/index.html`

Synthetic accounts: `admin` / `open`, `user@oloy.com` / `loyalty`, and
`john@doe.com` / `open`. The Nginx configuration now maps cockpit-relative
assets and templates to the built frontend files; the smoke target checks those
resources, not only the HTML shell.

## Runtime issues found and addressed

- The old Elasticsearch image's Go 1.5 `gosu` helper cannot start its runtime
  threads under ARM64 emulation. Compose runs the service as its existing
  image user (`105:108`) and gives its temporary data directory matching
  ownership. Elasticsearch 2.2.2 then starts.
- The first setup revealed that APCu is required by the application. The
  runtime pins APCu 5.1.21.
- The original tree has no `app/uploads` directory. Setup creates an empty
  writable directory in the disposable container.
- The frontend's application and shared files are relative to each cockpit
  URL. Initially Nginx returned 404 for those files while the HTML returned
  200. The recovery Nginx configuration now maps them to the built assets.
- Under emulation, the first PHP login may take longer than 15 seconds. The
  synthetic API check now uses a 60-second timeout and does not print tokens.
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
