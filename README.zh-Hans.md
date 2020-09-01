# UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> 发明一台可以用来计算任何可计算序列的机器是完全有可能的。

-- <cite>图灵（Alan Turing）, 1936年</cite>

UTM是一个功能齐全的iOS虚拟机主机。简而言之，它允许你在iPhone和iPad上运行Windows、Android、Ubuntu等操作系统。更多信息请访问https://getutm.app/

![在iPhone上运行UTM的截图][4]

## 特性

* 支持30+处理器，包括x86_64、ARM64和RISC-V，这要归功于后端qemu
* 得益于SPICE，通过准虚拟化实现了快速的本地图形
* 使用qemu TCG实现基于JIT的加速
* Frontend使用最新最好的api为iOS11+从零开始设计
* 直接从设备创建、管理和运行虚拟机
* 不需要越狱!

## 安装

如果您只是想使用UTM，这不是正确的地方!请访问https://getutm.app/install/ 来获取引导.

## 编译

请确保您已经clone子模块，请先clone子模块：`git submodule update --init --recursive`.

### 简单的

获取依赖项的推荐方法是使用[Github操作生成的构件][5].查找最新的版本构建并从arm64构建(用于iOS)或x86_64构建(用于Mac上的iOS模拟器)下载Sysroot工件。然后将Sysroot解压到UTM的根目录.然后就可以打开`UTM.xcodeproj`,选择您的签名证书，然后从Xcode运行并编译安装UTM。

### 高级的

如果您想自己构建依赖项，强烈建议您从一个全新的macOS VM开始。这是因为一些依赖项试图使用`/usr/local/lib`尽管架构并不匹配。某些已安装的库如`libusb`和`gawk`将破坏构建。
0. 还没安装brew的，运行命令以安装brew
`ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"`
1. 使用`brew`安装Xcode命令行和以下构建条件
`brew install bison pkg-config gettext glib libgpg-error nasm`
请确保将“bison”添加到您的“$PATH”环境中!
2. 如果你还没有clone子模块，运行以下命令
`git submodule update --init --recursive` 
3. 运行 `./scripts/build_dependencies.sh`来开始编译.如果为Mac的iOS设备模拟器构建，运行 `./scripts/ build_dependences .sh -a x86_64  `。
4. 打开`UTM.xcodeproj`并选择您的签名证书。
5. 从Xcode构建和部署。

## 签名

如果使用Xcode进行构建，则应该自动完成签名。由于签名错误，不支持iOS 13.3.1。您可以使用低于或高于13.3.1的任何版本。

### 签名版本

`ipa`[签名][3]是假的签名。如果你是越狱，你不应该签名它，您可以直接使用Filza进行安装。
如果您想要为库存设备签署发行版，有多种方法。推荐使用[iOS应用签名者][2]。注意，许多“云”签名服务(如AppCake)都存在一些已知的问题，而且它们与UTM不兼容。如果在试图启动VM虚拟机时发生崩溃（如闪退），那么您的签名证书是无效的。
在技术细节上，有两种签名证书:“开发”和“发布”。UTM需要“开发”，而“开发”具有“获得任务许可”的权利。

### 签名开发

如果你想要签署一个xcarchive，例如从[Github Actions][1]中编译构建，你可以使用以下命令:

```
./scripts/resign.sh UTM.xcarchive outputPath PROFILE_NAME TEAM_ID
```

其中`PROFILE_NAME`是配置配置文件的名称，而`TEAM_ID`是配置配置文件中团队名称旁边的标识符。确保签名密钥被导入到您的密钥链中，并且条款配置文件已安装在您的iOS设备上。

如果你有一个越狱的设备，你也可以伪造签名(安装了“ldid”):

```
./scripts/resign.sh UTM.xcarchive outputPath
```
## UTM使用注意事项

1. ISO镜像要开启CD/DVD选项
2. 虚拟硬盘文件不要开CD/DVD选项
3. 启动app时白屏需要重启iOS设备

## 为什么UTM不在AppStore中?

苹果不允许任何解释或生成代码的应用程序在AppStore中上架，因此UTM不太可能被允许上架。然而，人们在互联网上有各种各样的方式来获得不需要越狱就能加载的应用程序。我们支持这些方法中的任何一种。

## 许可

UTM是在Apache 2.0许可下发布的。但是，它使用几个(L)GPL组件。大多数插件是动态链接的，但gstreamer插件是静态链接的，部分代码取自qemu。如果您打算重新分发此应用程序，请注意这一点。

[1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
[2]: https://dantheman827.github.io/ios-app-signer/
[3]: https://github.com/utmapp/UTM/releases
[4]: screen.png
[5]: https://github.com/utmapp/UTM/actions?query=workflow%3ABuild+event%3Arelease+is%3Asuccess

