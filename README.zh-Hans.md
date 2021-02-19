# UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> 发明一台可以用来计算任何可计算序列的机器是完全有可能的。
-- <cite>图灵（Alan Turing）, 1936年</cite>

UTM是一个功能齐全的iOS虚拟机。简而言之，它允许你在iPhone和iPad上运行Windows、Android、Ubuntu等操作系统。更多信息请访问https://getutm.app/

![在iPhone上运行UTM的截图](https://kyun.ltyuanfang.cn/tc/2020/08/16/b71e7b3b8d695.png)

## 特征

* 支持30+处理器，包括x86_64、ARM64和RISC-V，这要归功于后端qemu
* 得益于SPICE，通过准虚拟化实现了快速的本地图形
* 使用qemu TCG实现基于JIT的加速
* 前端使用最新最好的应用程序接口(API)为iOS11+从零开始设计
* 直接从设备上创建、管理和运行虚拟机
* iOS11.0~14.3不需要越狱!（iOS 14.4+需要）

## 安装

如果您只是想使用UTM，请访问https://getutm.app/install/ 来获取引导.

## 编译(iOS)

要在iOS14上运行UTM而不越狱（以及在任何iOS版本上开发UTM），必须附加Xcode调试器。

### 简单的

获取依赖项的推荐方法是使用[Github操作生成的构件][4].查找最新的版本构建并从arm64构建(用于iOS)或x86_64构建(用于Mac上的iOS模拟器)下载Sysroot工件。然后将Sysroot解压到UTM的根目录.然后就可以打开`UTM.xcodeproj`,选择您的签名证书，然后从Xcode运行并编译安装UTM。

### 高级的

如果您想自己构建依赖项，强烈建议您从一个全新的macOS VM开始。这是因为一些依赖项尽管架构并不匹配，仍试图使用`/usr/local/lib`。某些已安装的库如`libusb`和`gawk`将破坏构建。
1. 使用`brew`安装Xcode命令行和以下构建条件
`brew install bison pkg-config gettext glib libgpg-error nasm make meson`
并且请确保将“bison”添加到您的“$PATH”环境中!
2. 如果你还没有clone子模块，运行以下命令
`git submodule update --init --recursive` 
3. 运行 `./scripts/build_dependencies.sh`以开始编译。如果为Mac的iOS设备模拟器构建，请运行 `./scripts/ build_dependences .sh -a x86_64  `。
4. 打开`UTM.xcodeproj`并选择您的签名证书。
5. 从Xcode构建和部署。

## 编译(MacOS)

基本上与iOS相同，但有以下更改：

* 要在Intel平台上建立依赖关系，请运行 `./scripts/build_dependencies.sh -p macos -a x86_64`
* 要建立对苹果arm平台的依赖，请运行 `./scripts/build_dependencies.sh -p macos -a arm64`

您也可以从Github下载预构建的依赖项。

## 签名(iOS)

如果使用Xcode进行构建，则应该自动完成签名。由于iOS签名的错误导致不支持iOS 13.3.1。您可以使用低于或高于13.3.1的任何版本。

在Github [Release][3]页面的`ipa`是伪签名。如果您越狱了，您不需要签名它，您可以直接使用越狱软件Filza进行安装。
如果您想要为备用设备签名正式版，有多种方法。推荐使用[iOS App Signer][2]。注意，许多“在线”签名服务(如AppCake)都存在一些已知的问题，而且它们与UTM不兼容。如果在试图启动VM虚拟机时发生崩溃（如闪退），那么您的签名证书是无效的。
>译者注：据反馈，使用` i4Tools(即爱思助手) `生成的开发者证书签名的ipa也大概率无法正常使用

在技术细节上，有两种签名证书:“开发证书”和“分发证书”。UTM需要“开发证书”，而“开发证书”具有`get-task-allow `的权利。
>译者注：开发证书即苹果开发者证书，分发证书即企业证书

### 签名开发版

如果你想要给一个` xcarchive `签名，例如从[Github Actions][1]中编译Build，你可以使用以下命令:

```
./scripts/package.sh signedipa UTM.xcarchive outputPath PROFILE_NAME TEAM_ID
```

其中`PROFILE_NAME`是配置文件的名称，而`TEAM_ID`是配置文件中结构名称旁边的标识符。确保签名密钥已被导入到您的密钥链中，并且配置文件已安装在您的iOS设备上。

如果你有一个越狱的设备，你也可以伪造签名(安装了“ldid”插件):

```
./scripts/package.sh ipa UTM.xcarchive outputPath
```
## UTM使用注意事项

1. ISO镜像要开启CD/DVD选项
2. 虚拟硬盘文件不要开CD/DVD选项
3. 启动app时白屏需要重启您的iOS设备

## 为什么UTM不在App Store中?

苹果不允许大部分解释或生成代码的应用程序在App Store中上架，因此UTM不太可能被允许上架。然而，人们在互联网上有各种各样的方式来获得不需要越狱就能下载的应用程序。我们支持这些方法中的任何一种。

## 许可

UTM是在Apache 2.0许可下发布的。但是，它使用了几个(L)GPL组件。大多数插件是动态链接的，但gstreamer插件是静态链接的，部分代码来自qemu。如果您打算重新分发此应用程序，请注意这一点。

[1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
[2]: https://dantheman827.github.io/ios-app-signer/
[3]: https://github.com/utmapp/UTM/releases
[4]: https://github.com/utmapp/UTM/actions?query=workflow%3ABuild+event%3Arelease+is%3Asuccess
