#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> Il est possible d'inventer une machine unique qui peut être utilisée pour calculer n'importe quelle séquence calculable. (It is possible to invent a single machine which can be used to compute any computable sequence.)

-- <cite>Alan Turing, 1936</cite>

UTM est émulateur de système complet et un hôte pour machine virtuelle pour iOS et macOS. Il s'appuie sur QEMU. Pour faire court, il vous permet d'exécuter Windows, Linux, et autres sur votre Mac, iPhone, et iPad. Plus d'informations sur https://getutm.app/ et https://mac.getutm.app/

![Capture d'écran d'UTM fonctionnant sur iPhone][2]

## Fonctionnalités

* Émulation complète de système (MMU, appareils, etc) en utilisant QEMU
* Plus de 30 processeurs pris en charge, dont x86_64, ARM64, et RISC-V
* Graphismes en mode VGA en utilisant SPICE et QXL
* Mode texte terminal
* Appareils USB
* Accélération basée sur JIT en utilisant QEMU TCG
* Interface originale pour macOS 11 et iOS 11+ en utilisant les dernières API
* Créez, gérez et exécutez des VM directement depuis votre appareil

## Fonctionnalités supplémentaires pour macOS

* Virtualisation accélérée matérielement en utilisant Hypervisor.framework et QEMU
* Démarrez des clients macOS avec Virtualization.framework sur macOS 12+

## UTM SE

UTM/QEMU requiert la génération de code dynamique (JIT) pour des performances maximales. Sur les appareils iOS, JIT requiert soit un appareil jailbreaké, soit un des différents contournements existants pour des versions spécifiques d'iOS (consultez "Installation" pour plus de détails).

UTM SE ("slow edition", édition lente) utilise un [threaded interpreter][3] qui fonctionne mieux qu'un interpréteur traditionnel mais qui reste plus lent que JIT. Cette technique est simiaire à ce que fait [iSH][4] pour l'exécution dynamique. Par conséquent, UTM SE ne demande pas de jailbreak et n'utilise pas de contournements pour JIT et peut être sideloadé comme n'importe quelle app.

Afin d'optimiser la taille de l'app et les temps de compilation, seules ces architectures sont fournies avec UTM SE : ARM, PPC, RISC-V, et x86 (avec les variantes 32-bit et 64-bit).

## Installation

UTM (SE) pour iOS : https://getutm.app/install/

UTM est aussi disponible sur macOS : https://mac.getutm.app/

## Développement

### [Développement sur macOS](Documentation/MacDevelopment.md)

### [Développement sur iOS](Documentation/iOSDevelopment.md)

## Et aussi

* [iSH][4]: émule une interface de terminal Linux en mode utilisateur pour exécuter des applications Linux x86 sur iOS
* [a-shell][5]: empaquette les commandes et utilitaires communs d'Unix compilés nativement pour iOS et accessibles via l'interface terminal

## Licence

UTM est distribué sous la licence permissive Apache 2.0. Cependant, il utilise plusieurs composants (L)GPL. La plupart sont liés dynamiquement mais les plugins gstreamer le sont statiquement et certaines parties du code viennent de QEMU. Soyez conscient de cela si vous souhaitez redistribuer cette application.

Certaines icônes sont faites par [Freepik](https://www.freepik.com) de [www.flaticon.com](https://www.flaticon.com/).

De plus, le frontend d'UTM dépend de ces composants qui sont sous licence MIT :

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)

L'hébergement en intégration continue est fourni par [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)
  
  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
