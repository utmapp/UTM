#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> Es ist möglich, eine einzige Maschine zu entwerfen, mit der jede berechenbare Folge berechnet werden kann.

-- <cite>Alan Turing, 1936</cite>

UTM ist ein voll umfänglicher Systememulator und Virtualisierungs-Host für iOS und macOS. Es basiert auf QEMU. Kurz gesagt ermöglicht es, Windows, Linux und weitere Betriebssysteme auf Ihrem Mac, iPhone und iPad auszuführen. Weitere Informationen finden Sie unter https://getutm.app/ und https://mac.getutm.app/

<p align="center">
  <img width="450px" alt="UTM running on an iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM running on a MacBook" src="screenmac.png">
</p>

## Funktionen

* Vollständige Systememulation (MMU, Geräte usw.) mithilfe von QEMU
* Unterstützung für über 30 Prozessorarchitekturen, darunter x86_64, ARM64 und RISC-V
* VGA-Grafikmodus unter Verwendung von SPICE und QXL
* Textterminalmodus
* USB-Geräte
* JIT-basierte Beschleunigung mithilfe von QEMU TCG
* Von Grund auf neu entwickeltes Frontend für macOS 11 und iOS 11+ unter Nutzung aktueller und modernster APIs
* Virtuelle Maschinen direkt auf dem Gerät erstellen, verwalten und ausführen

## Zusätzliche macOS-Funktionen

* Hardwarebeschleunigte Virtualisierung unter Verwendung von Hypervisor.framework und QEMU
* Starten von macOS-Gastsystemen mit dem Virtualization.framework unter macOS 12+

## UTM SE

UTM/QEMU benötigt für maximale Leistung die dynamische Codegenerierung (JIT).
JIT auf iOS-Geräten erfordert entweder ein Gerät mit Jailbreak oder eine der verschiedenen Umgehungslösungen, die für bestimmte iOS-Versionen verfügbar sind (siehe „Installation“ für weitere Details).

UTM SE („Slow Edition“) verwendet einen [threaded interpreter][3], der eine bessere Leistung als ein herkömmlicher Interpreter bietet, jedoch weiterhin langsamer als JIT ist. Diese Technik ähnelt dem Ansatz, den [iSH][4] für die dynamische Ausführung verwendet. Daher benötigt UTM SE weder einen Jailbreak noch JIT-Workarounds und kann als reguläre App per Sideloading installiert werden.

Zur Optimierung von Größe und Build-Zeiten sind in UTM SE ausschließlich die folgenden Architekturen enthalten: ARM, PPC, RISC-V und x86 (jeweils in 32-Bit- und 64-Bit-Varianten).

## Installation

UTM (SE) für iOS: https://getutm.app/install/

UTM ist auch für macOS verfügbar: https://mac.getutm.app/

## Entwicklung

### [macOS Development](Documentation/MacDevelopment.md)

### [iOS Development](Documentation/iOSDevelopment.md)

## Verwandte Themen

* [iSH][4]: Emuliert eine User-Mode-Linux-Terminalschnittstelle zum Ausführen von x86-Linux-Anwendungen unter iOS
* [a-shell][5]: Stellt gängige Unix-Befehle und -Utilities bereit, die nativ für iOS erstellt wurden und über ein Terminal genutzt werden können

## Lizenz

UTM wird unter der permissiven Apache-2.0-Lizenz vertrieben. Es verwendet jedoch mehrere (L)GPL-Komponenten. Die meisten davon sind dynamisch eingebunden, die gstreamer-Plugins sind jedoch statisch gelinkt, und Teile des Codes stammen aus QEMU. Bitte beachten Sie dies, sofern Sie beabsichtigen, diese Anwendung weiterverbreiten.

Einige Icons wurden von [Freepik](https://www.freepik.com) erstellt und stammen von [www.flaticon.com](https://www.flaticon.com/).

Zusätzlich verwendet das UTM-Frontend die folgenden Komponenten unter der MIT-/BSD-Lizenz:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Das Hosting für kontinuierliche Integration wird bereitgestellt von [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell