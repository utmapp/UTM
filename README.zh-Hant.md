# UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> 發明一台可以用來計算任何可計算序列的機器是完全有可能的。

-- <cite>圖靈（Alan Turing）, 1936年</cite>

UTM是一個功能齊全的iOS虛擬機主機。簡而言之，它允許你在iPhone和iPad上運行Windows、Android、Ubuntu等操作系統。更多信息請訪問https://getutm.app/

![在iPhone上運行UTM的截圖](https://kyun.ltyuanfang.cn/tc/2020/08/16/b71e7b3b8d695.png)

## 特性

* 支持30+處理器，包括x86_64、ARM64和RISC-V，這要歸功於後端qemu
* 得益於SPICE，通過准虛擬化實現了快速的本地圖形
* 使用qemu TCG實現基於JIT的加速
* Frontend使用最新最好的api為iOS11+從零開始設計
* 直接從設備創建、管理和運行虛擬機
* 不需要越獄!

## 安裝

如果您只是想使用UTM，請訪問https://getutm.app/install/ 來獲取引導.

## 編譯

請確保您已經clone子模塊，請先clone子模塊：`git submodule update --init --recursive`.

### 簡單的

獲取依賴項的推薦方法是使用[Github操作生成的構件][4].查找最新的版本構建並從arm64構建(用於iOS)或x86_64構建(用於Mac上的iOS模擬器)下載Sysroot工件。然後將Sysroot解壓到UTM的根目錄.然後就可以打開`UTM.xcodeproj`,選擇您的簽名證書，然後從Xcode運行並編譯安裝UTM。

### 高級的

如果您想自己構建依賴項，強烈建議您從一個全新的macOS VM開始。這是因為一些依賴項儘管架構並不匹配，仍試圖使用`/usr/local/lib`。某些已安裝的庫如`libusb`和`gawk`將破壞構建。
1. 使用`brew`安裝Xcode命令行和以下構建條件
`brew install bison pkg-config gettext glib libgpg-error nasm`
並且請確保將「bison」添加到您的「$PATH」環境中!
2. 如果你還沒有clone子模塊，運行以下命令
`git submodule update --init --recursive` 
3. 運行 `./scripts/build_dependencies.sh`以開始編譯。如果為Mac的iOS設備模擬器構建，請運行 `./scripts/ build_dependences .sh -a x86_64  `。
4. 打開`UTM.xcodeproj`並選擇您的簽名證書。
5. 從Xcode構建和部署。

## 簽名

如果使用Xcode進行構建，則應該自動完成簽名。由於iOS簽名的錯誤導致不支持iOS 13.3.1。您可以使用低於或高於13.3.1的任何版本。

### 簽名版本

`ipa`[簽名][3]是假的簽名。如果你是越獄，你不應該簽名它，您可以直接使用Filza進行安裝。
如果您想要為庫存設備簽署發行版，有多種方法。推薦使用[iOS應用簽名者][2]。注意，許多「雲」簽名服務(如AppCake)都存在一些已知的問題，而且它們與UTM不兼容。如果在試圖啓動VM虛擬機時發生崩潰（如閃退），那麼您的簽名證書是無效的。
在技術細節上，有兩種簽名證書:「開發」和「發佈」。UTM需要「開發」，而「開發」具有「獲得任務許可」的權利。

### 簽名開發

如果你想要簽署一個xcarchive，例如從[Github Actions][1]中編譯構建，你可以使用以下命令:

```
./scripts/package.sh signedipa UTM.xcarchive outputPath PROFILE_NAME TEAM_ID
```

其中`PROFILE_NAME`是配置配置文件的名稱，而`TEAM_ID`是配置配置文件中團隊名稱旁邊的標識符。確保簽名密鑰被導入到您的密鑰鏈中，並且條款配置文件已安裝在您的iOS設備上。

如果你有一個越獄的設備，你也可以偽造簽名(安裝了「ldid」):

```
./scripts/package.sh ipa UTM.xcarchive outputPath
```
## UTM使用注意事項

1. ISO鏡像要開啓CD/DVD選項
2. 虛擬硬盤文件不要開CD/DVD選項
3. 啓動app時白屏需要重啓iOS設備

## 為什麼UTM不在AppStore中?

蘋果不允許任何解釋或生成代碼的應用程序在AppStore中上架，因此UTM不太可能被允許上架。然而，人們在互聯網上有各種各樣的方式來獲得不需要越獄就能加載的應用程序。我們支持這些方法中的任何一種。

## 許可

UTM是在Apache 2.0許可下發佈的。但是，它使用幾個(L)GPL組件。大多數插件是動態鏈接的，但gstreamer插件是靜態鏈接的，部分代碼取自qemu。如果您打算重新分發此應用程序，請注意這一點。

[1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
[2]: https://dantheman827.github.io/ios-app-signer/
[3]: https://github.com/utmapp/UTM/releases
[4]: https://github.com/utmapp/UTM/actions?query=workflow%3ABuild+event%3Arelease+is%3Asuccess

