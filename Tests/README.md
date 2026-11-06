# Tests

UTM's automated tests. Each tier runs on its own; none of them touches the VMs or
settings of an installed UTM.

| Folder | Target | What it holds |
|---|---|---|
| `Shared/` | `UTMTests` | XCTest unit tests hosted by the macOS app (`@testable import UTM`), compiled into every app-hosted test bundle |
| `Fixtures/` | `UTMTests` | Resource files the tests load, such as legacy `config.plist` files |
| `macOS/` | `UTMTests` | Tests of macOS-only code such as scripting, compiled only into the macOS-hosted bundle |
| `Shared/` | `UTMTests`, `UTMTests-iOS` | XCTest unit tests hosted by the macOS app, and by the iOS app on a simulator (`@testable import UTM`); every file here is compiled into both bundles |
| `Fixtures/` | `UTMTests`, `UTMTests-iOS` | Resource files the tests load, such as legacy `config.plist` files |
| `UITests/macOS/` | `UTMUITests` | XCUITest flows that launch the macOS app and drive its windows |
| `UITests/iOS/` | `UTMUITests-iOS` | XCUITest flows that launch the iOS app on a simulator and drive its screens |
| `macOS/` | `UTMTests` | Tests only the macOS host can run: the scripting records, and the VM lifecycle tests that start real QEMU virtual machines in a signed host |
| `Static/` | none | Scripts that check the tree without building it (`sh Tests/Static/run_all.sh`) |

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

## Running the tests on the iOS simulator

The same test files are compiled into `UTMTests-iOS`, hosted by the iOS app on
a simulator, so a rule that differs between platforms (`#if os(macOS)`) is
tested where it applies. The simulator needs `sysroot-iOS_Simulator-arm64`:

```sh
./scripts/test_utm.sh -s                  # the newest runtime's first iPhone simulator
./scripts/test_utm.sh -s "iPhone 17"      # a simulator by name prefix
./scripts/test_utm.sh -s -only-testing:UTMTests-iOS/QEMUArgumentFragmentTests
```

`Tests/Static/check_test_targets.py` fails when a file under `Shared/` or
`Fixtures/` is missing from either bundle, so a test cannot quietly run on one
platform only.

CI runs this bundle on every push and pull request (`Test UTM (iOS Simulator)` in
`.github/workflows/build.yml`), next to the macOS bundle.

The host is built with the test bundle prefix and no code signing; the simulator
keeps its data per app, so nothing of an installed UTM is touched. The script keeps
the simulator build out of Documents, Desktop and Downloads: a simulator app that
opens a file there is held on macOS's privacy prompt, and dyld opens the derived
data paths before XCTest can connect, so the host would hang silently.

## Running the UI tests

The UI tests launch the same test build of the app and click through it, so
they need a logged-in desktop session on the machine that runs them. The
script runs them only when selected (a scheme cannot both skip a bundle and
let `-only-testing` pick it, so in Xcode deselect `UTMUITests` in the test
action before pressing Cmd-U against a Debug app that is not a test build):

```sh
./scripts/test_utm.sh -only-testing:UTMUITests
./scripts/test_utm.sh -s -only-testing:UTMUITests-iOS     # the iOS flows, on a simulator
```

CI runs them after a merge to `main` and on manual dispatch (`Test UTM (macOS UI)`
and the UI step of `Test UTM (iOS Simulator)`), not on pull requests: the macOS job
fails without a desktop session, and neither blocks the workflow.

Each test starts the app with `-UTMTestReset`, which empties the test build's
defaults and documents, and `-UTMTestMode`, which keeps the release notes, the
server and screenshots out of the way (`Platform/UTMTestSupport.swift`; only a
bundle identifier with the test prefix honours them). Tests find controls by the
identifiers in `Platform/Shared/UTMAccessibilityID.swift`, which is compiled
into the bundle, and only by a visible label where there is no identifier yet.
No test starts a VM.

## Running the VM lifecycle tests

`VMLifecycleTests` creates a disposable aarch64 VM with no drives and no network
(it boots the bundled firmware to its shell in seconds under the hypervisor), starts,
pauses, stops and screenshots it through the same `UTMQemuVirtualMachine` calls the
app makes, and deletes it. The host must be signed with a development identity so
that its app group and the helpers' hypervisor entitlement are valid, and it uses a
bundle prefix of its own (`com.utmapp.test.vm`) so that it never shares a container
with the unsigned unit-test host; start it from a desktop session:

```sh
./scripts/test_utm.sh -v        # needs DEVELOPMENT_TEAM in CodeSigning.xcconfig
```

The script builds the tests first, then signs `QEMULauncher` and `QEMURenderServer`
again without the two sandbox exceptions Xcode adds to every sandboxed product of a
test build (they inherit the helper's sandbox, and a process that inherits a sandbox
is trapped at launch if it carries any other sandbox exception), re-seals the helper
and the host, and runs the tests without building.
In any other host, every test of the class skips. An installed UTM and its VMs are
not touched, and a test that fails kills and deletes its own VM. These tests are not
part of the CI workflow on pull requests.

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
