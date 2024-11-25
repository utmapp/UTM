#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

> এমন মেশিন আবিষ্কার করা সম্ভব যা যেকোনো ধরনের সিকোয়েনশিয়াল গণনা করতে পারে তা যত কঠিন গণনাই হোক না কেন 

-- <cite>অ্যালান টুরিং, ১৯৩৬</cite>

UTM হল iOS এবং macOS-এর জন্য সমস্ত ফিচার বিশিষ্ট সিস্টেম ইমিউলেটর এবং  ভার্চুয়াল মেশিন হোস্ট। এটি QEMU এর উপর বেজ করে বানানো হয়েছে । সংক্ষেপে বলা যায় যে, UTM আপনাকে আপনার ম্যাক, আইফোন এবং আইপ্যাডে উইন্ডোজ, লিনাক্স এবং আরও অনেক অপারেটিং সিস্টেম চালানোর অনুমতি দেয়। লিঙ্ক গুলোতে আরও বিস্তারিত জানতে পারবেনঃ 
১। https://getutm.app/ এবং 
২। https://mac.getutm.app/ 

<p align="center">
  <img width="450px" alt="একটি আইফোনে UTM চলছে" src="screen.png">
  <br>
  <img width="450px" alt="একটি ম্যাকবুকে UTM চলছে" src="screenmac.png">
</p>

## UTM এ যা যা ফিচার আছেঃ

* QEMU ব্যবহার করে সম্পূর্ণ সিস্টেম ইমিউলেশন (MMU, ডিভাইস, ইত্যাদি)
* x86_64, ARM64, এবং RISC-V সহ 30+ প্রসেসর সাপোর্টেড
* SPICE এবং QXL ব্যবহার করে VGA গ্রাফিক্স মোড
* টেক্সট টার্মিনাল মোড
* ইউএসবি ডিভাইস
* QEMU TCG ব্যবহার করে JIT ভিত্তিক এক্সিলারেশন 
* সবচেয়ে লেটেস্ট এবং সেরা API গুলো ব্যবহার করে macOS 11 এবং iOS 11+ এর জন্য স্ক্র্যাচ থেকে ডিজাইন করা ফ্রন্টেন্ড
* আপনার ডিভাইস থেকে সরাসরি VM তৈরি করুন, ম্যানেজ করুন, চালান

## macOS এর ক্ষেত্রে অতিরিক্ত যা যা ফিচার আছে

* Hypervisor.framework এবং QEMU ব্যবহার করে হার্ডওয়্যার এক্সিলারেটেড ভার্চুয়ালাইজেশন
* macOS 12+ এ Virtualization.framework সহ macOS গেস্ট বুট করুন

## UTM SE

UTM/QEMU-এর সর্বোচ্চ পারফরমেন্স এর জন্য ডায়নামিক কোড জেনারেশন (JIT) প্রয়োজন। iOS ডিভাইসে JIT-এর জন্য দরকার একটি জেলব্রোকেন ডিভাইস, অথবা iOS-এর নির্দিষ্ট ভার্শন এর জন্য যেকোনো ওয়ার্ক এরাউন্ড (আরো বিশদ বিবরণের জন্য "ইনস্টল" পার্ট টি দেখুন)।

UTM SE ("স্লো এডিশন") একটি [থ্রেডেড ইন্টারপ্রেটার][3] ব্যবহার করে যা একটি ট্র্যাডিশনাল ইন্টারপ্রেটার এর চেয়ে যদিও ভাল পারফর্ম করে কিন্তু এখনও JIT এর চেয়ে স্লো। এই টেকনিকটি ডাইনামিক এক্সিকিউশন এর জন্য [iSH][4] যা করে তার মতোই। ফলস্বরূপ, UTM SE-এর জন্য জেলব্রেকিং বা কোনো JIT সমাধানের প্রয়োজন নেই এবং রেগুলার অ্যাপ হিসেবে সাইডলোড করা যায়।

সাইজ  এবং বিল্ড এর সময় অপ্টিমাইজ করার জন্য, শুধুমাত্র নিচের আর্কিটেকচারগুলি UTM SE-তে ইনক্লুড করা হয়েছে: ARM, PPC, RISC-V, এবং x86 (সমস্তই 32-বিট এবং 64-বিট ভেরিয়েন্টের সাথে)।

## ইনস্টল

iOS এর জন্য UTM (SE): https://getutm.app/install/

 macOS এর জন্য UTM নামাতে পারবেন এখান থেকে: https://mac.getutm.app/

## ডেভেলপমেন্ট

### [macOS ডেভেলপমেন্ট](Documentation/MacDevelopment.md)

### [iOS ডেভেলপমেন্ট](Documentation/iOSDevelopment.md)

## রিলেটেড

* [iSH][4]: iOS এ x86 Linux অ্যাপ্লিকেশন চালানোর জন্য একটি usermode Linux টার্মিনাল ইন্টারফেস ইমিউলেট করে
* [a-shell][5]: সাধারণ ইউনিক্স কমান্ড এবং ইউটিলিটি যেগুলো iOS এর জন্য নেটিভ সেগুলো এটি প্যাকেজ করে দেয় এবং এটি টার্মিনাল ইন্টারফেসের মাধ্যমে অ্যাক্সেস করা যায়। 

## লাইসেন্স

UTM পারমিসিভ Apache 2.0 লাইসেন্সের অধীনে ডিস্ট্রিবিউট করা হচ্ছে। সেই সাথে এটি বেশ কয়েকটি (L)GPL কম্পোনেন্ট ব্যবহার করছে। বেশিরভাগই ডাইন্যামিক্যালি লিঙ্কড  কিন্তু gstreamer প্লাগইনগুলি স্ট্যাটিকভাবে লিঙ্ক করা এবং কোডের কিছু অংশ qemu থেকে নেওয়া। আপনি যদি এই অ্যাপ্লিকেশনটি পুনরায় ডিস্ট্রিবিউট করতে চান তবে দয়া করে এই বিষয় গুলো সম্পর্কে খেয়াল রাখবেন৷
Some icons made by [Freepik](https://www.freepik.com)  [www.flaticon.com](https://www.flaticon.com/).

[www.flaticon.com](https://www.flaticon.com/) থেকে [ফ্রিপিকের](https://www.freepik.com) তৈরি কিছু আইকন এখানে ব্যবহার করা হয়েছে।


এছাড়াও, UTM ফ্রন্টএন্ড নিম্নলিখিত MIT/BSD লাইসেন্স কম্পোনেন্ট এর উপর নির্ভর করে:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

কন্টিনিউয়াস ইন্টিগ্রেশন হোস্টিং টি [MacStadium](https://www.macstadium.com/opensource) প্রোভাইড করছে 


[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
