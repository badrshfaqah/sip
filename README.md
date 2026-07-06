# Developer SoftPhone for macOS

<div dir="rtl">

تطبيق SoftPhone احترافي لنظام macOS بواجهة عربية (RTL) يحمل هوية الشركة، يدعم بروتوكول SIP بالكامل ويعمل مع أغلب مزودي VoIP وأنظمة PBX (Asterisk، FreePBX، 3CX، Yeastar، Issabel، Grandstream، Cisco، Avaya، Elastix، SubTrunk وغيرها) — بديل كامل للبرامج التجارية مثل Zoiper وBria وMicroSIP.

## المميزات

- **واجهة عربية حديثة** بتصميم macOS أصيل (SwiftUI) مع دعم الوضع الفاتح والداكن.
- **محرك SIP كامل** مبني على [Linphone SDK](https://linphone.org) (liblinphone):
  - وسائل النقل: UDP / TCP / TLS (+WebSocket).
  - اجتياز NAT: STUN / TURN / ICE، مع Outbound Proxy.
  - الأكواد: G711 (PCMU/PCMA) / G722 / G729 / Opus / تلقائي.
  - تشفير الوسائط: SRTP / ZRTP / DTLS-SRTP.
  - DTMF: RFC 2833 / SIP INFO / In-Band.
  - إلغاء الصدى، تقليل الضوضاء، Jitter Buffer، VAD، Keep-Alive.
- **تعدد الحسابات** مع التبديل الفوري، ونسخ/استيراد/تصدير الإعدادات.
- **لوحة اتصال كاملة** (0-9، *، #) مع إعادة الطلب، كتم، مكبر صوت، تعليق (Hold)، تحويل (Transfer)، مؤتمر (Conference)، تسجيل المكالمة، وDTMF أثناء المكالمة.
- **جودة الاتصال المباشرة**: Ping، فقد الحزم، Jitter، Latency.
- **سجل مكالمات** (واردة/صادرة/فائتة) مع بحث وتصدير CSV.
- **جهات اتصال** مع مفضلة وتصنيفات واستيراد/تصدير CSV.
- **إشعارات النظام** للمكالمات والتسجيل وفقد الاتصال.
- **الأمان**: كلمات المرور في Keychain (مشفّرة)، قفل التطبيق بكلمة مرور، ولا تُحفظ كلمة المرور إلا بموافقة المستخدم.
- **سجلات SIP** مفصّلة مع تصفية وتصدير ومسح.
- **سلوك macOS**: التشغيل مع بدء النظام، العمل في الخلفية، الإغلاق إلى شريط القوائم، والتحقق من التحديثات.

## بنية المشروع

</div>

```
├── project.yml              ← مواصفات المشروع (XcodeGen)
├── Sources/
│   ├── App/                 ← نقطة الدخول وحالة التطبيق وشريط القوائم
│   ├── Models/              ← SIPAccount, CallRecord, Contact, AppSettings
│   ├── Services/            ← SIPManager (محرك SIP), Keychain, المخازن, الإشعارات
│   ├── Theme/               ← هوية الشركة (الألوان والشعار)
│   └── Views/               ← شاشات الدخول والاتصال والسجل وجهات الاتصال والإعدادات
├── Resources/               ← Assets (الأيقونة، الشعار، الألوان) والترجمة ar/en
└── Scripts/
    ├── build_dmg.sh         ← بناء Universal DMG
    └── notarize.sh          ← التوقيع والتوثيق للتوزيع
```

<div dir="rtl">

## البناء (يتطلب جهاز Mac + Xcode 15+)

```bash
# 1) تثبيت XcodeGen مرة واحدة
brew install xcodegen

# 2) توليد المشروع وفتحه
xcodegen generate
open DeveloperSoftPhone.xcodeproj
```

عند أول فتح سيقوم Xcode بتنزيل حزمة `linphone-sdk-swift-macos` تلقائياً عبر Swift Package Manager.

### إخراج DMG (يدعم Apple Silicon + Intel)

```bash
./Scripts/build_dmg.sh
# الناتج: dist/DeveloperSoftPhone.dmg
```

### التوقيع والتوثيق (Code Signing + Notarization)

1. ضع بيانات حساب المطور في `Scripts/notarization.env` (انظر التعليمات داخل السكربت).
2. شغّل:

```bash
./Scripts/notarize.sh
```

## تخصيص هوية الشركة

| العنصر | المكان |
|---|---|
| الألوان الأساسية | `Sources/Theme/Brand.swift` + `Resources/Assets.xcassets/AccentColor.colorset` |
| شعار الشركة | أضف صور PNG إلى `Resources/Assets.xcassets/CompanyLogo.imageset` |
| أيقونة التطبيق | أضف الأحجام إلى `Resources/Assets.xcassets/AppIcon.appiconset` |
| اسم الشركة | `Brand.companyName` في `Sources/Theme/Brand.swift` |
| رابط التحديثات | `UpdateChecker.feedURL` في `Sources/Services/UpdateChecker.swift` |
| معرّف الحزمة | `PRODUCT_BUNDLE_IDENTIFIER` في `project.yml` |

## التحديثات المستقبلية

انشر ملف JSON على خادم الشركة بالرابط المحدد في `UpdateChecker.feedURL`:

```json
{ "version": "1.1.0", "url": "https://badr-s.com/softphone/DeveloperSoftPhone.dmg", "notes": "ملاحظات الإصدار" }
```

## ملاحظات تقنية

- الحد الأدنى للنظام: macOS 13 (Ventura).
- كودك G729 قد يتطلب ترخيصاً تجارياً حسب إصدار Linphone SDK المستخدم.
- الواجهة الإنجليزية: أضف الترجمات إلى `Resources/en.lproj/Localizable.strings`.
- هذه أول نسخة من الشيفرة ولم تُبنَ بعد على جهاز Mac؛ عند أول بناء قد تحتاج بعض استدعاءات واجهة linphonesw إلى مواءمة بسيطة مع إصدار الحزمة المُنزَّل (الواجهة تتغير قليلاً بين الإصدارات).

</div>
