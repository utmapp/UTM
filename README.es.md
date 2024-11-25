# UTM

[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> Es posible inventar una única máquina que pueda ser usada para computar cualquier secuencia computable. (It is possible to invent a single machine which can be used to compute any computable sequence.)

-- <cite>Alan Turing, 1936</cite>

UTM es un emulador de sistemas completo y un host de máquinas virtuales para iOS y macOS, que está basado directamente en QEMU. En otras palabras, te permite ejecutar Windows, Linux y más en tu Mac, iPhone e iPad. Puedes ver más información en https://getutm.app y https://mac.getutm.app.

<p align="center">
  <img width="450px" alt="UTM ejecutando en un iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM ejecutando en una MacBook" src="screenmac.png">
</p>

## Características

* Emulación de sistema completa (MMU, dispositivos, etc) usando QEMU.
* Más de 30 procesadores compatibles, incluídos x86_64, ARM64 y RISC-V.
* Modo de gráficos VGA usando SPICE y QXL.
* Modo de terminal de texto.
* Dispositivos USB.
* Aceleración basada en JIT con QEMU TCG.
* Interfaz diseñada desde cero para macOS 11 e iOS 11+ usando las mejores y más recientes APIs.
* Crea, gestiona y ejecuta máquinas virtuales (VM) directamente desde tu dispositivo.

## Características adicionales de macOS

* Virtualización acelerada por hardware con el uso de Hypervisor.framework y QEMU.
* Ejecuta clientes de macOS con Virtualization.framework en macOS 12+.

## UTM SE

UTM/QEMU requiere de la generación de código dinámico (JIT) para un máximo rendimiento. En dispositivos iOS, Jit requiere ya sea de un dispositivo con Jailbreak o cualquiera de las soluciones encontradas para versiones específicas de iOS (consulte "Instalar" para más detalles).

UTM SE ("slow edition", edición lenta) usa un [intérprete de subprocesos][3] que funciona mejor que un intérprete tradicional pero aún más lento que JIT. Esta técnica es similar a lo que [iSH][4] realiza para la ejecución dinámica. Como resultado, UTM SE no requiere de Jailbreak ni ninguna solución alterna de JIT, además que puede ser descargada como una aplicación normal (a través del sideloading).

Para optimizar el tamaño y los tiempos de compilación, sólo se incluyen las siguientes arquitecturas en UTM SE: ARM, PPC, RISC-V y x86 (todas con variantes de 32 y 64 bits).

## Instalar

UTM (SE) para iOS: https://getutm.app/install/

UTM está también disponible para macOS: https://mac.getutm.app/

## Desarrollo

### [Desarrollo en macOS](Documentation/MacDevelopment.md)

### [Desarrollo en iOS](Documentation/iOSDevelopment.md)

## Relacionado

* [iSH][4]: emula una interfaz de terminal de Linux para ejecutar aplicaciones x86 de Linux en iOS.
* [a-shell][5]: paquetes de comandos y utilidades comunes de Unix, creados de forma nativa para iOS y accesibles a través de una interfaz de terminal.

## Licencia

UTM es distribuido bajo la licencia permisiva de Apache 2.0. Sin embargo, usa varios componentes (L)GPL. Muchos son dinámicamente enlazados a excepción de los plugins de gstreamer que son estáticamente enlazados, y partes del código que son tomados de qemu. Por favor tenga esto en consideración si pretende redistribuir esta aplicación.

Algunos iconos fueron hechos por [Freepik](https://www.freepik.com) de [www.flaticon.com](https://www.flaticon.com/).

Adicionalmente, el frontend de UTM depende en los siguientes componentes bajo la licencia MIT/BSD:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

El alojamiento de la integración continua es proporcionado por [MacStadium](https://www.macstadium.com/opensource).

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="Logo de MacStadium" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
