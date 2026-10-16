# UTM

[![Build](https://github.com/utmapp/UTM/actions/workflows/build.yml/badge.svg?branch=main&event=push)][1]
[![Mac App Store](https://img.shields.io/badge/Mac_App_Store-UTM-0D96F6?logo=appstore&logoColor=white)](https://apps.apple.com/cz/app/utm-virtual-machines/id1538878817)
[![App Store](https://img.shields.io/badge/App_Store-UTM_SE-0D96F6?logo=appstore&logoColor=white)](https://apps.apple.com/cz/app/utm-se-retro-pc-emulator/id1564628856)
[![Download](https://img.shields.io/badge/Download-UTM.dmg-24292F?logo=github&logoColor=white)](https://github.com/utmapp/UTM/releases/latest/download/UTM.dmg)

> Je možné vynalézt jediný stroj, který lze použít k výpočtu libovolné vypočitatelné posloupnosti.

-- <cite>Alan Turing, 1936</cite>

UTM je plnohodnotný emulátor systému a hostitel virtuálního počítače pro iOS, macOS a visionOS, který je založen přímo na QEMU. Jinými slovy, na Macu, iPhonu a iPadu můžete spouštět Windows, Linux a další systémy. Další informace naleznete zde  https://getutm.app y https://mac.getutm.app.

<p align="center">
  <img width="450px" alt="UTM ejecutando en un iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM ejecutando en una MacBook" src="screenmac.png">
</p>

## Funkce

* Úplná emulace systému (MMU, zařízení atd.) pomocí QEMU.
* Podporuje více než 30 procesorů, včetně x86_64, ARM64 a RISC-V.
* Grafický režim VGA pomocí SPICE a QXL.
*  Režim textového terminálu.
*  Zařízení USB.
*  Akcelerace na bázi JIT pomocí QEMU TCG.
*  Rozhraní od základu navržené pro macOS 12+ a iOS 15+ s využitím nejnovějších a nejlepších rozhraní API.
*  Vytvářejte, spravujte a spouštějte virtuální počítače (VM) přímo ze svého zařízení.

Translated with www.DeepL.com/Translator (free version)
## Další funkce v systému macOS

* Hardwarově akcelerovaná virtualizace pomocí Hypervisor.frameworku a QEMU.
* Spouštění klientů macOS s Virtualization.framework.

## UTM SE

pro dosažení maximálního výkonu vyžaduje UTM/QEMU dynamické generování kódu (JIT) . Na zařízeních se systémem iOS vyžaduje JIT buď jailbreaknuté zařízení, nebo některé z řešení nalezených pro konkrétní verze systému iOS (podrobnosti najdete v části "Instalace").

UTM SE ("slow edition") používá vláknový interpret, který funguje lépe než tradiční interpret, ale stále pomaleji než JIT. Tato technika je podobná technice iSH pro dynamické spouštění. UTM SE proto nevyžaduje Jailbreak ani žádné alternativní řešení JIT a lze jej stáhnout jako běžnou aplikaci (pomocí sideloadingu).

Z důvodu optimalizace velikosti a doby kompilace jsou v UTM SE zahrnuty pouze následující architektury: ARM, PPC, RISC-V a x86 (všechny 32bitové a 64bitové varianty).

## Instalace

UTM (SE) pro iOS: https://docs.getutm.app/installation/ios/

UTM je k dispozici také pro macOS: https://docs.getutm.app/installation/macos/

## Vývoj

### [Vývoj v systému macOS](Documentation/MacDevelopment.md)

### [Vývoj pro iOS](Documentation/iOSDevelopment.md)

## Související stránky

* [iSH][4]: emuluje terminálové rozhraní Linuxu pro spouštění aplikací x86 Linux v systému iOS.
* [a-shell][5]: balíčky běžných unixových příkazů a nástrojů vytvořené nativně pro iOS a přístupné přes terminálové rozhraní.

## Licence

UTM je šířen pod licencí Apache 2.0. Používá však několik komponent (L)GPL. Mnohé z nich jsou dynamicky linkované, s výjimkou zásuvných modulů gstreameru, které jsou staticky linkované, a částí kódu, které jsou převzaty z qemu. Pokud máte v úmyslu tuto aplikaci dále šířit, vezměte to prosím v úvahu.

Některé ikony byly vytvořeny [Freepik](https://www.freepik.com) de [www.flaticon.com](https://www.flaticon.com/).

Frontend UTM navíc využívá následující komponenty pod licencí MIT/BSD:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Kontinuální hostování integrace zajišťuje [MacStadium](https://macstadium.com/company/opensource).

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="Logo de MacStadium" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
