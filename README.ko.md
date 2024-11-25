#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> 계산 가능한 수열을 계산하는 단일 기계를 발명할 수 있습니다.(It is possible to invent a single machine which can be used to compute any computable sequence.)

-- <cite>엘런 튜링, 1936</cite>

UTM은 iOS와 macOS를 위한 완전한 시스템 에뮬레이터, 가상머신입니다. 이것은 QEMU를 기반으로 합니다. 요컨데 당신은 이것을 통해, Windows나 Linux와 같은 운영체제들을 Mac, iPhone, iPad 등에서 구동할 수 있습니다. 자세한 내용은 https://getutm.app/ 와 https://mac.getutm.app/ 를 읽어주세요.

<p align="center">
  <img width="450px" alt="iPhone에서 동작하는 UTM" src="screen.png">
  <br>
  <img width="450px" alt="MacBook에서 동작하는 UTM" src="screenmac.png">
</p>

## 주요기능

* QMEU를 활용한 완전한 시스템 에뮬레이션(MMU, 기타 기기들)
* x86_64, ARM64, and RISC-V를 포함한 30가지 이상의 프로세서 지원
* SPICE와 QXL을 활용한 VGA 그래픽 모드
* 텍스트 터미널 모드
* USB 장치들
* QEMU TCG를 활용한 JIT 기반 가속
* 초기부터 macOS 11과 iOS 11+를 위해 디자인된, 최신 및 최고의 API를 활용한 프론트엔드
* 당신의 기기에서 바로 가상머신을 생성하고, 관리하고, 구동하기

## macOS 추가 기능

* Hypervisor.framework와 QEMU를 활용한 하드웨어 가속 가상화
* macOS 12+에서 Virtualization.framework를 통해 macOS 게스트 구동

## UTM SE

UTM/QEMU이 최고의 성능을 내기 위해서는 동적 코드 생성이(JIT) 필요합니다. iOS 기기에서 JIT는 jailbroken를 요구하거나, 특정 iOS 버전에서 발견된 다양한 해결책 중 하나를 필요로 합니다.(자세한 내용은 "설치" 부분을 참고해주세요."

UTM SE("slow edition")은 [threaded interpreter][3]를 사용합니다. 이는 전통적인 인터프리터보다는 좋지만, 그래도 여전히 JIT보다는 느립니다. 이 기술은 [iSH][4]가 동적 실행을 위해 하는 일과 유사한데요. 결과적으로 UTM SE는 탈옥이나 JIT 해결책을 요구하진 않고, 정규 앱으로 나란히 메모리에 적재될 수 있습니다.

빌드 시간과 크기를 최적하기 위해서, UTM SE에는 ARM, PPC, RISC-V, x86(32bit와 64bit 변종 모두) 아키텍처들만이  포함되어 있습니다. 

## 설치

iOS를 위한 UTM (SE): https://getutm.app/install/

macOS를 위한 UTM: https://mac.getutm.app/

## 개발

### [macOS 개발](Documentation/MacDevelopment.md)

### [iOS 개발](Documentation/iOSDevelopment.md)

## 관련사항

* [iSH][4]: iOS에서 x86 Linux 앱을 실행하기 위해, 사용자 모드 Linux 터미널 인터페이스를 에뮬레이트
* [a-shell][5]: 기본적으로 iOS용으로 구축되면서, 터미널 인터페이스를 통해 액세스할 수 있는, 범용 유닉스 명령 및 유틸리티 패키지

## 라이센스

UTM은 permissive Apache 2.0 license를 따르며 배포되었습니다. 하지만 몇몇 (L)GPL 컴포넌트들을 사용하는데요. 대부분은 동적으로 연결되어있지만, gstreamer 플러그인은 정적으로 연결되어 있고, 일부 코드는 qemu에서 가져왔습니다. 이 앱을 재배포 하려는 경우 꼭 이에 유의하시길 바랍니다.

일부 아이콘은 [www.flaticon.com](https://www.flaticon.com/)에서 [Freepik](https://www.freepik.com)를 통해 만들어졌습니다.

추가적으로 UTM 프론트엔드는 아래의 MIT/BSD 라이센스를 사용하는 컴포넌트들에 의존하고 있습니다.

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

지속 통합 호스팅은 다음을 통해 제공됩니다. [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
