#  UTM(English)
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured virtual machine host for iOS. In short, it allows you to run Windows, Android, and more on your iPhone and iPad. More information at https://getutm.app/

![Screenshot of UTM running on iPhone][4]

## Features

* 30+ processors supported including x86_64, ARM64, and RISC-V thanks to qemu as a backend
* Fast native graphics through para-virtualization thanks to SPICE
* JIT based acceleration using qemu TCG
* Frontend designed from scratch for iOS11+ using the latest and greatest APIs
* Create, manage, run VMs directly from your device
* No jailbreak required!

## Install

If you just want to use UTM, this is not the right place! Visit https://getutm.app/install/ for directions.

## Building

Make sure you have cloned with submodules `git submodule update --init --recursive`.

### Easy

The recommended way to obtain the dependencies is to use the built artifacts from [Github Actions][5]. Look for the latest release build and download the Sysroot artifact from either the arm64 build (for iOS) or x86_64 build (for iOS Simulator). Then unzip the artifact to the root directory of UTM. You can then open `UTM.xcodeproj`, select your signing certificate, and then run UTM from Xcode.

### Advanced

If you want to build the dependencies yourself, it is highly recommended that you start with a fresh macOS VM. This is because some of the dependencies attempt to use `/usr/local/lib` even though the architecture does not match. Certain installed libraries like `libusb` and `gawk` will break the build.

1. Install Xcode command line and the following build prerequisites
    `brew install bison pkg-config gettext glib libgpg-error nasm`
   Make sure to add `bison` to your `$PATH` environment!
2. `git submodule update --init --recursive` if you haven't already
3. Run `./scripts/build_dependencies.sh` to start the build. If building for the simulator, run `./scripts/build_dependencies.sh -a x86_64` instead.
4. Open `UTM.xcodeproj` and select your signing certificate
5. Build and deploy from Xcode

## Signing

If you build with Xcode, signing should be done automatically. iOS 13.3.1 is NOT supported due to a signing bug. You can use any version lower or higher than 13.3.1.

### Signing Release

The `ipa` [releases][3] are fake-signed. If you are jailbroken, you should NOT sign it. You can install directly with Filza.

If you want to sign the release for stock devices, there are a variety of ways. The recommended way is with [iOS App Signer][2]. Note there are known issues with many "cloud" signing services such as AppCake and they do not work with UTM. If you get a crash while trying to launch a VM, then your signing certificate was invalid.

In more technical detail, there are two kinds of signing certificates: "development" and "distribution". UTM requires "development" which has the `get-task-allow` entitlement.

### Signing Development Build

If you want to sign an `xcarchive` such as from a [Github Actions][1] built artifact, you can use the following command:

```
./scripts/resign.sh UTM.xcarchive outputPath PROFILE_NAME TEAM_ID
```

Where `PROFILE_NAME` is the name of the provisioning profile and `TEAM_ID` is the identifier next to the team name in the provisioning profile. Make sure the signing key is imported into your keychain and the provision profile is installed on your iOS device.

If you have a jailbroken device, you can also fake-sign it (with `ldid` installed):

```
./scripts/resign.sh UTM.xcarchive outputPath
```

## Why isn't this in the AppStore?

Apple does not permit any apps that have interpreted or generated code therefore it is unlikely that UTM will ever be allowed. However, there are various ways people on the internet have come up to sideload apps without requiring a jailbreak. We do not condone or support any of these methods.

## License

UTM is distributed under the permissive Apache 2.0 license. However, it uses several (L)GPL components. Most are dynamically linked but the gstreamer plugins are statically linked and parts of the code are taken from qemu. Please be aware of this if you intend on redistributing this application.



# UTM(Chinese)
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> 发明一台可以用来计算任何可计算序列的机器是完全有可能的。

-- <cite>Alan Turing, 1936</cite>

UTM是一个功能齐全的iOS虚拟机主机。简而言之，它允许你在iPhone和iPad上运行Windows、Android等操作系统。更多信息请访问https://getutm.app/

![Screenshot of UTM running on iPhone][4]

## 特性

* 支持30+处理器，包括x86_64、ARM64和RISC-V，这要归功于后端qemu
* 得益于SPICE，通过准虚拟化实现了快速的本地图形
* 使用qemu TCG实现基于JIT的加速
* Frontend使用最新最好的api为iOS11+从零开始设计
* 直接从设备创建、管理和运行虚拟机
* 不需要越狱!

## 安装

如果您只是想使用UTM，这不是正确的地方!请访问https://getutm.app/install/ for directions.

## 编译

请确保您已经clone子模块 `git submodule update --init --recursive`.

### 简单的

获取依赖项的推荐方法是使用[Github操作生成的构件][5].查找最新的版本构建并从arm64构建(用于iOS)或x86_64构建(用于iOS模拟器)下载Sysroot工件。然后将Sysroot解压缩到UTM的根目录.然后就可以打开`UTM.xcodeproj`,选择您的签名证书，然后从Xcode运行UTM。

### 高级的

如果您想自己构建依赖项，强烈建议您从一个全新的macOS VM开始。这是因为一些依赖项试图使用`/usr/local/lib`尽管架构并不匹配。某些已安装的库如`libusb`和`gawk`将破坏构建。

1. 安装Xcode命令行和以下构建先决条件
`brew install bison pkg-config gettext glib libgpg-error nasm`
请确保将“bison”添加到您的“$PATH”环境中!
2. `git submodule update --init --recursive` 如果你还没有。
3. 运行 `./scripts/build_dependencies.sh`来开始编译.如果为模拟器构建，运行 `./scripts/ build_dependences .sh -a x86_64  `。
4. 打开`UTM.xcodeproj`并选择您的签名证书。
5. 从Xcode构建和部署。

## 签名

如果使用Xcode进行构建，则应该自动完成签名。由于签名错误，不支持iOS 13.3.1。您可以使用低于或高于13.3.1的任何版本。

### 签名版本

`ipa`[签名][3]是fake-signed。如果你是越狱，你不应该签名它，您可以直接使用Filza进行安装。
如果您想要为库存设备签署发行版，有多种方法。推荐使用[iOS应用签名者][2]。注意，许多“云”签名服务(如AppCake)都存在一些已知的问题，而且它们与UTM不兼容。如果在试图启动VM虚拟机时发生崩溃（如闪退），那么您的签名证书是无效的。
在技术细节上，有两种签名证书:“开发”和“发布”。UTM需要“开发”，而“开发”具有“获得任务许可”的权利。

### 签名开发

如果你想要签署一个xcarchive，例如从[Github Actions][1] built artifact，你可以使用以下命令:

```
./scripts/resign.sh UTM.xcarchive outputPath PROFILE_NAME TEAM_ID
```

其中`PROFILE_NAME`是配置配置文件的名称，而`TEAM_ID`是配置配置文件中团队名称旁边的标识符。确保签名密钥被导入到您的密钥链中，并且条款配置文件已安装在您的iOS设备上。

如果你有一个越狱的设备，你也可以伪造签名(安装了“ldid”):

```
./scripts/resign.sh UTM.xcarchive outputPath
```

## 为什么UTM不在AppStore中?

苹果不允许任何解释或生成代码的应用程序，因此UTM不太可能被允许。然而，人们在互联网上有各种各样的方式来获得不需要越狱就能加载的应用程序。我们不宽恕或支持这些方法中的任何一种。

## 许可

UTM是在许可的Apache 2.0许可下发布的。但是，它使用几个(L)GPL组件。大多数插件是动态链接的，但gstreamer插件是静态链接的，部分代码取自qemu。如果您打算重新分发此应用程序，请注意这一点。

--Translated by Ty

[1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
[2]: https://dantheman827.github.io/ios-app-signer/
[3]: https://github.com/utmapp/UTM/releases
[4]: screen.png
[5]: https://github.com/utmapp/UTM/actions?query=workflow%3ABuild+event%3Arelease+is%3Asuccess
