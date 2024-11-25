#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> Можливо створити єдину машину, яку можна використовувати для обчислення будь-якої обчислювальної послідовності.

-- <cite>Алан Тюрінг, 1936</cite>

UTM - це повнофункціональний емулятор систем та віртуальних машин хостів для iOS та macOS. Він базується на QEMU. Коротко кажучи, він дозволяє запускати Windows, Linux та інші операційні системи на вашому Mac, iPhone та iPad. Додаткову інформацію можна знайти на https://getutm.app/ та https://mac.getutm.app/.

<p align="center">
  <img width="450px" alt="UTM працює на iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM працює на MacBook" src="screenmac.png">
</p>

## Особливості

* Повна емуляція системи (MMU, пристрої тощо) за допомогою QEMU
* Підтримується більше 30 процесорів, включаючи x86_64, ARM64 та RISC-V
* Графічний режим VGA з використанням SPICE та QXL
* Режим текстового терміналу
* USB пристрої
* Прискорення на основі JIT з використанням QEMU TCG
* Фронтенд розроблено з нуля для macOS 11 та iOS 11+ з використанням найновіших та найкращих API
* Створюйте, керуйте та запускайте віртуальні машини безпосередньо зі свого пристрою

## Додаткові можливості macOS

* Апаратне прискорення віртуалізації за допомогою використання Hypervisor.framework та QEMU
* Запуск гостьових операційних систем macOS з використанням Virtualization.framework на macOS 12+

## UTM SE

Для досягнення максимальної продуктивності, UTM/QEMU потребує динамічну генерацію коду (JIT). Для використання JIT на пристроях iOS потрібно мати пристрій з джейлбрейком або використовувати один з обхідних шляхів, які були знайдені для певних версій iOS (детальніше дивіться в розділі "Встановлення").

UTM SE ("повільна версія") використовує [потіковий інтерпретатор][3], який працює краще, ніж традиційний інтерпретатор, але все ще повільніший, ніж JIT. Ця техніка схожа на те, що робить [iSH][4] для динамічного виконання. В результаті, UTM SE не потребує джейлбрейка або будь-яких обходів JIT і може бути завантажений як звичайний додаток.

Для оптимізації розміру та часу збірки до UTM SE включено лише наступні архітектури: ARM, PPC, RISC-V та x86 (всі з 32-розрядними та 64-розрядними варіантами).

## Встановлення

UTM (SE) для iOS: https://getutm.app/install/

UTM також доступний для macOS: https://mac.getutm.app/

## Розробка

### [macOS розробка](Documentation/MacDevelopment.md)

### [iOS розробка](Documentation/iOSDevelopment.md)

## Пов'язані

* [iSH][4]: емулює інтерфейс терміналу користувача Linux для запуску додатків Linux x86 на iOS
* [a-shell][5]: упаковує загальні команди та утиліти Unix, побудовані нативно для iOS та доступні через інтерфейс терміналу

## Ліцензія

UTM розповсюджується на умовах ліцензії Apache 2.0, однак він використовує декілька компонентів (L)GPL. Більшість з них являються динамічно зв'язаними, але плагіни gstreamer являються статично зв'язаними, а частина коду взята з qemu. Будь ласка, пам'ятайте про це, якщо ви маєте намір розповсюджувати цю програму.

Деякі іконки створені [Freepik](https://www.freepik.com) з [www.flaticon.com](https://www.flaticon.com/).

Крім того, фронтенд UTM залежить від наступних компонентів з ліцензією MIT/BSD:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Хостинг для безперервної інтеграції забезпечується компанією [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
