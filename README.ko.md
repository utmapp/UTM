#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> 계산 가능한 수열을 계산하는 단일 기계를 발명할 수 있습니다.(It is possible to invent a single machine which can be used to compute any computable sequence.)

-- <cite>엘런 튜링, 1936</cite>

UTM은 QEMU를 기반으로 하는, iOS와 macOS를 위한 완전한 시스템 에뮬레이터 및 가상 머신 호스트 프로그램입니다. 이 프로그램을 이용해 Windows나 Linux와 같은 운영체제들을 Mac, iPhone, iPad 등에서 구동할 수 있습니다. 자세한 내용은 https://getutm.app/ 및 https://mac.getutm.app/ 를 참고해주세요.

<p align="center">
  <img width="450px" alt="iPhone에서 동작하는 UTM" src="screen.png">
  <br>
  <img width="450px" alt="MacBook에서 동작하는 UTM" src="screenmac.png">
</p>

## 주요 기능

* QEMU를 이용한 완전한 시스템 에뮬레이션 (MMU, 기타 기기들)
* x86_64, ARM64, RISC-V를 포함한 30가지 이상의 프로세서 지원
* SPICE 및 QXL을 이용한 VGA 그래픽 모드
* 텍스트 터미널 모드
* USB 장치 연결
* QEMU TCG를 활용한 JIT 기반 가속
* macOS 11 / iOS 11 이상에서 제공되는 최신·최고의 API를 사용한 프론트엔드
* 사용자의 기기에서 직접 가상 머신 생성·관리·구동

## macOS 추가 기능

* Hypervisor.framework와 QEMU를 활용한 하드웨어 가속 가상화
* macOS 12 이상에서 Virtualization.framework를 통해 macOS 게스트 구동

## UTM SE

UTM/QEMU가 최고의 성능을 내기 위해서는 동적 코드 생성(JIT)이 필요합니다. iOS 기기에서 JIT을 사용하기 위해서는 기기를 탈옥하거나, 특정 iOS 버전에서 사용 가능한 다양한 해결책 중 하나를 사용해야 합니다. ("설치" 항목을 참고해주세요.)

UTM SE ("slow edition")은 [스레드된 인터프리터][3]를 사용합니다. 이는 전통적인 인터프리터보다는 성능은 좋지만, 여전히 JIT보다는 느립니다. 이 기법은 [iSH][4]가 동적 실행을 위한 구현 방식과 유사합니다. 결과적으로 UTM SE는 탈옥이나 JIT 해결책을 요구하지 않고, 일반 앱처럼 사이드로딩될 수 있습니다.

빌드 소요 시간과 프로그램 크기를 최적하기 위해, UTM SE에는 ARM, PPC, RISC-V, x86 (전부 32비트 및 64비트 포함) 아키텍처만 포함됩니다.

## 설치

iOS용 UTM (SE): https://getutm.app/install/

macOS용 UTM: https://mac.getutm.app/

## 개발

### [macOS 개발 문서](Documentation/MacDevelopment.md)

### [iOS 개발 문서](Documentation/iOSDevelopment.md)

## 관련 사항

* [iSH][4]: iOS에서 x86 Linux 프로그램을 실행하기 위해 사용자 모드 Linux 터미널 인터페이스를 에뮬레이트하는 앱
* [a-shell][5]: iOS용으로 빌드되고 터미널 인터페이스를 통해 접근 가능한 범용 Unix 명령어 및 유틸리티를 모아둔 앱

## 라이선스

UTM은 Permissive 형태인 Apache 2.0 라이선스 하에 배포됩니다. (L)GPL 라이선스를 사용하는 컴포넌트가 있지만, 대부분은 동적으로 링크하여 사용합니다. 예외적으로 GStreamer 플러그인은 정적 링크하여 사용하고, 코드 일부분은 QEMU에서 가져와 사용합니다. 이 프로그램을 재배포하고자 한다면 이에 주의해주시기 바랍니다.

[Freepik](https://www.freepik.com) 산하 [www.flaticon.com](https://www.flaticon.com/)에서 제공되는 아이콘을 일부 사용하였습니다.

추가적으로 UTM 프론트엔드는 아래의 MIT 또는 BSD 라이선스를 사용하는 컴포넌트들에 의존하고 있습니다.

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

지속적 통합(CI) 호스팅은 [MacStadium](https://www.macstadium.com/opensource)에서 제공하고 있습니다.

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
