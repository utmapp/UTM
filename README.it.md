#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> È possibile inventare una macchina singola che può essere usata per computare qualsiasi sequenze compatibili.

-- <cite>Alan Turing, 1936</cite>

UTM è un emulatore e virtualizzatore di macchine per iOS e macOS. È basato su QEMU. In breve, ti permette di eseguire Windows, Linux, ed altro nel tuo Mac, iPhone e iPad. Ulteriori informazioni su https://getutm.app/ e https://mac.getutm.app/

<p align="center">
  <img width="450px" alt="UTM su sun iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM su un MacBook" src="screenmac.png">
</p>

## Funzioni

* Emulazione completa di sistemi (MMU, dispositivi, etc) usando QEMU
* 30+ processori supportati includendo x86_64, ARM64, e RISC-V
* Modalità grafica VGA usando SPICE e QXL
* Modalità testo da terminale
* Dispostivi USB
* Accelerazione basata su JIT usando QEMU TCG
* Frontend fatto da zero per macOS 11 e iOS 11+ usando le ultime e grandi API
* Crea, gestisci ed esegui Macchine Virtuali direttamente dal tuo dispositvo

## Funzioni aggiuntive su macOS

* Accelerazione Hardware per virtualizzazione usando Hypervisor.framework e QEMU
* Puoi far Boot su diversi macOS usando Virtualization.framework su macOS 12+

## UTM SE

UTM/QEMU richiedono generazione dinamica del codice (JIT) per le maggiori prestazioni. JIT sui dispositivi iOS richiedono il jailbreak, oppure una dei vari workaround trovati per versioni iOS specifiche (vedi sezione "Installazione" per più dettagli).

UTM SE ("versione lenta") usa un [interprete a thread][3] che performa meglio di un interprete tradizionale ma più lento del JIT. Questa tecnica è simile a quella che usa [iSH][4] per l'esecuzione dinamica. Come risultato, UTM SE non richiede jailbreak o JIT e può essere installato come un'app normale.

Per ottimizzare il peso (in MB) ed i tempi di costruzione, solo queste archittetture sono incluse in UTM SE: ARM, PPC, RISC-V, and x86 (tutte con le varianti 32-bit e 64-bit).

## Installazione

UTM (SE) per iOS: https://getutm.app/install/

UTM è anche per macOS: https://mac.getutm.app/

## Sviluppo

### [Sviluppo su macOS](Documentation/MacDevelopment.md)

### [Sviluppo su iOS](Documentation/iOSDevelopment.md)

## Progetti Relativi

* [iSH][4]: emula un'interfaccia di un terminale Linux per eseguire applicazioni Linux x86 su iOS
* [a-shell][5]: pacchetti Unix comuni con comandi e strumenti per iOS nativi accessibili da un'interfaccia da terminale

## Licenza

UTM è distribuito sotto la licenza Apache 2.0. Però, usa vari componenti (L)GPL. Molti sono collegati dinamicamente, ma i plugin di gstreamer sono collegati staticamente e parti di codice sono presi da qemu. Per favore sii consapevole se intendi a redistribuire quest'applicazione.

Alcune icone fatte da [Freepik](https://www.freepik.com) da [www.flaticon.com](https://www.flaticon.com/).

Inoltre, il frontend di UTM dipende da queste licenze MIT/BSD:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Integraziobe continuata di hosting è data da [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
