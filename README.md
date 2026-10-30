# عين — ديمو مساعد النظارة الذكية

تطبيق Flutter (أندرويد) تجريبي لإثبات فكرة بيع نظارات AIMB G1 / عائلة HeyCyan ويا تطبيق عربي.
الواجهة عربية RTL باللهجة العراقية، أزرار كبيرة، وكل نتيجة تنحچى بالصوت.

## الأوضاع
- **قراءة للمكفوفين**: صوّر لوحة أو علبة دوا ← قراءة النص ← نطق عربي. زر «وصف المكان» (يحتاج مفتاح سحابي).
- **ترجمة**: صوّر نص أو احچي (إنگليزي/تركي/فارسي/فرنسي/ألماني) ← ترجمة للعربي على الجهاز ← نطق.
- **جرد باركود**: مسح مستمر للباركود و QR، عدّاد لكل صنف، تعديل +/-، تصدير CSV.

## على الجهاز / سحابي
| الميزة | على الجهاز | ملاحظة |
|---|---|---|
| قراءة نص لاتيني | ML Kit Text Recognition | |
| قراءة نص **عربي** | ❌ | ML Kit v2 ما يدعم الحروف العربية — يحتاج الذكاء السحابي الاختياري |
| ترجمة للعربي | ML Kit On-Device Translation | أول مرة ينزل ملف اللغة (~30MB) ويحتاج نت |
| باركود / QR | ML Kit (mobile_scanner) | |
| نطق | flutter_tts (محرك Google TTS العربي) | |
| استماع | speech_to_text | يعتمد على خدمة Google بالجهاز |
| وصف المشهد / قراءة عربي | سحابي اختياري | أي API متوافق مع OpenAI، المفتاح يندخل بالإعدادات ويتخزن بالجهاز فقط |

## المصادر (`lib/sources/`)
`GlassesSource` واجهة موحدة، وإلها تطبيقين:
- `PhoneCameraSource` — يشتغل هسه بكاميرة التلفون.
- `HeyCyanGlassesSource` — **غير مجرّب على نظارة حقيقية**. فحص BLE، اتصال، بطارية، تعلّم زر النظارة، أمر تصوير، وضع نقل الواي فاي، وتحميل الصورة من `http://IP/files/media.config`.

### مصدر كل أمر / UUID
| العنصر | القيمة | المصدر |
|---|---|---|
| خدمة رئيسية | `7905FFF0-B5CE-4E99-A40F-4B1E122D00D0` | ebowwa/HeyCyanSmartGlassesSDK — `examples/untested/python/build_for_pypi.py` |
| خدمة UART + أوامر/إشعار/بيانات | `6e40fff0/1/2/3-b5a3-f393-e0a9-e50e24dcca9e` | نفس الملف |
| تصوير | `02 01 01` | نفس الملف + FerSaiyan CyanBridge `MainActivity.kt` (`glassesControl`) |
| فيديو بدء/إيقاف | `02 01 02` / `02 01 03` | ebowwa `build_for_pypi.py` |
| صوت بدء/إيقاف | `02 01 08` / `02 01 0C` | ebowwa + CyanBridge `AutoAudioCaptureService.kt` |
| وضع نقل الواي فاي | `02 01 04` | CyanBridge `wifiadb/DefaultWifiAdbDebugControllerFactory.kt` |
| عدد الوسائط | `02 04` | CyanBridge `MainActivity.kt` |
| قائمة الملفات | `GET /files/media.config` ثم `/files/NAME` | ebowwa `ios/QCSDKDemo/GlassesMediaDownloader.m` + CyanBridge `IosMediaTransfer.kt` |
| أوامر احتياط | `0x2001` / `0x2002` | CyanBridge `BRIDGE_RESEARCH_NOTES.md` (لنظارات مشابهة) |
| بطارية | خدمة BLE القياسية `180F/2A19` | معيار Bluetooth SIG (الطريقة الخاصة بالمصنع مو معروفة البايتات) |

### الغير مؤكد
- CyanBridge يرسل الأوامر عبر مكتبة المصنع (`LargeDataHandler.glassesControl` داخل `glasses_sdk_*.aar`) واللي ممكن تضيف تغليف. إحنا نكتب البايتات الخام.
- نقل الصور بأندرويد يصير بـ Wi-Fi Direct بالتطبيق الأصلي؛ هنا لازم تربط التلفون بواي فاي النظارة يدوياً وتكتب الـ IP بالإعدادات.
- زر النظارة: بايتاته مو موثقة، فالتطبيق «يتعلّمه» (تدوس الزر ويحفظ الإشعار).
- الصوت: اربط النظارة كسماعة بلوتوث من أندرويد والصوت والمايك يمرون منها.
- `flutter_blue_plus` 2.x مجاني للاستخدام غير التجاري؛ البيع التجاري يحتاج رخصة.

## التشغيل
```
flutter pub get
flutter build apk --release
```
