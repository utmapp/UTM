# Tethered Launch

On iOS 14, Apple [patched][1] the trick we used to get JIT working. As a result, the next best workaround is significantly more involved. This only applies to non-jailbroken devices. If you are jailbroken, you do not need to do this.

## Prerequisites

* Xcode
* [Latest IPA Release][3]
* [iOS App Signer][4]
* [Homebrew][2]
* [ios-deploy][5] (`brew install ios-deploy`)

## Signing

Install and follow the instructions for [iOS App Signer][4]. Make sure your signing certificate and provisioning profiles matches. Select the UTM.ipa release as the input file, uncheck ```No get-task-allow``` and press start.

Save the signed IPA as `UTM-signed.ipa`. Once the process is completed, rename `UTM-signed.ipa` to `UTM-signed.zip` and open the ZIP file. macOS should extract the files to a new directory named `Payload/`.

## Deploying

To deploy UTM, connect your device and run in Terminal:

```sh
ios-deploy --bundle /path/to/Payload/UTM.app
```

(Hint: you can drag `Payload/UTM.app` into Terminal to auto-fill in the path.)

## Launching

You need to run the following each subsequent time you wish to launch UTM. (You cannot launch UTM from the home screen in iOS 14 or it will not work properly!)

```sh
ios-deploy --justlaunch --noinstall --bundle /path/to/Payload/UTM.app
```

(Hint: if you open Xcode and go to Window -> Devices and Simulators and find your device, you can check "Connect via network" in order to deploy/launch without a USB cable. You just need the device unlocked and near your computer.)

## Troubleshooting

### Trust issue

If you see the message `The operation couldn’t be completed. Unable to launch xxx because it has an invalid code signature, inadequate entitlements or its profile has not been explicitly trusted by the user.`, you need to open Settings -> General -> Device Management, select the developer profile, and press Trust.

### Failed to register bundle identifier

Xcode might show this message when trying to create a signing profile. You need to change the Bundle Identifier and try again.

[1]: https://github.com/utmapp/UTM/issues/397
[2]: https://brew.sh
[3]: https://github.com/utmapp/UTM/releases
[4]: https://dantheman827.github.io/ios-app-signer/
[5]: https://github.com/ios-control/ios-deploy
