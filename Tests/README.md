# Tests

UTM's automated tests. Each tier runs on its own; none of them touches the VMs or
settings of an installed UTM.

| Folder | Target | What it holds |
|---|---|---|
| `Shared/` | `UTMTests` | XCTest unit tests hosted by the macOS app (`@testable import UTM`), compiled into every app-hosted test bundle |
| `Fixtures/` | `UTMTests` | Resource files the tests load, such as legacy `config.plist` files |
| `macOS/` | `UTMTests` | Tests of macOS-only code such as scripting, compiled only into the macOS-hosted bundle |
| `Static/` | none | Scripts that check the tree without building it (`sh Tests/Static/run_all.sh`) |

`Shared/PreviewSmokeTests.generated.swift` holds one test per `PreviewProvider` of
the app and is written by `scripts/gen-preview-smoke.py`; run the script after adding
or removing a preview (the static checks fail when it is out of date). Each test
renders the preview offscreen with the environment objects the base class builds, so
a trap in a view's body fails the test that names it.
The `Shared/Views/` tests inspect SwiftUI views with
[ViewInspector](https://github.com/nalexn/ViewInspector), a test-only package
pinned to an exact version because its minor releases change the API. Only
`UTMTests` links it, but Xcode resolves packages per project, so every scheme
fetches it once; the committed `Package.resolved` pin keeps that a cached fetch.

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
- Keep tests free of host state: writes go only to the test host's own container
  and to `FileManager.default.temporaryDirectory`, and a test resets what it
  touched (`TestStorage` does this for the VM list and registry). No running VMs.
- Put fixtures under `Fixtures/` and load them from `Bundle(for: Self.self)`.
- `Fixtures/expected/*.argv` are whole macOS QEMU command lines of a few canonical
  configurations, one argument per line, compared by `QemuArgumentGoldenTests`
  with the resources path and per-drive identifiers masked. When a change to
  the generator is intended, record them again with
  `TEST_RUNNER_UTM_RECORD_GOLDENS=1 ./scripts/test_utm.sh -only-testing:UTMTests/QemuArgumentGoldenTests`,
  copy the files the skipped tests name into `Fixtures/expected/`, and review the diff.
- Name a regression test after the bug it would have caught, with the fix's commit
  hash as a suffix (`testSingleUrlArgumentIsNotEscaped_a2552606`), when you have
  shown that the test fails with that commit reverted. Cite the commit in a comment
  otherwise. A test of current behaviour that no fix motivated is named after the
  behaviour.
- Keep tests free of host state: no `UserDefaults.standard` writes, no files
  outside `FileManager.default.temporaryDirectory`, no running VMs.
- Put fixtures under `Fixtures/` and load them from `Bundle(for: Self.self)`.

## SwiftUI views

ViewInspector reads a view's `body` without hosting it. Three things it can do
in this project, each shown by a test under `Shared/Views/`:

- A view driven by `@Binding` or `@ObservedObject` is inspected synchronously
  from a binding the test owns (`VMConfigDriveCreateViewTests`). `tap()` on a
  toggle changes the binding but does not run `onChange`; call
  `callOnChange(newValue:)` on the view the modifier is attached to.
- A view that reads an `@EnvironmentObject` is inspected synchronously after
  `.environmentObject(object)`; no hosting and no hook in the view is needed
  (`BusyOverlayTests`).
- A legacy `.alert(item:content:)` that returns an `Alert` cannot be opened by
  ViewInspector. Use `.utmAlert(item:content:)` from `Platform/Shared/UTMAlert.swift`
  instead; it is the same modifier wrapped so that the test target can open the
  alert and read its title and buttons.

Use `find(...)` queries rather than positional chains, because SwiftUI wraps
some children in an implicit `AnyView`, and pass `containing:` when a view has
more than one control of a type.
