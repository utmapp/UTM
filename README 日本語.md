#  UTM(English)
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured virtual machine host for iOS. In short, it allows you to run Windows, Android, and more on your iPhone and iPad. More information at https://getutm.app/

![Screenshot of UTM running on iPhone][4]

## Features

* 30+ processors supported including x86_64, ARM64, and RISC-V thanks to qemu as a backend
* Fast native graphics through para-virtualization thanks to SPICE
* JIT based acceleration using qemu TCG
* Create, manage, run VMs directly from your device
* No jailbreak required!

## Install

If you just want to use UTM, this is not the right place! Visit https://getutm.app/install/ for directions.

## Building

Make sure you have cloned with submodules `git submodule update --init --recursive`.

### Easy

The recommended way to obtain the dependencies is to use the built artifacts from [Github Actions][5]. Look for the latest release build and download the Sysroot artifact from either the arm64 build (for iOS) or x86_64 build (for iOS Simulator). Then unzip the artifact to the root directory of UTM. You can then open `UTM.xcodeproj`, select your signing certificate, and then run UTM from Xcode.

### Advanced

If you want to build the dependencies yourself, it is highly recommended that you start with a fresh macOS VM. This is because some of the dependencies attempt to use `/usr/local/lib` even though the architecture does not match. Certain installed libraries like `libusb` and `gawk` will break the build.

1. Install Xcode command line and the following build prerequisites
    `brew install bison pkg-config gettext glib libgpg-error nasm`
   Make sure to add `bison` to your `$PATH` environment!
2. `git submodule update --init --recursive` if you haven't already
3. Run `./scripts/build_dependencies.sh` to start the build. If building for the simulator, run `./scripts/build_dependencies.sh -a x86_64` instead.
4. Open `UTM.xcodeproj` and select your signing certificate
5. Build and deploy from Xcode

## Signing

If you build with Xcode, signing should be done automatically. iOS 13.3.1 is NOT supported due to a signing bug. You can use any version lower or higher than 13.3.1.

### Signing Release

The `ipa` [releases][3] are fake-signed. If you are jailbroken, you should NOT sign it. You can install directly with Filza.

If you want to sign the release for stock devices, there are a variety of ways. The recommended way is with [iOS App Signer][2]. Note there are known issues with many "cloud" signing services such as AppCake and they do not work with UTM. If you get a crash while trying to launch a VM, then your signing certificate was invalid.

In more technical detail, there are two kinds of signing certificates: "development" and "distribution". UTM requires "development" which has the `get-task-allow` entitlement.

### Signing Development Build

If you want to sign an `xcarchive` such as from a [Github Actions][1] built artifact, you can use the following command:

```
./scripts/resign.sh UTM.xcarchive outputPath PROFILE_NAME TEAM_ID
```

Where `PROFILE_NAME` is the name of the provisioning profile and `TEAM_ID` is the identifier next to the team name in the provisioning profile. Make sure the signing key is imported into your keychain and the provision profile is installed on your iOS device.

If you have a jailbroken device, you can also fake-sign it (with `ldid` installed):

```
./scripts/resign.sh UTM.xcarchive outputPath
```

## Why isn't this in the AppStore?

Apple does not permit any apps that have interpreted or generated code therefore it is unlikely that UTM will ever be allowed. However, there are various ways people on the internet have come up to sideload apps without requiring a jailbreak. We do not condone or support any of these methods.

## License

UTM is distributed under the permissive Apache 2.0 license. However, it uses several (L)GPL components. Most are dynamically linked but the gstreamer plugins are statically linked and parts of the code are taken from qemu. Please be aware of this if you intend on redistributing this application.



# UTM(日本語)
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

 任意の計算可能なシーケンスを計算するために使用できる機械を発明することは、完全に可能である。（図霊）
-- <cite>Alan Turing, 1936</cite>

UTMは機能がそろっているiOS仮想マシンのホストです。つまり、WindowsやAndroidなどのOSをiPhoneやiPadで実行することができます。詳細はアクセスしてください。https://getutm.ap/

!iPhoneでUTMのスクリーンショットを実行します。][4]
## 特性
* 30+プロセッサに対応しています。x 86_を含みます。64、ARM 64とRISC-Vは後端のqemeのおかげです。
* SPICEのおかげで，準仮想化により高速なローカルパターンが実現した。
* qeme TCGを使ってJITによる加速を実現
* *作成、管理、デバイスから直接VMSを実行する
* 脱獄はいらない
## インストール

UTMを使いたいだけなら、ここは正しいところではないです。訪問してください。https://getutm.ap/install/for directions.

## コンパイル
また、clone Sub module-i-nit-recursive.」.最新バージョンを検索して構築し、arm 64から構築する（iOS用）またはx 86_64構築（iOSシミュレータ用）Sysrootワークをダウンロードします。SysrootをUTMのルートディレクトリに展開します。UTM.xcodeprojあなたの署名証明書を選択して、XcodeからUTMを実行します。
## 簡単:
依存関係を得るために推奨される方法は[ Github action ] [ 5 ]からビルドされたアーティファクトを使用することです。最新のリリースビルドを探して、どちらかのARM 64ビルド（IOS）またはX 86 RAW 64ビルド（IOSシミュレータ用）からsysrootアーティファクトをダウンロードしてください。その後、アーティファクトをutmのルートディレクトリに展開します。その後、`を開くことができますUTM.xcodeprojシグネチャ証明書を選択してから、xcodeからUTMを実行します。
### 高级：
依存項を自分で構築したいなら、新しいmacOS VMから始めることを強く勧めます。これは、いくつかの依存項が、アーキテクチャがマッチングしていないにもかかわらず、`。いくつかの取り付けられたライブラリは、例えば`libusb`と`gawk`のように破壊されて構築されます。
1.Xcodeコマンドラインの取り付けと以下の先決条件の構築
`brew install bison pkg-config gettext glib libgpg-error nasm`
「bison」をあなたの「$PATH」環境に追加してください。
2. `git submodule update --init --recursive` もしあなたがまだいないなら。
3.実行`。/scripts/build_dependencies.shコンパイルを開始します。シミュレータの構築のためなら、実行します`。dependences.sh-a x 86_64`。実行`。/scripts/build_dependencies.shコンパイルを開始します。シミュレータの構築のためなら、実行します`。dependences.sh-a x 86_64`。
4.開く`UTM.xcodeproj署名証明書を選択します。
5.Xcodeからの構築と配置。
## 署名する
Xcodeを使って構築すれば、自動的に署名が完了するはずです。署名機構のエラーのため、iOS 13.3.1はサポートされていません。13.3.1以下のいずれかのバージョンのIOSを使用することができます。

## 署名バージョン
`ipa`[署[3]はfake-`ipa`[署名][3]はfake-signedです。脱獄したら、サインしなくてもいいです。直接Filzaを使ってインストールしてもいいです。です。
在庫設備のために発行版をサインしたいなら、様々な方法があります。[iOSアプリケーション署名者][2]の使用を推奨します。多くの「クラウド」署名サービス（ApCakeなど）にはいくつかの既知の問題が存在し、UTMと互換性がないことに留意されたい。VM仮想マシンを起動しようとしたときにクラッシュした場合、署名証明書は無効です。
技術の詳細には、「開発」と「発表」の二つの署名証明書があります。UTMは「開発」が必要であり、「開発」は「任務の許可を得る」権利を有する。

### 署名開発

もしあなたがxcarchiveに署名したいなら、例えば「Githubアクション」から［1］built artfractから、以下のコマンドが使用できます。
`
./scripts/reign.shUTM.xcarchiveout putPath PROFILE_NAMEチームID
`
そのうち`PROFILE_NAME`は配置ファイルの名称であり、`TEAM_ID`は構成ファイルにおけるチーム名の隣の識別子である。署名鍵が鍵チェーンに導入され、アイテム設定ファイルがiOSデバイスにインストールされていることを確認します。
脱獄したios設備があれば、署名を偽造することもできます。
`
./scripts/reign.shUTM.xcarchiveout put Path
`
## これがAppStoreになぜないのか？
アップルは、コードを解釈したか、生成したどんなアプリケーションも許可しません、したがって、UTMが決して許されないでしょう。しかし、インターネット上の人々が脱獄を必要とせずにサイドローブのアプリに来ている様々な方法があります。我々は、これらのメソッドのどれかを容認しないか、支持しません。
## 許可する
UTMは許容Apache 2.0ライセンスの下で配布されます。しかし、いくつかの（L）GPLコンポーネントを使用します。ほとんどが動的にリンクされますが、gstreamerプラグインは静的にリンクされ、コードの一部はqemuから取得されます。あなたがこのアプリケーションを再配布するつもりならば、これに注意してください。

[1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
[2]: https://dantheman827.github.io/ios-app-signer/
[3]: https://github.com/utmapp/UTM/releases
[4]: screen.png
[5]: https://github.com/utmapp/UTM/actions?query=workflow%3ABuild+event%3Arelease+is%3Asuccess
