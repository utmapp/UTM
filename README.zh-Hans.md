#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> 发明一台可用于计算任何可计算序列的机器是可行的。
-- <cite>艾伦·图灵（Alan Turing）, 1936 年</cite>

UTM 是一个功能齐全的系统模拟器和虚拟机主机，适用于 iOS 和 macOS。它基于 QEMU。简而言之，它允许您在 Mac、iPhone 和 iPad 上运行 Windows、Linux 等。更多信息请访问 https://getutm.app/ 和 https://mac.getutm.app/。

<p align="center">
  <img width="450px" alt=“在 iPhone 上运行 UTM" src="screen.png">
  <br>
  <img width="450px" alt=“在 MacBook 上运行 UTM" src="screenmac.png">
</p>

## 特性

* 使用 QEMU 进行全系统模拟（MMU、设备等）
* 支持三十余类处理器，包括 x86_64、ARM64 和 RISC-V
* 使用 SPICE 和 QXL 的 VGA 图形模式
* 文本终端模式
* USB 设备
* 使用 QEMU TCG 进行基于 JIT 的加速
* 采用了最新、最好的 API，从零开始设计前端，支持 macOS 11+ 和 iOS 11+
* 直接从你的设备上创建、管理和运行虚拟机

## macOS 的附加功能

* 使用 Hypervisor.framework 和 QEMU 实现硬件加速虚拟化
* 在 macOS 12+ 上使用 Virtualization.framework 来启动 macOS 客户机

## UTM SE

UTM/QEMU 需要动态代码生成（JIT）以获得最大性能。iOS 设备上的 JIT 需要已经越狱的设备（iOS 11.0~14.3 不需要越狱，iOS 14.4+ 需要），或者为特定版本的 iOS 找到的其他变通办法之一（有关更多详细信息，请参阅“安装”）。

UTM SE（“较慢版”）使用了“[线程解释器][3]”，其性能优于传统解释器，但仍然比 JIT 要慢。这种技术类似于 [iSH][4] 的动态执行。因此，UTM SE 不需要越狱或任何 JIT 的变通方法，可以作为常规应用程序侧载。

为了优化大小和构建时间，UTM SE 中只包含以下架构：ARM、PPC、RISC-V 和 x86（均包含 32 位和 64 位）。

## 安装

iOS 版 UTM（SE）：https://getutm.app/install/

UTM 也支持 macOS：https://mac.getutm.app/

## 开发

### [macOS 端开发](Documentation/MacDevelopment.md)

### [iOS 端开发](Documentation/iOSDevelopment.md)

## 相关开源项目

* [iSH][4]：模拟用户模式 Linux 终端接口，用于在 iOS 上运行 x86 Linux 应用程序
* [a-shell][5]：为 iOS 原生构建的常用 Unix 命令和实用程序包，可通过终端界面访问

## 许可

UTM 是在 Apache 2.0 的许可证下发布的，但它使用了若干个 GPL 与 LGPL 组件。这其中的大多数组件是动态链接的，但 gstreamer 组件是静态链接的，部分代码取自 QEMU。如果你打算重新分发此应用程序，请务必注意这一点。

某些图标由 [Freepik](https://www.freepik.com) 从 [www.flaticon.com](https://www.flaticon.com/) 制作。

此外，UTM 前端依赖于以下 MIT/BSD 许可证的组件：

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

持续集成托管由 [MacStadium](https://www.macstadium.com/opensource) 提供。

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
