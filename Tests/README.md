# Tests

UTM's automated tests. Each tier runs on its own; none of them touches the VMs or
settings of an installed UTM.

| Folder | Target | What it holds |
|---|---|---|
| `Shared/` | `UTMTests` | XCTest unit tests hosted by the macOS app (`@testable import UTM`), compiled into every app-hosted test bundle |
| `Fixtures/` | `UTMTests` | Resource files the tests load, such as legacy `config.plist` files |
| `macOS/` | `UTMTests` | Tests of macOS-only code such as scripting, compiled only into the macOS-hosted bundle |
| `Static/` | none | Scripts that check the tree without building it (`sh Tests/Static/run_all.sh`) |

## Running the unit tests

The tests are hosted by `UTM.app`, so they need the prebuilt `sysroot-*`
dependencies like any other build:

```sh
./scripts/test_utm.sh                                      # everything
./scripts/test_utm.sh -only-testing:UTMTests/QEMUArgumentFragmentTests
./scripts/test_utm.sh -d "$SCRATCH/dd-tests" -r "$SCRATCH/tests.xcresult"
```

The script builds the host as `com.utmapp.test.UTM` with ad-hoc signing, so it
is a different app from any installed UTM, with its own sandbox container and
defaults, and it uses a separate derived-data path so those overrides never land
in a normal Debug build. Under XCTest the app skips its normal startup
(`Main.runAsTestHost`): no window opens and no VM list is read. Running the
tests from Xcode with the plain macOS scheme does not get this isolation.

The script also builds the host with a dSYM and passes a per-test execution-time
allowance. Without a dSYM, the first failing test after the host is rebuilt takes
minutes to report, because XCTest symbolicates the failure by reading the debug
map of the large `-Onone` host; with a dSYM it reports in seconds. A test that
still stalls is reported as exceeding its allowance instead of blocking the run.

## Writing tests

- Name a test after the bug it would have caught, with the fix's commit hash as a
  suffix (`testSingleUrlArgumentIsNotEscaped_a2552606`), when you have shown that
  the test fails with that commit reverted. Cite the commit in a comment otherwise.
- Keep tests free of host state: no `UserDefaults.standard` writes, no files
  outside `FileManager.default.temporaryDirectory`, no running VMs.
- Put fixtures under `Fixtures/` and load them from `Bundle(for: Self.self)`.
