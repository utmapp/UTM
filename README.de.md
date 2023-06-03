#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> Es ist möglich eine einzige Machine zu entwickeln, die es ermöglicht jede berechenbare sequenz zu berechnen.

-- <cite>Alan Turing, 1936</cite>

UTM ist ein voll funktionaler System Emulator und ein virtueller Maschinen-Host für iOS und macOS. Es basiert auf QEMU. Zusammengefasst: es ermöglicht Ihnen Windows, Linux, und mehr auf Ihrem Mac, iPhone, und iPad zu emulieren. Mehr Informationen finden Sie bei https://getutm.app/ und https://mac.getutm.app/

<p align="center">
  <img width="450px" alt="UTM running on an iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM running on a MacBook" src="screenmac.png">
</p>

## Funktionen

* Komplette System Emulation (MMU, Gerät, etc) mit Benutzung von QEMU
* 30+ Prozessoren ünterstützt inklusive x86_64, ARM64, und RISC-V
* VGA Graphik Modi mit Benutzung von SPICE und QXL
* Text terminal Modus
* USB Geräte
* JIT basierende Beschleunigung mit Benutzung von QEMU TCG
* Frontend designed vom Grund auf für macOS 11 und iOS 11+ mithilfe der neusten und besten APIs
* Kreiere, Konfiguriere, Starte VMs direkt von Ihrem Gerät

## Zusätzliche macOS Funktionen

* Hardware beschleunigung virtuellisierung mithilfe Hypervisor.framework und QEMU
* Booten von macOS guests mithilfe Virtualization.framework in macOS 12+

## UTM SE

UTM/QEMU benötigt dynamische code generierung (JIT) für maximale Leistung. JIT auf iOS Geräten benötigt entweder ein Gerät mit jailbreak, oder eine der vielfältigen für andere, spezifische IOS versionen gefundenen Umwege (siehe "Install" für mehr details).

UTM SE ("slow edition") uses a [threaded interpreter][3] which performs better than a traditional interpreter but still slower than JIT. This technique is similar to what [iSH][4] does for dynamic execution. As a result, UTM SE does not require jailbreaking or any JIT workarounds and can be sideloaded as a regular app.

To optimize for size and build times, only the following architectures are included in UTM SE: ARM, PPC, RISC-V, and x86 (all with both 32-bit and 64-bit variants).

## Installierung

UTM (SE) für iOS: https://getutm.app/install/

UTM ist auch verfügbar für macOS: https://mac.getutm.app/

## Entwicklung

### [macOS Entwicklung](Documentation/MacDevelopment.md)

### [iOS Entwicklung](Documentation/iOSDevelopment.md)

## Ähnliches

* [iSH][4]: emuliert ein usermode Linux terminal interface für die Ausführung von x86 Linux Applikationen in iOS
* [a-shell][5]: verpackt häufige Unix commands und Dienstprogramme nativ gebaut für iOS und zugreifbar durch ein terminal interface

## Lizens

UTM wird unter der freizügigen Apache-2.0-Lizenz vertrieben. Es verwendet jedoch mehrere (L)GPL-Komponenten. Die meisten sind dynamisch verlinkt, aber die gstreamer-Plugins sind statisch verlinkt und Teile des Codes stammen aus qemu. Bitte beachten Sie dies, wenn Sie beabsichtigen, diese Anwendung weiterzuvermitteln.

Manche Icons von [Freepik](https://www.freepik.com) von [www.flaticon.com](https://www.flaticon.com/).

Zusätzlich basiert das frontend UTM's auf den folgenden MIT/BSD Lizens Komponenten:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Weiterlaufendes integrations-hosting wird betrieben von [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
