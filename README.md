# سوق الوساط - تطبيق أندرويد (PWA/TWA)

تطبيق أندرويد لمتجر **سوق الوساط** الإلكتروني مبني بتقنية Trusted Web Activity (TWA) باستخدام Bubblewrap من Google.

## 📱 ما هو هذا المشروع؟

هذا المشروع يحوّل تطبيق الويب التقدمي (PWA) الخاص بسوق الوساط إلى تطبيق أندرويد أصلي يمكن:
- تحميله كملف APK وتثبيته على أي جهاز أندرويد
- نشره على متجر Google Play Store

التطبيق يعمل كغلاف (wrapper) يفتح موقع `souqalwisat.com` بتقنية TWA مما يمنح المستخدم تجربة تطبيق أصلي بدون شريط العنوان.

---

## 🚀 كيفية إنشاء المستودع على GitHub وتشغيل البناء

### الخطوة 1: إنشاء مستودع GitHub

1. اذهب إلى [github.com/new](https://github.com/new)
2. اكتب اسم المستودع: `souq-alwisat-pwa`
3. اختر **Private** (خاص) أو **Public** (عام)
4. **لا تختر** أي خيارات مثل README أو .gitignore (لأننا سنرفع الملفات)
5. اضغط **Create repository**

### الخطوة 2: رفع الكود إلى GitHub

افتح Terminal في جهازك ونفذ الأوامر التالية (بعد فك ضغط الملف المرفق):

```bash
cd souq-alwisat-pwa
git remote add origin https://github.com/USERNAME/souq-alwisat-pwa.git
git branch -M main
git push -u origin main
```

> استبدل `USERNAME` باسم حسابك على GitHub

### الخطوة 3: تشغيل البناء يدوياً

1. اذهب إلى مستودعك على GitHub
2. اضغط على تبويب **Actions**
3. اختر **Build Android APK** من القائمة الجانبية
4. اضغط زر **Run workflow** (تشغيل سير العمل)
5. اضغط **Run workflow** مرة أخرى للتأكيد
6. انتظر حتى ينتهي البناء (عادة 5-10 دقائق)

### الخطوة 4: تحميل ملف APK

1. بعد انتهاء البناء بنجاح ✅
2. اضغط على العملية المكتلمة
3. مرر لأسفل حتى قسم **Artifacts**
4. حمل `souq-alwisat-apk` (ملف APK للتثبيت المباشر)
5. حمل `souq-alwisat-aab` (ملف AAB للنشر على Google Play)

---

## 🔧 إعداد Digital Asset Links (مهم!)

لكي يعمل التطبيق بدون شريط العنوان، يجب إضافة ملف التحقق على الموقع:

### الخطوة 1: الحصول على SHA-256 fingerprint

بعد البناء الأول، شغّل:
```bash
keytool -list -v -keystore android.keystore -alias souqalwisat
```

كلمة المرور: `souqalwisat123`

انسخ قيمة **SHA-256** من الناتج.

### الخطوة 2: إنشاء ملف assetlinks.json

أنشئ الملف على المسار التالي على الموقع:
```
https://souqalwisat.com/.well-known/assetlinks.json
```

بالمحتوى التالي:
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.souqalwisat.pwa",
      "sha256_cert_fingerprints": ["SHA-256_FINGERPRINT_HERE"]
    }
  }
]
```

> استبدل `SHA-256_FINGERPRINT_HERE` بالقيمة التي حصلت عليها من الخطوة 1.

### الخطوة 3: التحقق

استخدم أداة Google للتحقق:
https://developers.google.com/digital-asset-links/tools/generator

---

## 📁 هيكل المشروع

```
souq-alwisat-pwa/
├── .github/
│   └── workflows/
│       └── build-apk.yml      # GitHub Actions workflow لبناء APK
├── app/                        # ملفات تطبيق الويب (PWA)
│   ├── index.html
│   ├── manifest.json
│   ├── sw.js
│   ├── logo.png
│   ├── logo-192.png
│   ├── logo-512.png
│   ├── logo-512-maskable.png
│   ├── proxy.php
│   ├── css/
│   └── js/
├── twa-manifest.json           # إعدادات تطبيق أندرويد (Bubblewrap)
├── README.md                   # هذا الملف
├── .gitignore
└── package.json                # معلومات المشروع
```

---

## 🔑 معلومات التوقيع

| العنصر | القيمة |
|--------|--------|
| Keystore | `android.keystore` |
| Alias | `souqalwisat` |
| كلمة مرور Keystore | `souqalwisat123` |
| كلمة مرور Key | `souqalwisat123` |
| صلاحية المفتاح | 10000 يوم |

> ⚠️ **تحذير مهم:** كلمة المرور هذه للمفاتيح التجريبية فقط. للنشر على Play Store رسمياً، يجب إنشاء مفتاح توقيع خاص وتخزينه بأمان!

---

## 🏪 النشر على Google Play Store

1. أنشئ حساب مطور على [Google Play Console](https://play.google.com/console) (رسوم لمرة واحدة: $25)
2. أنشئ تطبيق جديد بمعرف الحزمة: `com.souqalwisat.pwa`
3. ارفع ملف `app-release-bundle.aab` (من Artifacts)
4. املأ بيانات المتجر (الاسم، الوصف، الصور، إلخ)
5. ارفع ملف `assetlinks.json` على الموقع
6. أرسل التطبيق للمراجعة

---

## ⚙️ تحديث التطبيق

لتغيير إعدادات التطبيق (الاسم، الألوان، الأيقونات):

1. عدّل ملف `twa-manifest.json`
2. ارفع التعديلات إلى GitHub
3. شغّل البناء من Actions

لتغيير رقم الإصدار:
```json
{
  "appVersionCode": 2,
  "appVersionName": "1.1.0"
}
```

---

## 🛠️ التقنيات المستخدمة

- **Bubblewrap** (@bubblewrap/cli) - أداة Google لتحويل PWA إلى تطبيق أندرويد
- **Trusted Web Activity (TWA)** - تقنية أندرويد لعرض الويب بدوّن شريط العنوان
- **GitHub Actions** - أتمتة البناء والنشر
- **PWA** - تطبيق الويب التقدمي الأصلي

---

## 📞 الدعم

- **المتجر:** سوق الوساط
- **الموقع:** souqalwisat.com
- **البريد:** souq.alwisat101@gmail.com
- **الهاتف:** +968 91705789
- **العنوان:** نزوى - الصقرية بجوار مجلس الغنتق
