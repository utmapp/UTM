# UTM

[![Статус](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)](https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild)

> Возможно изобрести [такую машину](https://ru.wikipedia.org/wiki/Универсальная_машина_Тьюринга), которая справится с любой вычислимой последовательностью.

— <cite>Алан Тьюринг, «О вычислимых числах применительно к [проблеме разрешения](https://ru.wikipedia.org/wiki/Проблема_разрешения)» ([*On Computable Numbers, with an Application to the Entscheidungsproblem*](https://www.cs.virginia.edu/~robins/Turing_Paper_1936.pdf)) (1936)</cite>

UTM — это полноценный эмулятор системы и хост виртуальных машин для iOS и macOS. В основе UTM лежит [QEMU](https://www.qemu.org/). UTM позволяет запускать Windows, Linux и другие операционные системы на Mac, iPhone и iPad.

Дополнительная информация на [getutm.app](https://getutm.app/) и [mac.getutm.app](https://mac.getutm.app/).

<p align="center">
  <img width="450px" alt="UTM на iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM на MacBook" src="screenmac.png">
</p>

## Возможности

* Полная эмуляция системы (с поддержкой [блоков управления памятью](https://ru.wikipedia.org/wiki/Блок_управления_памятью), устройств и т.д.) на основе QEMU
* Более 30 архитектур процессора, в том числе x86_64, ARM64 и RISC-V
* VGA-графика на основе SPICE и QXL
* Режим текстового терминала
* Поддержка USB-устройств
* JIT-оптимизация на основе [QEMU TCG](https://www.qemu.org/docs/master/devel/index-tcg.html)
* UI, разработанный специально для macOS 11+ и iOS 11+ с помощью нативных API
* Возможность создавать, настраивать и запускать виртуальные машины прямо на устройстве

## Дополнительные возможности (только на macOS)

* Аппаратное ускорение виртуализации с помощью [фреймворка Hypervisor](https://developer.apple.com/documentation/hypervisor) и QEMU
* Возможность запускать macOS в виртуальных машинах с помощью [фреймворка Virtualization](https://developer.apple.com/documentation/virtualization) (требуется macOS 12 или новее на хосте)

## UTM SE

Для максимальной скорости работы UTM и QEMU используют кодогенерацию just-in-time, которая ограничена на iOS. Чтобы запустить UTM, можно воспользоваться джейлбрейком или — для некоторых версий iOS — одним из обходных путей (см. раздел «Установка»).

UTM SE (“slow edition”) использует [поточный интерпретатор](https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md), который работает быстрее традиционного, но всё же медленнее JIT. Подобный подход используется в проекте [iSH](https://github.com/ish-app/ish) для динамического исполнения. В результате версия UTM SE не требует джейлбрейк или прочие хаки и может быть установлена как любое другое приложение.

Чтобы оптимизировать время сборки и размер приложения, UTM SE поддерживает только x86, ARM, PowerPC и RISC-V (все — в 32- и 64-битном вариантах).

## Установка

* [UTM для macOS](https://mac.getutm.app/)
* [UTM (SE) для iOS](https://getutm.app/install/)

## Разработка

* [UTM для macOS](Documentation/MacDevelopment.md)
* [UTM для iOS](Documentation/iOSDevelopment.md)

## Лицензии

UTM распространяется по лицензии Apache 2.0.

Однако некоторые компоненты проекта используют более строгие лицензии из группы (L)GPL. Большинство таких компонентов использует динамическую связку, но плагины `gstreamer` связаны статически, а некоторые части кода взяти из QEMU. Пожалуйста, обращайте внимание на ограничения этих лицензий, если планируете распространять UTM.

Кроме того, UI приложения использует следующие компоненты, распространяемые по лицензиям MIT или BSD:
* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Некоторые значки взяты с [Flaticon](https://www.flaticon.com/) и сгенерированы с помощью [Freepik](https://www.freepik.com/).

Хостинг для CI предоставлен [MacStadium](https://www.macstadium.com/opensource).

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)
