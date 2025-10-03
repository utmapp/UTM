#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> 可以發明一個用於計算任何可計算序列的機器。

-- <cite>艾倫·圖靈（Alan Turing），1936 年</cite>

UTM 是一個為 iOS 與 macOS 而設的全功能系統模擬器與虛擬機主機，它基於 QEMU。簡而言之，它允許你在 Mac、iPhone 與 iPad 上執行 Windows、Linux 等。有關更多訊息，請見 https://getutm.app 與 https://mac.getutm.app

<p align="center">
  <img width="450px" alt="在 iPhone 上執行的 UTM" src="screen.png">
  <br>
  <img width="450px" alt="在 MacBook 上執行的 UTM" src="screenmac.png">
</p>

## 特點

* 使用 QEMU 的完整系統模擬（MMU、裝置等）
* 支援 30+ 處理器，當中包括 x86_64、ARM64 與 RISC-V
* 使用 SPICE 與 QXL 的 VGA 圖形模式
* 文字終端模式
* USB 裝置
* 使用 QEMU TCG 的基於 JIT 的加速
* 採用最新最靚的 API，為 macOS 11+ 與 iOS 11+ 從頭開始設計前端
* 直接從你的裝置製作、管理與執行虛擬機

## 其他 macOS 功能

* 使用 Hypervisor.framework 與 QEMU 進行硬件加速虛擬化
* 於 macOS 12+ 上使用 Virtualization.framework 啟動 macOS 客户端

## UTM SE

UTM/QEMU 需要動態程式碼生成（JIT）才能取得最大性能。iOS 裝置上的 JIT 需要越獄（Jailbreak）的裝置，或者為特定版本的 iOS 找到的全部變通方法之一（有關更多詳細訊息，請見「安裝」）。

UTM SE（「慢速版」）使用[執行緒解釋器][3]，其效能雖然優於傳統解釋器，但仍然比 JIT 慢。此技術類似於 [iSH][4] 的動態執行。 因此，UTM SE 無需越獄或者其他 JIT 變通辦法，可以做為一般的應用程式側載。

為了最佳化大小與構建時間，UTM SE 當中只包括以下架構：ARM、PPC、RISC-V 與 x86（均有 32 位元與 64 位元變體）。

## 安裝

iOS 版本 UTM (SE)：https://getutm.app/install/

UTM 亦可以於 macOS 上使用：https://mac.getutm.app/

## 開發

### [macOS 開發](Documentation/MacDevelopment.md)

### [iOS 開發](Documentation/iOSDevelopment.md)

## 相關項目

* [iSH][4]：模擬用户模式的 Linux 終端介面，用於在 iOS 上執行 x86 Linux 應用程式
* [a-shell][5]：為 iOS 原生構建的通用 Unix 命令與工具程式包，可透過終端介面訪問

## 許可證

UTM 於允許的 Apache 2.0 許可證下分發。然而，它使用了幾個 (L)GPL 元件。當中大多數元件為動態連接，但 gstreamer 延伸功能為靜態連接，部分程式碼來自 QEMU。如你打算重新分發此應用程式，請緊記這一點。

一些圖示由 [Freepik](https://www.freepik.com) 從 [www.flaticon.com](https://www.flaticon.com/) 製作。

另外，UTM 前端依賴以下 MIT/BSD 許可證的元件：

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
