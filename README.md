#  UTM

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured virtual machine host for iOS. In short, it allows you to run Windows, Android, and more on your iPhone and iPad.

## Features

* 30+ processors supported including x86_64, ARM64, and RISC-V thanks to qemu as a backend
* Fast native graphics through para-virtualization thanks to SPICE
* JIT based acceleration using qemu TCG
* Frontend designed from scratch for iOS11+ using the latest and greatest APIs
* Create, manage, run VMs directly from your device
* No jailbreak required!

## Building

1. Install Xcode command line and the following build prerequisites
    `brew install bison pkg-config gettext glib`
   Make sure to add `bison` to your `$PATH` environment!
2. `git submodule update --init --recursive` if you haven't already
3. Run `./build_dependencies.sh` and wait for everything to build
4. Open `UTM.xcodeproj` and select your signing certificate
5. Build and deploy from Xcode

## Why isn't this in the AppStore?

Apple does not permit any apps that has interpreted or generated code therefore it is unlikely that UTM will ever be allowed. However, there are various ways people on the internet have come up to side load apps without requiring a jailbreak. We do not condone or support any of these methods.

## License

UTM is distributed under the permissive Apache 2.0 license. However, it uses several (L)GPL components. Most are dynamically linked but the gstreamer plugins are LGPL and statically linked. Please be aware of this if you intend on redistributing this application.

Several CC BY-SA 4.0 licensed icons are obtained from [www.flaticon.com](www.flaticon.com) and used in this project.

* [Smashicons](https://smashicons.com/)
* [freepik](https://www.freepik.com/)
* [mynamepong](https://www.flaticon.com/authors/mynamepong)
* [Pixel Buddha](https://www.flaticon.com/authors/pixel-buddha)
* [Those Icons](https://www.flaticon.com/authors/those-icons)
* [Google](https://www.flaticon.com/authors/google)
