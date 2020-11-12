# 不完美启动

在iOS14中，苹果[修补][1]了我们用来让JIT工作的“把戏”。因此，下一个最佳的解决方案所涉及的范围更广。这只适用于非越狱设备。 如果你越狱了，你不需要这样做。

## 前置条件

* Xcode
* [最新的正式版IPA][3]
* [iOS App Signer][4]
* [Homebrew][2]
* [ios-deploy][5] (`brew install ios-deploy`)

## 签名

安装并按照[iOS App Signer][4]的说明进行操作。请确保您的签名证书和配置文件匹配。 选择UTM.ipa正式版作为输入文件并且按下开始。

将已签名的IPA保存为`UTM-signed.ipa`，过程完成后将`UTM-signed.ipa`重命名为`UTM-signed.zip`并且打开ZIP文件。 macOS会将文件提取至名为`Payload/`的新目录。

## 部署

要部署UTM，连接你的设备然后在终端中运行：

```sh
ios-deploy --bundle /path/to/Payload/UTM.app
```

(提示：你可以把 `Payload/UTM.app` 拖放进终端来自动填充目录。)

## 启动

当你每次希望启动UTM时，都需要运行以下命令。 (你无法在iOS14中从主屏幕正常启动UTM否则它无法正常运行！)

```sh
ios-deploy --justlaunch --noinstall --bundle /path/to/Payload/UTM.app
```

(提示：如果您打开Xcode并转到Window->Devices and Simulators并找到您的设备，那么您可以选中“Connect via network”（通过网络连接）以便在没有USB电缆的情况下部署/启动。你只需要解锁设备并靠近你的电脑。)

## 疑难解答

### 信任问题

如果你看见了消息：`The operation couldn’t be completed. Unable to launch xxx because it has an invalid code signature, inadequate entitlements or its profile has not been explicitly trusted by the user.（无法完成操作。无法启动xxx，因为它的代码签名无效、授权不足或其配置文件未被用户明确信任。 ）`，你需要打开设置 -> 通用 -> 设备管理，选择开发者描述文件，然后选择信任。

### 注册捆绑标识符失败

Xcode 可能在尝试创建签名配置文件时显示此消息，您需要更改绑定标识符并重试。

[1]: https://github.com/utmapp/UTM/issues/397
[2]: https://brew.sh
[3]: https://github.com/utmapp/UTM/releases
[4]: https://dantheman827.github.io/ios-app-signer/
[5]: https://github.com/ios-control/ios-deploy
