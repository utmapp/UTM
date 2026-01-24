#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> Hesaplanabilir herhangi bir diziyi hesaplamak için kullanılabilecek tek bir makine icat etmek mümkündür.

-- <cite>Alan Turing, 1936</cite>

UTM, iOS ve macOS için tam özellikli bir sistem emülatörü ve sanal makine ana bilgisayarıdır. QEMU üzerine kurulmuştur. Kısacası, Mac, iPhone ve iPad'inizde Windows, Linux ve daha fazlasını çalıştırmanıza olanak tanır. Daha fazla bilgi için https://getutm.app/ ve https://mac.getutm.app/ adreslerini ziyaret edin.

<p align="center">
  <img width="450px" alt="iPhone'da çalışan UTM" src="screen.png">
  <br>
  <img width="450px" alt="MacBook'ta çalışan UTM" src="screenmac.png">
</p>

## Özellikler

* QEMU kullanarak tam sistem emülasyonu (MMU, aygıtlar vb.)
* x86_64, ARM64 ve RISC-V dahil 30'dan fazla işlemci desteği
* SPICE ve QXL kullanarak VGA grafik modu
* Metin terminal modu
* USB aygıtları
* QEMU TCG kullanarak JIT tabanlı hızlandırma
* macOS 11 ve iOS 11+ için en son API'ler kullanılarak sıfırdan tasarlanmış arayüz
* Doğrudan cihazınızdan sanal makineler oluşturun, yönetin ve çalıştırın

## Ek macOS Özellikleri

* Hypervisor.framework ve QEMU kullanarak donanım hızlandırmalı sanallaştırma
* macOS 12+ sürümünde Virtualization.framework ile macOS misafirleri önyükleyin

## UTM SE

UTM/QEMU, maksimum performans için dinamik kod üretimi (JIT) gerektirir. iOS cihazlarda JIT, ya jailbreak yapılmış bir cihaz ya da belirli iOS sürümleri için bulunan çeşitli geçici çözümler gerektirir (daha fazla ayrıntı için "Kurulum" bölümüne bakın).

UTM SE ("yavaş sürüm"), geleneksel bir yorumlayıcıdan daha iyi performans gösteren ancak yine de JIT'den daha yavaş olan [iş parçacıklı yorumlayıcı][3] kullanır. Bu teknik, [iSH][4]'ın dinamik yürütme için yaptığına benzer. Sonuç olarak, UTM SE jailbreak veya herhangi bir JIT geçici çözümü gerektirmez ve normal bir uygulama olarak yan yüklenebilir.

Boyut ve derleme süreleri için optimize etmek amacıyla, UTM SE'ye yalnızca şu mimariler dahildir: ARM, PPC, RISC-V ve x86 (tümü 32-bit ve 64-bit varyantlarıyla).

## Kurulum

iOS için UTM (SE): https://getutm.app/install/

UTM macOS için de mevcuttur: https://mac.getutm.app/

## Geliştirme

### [macOS Geliştirme](Documentation/MacDevelopment.md)

### [iOS Geliştirme](Documentation/iOSDevelopment.md)

## İlgili Projeler

* [iSH][4]: iOS'ta x86 Linux uygulamalarını çalıştırmak için bir kullanıcı modu Linux terminal arayüzü emüle eder
* [a-shell][5]: iOS için yerel olarak oluşturulmuş ve bir terminal arayüzü aracılığıyla erişilebilen yaygın Unix komutlarını ve yardımcı programları paketler

## Lisans

UTM, izin verici Apache 2.0 lisansı altında dağıtılmaktadır. Ancak, birçok (L)GPL bileşeni kullanmaktadır. Çoğu dinamik olarak bağlanmıştır ancak gstreamer eklentileri statik olarak bağlanmıştır ve kodun bazı bölümleri QEMU'dan alınmıştır. Bu uygulamayı yeniden dağıtmayı planlıyorsanız lütfen bunun farkında olun.

Bazı simgeler [Freepik](https://www.freepik.com) tarafından [www.flaticon.com](https://www.flaticon.com/) için yapılmıştır.

Ayrıca, UTM ön uç aşağıdaki MIT/BSD Lisanslı bileşenlere bağlıdır:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Sürekli entegrasyon barındırma [MacStadium](https://www.macstadium.com/opensource) tarafından sağlanmaktadır

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logosu" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
