---
name: utm-test
description: Build, run, and debug a UTM change for real. Covers building UTM, building all dependencies or just one after changing it, creating a disposable test VM by scripting and deleting it afterwards, where logs go, debugging, headless GUI checks, and the iOS simulator. Use this when you need to run UTM, reproduce a bug, or check that a change works in the app and not just that it compiles. Run it before /utm-review.
---

# utm-test

This is the canonical copy. The per-agent entries in `.claude/commands/` and
`.opencode/command/` point here. Commands assume macOS on arm64 and the repo root
as the working directory. `$SCRATCH` means your agent's scratch directory, or
`mktemp -d` if you don't have one.

## Ground rules

- **Test only on VMs you created, and delete them when you're done.** Never start,
  change, or delete the user's VMs. Other agent sessions may be using UTM on the
  same machine. Ask before you kill a UTM process that you didn't launch.
- **Run one UTM instance: your dev build.** `/Applications/UTM.app` has the same
  bundle id. Scripting then goes to whichever instance is running, and it can
  launch the release app instead of yours. A stale binary also silently ignores
  scripting parameters it doesn't know, so a new parameter can turn into a plain
  `start`. Check with `pgrep -fl "MacOS/UTM|QEMULauncher"` before you launch and
  after you finish.
- **Report only what you saw.** If your test VM never runs the code path you
  changed, say so rather than implying the change was validated. Before you call
  a failure pre-existing, build `main` in a worktree and compare, and check the
  issue tracker.

## Build UTM

```sh
xcodebuild -project UTM.xcodeproj -scheme macOS -configuration Debug \
    -destination 'platform=macOS,arch=arm64' build > "$SCRATCH/build.log" 2>&1
grep -E "error:|^\*\* BUILD" "$SCRATCH/build.log" | sort -u
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/UTM-*/Build/Products/Debug/UTM.app | head -1)
```

- Match `^\*\* BUILD`. A bare `BUILD` can match a path. If a build fails, the app
  from the last good build is still on disk, so check the result before testing.
- Swift code goes into `Contents/MacOS/UTM.debug.dylib`. To prove your change is in
  the binary you run, use `strings "$APP/Contents/MacOS/UTM.debug.dylib" | grep <marker>`.
- The Debug build is signed through the local `CodeSigning.xcconfig`. Keep that
  signing when you intend to run the app. `CODE_SIGNING_ALLOWED=NO` drops the
  virtualization and networking entitlements. Even when signed, vmnet
  (Shared/Bridged) networking may fail locally, so test VMs should use emulated
  networking or none.
- Compile-only checks for other platforms:
  - Add `CODE_SIGNING_ALLOWED=NO` and a separate `-derivedDataPath "$SCRATCH/dd-<scheme>"`.
  - Use `-destination 'generic/platform=iOS'` with scheme `iOS`, `iOS-SE`, or
    `iOS-Remote`, or `'generic/platform=visionOS'` with scheme `iOS`.
  - Add `ARCHS=arm64` to any `generic/` destination. Otherwise it tries to build
    universal and looks for `sysroot-*-arm64_x86_64`.
- If SPM plugin validation fails after a package URL changes, pass
  `-skipPackagePluginValidation`.
- **Baseline or per-commit builds:** don't check out over the user's tree.
  1. `git worktree add --detach "$SCRATCH/wt" <rev>`.
  2. Symlink every `sysroot-*` and `CodeSigning.xcconfig` into the worktree. A
     missing sysroot shows up as a misleading "missing resource" error.
  3. Build with its own `-derivedDataPath`.
  4. Remove the symlinks by name, then run `git worktree remove`.

## Dependencies

QEMU, SPICE, GLib, and the other native dependencies reach the app as frameworks
in `sysroot-<Platform>-<arch>/Frameworks`. Xcode embeds them and re-signs them.

### Full build

Usually you don't need one. Download the `Sysroot-*` artifacts from a recent
GitHub Actions run and extract them at the repo root. Build them yourself only
when you're changing a dependency:

```sh
./scripts/build_dependencies.sh -p macos -a arm64 > "$SCRATCH/deps.log" 2>&1   # -p ios|ios-tci|ios_simulator|visionos|…
grep -a "Building \|All done" "$SCRATCH/deps.log" | tail
```

- The build takes hours and deletes the sysroot before it starts.
- It leaves source trees in `build-<Platform>-<arch>/`. Those trees are what the
  single-dependency path below needs, and CI artifacts don't include them.
- A successful run ends with `All done` and writes `build-*/BUILD_SUCCESS`.
- If a build dies from memory pressure (LLVM and Mesa are the heavy parts), set
  `NCPU=4`.
- Source versions are pinned in `patches/sources`, and UTM's changes to them are
  in `patches/*.patch`. If you change a patch, check that it still applies to a
  fresh extract of the tarball: `patch -p1 --dry-run`.
- If a staged sysroot crashes inside a framework on an older macOS, suspect the
  sysroot before your change. For example, a weak import of an SDK-new symbol is
  NULL on older systems. Check `nm -m <binary> | grep "weak external"`,
  `vtool -show-build <binary>`, and `git log -S<symbol> -- scripts/` against the
  sysroot's date.

### Rebuild one dependency after a change

1. **Rebuild the library in its tree.** The trees are gitignored, so there is no
   git safety net for your edits.
   - QEMU: build only the target you need:

     ```sh
     ninja -C build-macOS-arm64/qemu-<ver>-utm/build libqemu-aarch64-softmmu.dylib
     ```

     A small edit takes seconds. `ninja -t targets all | grep <file>` finds object
     targets.
   - Meson projects such as spice-gtk, spice, and virglrenderer:
     `meson install -C build-macOS-arm64/<tree>/utm_build`. This installs into the
     sysroot's `lib/`.
   - Autotools projects: `make -C build-macOS-arm64/<tree> install`.
2. **Repackage it** into the framework the app embeds:

   ```sh
   scripts/fixup.sh -p macos -s sysroot-macos-arm64 <path/to/libfoo.N.dylib>
   ```

   - This writes `Frameworks/foo.N.framework` (the name drops `lib` and the last
     extension), sets the `@rpath` install name, and points imports of other
     sysroot libraries at their frameworks.
   - It is safe to re-run on a sysroot that has already been fixed up.
   - It matches sysroot libraries by file name, so it also works on a sysroot
     downloaded from CI, whose install names record the CI machine's paths.
   - `-i` rewrites only the imports of an executable, such as
     `libexec/virgl_render_server`, in place.
   - For iOS, pass `-p ios` and the iOS sysroot. That produces the flat framework
     layout.
3. **Check the framework, then rebuild UTM** so Xcode copies it into the app:

   ```sh
   otool -L sysroot-macos-arm64/Frameworks/<name>.framework/Versions/A/<name> | tail -n +2 | grep -v '@rpath\|/System/\|/usr/lib/'   # prints nothing
   strings "$APP/Contents/Frameworks/<name>.framework/Versions/A/<name>" | grep -c <marker>                                          # after xcodebuild
   ```

   Testing a stale framework and concluding "no effect" is the most common way to
   waste time here.

### Swift packages (CocoaSpice, QEMUKit, SwiftTerm)

These are remote packages pinned in `Package.resolved`, not the sibling checkouts.
There are two ways to test a change to one:

- **Quick patch:** edit the checkout in
  `~/Library/Developer/Xcode/DerivedData/UTM-*/SourcePackages/checkouts/<Pkg>`.
  The files are read-only, so `chmod u+w` first. A normal `xcodebuild` picks the
  edit up. Revert afterwards with `git checkout -- <file>` inside the checkout.
- **Local override:** add the local package folder to `project.pbxproj` as a
  folder reference (`lastKnownFileType = wrapper; path = ../<Pkg>`). Xcode then
  prefers it over the remote package. Remove the reference, and bump the pin once
  the package change is pushed.

## Run a disposable test VM

Launch the dev build yourself. Launching the binary directly is also how you
capture its stdout and pass it environment variables. Wait with `is running`.
Anything else sent before the app registers, even `tell application "$APP"`,
launches a second instance.

```sh
caffeinate -d -u -t 3600 &     # a sleeping display blocks Apple VM start and hides dialogs
nohup "$APP/Contents/MacOS/UTM" > "$SCRATCH/utm-stdout.log" 2>&1 &
until [ "$(osascript -e "application \"$APP\" is running")" = true ]; do sleep 1; done
utm() { osascript -e "tell application \"$APP\"" -e "$1" -e "end tell"; }
```

Create a QEMU VM that boots to the EDK2 UEFI shell. It has no disk and no NIC (a
NIC would add a PXE delay). It reaches `Shell>` in about 12 s:

```sh
VM="utm-test-$$"
utm "make new virtual machine with properties {backend:qemu, configuration:{name:\"$VM\", architecture:\"aarch64\", drives:{}, network interfaces:{}, displays:{{hardware:\"virtio-gpu-gl-pci\"}}}}"
utm "start virtual machine named \"$VM\""
utm "get status of virtual machine named \"$VM\""   # stopped|starting|started|paused|…
```

- **Shape the VM to the code path you're testing.** The configuration record
  accepts `memory`, `cpu cores`, `hypervisor` (default true; use false for TCG),
  `uefi`, `drives` (`{{guest size:<MiB>}}`, or `{{removable:true, source:POSIX file "…"}}`
  for an ISO), `network interfaces`, `serial ports`, `displays`
  (`{}` for headless, or `hardware:"virtio-ramfb"` to use the 2D path instead of
  GL), and `qemu additional arguments`.
- **Apple backend:** `{backend:apple, configuration:{name:"…"}}` creates a Linux
  VM with no display. The full vocabulary is in `Scripting/UTM.sdef`.
- **Change the configuration** of a stopped VM:
  1. `set c to configuration of vm`
  2. Edit fields of `c`.
  3. `update configuration of vm with c`.

  Lists such as `drives` are replaced whole, so any element you leave out is
  removed.
- **Other verbs:**
  - `start … saving false`: disposable run.
  - `stop … by force|kill|request`.
  - `suspend … saving true`.
  - `duplicate virtual machine named "X" with properties {configuration:{name:"Y"}}`.
    `duplicate` returns before the bundle exists on disk.
  - `$APP/Contents/MacOS/utmctl` has the same verbs. It exits 0 even when it
    fails, so read its output. It hangs if UTM's main thread is blocked.
- **When testing a new verb or parameter, try it on your throwaway VM first.**
  Confirm that the new parameter takes effect before you point it anywhere else.
  A `delete` on a child object that can't be resolved has been applied to the
  parent VM.
- **Bundles** are at `~/Library/Containers/com.utmapp.UTM/Data/Documents/<name>.utm`
  (`config.plist`, `Data/`). If you edit `config.plist` by hand, quit UTM first.
  For plists that contain dates or data, use `plutil -p` or PlistBuddy; `plutil -convert json`
  fails on them.

### Verify it really worked

A `started` status proves only that the process launched.

- **Screenshot the VM window by ID.** This works even when other windows cover it.
  Look at the image; don't assume.

  ```sh
  WID=$(osascript -l JavaScript -e "ObjC.import('CoreGraphics'); ObjC.deepUnwrap(ObjC.castRefToObject(\$.CGWindowListCopyWindowInfo(\$.kCGWindowListOptionAll, 0))).filter(w => w.kCGWindowOwnerName == 'UTM' && w.kCGWindowName == '$VM' && w.kCGWindowIsOnscreen).map(w => w.kCGWindowNumber).join('\n')")
  screencapture -x -o -l "$WID" "$SCRATCH/vm.png" && sips -Z 1200 "$SCRATCH/vm.png"
  ```

  - A healthy run shows the EDK2 banner, `Mapping table`, and `Shell>`.
  - A black, torn, or frozen frame is a real failure.
  - Use `kCGWindowName == 'UTM'` for the library window. Don't match on size: a
    500×500 offscreen helper window also exists.
  - A disposable run's window is titled "<VM> – Disposable Mode" in
    Accessibility, but "<VM>" here.
- **Serial I/O without the GUI:** the default ptty serial port carries the
  firmware console both ways.

  ```sh
  P=$(utm "get address of serial port 1 of virtual machine named \"$VM\"")
  cat "$P" > "$SCRATCH/serial.txt" &
  printf 'ver\r' > "$P"
  ```

  The shell's reply lands in `serial.txt`, with ANSI escapes.
- **Check the status again** after the checks above. A guest that crashed can
  still report `started` for a moment.
- **Performance:** measure before and after in the same session, and re-run
  outliers. Say whether Debug Log was on (see below).

### Clean up

```sh
utm "stop virtual machine named \"$VM\" by force"
until [ "$(utm "get status of virtual machine named \"$VM\"")" = stopped ]; do sleep 1; done
utm "delete virtual machine named \"$VM\""        # no confirmation; refused while running
utm quit; pkill caffeinate
pgrep -fl "MacOS/UTM|QEMULauncher"                 # expect nothing of yours
```

- `quit` fails with -128 while any VM is running or paused, because a
  confirmation dialog blocks it.
- `pkill` on UTM can orphan `QEMULauncher`, which keeps `efi_vars.fd` locked
  ("Is another process using the image"). Kill any leftover launcher of yours.
- Remove every temporary hook, log line, and dependency-tree edit. `/utm-review`
  flags stray diagnostics, and `git status` doesn't see the gitignored `build-*`
  trees. Tag temporary code with a marker you can grep for.

## Observe and debug

- **App stdout is the main log.** Everything `QEMULogging` receives is `NSLog`ed
  there: the QEMU command line and environment, `[CocoaSpice]`, `GSpice-*`, QMP,
  and app logging.
- **`Data/debug.log` in the bundle** only gets the launch header, even with Debug
  Log on.
- **The unified log:**
  `log show --last 5m --info --debug --style compact --predicate 'process IN {"UTM","QEMUHelper","QEMULauncher"}'`.
  Use `/usr/bin/log` in zsh, where `log` is a builtin.
- **Swift `logger.debug` is hidden** at the default level. Temporarily set
  `logLevel` to `.debug` in `Services/UTMLoggingSwift.swift`, and don't commit it.
- **To get output from CocoaSpice**, use `g_message()`, which always passes the
  handler in `CSMain.m`. `g_debug()` output only appears with SPICE debugging on.
- **QEMU's own stderr reaches no log.** QEMU runs in `QEMULauncher` under
  `QEMUHelper` (XPC), sandboxed, with an environment built explicitly by
  `Services/UTMQemuSystem.m`. It does not inherit the app's environment.
  - To trace inside QEMU, write to a file in
    `~/Library/Group Containers/WDNLXAD4W8.com.utmapp.UTM/`.
  - To pass an environment variable to QEMU, add it in `UTMQemuSystem.m`
    temporarily.
  - `ps eww -p <launcher pid>` shows what QEMU actually got.
- **The VM's Debug Log setting** injects `MTL_DEBUG_LAYER`, `MVK_DEBUG`,
  `VK_LOADER_DEBUG`, `MESA_DEBUG`, and `VIRGL_LOG_LEVEL` into QEMU, which costs
  performance.
- **Hangs:** run `sample <pid> 2 -file "$SCRATCH/utm.sample"` and read the main
  thread's stack.
- **Crashes:** reports are at `~/Library/Logs/DiagnosticReports/UTM*.ips`. The file
  is JSON after the first line; use `threads[<triggered>].frames` together with
  `usedImages`.
- **lldb:** the Debug build has `get-task-allow`, so you can attach and script it:
  `lldb -p $(pgrep -f "Debug/UTM.app/Contents/MacOS/UTM$") --batch -o '…' -o detach`.
  - Give breakpoints `-G true` (auto-continue). A breakpoint that stops freezes
    UTM, and every scripted step then hangs.
  - A slow app may simply have a debugger attached.
- **Hard-to-reach UI states:** add a temporary environment-variable hook, such as
  selecting a VM or switching a tab in `ContentView.onAppear`. Launch with
  `env UTM_TMP_X=… "$APP/Contents/MacOS/UTM"`, then remove the hook.
- **Stale state:** AppKit and user defaults can mask a change. The VM registry is
  in `defaults read com.utmapp.UTM Registry`. Toolbars are autosaved under
  `NSToolbar Configuration <id>`.

## Headless GUI input (macOS)

- **System Events clicks** don't register on SwiftUI lists, menu extras, and some
  toolbar items. Build a small `swiftc` tool instead: post `.mouseMoved`, wait
  about 100 ms, then post `.leftMouseDown` and `.leftMouseUp` through
  `CGEvent(mouseEventSource:…).post(tap: .cghidEventTap)`.
- **Coordinates are points.** Retina screenshots are 2× that, so downscale with
  `sips -Z <screen width in points>` to make image pixels match points.
- **Bring UTM to the front** before each click, and take a screenshot after each
  click to check what happened:
  `tell application "System Events" to set frontmost of process "UTM" to true`.
- **Typing into guests:** send text slowly. The Virtualization.framework view
  drops shifted characters and some punctuation from `keystroke`, so use
  `key code` or choose commands that don't need them.
- **Locked screen:** check with `ioreg -n Root -d1 -a | grep -A1 CGSSessionScreenIsLocked`.
  - While the screen is locked, input and Accessibility do nothing, and window
    capture may fail too.
  - Fall back to serial or logs, or ask the user to unlock.
  - System consent dialogs belong to `UserNotificationCenter` and don't appear
    while the display sleeps.
- **Launch method:** `open -a "$APP"` makes UTM the responsible process for
  privacy prompts. Launching the binary from a shell makes the terminal
  responsible instead, but `open` loses the stdout log.

## iOS simulator

```sh
xcodebuild -project UTM.xcodeproj -scheme iOS -configuration Debug -destination "platform=iOS Simulator,id=$UDID" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build     # needs sysroot-iOS_Simulator-arm64
IOSAPP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/UTM-*/Build/Products/Debug-iphonesimulator/UTM.app | head -1)
xcrun simctl boot $UDID; xcrun simctl bootstatus $UDID -b; xcrun simctl install $UDID "$IOSAPP"
xcrun simctl spawn $UDID defaults write com.utmapp.UTM ReleaseNotesLastVersion \
    "$(defaults read "$IOSAPP/Info.plist" CFBundleShortVersionString)"   # skip What's New
```

- **Use a device you created** with `simctl create`, and run one simulator at a
  time. Parallel simulators hang `simctl`.
- **Boot errors:** if boot fails with "Invalid argument" or the device wedges,
  run `simctl shutdown`, boot again, and wait for `bootstatus`.
- **Seed a VM:** create one on macOS as above, then copy it with `cp -c -R` into
  `$(xcrun simctl get_app_container $UDID com.utmapp.UTM data)/Documents/`.
  Resolve that path each time, because it changes on reinstall.
- **There is no scripting on iOS.** Drive the app with a temporary
  environment-variable hook, passed as `SIMCTL_CHILD_<VAR>=… xcrun simctl launch …`.
  For taps, use a throwaway XCUITest target (`bundle.ui-testing`, no host app)
  run with `test-without-building`.
- **Observe:** `xcrun simctl io $UDID screenshot out.png`, and
  `xcrun simctl spawn $UDID log show --last 2m --style compact --predicate 'process == "UTM"'`.
  lldb can't attach, because UTM ptraces itself for JIT.
- **iOS runs QEMU in-process, once per process.** Stopping a VM quits the app.
- **Clean up:** `xcrun simctl shutdown $UDID`, and delete any device you created.
