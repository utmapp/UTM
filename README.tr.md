#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> Herhangi bir hesaplanabilir diziyi hesaplamak için kullanılabilecek tek bir makine icat etmek mümkündür.

-- <cite>Alan Turing, 1936</cite>

UTM, iOS ve macOS için tam donanımlı bir sistem öykünücüsü (emülatör) ve sanal makine barındırıcısıdır. QEMU tabanlıdır.
Kısacası, Mac, iPhone ve iPad’inizde Windows, Linux ve daha birçok işletim sistemini çalıştırmanıza olanak tanır.
Daha fazla bilgi için: https://getutm.app/ ve https://mac.getutm.app/


<p align="center">
  <img width="450px" alt="iPhone üzerinde çalışan UTM" src="screen.png">
  <br>
  <img width="450px" alt="MacBook üzerinde çalışan UTM" src="screenmac.png">
</p>

## Özellikler

* QEMU ile tam sistem emülasyonu (MMU, aygıtlar, vs.)
* x86_64, ARM64, and RISC-V dahil 30'dan fazla işlemci desteği
* SPICE ve QXL teknolojilerini kullanan VGA grafik modu
* Metin tabanlı terminal modu
* USB aygıtları
* QEMU TCG yardımıyla JIT tabanlı hızlandırma
* macOS 11 ve iOS 11+ için, en yeni ve gelişmiş API’ler kullanılarak sıfırdan tasarlanmış arayüz
* Sanal Makineleri doğrudan aygıtınızda oluşturun, yönetin ve çalıştırın

## Ek macOS Özellikleri

* Hypervisor.framework ve QEMU kullanılarak donanım hızlandırmalı sanallaştırma
* macOS 12 ve üzeri sürümlerde, Virtualization.framework kullanarak macOS sanal sistemlerini (konuk işletim sistemlerini) başlatın

## UTM SE (slow edition - yavaş sürüm)

UTM/QEMU, en yüksek performans için dinamik kod üretimi (JIT) gerektirir. iOS cihazlarda JIT çalıştırmak için ya cihazın jailbreak yapılmış olması ya da belirli iOS sürümleri için bulunan çeşitli geçici çözümlerden birinin kullanılması gerekir (daha fazla bilgi için “Install” bölümüne bakın).

UTM SE (“slow edition” – yavaş sürüm), [threaded interpreter][3] kullanan bir yapıya sahiptir. Bu yöntem, geleneksel yorumlayıcılara göre daha iyi performans gösterir ancak JIT’ten hâlâ daha yavaştır. Bu teknik, dinamik yürütme için [iSH][4] uygulamasının kullandığı yaklaşıma benzerdir. Sonuç olarak, UTM SE’nin jailbreak yapılmış bir cihaza ya da JIT geçici çözümlerine ihtiyacı yoktur ve normal bir uygulama olarak sideload (manuel yükleme) yöntemiyle kurulabilir.

Boyut ve derleme süresini en iyi duruma getirmek (optimize etmek) için, UTM SE yalnızca aşağıdaki mimarileri içerir: ARM, PPC, RISC-V ve x86 (her biri için 32-bit ve 64-bit sürümleriyle birlikte).

## Yükleme

iOS için UTM (SE): https://getutm.app/install/

UTM'nin macOS sürümü de mevcuttur: https://mac.getutm.app/

## Geliştirme

### [macOS Uygulamasını Geliştirme](Documentation/MacDevelopment.md)

### [iOS Uygulamasını Geliştirme](Documentation/iOSDevelopment.md)

## İlgili Bilgiler

* [iSH][4]: iOS üzerinde x86 Linux uygulamalarını çalıştırmak için kullanıcı modu Linux terminal arayüzünü emüle eder
* [a-shell][5]: iOS için yerel olarak derlenmiş ortak Unix komutlarını ve araçlarını içerir ve bunlara bir terminal arayüzü üzerinden erişilebilir

## Lisans

UTM, esnek bir lisans olan Apache 2.0 lisansı altında dağıtılmaktadır. Ancak, uygulama birkaç (L)GPL bileşeni de kullanmaktadır. Bunların çoğu dinamik olarak bağlanmıştır, ancak gstreamer eklentileri statik olarak bağlanmıştır ve kodun bazı bölümleri qemu’dan alınmıştır. Bu uygulamayı yeniden dağıtmayı düşünüyorsanız, lütfen bu durumu göz önünde bulundurun.

Bazı simgeler [Freepik](https://www.freepik.com) tarafından yapılmış ve [www.flaticon.com](https://www.flaticon.com/) sitesinden alınmıştır.

Ek olarak, UTM'nin kullanıcı arayüzü aşağıdaki MIT/BSD Lisanslı bileşenlere bağlıdır:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Sürekli entegrasyon barındırma hizmeti [MacStadium] tarafından sağlanmaktadır.
(https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
