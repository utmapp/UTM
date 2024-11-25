#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTMは、QEMUベースのiOSとmacOSのためのフル機能システムエミュレータと仮想マシンホストです。Mac、iPhone及びiPad上でWindows、Linuxなどを実行することができます。詳細については、[https://getutm.app/](https://getutm.app/) および [https://mac.getutm.app/](https://mac.getutm.app/) をご覧ください。

<p align="center">
  <img width="450px" alt="UTM running on an iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM running on a MacBook" src="screenmac.png">
</p>

## 機能

* QEMUによるフルシステムのエミュレーション（MMU、デバイスなど)
* x86_64、ARM64、RISC-Vを含む30以上のプロセッサをサポート
* SPICEとQXLを用いたVGAグラフィックスモード
* ターミナルモード
* USBデバイス
* QEMU TCGを用いたJITベースのアクセラレーション
* フロントエンドは、最新かつ最高のAPIを使用して、macOS 11およびiOS 11+用にゼロから設計
* デバイスから直接VMの作成、管理、実行が可能

## macOSでの追加機能

* Hypervisor.frameworkとQEMUによるハードウェアアクセラレーション仮想化
* macOS 12+でVirtualization.frameworkを使用してmacOSゲストを起動

## UTM SE

UTM/QEMU は、パフォーマンスを最大化するために動的コード生成（JIT）を必要とします。iOS デバイスでの JIT は、ジェイルブレイクしたデバイスか、特定のバージョンの iOS で利用できるさまざまな回避策のいずれかが必要です（詳細については、「インストール」を参照してください）。

UTM SE ("slow edition") は従来のインタープリタよりは性能が良いですが、JITよりは遅い [threaded interpreter][3] を使用します。この手法は、[iSH][4]が動的実行のために行っているものと同様です。それによって、UTM SEは、ジェルブレイクやJITの回避策を必要とせず、通常のアプリとしてサイドロードすることができます。

サイズとビルド時間の最適化のため、UTM SE には以下のアーキテクチャのみが含まれています：ARM、PPC、RISC-V、x86（すべてのアーキテクチャには32bitと64bitの両方のバリエーションがあります）

## インストール

iOSのためのUTM (SE): [https://getutm.app/install/](https://getutm.app/install/)

macOSのためのUTM: [https://mac.getutm.app/](https://mac.getutm.app/)

## Development

### [macOS Development](Documentation/MacDevelopment.md)

### [iOS Development](Documentation/iOSDevelopment.md)

## 関連

* [iSH][4]: iOS上でx86Linuxアプリケーションを実行するためのusermode Linuxターミナルインターフェイスをエミュレートします
* [a-shell][5]: iOS用にネイティブにビルドされ、ターミナル・インターフェースからアクセスできる一般的なUnixコマンドとユーティリティのパッケージ

## License

UTMは、寛容なApache 2.0ライセンスで配布されています。しかし、いくつかの (L)GPL コンポーネントを使用しています。ほとんどは動的にリンクされていますが、gstreamerプラグインは静的にリンクされており、コードの一部はqemuから取得されています。このアプリケーションを再配布するつもりであれば、このことに注意してください。

いくつかのアイコンは[www.flaticon.com](https://www.flaticon.com/)からの[Freepik](https://www.freepik.com)によって作られたものです

さらに、UTMフロントエンドは、以下のMIT/BSDライセンスのコンポーネントに依存しています:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

[MacStadium](https://www.macstadium.com/opensource)によって継続的インテグレーションのホスティングが提供されています

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
