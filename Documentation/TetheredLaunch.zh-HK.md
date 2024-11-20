# 捆綁式啟動

在 iOS 14 當中，Apple [修複][1]了我們之前令 JIT 工作的“蠱惑招”。因此，下一個最佳的變通方法涉及更多。這只限用於未越獄的裝置。如你已經越獄，就無需這樣做。

## 先決條件

* Xcode
* [最新版本的 IPA][3]
* [iOS App Signer][4]
* [Homebrew][2]
* [ios-deploy][5] (`brew install ios-deploy`)

## 簽署

安裝並依照 [iOS App Signer][4] 的說明執行操作。確保你的簽署證書與配置檔案匹配。選擇 UTM.ipa 發行版本作為輸入檔案，然後按一下「開始」。

將已經簽署的 IPA 儲存為 `UTM-signed.ipa`，完成程序之後，將 `UTM-signed.ipa` 重新命名為`UTM-signed.zip`，並且開啟 ZIP 檔案。macOS 應將檔案解壓縮至名稱為 `Payload/` 的新目錄當中。

## 部署

如要部署 UTM，連接你的裝置並在終端機中執行：

```sh
ios-deploy --bundle /path/to/Payload/UTM.app
```

（貼士：你可以拖放 `Payload/UTM.app` 至終端機以自動填充目錄。）

## 啟動

如你每次希望啟動 UTM，都需要執行以下內容。（在 iOS 14 當中，不應該透過主畫面啟動 UTM，否則它將無法正常工作！）

```sh
ios-deploy --justlaunch --noinstall --bundle /path/to/Payload/UTM.app
```

（貼士：如你要開啟 Xcode 並轉到 Window > Devices and Simulators 找到你的裝置，則你可以選中「Connect via network」以便於在無 USB 連線的條件下部署/啟動。你只需要解鎖裝置並令它靠近你的電腦。）

## 疑難排解

### 信任問題

如你看到訊息：`The operation couldn't be completed. Unable to launch xxx because it has an invalid code signature, inadequate entitlements or its profile has not been explicitly trusted by the user.`，你需要開啟設定 > 一般 > 裝置管理，選擇「開發者描述檔」，然後選擇「信任」。

### 註冊套裝識別碼失敗（Failed to register bundle identifier）

Xcode 可能在嘗試製作簽名設定檔時顯示此訊息，你需要更改套裝識別碼，然後再試。

[1]: https://github.com/utmapp/UTM/issues/397
[2]: https://brew.sh
[3]: https://github.com/utmapp/UTM/releases
[4]: https://dantheman827.github.io/ios-app-signer/
[5]: https://github.com/ios-control/ios-deploy
