#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> 发明一台可用于计算任何可计算序列的机器是可行的。

-- <cite>艾伦·图灵（Alan Turing），1936 年</cite>

UTM 是适用于 iOS 和 macOS 的全功能系统模拟器和虚拟机主机。它基于 QEMU。简而言之，它允许你在 Mac、iPhone 和 iPad 上运行 Windows、Linux 等。有关更多信息，请访问 https://getutm.app/ 与 https://mac.getutm.app/

<p align="center">
  <img width="450px" alt="在 iPhone 上运行的 UTM" src="screen.png">
  <br>
  <img width="450px" alt="在 MacBook 上运行的 UTM" src="screenmac.png">
</p>

## 特色

* 使用 QEMU 的全系统模拟（MMU、设备等）
* 支持 30+ 处理器，包括 x86_64、ARM64 和 RISC-V
* 使用 SPICE 和 QXL 的 VGA 图形模式
* 文本终端模式
* USB 设备
* 使用 QEMU TCG 的基于 JIT 的加速
* 采用最新最好的 API，为 macOS 11+ 和 iOS 11+ 从头开始设计前端
* 直接从你的设备创建、管理、运行虚拟机

## 其他 macOS 功能

* 使用 Hypervisor.framework 和 QEMU 的硬件加速虚拟化
* 在 macOS 12+ 上使用 Virtualization.framework 启动 macOS 客户机

## UTM SE

UTM/QEMU 需要动态代码生成（JIT）才能获得最佳性能。iOS 设备上的 JIT 需要越狱设备，或为特定版本的 iOS 找到的各种变通方法之一（有关更多详细信息，请参阅“安装”）。

UTM SE（“较慢版”）使用[线程解释器][3]，其性能优于传统解释器，但仍然比 JIT 慢。这种技术与 [iSH][4] 用于动态执行的技术相似。因此，UTM SE 不需要越狱或任何 JIT 变通办法，且可以作为常规应用程序侧载。

为了优化大小和构建时间，UTM SE 中仅包含以下架构：ARM、PPC、RISC-V 和 x86（均有 32 位和 64 位变体）。

## 安装

适用于 iOS 的 UTM (SE)：https://getutm.app/install/

UTM 也适用于 macOS：https://mac.getutm.app/

## 开发

### [macOS 开发](Documentation/MacDevelopment.md)

### [iOS 开发](Documentation/iOSDevelopment.md)

## 相关项目

* [iSH][4]：模拟用户模式 Linux 终端接口，用于在 iOS 上运行 x86 Linux 应用程序
* [a-shell][5]：为 iOS 原生构建的通用 Unix 命令和实用程序，可通过终端接口访问

## 许可

UTM是在宽容的Apache 2.0许可证下分发的。然而，它使用了若干个 (L)GPL 组件。大多数是动态链接的，但 gstreamer 插件是静态链接的，部分代码取自 QEMU。若要打算重新分发此应用程序，请注意这一点。

某些图标由 [Freepik](https://www.freepik.com) 从 [www.flaticon.com](https://www.flaticon.com/) 制作。

此外，UTM 前端依赖于以下 MIT/BSD 许可的组件：

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
