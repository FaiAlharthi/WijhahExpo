# وجهة · Wijha (iOS)

تطبيق SwiftUI لزوار إكسبو 2030 الرياض، مبني على تصميم فيقما «وجهة — Final UI & Developer Handoff» ومربوط بباك إند Spring Boot (مشروع Expo).

## التشغيل
1. شغّل الباك إند أول (`http://localhost:8080`).
2. افتح `Wijha.xcodeproj` في **Xcode 16 أو أحدث**، واختر محاكي آيفون (iOS 17+) ثم ▶︎ Run.
3. على جوال حقيقي: من الشاشة الأولى (⋯ ← عنوان السيرفر) أو من الإعدادات، غيّر العنوان إلى IP جهازك، مثل `http://192.168.1.5:8080`.

## الحسابات
- **زائر:** تسجيل من التطبيق (خطوتين + الاهتمامات).
- **مشرف:** نفس شاشة الدخول. إذا كان الحساب ADMIN تفتح لوحة المشرف تلقائيًا.

## الهوية
- الداكن مطابق للتصميم (ink / blue / lime / mint)، والفاتح بنفس الهوية. التبديل من حسابي ← الإعدادات (داكن / فاتح / حسب الجهاز).
- عربي (RTL) وإنجليزي، والأرقام غربية في اللغتين.
- الخريطة بنمطين (توضيحية تُرسم من البيانات / مصوّرة من `expo-map.png` و `expo-map-light.png`)، وما تقرّب أو تتحرك من نفسها.

## الشاشات وربطها بالباك
| القسم | الشاشات | الإندبوينتات |
|---|---|---|
| Auth | ترحيب، تسجيل (خطوتين)، اهتمامات، دخول، ضيف | `visitor/register`, `visitor/getMyInfo`, `visitor/addInterest`, `user/auth/logout` |
| رحلتي | الرئيسية، الخطة الجديدة (4 خطوات + ملخص + توليد + جاهزة)، خططي، تفاصيل الخطة، تعديل الخطة، إجراءات الخطة، تغيير البوابة، مشاركة PDF | `roadmap/*` كلها، `path/roadmap/*`, `roadmap/pdf`, `roadmap/sendPdf` |
| الخريطة | مسار اليوم، المحطة التالية، بطاقة الجناح، الاتجاهات، بانرات الإتاحة | `path/roadmap/{id}`, `path/shortest`, `path/shortest-accessible`, `location/get`, `path/get`, `zone/get`, `entrance/getAll` |
| تسجيل الزيارة | تأكيد، ختم الطابع | `visit/checkIn`, `passport/*`, `review/getPending` |
| استكشف | قائمة/خريطة، الأعلى تقييمًا، المناطق، فلتر الإتاحة، الزحمة، البحث، صفحة الجناح | `pavilion/*`, `review/pavilion/*`, `crowd/now`, `crowd/pavilion/{id}` |
| جوازي | الطوابع (58)، السجل، بانتظار التقييم | `passport/getMyPassport`, `passport/getMyStamps`, `review/getPending` |
| التقييم | كتابة/تعديل/حذف، رأي الإتاحة | `review/add`, `review/update`, `review/delete`, `review/getMyReviews` |
| المساعد | اقتراحات ومحادثة | `chatbot/suggestions`, `chatbot/ask` |
| تنبيهات الزحمة | القائمة والموافقة | `crowd/alerts/my`, `crowd/alerts/{id}/accept` |
| حسابي | الملف، الاهتمامات، بيانات الحساب، حذف الحساب، الإعدادات | `visitor/updateVisitor`, `visitor/add|removeInterest`, `user/updateUser`, `user/deleteUser` |
| المشرف | اللوحة، البيانات (أجنحة + إتاحة + سعة، مناطق، بوابات، نقاط، ممرات، اهتمامات)، الزحمة (المعامل، الانتظار اليدوي، الفحص)، السجلات والزوار | `admin/dashboard`, كل CRUD، `crowd/factor`, `crowd/override`, `crowd/check`, `*/getAll`, `visitor/deleteVisitor/{id}`, `user/deleteUser/{id}` |

## أشياء في التصميم ما لها مقابل في الباك (مشالة)
- «اختر الأجنحة بنفسي» (B3 / POST roadmap/manual).
- «رتّبها بأقصر مشي» (B7).
- «نحو X دقائق مشيًا»: بدالها وقت الوصول المتوقع والانتظار (`plannedTime` و `expectedWait`).
- استعادة كلمة المرور (B5): رسالة توضيحية فقط.
- المفضلة (♡) في صفحة الجناح.
