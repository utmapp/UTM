# Dependencies

UTM is built upon QEMU, SPICE, and various libraries that those projects depend on. To support building as an Xcode project, we designed a custom build system that creates Xcode compatible frameworks from autoconf and meson projects.

## `build_dependencies.sh`

The build script sets up a build environment for the target platform and architecture.

```
Usage: [VARIABLE...] build_dependencies.sh [-p platform] [-a architecture] [-q qemu_path] [-d] [-r]

  -p platform      Target platform. Default ios. [ios|ios_simulator|ios-tci|ios_simulator-tci|macos]
  -a architecture  Target architecture. Default arm64. [armv7|armv7s|arm64|i386|x86_64]
  -q qemu_path     Do not download QEMU, use qemu_path instead.
  -d, --download   Force re-download of source even if already downloaded.
  -r, --rebuild    Avoid cleaning build directory.

  VARIABLEs are:
    SDKVERSION     Target a specific SDK version.
    CHOST          Configure host, set if not deducable by ARCH.

    CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
```

The build steps are summarized below:

1. It will attempt to detect if your build system has all the required tools before starting.
2. All source archives in [patches/sources](../patches/sources) are downloaded if not found. If the download is a Git repository, it is cloned and the right commit is checked out.
3. If found, the `.patch` file in [patches](../patches/) with the corresponding name is applied to each download.
4. Each dependency is configured, built, and installed to the sysroot directory.
5. Once all libraries are built, they are converted to a .framework. The id and library dependencies are patched to be relative to @rpath (using `install_name_tool`).
6. The QAPI sources are generated using [scripts/qapi-gen.py](../scripts/qapi-gen.py).

## Updating dependencies

### QEMU

The steps for updating QEMU is the most involved. UTM maintains a [fork][1] of QEMU which the updated QEMU version must be merged into. This will be the most time consuming part as the fork needs to build and run correctly outside of UTM.

Next, the QAPI generator for UTM needs to be updated with the changes from QEMU. The UTM [QAPI script](../scripts/qapi/) is derived from QEMU's `scripts/qapi/*`. Many of the files are unchanged and copied directly from QEMU. However, the key files (commands.py, events.py, types.py) are heavily modified. The best way to approach this is to do a 3-way diff with the UTM files, the version of QEMU where those files are derived from, and the new version of the scripts. Then take the changes from the old version of QEMU to the new version of QEMU and merge it into UTM. For files where there are no changes between UTM and QEMU, the new version from QEMU can be copied to directly. For files where there are changes, some work is required to integrate the changes. From experience, it may be easiest to do incremental changes from QEMU's commits. Also, QAPI does not change often so it is not required to update the scripts after each QEMU update.

As a result of the above, the [QAPI support files](../qapi/) may also need to be updated. Check with QEMU `qapi/*.c`'s commit history to see if there's any changes needed there. It will usually correspond to changes in the Python generator code.

[UTMQemuConfiguration+ConstantsGenerated.m](../Configuration/UTMQemuConfiguration+ConstantsGenerated.m) needs to be updated by running [const-gen.py](../scripts/const-gen.py). You need to build the [UTM fork of QEMU][1] for macOS and pass the build directory as an argument to const-gen. It will then run each QEMU executable in order to parse the help text to find changes in device support. If QEMU adds or removes a supported architecture, this must be manually changed in the const-gen script.

Finally, make sure to rename the [binary patches](../patches/data) directory to the new QEMU version. The code patch for the previous QEMU version can be deleted if all the changes have been integrated into the UTM fork of QEMU.

### Others

The other dependencies are more straightforward. Take the latest release tarball and re-integrate the UTM patches if needed. The UTM [GitHub][2] will usually keep forks of projects it depends on with required patches. The UTM changes should be rebased off of the commit corresponding to the latest release of the project. Then `git format-patch` can be used to generate the patch file which will be applied to the release tarball.

[1]: https://github.com/utmapp/qemu
[2]: https://github.com/utmapp
