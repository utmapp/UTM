# UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> 发明一台可以用来计算任何可计算序列的机器是完全有可能的。
-- <cite>艾伦·图灵（Alan Turing）, 1936 年</cite>

UTM 是一款功能完备的系统模拟和虚拟机平台，适用于 iOS 和 macOS。它基于 QEMU。简而言之，它允许您在 Mac、iPhone 和 iPad 上运行 Windows、Linux 等操作系统。更多信息请参见 https://getutm.app/ 和 https://mac.getutm.app/ 。

<p align="center">
  <img width="450px" alt="在iPhone上运行UTM" src="screen.png">
  <br>
  <img width="450px" alt="在MacBook上运行UTM" src="screenmac.png">
</p>

## 功能

* 使用 QEMU 进行全系统仿真（包括 MMU、设备等）
* 支持 30 多种处理器平台，包括 x86_64、ARM64 和 RISC-V
* 使用 SPICE 和 QXL 技术的 VGA 图形模式
* 支持文本终端模式
* 支持 USB 设备
* 使用 QEMU TCG 进行基于 JIT 的加速
* 使用最新、最强大的 API，为 macOS 11 和 iOS 11+ 全新设计前端。
* 直接从您的设备上创建、管理、运行虚拟机

## macOS 版的高级功能

* 使用 Hypervisor.framework 框架和 QEMU 进行硬件加速的虚拟化
* 在 macOS 12 及更新版本上使用 Virtualization.framework 框架启动 macOS 客户机

## UTM SE

UTM/QEMU 需要动态代码生成（JIT）以获得最佳性能。要想在 iOS 设备上的使用 JIT，您的设备需要进行 Jailbreak，或为特定版本的 iOS 找到的各种变通方法之一（更多细节见 "安装"）。

UTM SE（“慢”版）使用了一款比传统解释器要好但不如 JIT 的[线程解释器][3]。该技术的实现方式类似 [iSH][4] 对于动态执行的做法。因此，UTM SE 不需要对设备进行越狱，也不需要任何 JIT 技术，可以作为一个普通的应用被侧载。

为了优化体积和编译时间，UTM SE 只支持以下架构的模拟和虚拟化：ARM、PPC、RISC-V和 x86（32 位和 64 位均支持）。

## 安装

适用于 iOS 的 UTM (SE)：https://getutm.app/install/

UTM 同样适用于 macOS：https://mac.getutm.app/

## 开发

### [macOS 开发](Documentation/MacDevelopment.md)

### [iOS 开发](Documentation/iOSDevelopment.md)

## 相关内容

* [iSH][4]：模拟用户模式 Linux 终端接口，用于在 iOS 上运行基于 x86 的 Linux 应用程序。
* [a-shell][5]：将常见的 Unix 命令和实用程序打包，为iOS原生构建，可通过终端界面访问。

## 许可证

UTM 在 Apache 2.0 许可证下发布。然而，它使用了几个 (L)GPL 组件。其中大多数是动态链接的，但gstreamer 插件是静态链接的，部分代码取自 qemu。如果你打算重新发布这个应用程序，请注意这一点。

一些图标由 [Freepik](https://www.freepik.com) 制作，来自 [www.flaticon.com](https://www.flaticon.com/)。

此外，UTM 前端以下由 MIT/BSD 许可证许可的组件：

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

由 [MacStadium](https://www.macstadium.com/opensource) 进行持续集成托管。

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

[1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
[2]: screen.png
[3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
[4]: https://github.com/ish-app/ish
[5]: https://github.com/holzschu/a-shell
