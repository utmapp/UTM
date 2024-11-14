# 捆绑启动

在 iOS 14 中，Apple [修补][1]了我们用来让 JIT 工作的“把戏”。因此，下一个最佳的解决方案所涉及的范围更广。这一操作只适用于非越狱设备。如果你已经越狱，就不需要这样做了。

## 前置条件

* Xcode
* [最新版本的 IPA][3]
* [iOS App Signer][4]
* [Homebrew][2]
* [ios-deploy][5] (`brew install ios-deploy`)

## 签名

安装并按照 [iOS App Signer][4] 的说明进行操作。确保你的签名证书和配置文件相匹配。选择 UTM.ipa 版本作为输入的文件，然后点击“开始”。

将已签名的 IPA 保存为 `UTM-signed.ipa`，完成操作后将 `UTM-signed.ipa` 重命名为 `UTM-signed.zip`，打开 ZIP 文件。 macOS 会将文件提取到名为`Payload/`的新目录中。

## 部署

若要部署 UTM，请连接你的设备，然后在终端中运行：

```sh
ios-deploy --bundle /path/to/Payload/UTM.app
```

（提示：你可以把 `Payload/UTM.app` 拖放进终端来自动填充目录。）

## 启动

当你每次希望启动 UTM 时，都需要运行如下命令。（不能在 iOS 14 中从主屏幕启动 UTM，否则它将无法正常工作！）

```sh
ios-deploy --justlaunch --noinstall --bundle /path/to/Payload/UTM.app
```

（提示：如果你打开了 Xcode 并转到窗口（Window）> 设备和模拟器（Devices and Simulators）并找到你的设备，可以勾选“通过网络连接”，以便在没有 USB 电缆的情况下部署/启动。只需要解锁设备并靠近你的电脑即可。）

## 疑难解答

### 信任问题

如果你看到了消息 `The operation couldn’t be completed. Unable to launch xxx because it has an invalid code signature, inadequate entitlements or its profile has not been explicitly trusted by the user.（无法完成操作。无法启动 xxx，因为它的代码签名无效，授权不足，或者其配置文件尚未被用户明确信任。）`，你需要打开设置 > 通用 > 设备管理，选择开发者描述文件，然后选择信任。

### 注册捆绑包标识符失败（Failed to register bundle identifier）

Xcode 可能在尝试创建签名配置文件时显示此消息，你需要更改绑定标识符并重试。

[1]: https://github.com/utmapp/UTM/issues/397
[2]: https://brew.sh
[3]: https://github.com/utmapp/UTM/releases
[4]: https://dantheman827.github.io/ios-app-signer/
[5]: https://github.com/ios-control/ios-deploy
