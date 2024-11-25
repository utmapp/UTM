# UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> 發明一台可以用來計算任何可計算序列的機器是完全有可能的。

-- <cite>艾倫·圖靈（Alan Turing），1936年</cite>

UTM 是一個功能完整的系統模擬器和虛擬機器主機，適用於 iOS 和 macOS，基於 QEMU 開發。簡單來說，它讓你能在你的 Mac、iPhone 和 iPad 上執行 Windows、Linux 等作業系統。更多資訊請參考 [https://getutm.app/](https://getutm.app/) 和 [https://mac.getutm.app/](https://mac.getutm.app/)。

<p align="center">
  <img width="450px" alt="在 iPhone 上執行 UTM" src="screen.png">
  <br>
  <img width="450px" alt="在 MacBook 上執行 UTM" src="screenmac.png">
</p>

## 功能

* 使用 QEMU 進行完整的系統模擬（MMU、裝置等）
* 支援超過 30 種處理器，包括 x86_64、ARM64 和 RISC-V
* 使用 SPICE 和 QXL 的 VGA 圖形模式
* 文字終端模式
* USB 裝置
* 使用 QEMU TCG 的 JIT 基礎加速
* 專為 macOS 11 和 iOS 11+ 使用最新 API 從零設計的前端
* 直接從你的裝置建立、管理、執行虛擬機器

## macOS 額外功能

* 使用 Hypervisor.framework 和 QEMU 的硬體加速虛擬化
* 在 macOS 12+ 上使用 Virtualization.framework 啟動 macOS 客體

## UTM SE

UTM/QEMU 需要動態程式碼生成(JIT)以達到最大效能。iOS 裝置上的 JIT 需要越獄裝置，或是針對特定 iOS 版本的各種解決方案（詳見「安裝」）。

UTM SE（"慢速版/slow edition"）使用一個 [執行緒直譯器][3]，效能優於傳統的直譯器但仍然比 JIT 慢。這個技術與 [iSH][4] 用於動態執行的方式類似。因此，UTM SE 不需要越獄或任何 JIT 解決方案，可以作為一般應用程式側載。

為了最佳化大小和建置時間，UTM SE 只包含以下架構：ARM、PPC、RISC-V 和 x86（都包括 32 位和 64 位變體）。

## 安裝

適用於 iOS 的 UTM(SE)：[https://getutm.app/install/](https://getutm.app/install/)

也適用於 macOS 的 UTM：[https://mac.getutm.app/](https://mac.getutm.app/)

## 開發

### [macOS 開發](Documentation/MacDevelopment.md)

### [iOS 開發](Documentation/iOSDevelopment.md)

## 相關

* [iSH][4]：模擬使用者模式 Linux 終端介面，用於在 iOS 上執行 x86 Linux 應用程式
* [a-shell][5]：將常見的 Unix 指令和工具原生地建置於 iOS，並透過終端介面存取

## 授權

UTM 是在寬鬆的 Apache 2.0 授權下釋出。然而，它使用了幾個 (L)GPL 元件。大部分是動態連結的，但 gstreamer 外掛是靜態連結的，部分程式碼來自 qemu。如果你打算重新散佈這個應用程式，請留意這一點。

部分圖示由 [Freepik](https://www.freepik.com) 製作，來自 [www.flaticon.com](https://www.flaticon.com/)。

此外，UTM 前端相依於以下 MIT/BSD 授權元件：

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

持續整合主機由 [MacStadium](https://www.macstadium.com/opensource) 提供

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
