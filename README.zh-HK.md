#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> 發明一台可用於計算任何可計算序列的機器是可行的。
-- <cite>艾倫·圖靈（Alan Turing）, 1936 年</cite>

UTM 是一個功能完备的系統模擬工具和虛擬电脑主機，適用於 iOS 和 macOS。它以 QEMU 為基礎。簡言之，它允許你在 Mac、iPhone 和 iPad 上執行 Windows、Linux 等。更多訊息請參閱 https://getutm.app/ 與 https://mac.getutm.app/。

<p align="center">
  <img width="450px" alt=「在 iPhone 上執行 UTM" src="screen.png">
  <br>
  <img width="450px" alt=「在 MacBook 上執行 UTM" src="screenmac.png">
</p>

## 特性

* 使用 QEMU 進行全作業系統模擬（MMU、設備等）
* 支援逾三十種體系結構 CPU，包括 x86_64、ARM64 和 RISC-V
* 使用 SPICE 與 QXL 的 VGA 圖形模式
* 文本終端機模式
* USB 裝置
* 使用 QEMU TCG 進行基於 JIT 的加速
* 採用了最新最靚的 API，從零開始設計前端，支援 macOS 11+ 與 iOS 11+
* 從你的裝置上直接製作、管理和執行虛擬機

## macOS 的附加功能

* 使用 Hypervisor.framework 與 QEMU 實現硬件加速虛擬化
* 在 macOS 12+ 上使用 Virtualization.framework 來啓動 macOS 客戶端

## UTM SE

UTM/QEMU 需要動態程式碼生成（JIT）以得到最大性能。iOS 上的 JIT 需要已經越獄（Jailbreak）的裝置（iOS 11.0~14.3 無需越獄，iOS 14.4+ 需要），或者為特定版本的 iOS 找到其他變通方法之一（有關更多詳細訊息，請參閱「安裝」）。

UTM SE（「較慢版」）使用了「[執行緒解釋器][3]」，其性能優於傳統解釋器，但仍然比 JIT 要慢。此種技術類似於 [iSH][4] 的動態執行。因此，UTM SE 無需越獄或任何 JIT 的變通方法，可以作為常規應用程式側載（Sideload）。

為了最佳化大小與構建時間，UTM SE 中只包含以下的體系結構：ARM、PPC、RISC-V 和 x86（均包含 32 位元和 64 位元）。

## 安裝

iOS 版本 UTM（SE）：https://getutm.app/install/

UTM 同時支援 macOS：https://mac.getutm.app/

## 開發

### [macOS 版本開發](Documentation/MacDevelopment.md)

### [iOS 版本開發](Documentation/iOSDevelopment.md)

## 相關開放原始碼項目

* [iSH][4]：模擬用戶模式 Linux 終端機介面，可在 iOS 上執行 x86 Linux 應用程式
* [a-shell][5]：為 iOS 本地構建的常用 Unix 指令和實用程式包，可透過終端機介面訪問

## 許可證

UTM 於 Apache 2.0 許可證下發佈，但它採用了若干 GPL 與 LGPL 元件。這其中，大多數元件是動態連接的，但 gstreamer 元件是靜態連接的，部分程式碼來自 QEMU。如果你打算重新分發此應用程式，請務必謹記這一點。

某些图示由 [Freepik](https://www.freepik.com) 從 [www.flaticon.com](https://www.flaticon.com/) 製作。

此外，UTM 前端依賴於以下 MIT/BSD 許可證的元件：

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

持續整合託管由 [MacStadium](https://www.macstadium.com/opensource) 提供。

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
