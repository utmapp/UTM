#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> Możliwe jest wymyślenie pojedynczej maszyny, której można użyć do obliczenia dowolnej sekwencji obliczeniowej.

-- <cite>Alan Turing, 1936</cite>

UTM to wielofunkcyjny emulator systemu oraz menedżer wirtualnych maszyn dla iOS i macOS. Bazuje na QEMU. W skrócie, pozwala na uruchomienie systemu Windows, Linux, i wiele więcej na twoim Macu, iPhonie czy iPadzie. Więcej informacji na https://getutm.app/ i https://mac.getutm.app/

<p align="center">
  <img width="450px" alt="UTM uruchomione na iPhonie" src="screen.png">
  <br>
  <img width="450px" alt="UTM uruchomione na MacBooku" src="screenmac.png">
</p>

## Funkcje

* Pełna emulacja systemu (MMU, urządzenia, itd.) za pomocą QEMU,
* 30+ wspieranych procesorów m.in.: x86_64, ARM64, i RISC-V,
* Tryb graficzny VGA z użyciem sterowników SPICE i QXL,
* Tryb tekstowy (konsola),
* Urządzenia USB,
* Akceleracja JIT z pomocą QEMU TCG
* Frontend zaprojektowany od zera dla macOS 11 i iOS 11+ używając najlepszych i aktualnych API!
* Stwórz, zarządzaj i uruchamiaj wirtualne maszyny bezpośrednio z twojego urządzenia.

## Dodatkowe funkcje dla macOS

* Wirtualizacja z akceleracją sprzętową używając Hypervisor.framework i QEMU
* Uruchamiaj maszyny wirtualne macOS z wykorzystaniem Virtualization.framework na macOS 12+

## UTM SE

UTM/QEMU wymaga generowania dynamicznego kodu (JIT) dla zmaksymalizowania wydajności. JIT na urządzeniach iOS wymaga albo przerobionego urządzenia, albo jeden z kilku luk znalezionych w danej wersji systemu iOS (zobacz "Instacja" po więcej szczegółów).

UTM SE ("slow edition") używa [wielowątkowego interpretera][3] który działa lepiej niż tradycyjny interpreter, ale wciąż jest wolniejszy niż JIT. Ta technika jest podobna do tego co robi [iSH][4] dla dynamicznego wykonywania. W wyniku czego, UTM SE nie wymaga przerobionego urządzenia ani żadnych obejść systemu dla działąjącego JITa i może być uruchamiany jako normalna aplikacja.

Aby zoptymalizować czas kompliacji i rozmiar aplikacji, tylko wymienione architektury są dostępne w UTM SE: ARM, PPC, RISC-V, i x86 (wszystkie zarówno w wariancie 32 i 64-bitowym).

## Instalacja

UTM (SE) dla iOS: https://getutm.app/install/

UTM jest również dostępne na macOS: https://mac.getutm.app/

## Rozwój projektu

### [Rozwój projektu na platformie macOS](Documentation/MacDevelopment.md)

### [Rozwój projektu na platformie iOS](Documentation/iOSDevelopment.md)

## Powiązane

* [iSH][4]: emuluje interfejs terminala systemu Linux aby uruchomić aplikacje x86 Linux na iOS
* [a-shell][5]: zawiera podstawowe komendy Unixowe i narzędzia zbudowane natywnie dla iOS i dostępnych przez interfejs terminala

## Licencja

UTM jest dystrybuowane na licencji Apache 2.0. Jednak, używa wielu komponentów (L)GPL. Większość jest dynamicznie przypisana ale pluginy gstreamer są statycznie przypisane, a fragmenty kodu są wzięte z kodu źródłowego QEMU.

Niektóre ikony zostały zrobione przez [Freepik](https://www.freepik.com) z [www.flaticon.com](https://www.flaticon.com/).

Dodatkowo, interfejs UTM (frontend) jest zależny od komponentów na licencji MIT/BSD:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Continuous integration hosting jest zapewniony przez [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
