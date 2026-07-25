# Food Recognizer

Aplikasi Flutter yang mengidentifikasi jenis makanan dari foto menggunakan model
machine learning (TensorFlow Lite / LiteRT), lalu menampilkan halaman prediksi
berisi confidence score, referensi resep dari **TheMealDB API**, dan estimasi
nutrisi dari **Gemini API**.

Dibuat untuk submission kelas *Belajar Penerapan Machine Learning untuk Flutter* (Dicoding).

---

## ⚠️ Catatan penting sebelum mulai

Kode ini ditulis lengkap secara manual (bukan hasil `flutter create`), karena
disusun di lingkungan tanpa Flutter SDK/emulator untuk build & test langsung.
Sebelum dipakai, ikuti langkah **Setup** di bawah — terutama langkah 1 — supaya
struktur project menjadi project Flutter yang valid dan bisa di-build.

Struktur yang disediakan di sini:
```
food_recognizer/
├── lib/                  ✅ sudah lengkap (semua source code)
├── assets/model/         ✅ sudah lengkap (model .tflite + labels.txt)
├── pubspec.yaml          ✅ sudah lengkap
├── .env                  ✅ placeholder, isi API key Anda
└── android/, ios/, ...   ❌ belum ada — dibuat di langkah Setup #1
```

---

## Setup

### 1. Buat scaffold platform (Android/iOS/dll)
```bash
flutter create --project-name food_recognizer --org com.example --platforms android,ios .
```
Jalankan perintah ini **di dalam folder `food_recognizer` ini** (yang sudah berisi
`lib/`, `assets/`, `pubspec.yaml`). Perintah ini hanya menambahkan folder
`android/`, `ios/`, dsb — tidak menimpa `lib/` maupun `pubspec.yaml` yang sudah ada
(jika diminta overwrite `pubspec.yaml`/`lib/main.dart`, pilih **No**).

### 2. Tambahkan permission
**Android** — `android/app/src/main/AndroidManifest.xml`, tambahkan sebelum `<application>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```
Dan di dalam tag `<application>`, tambahkan (dibutuhkan `image_cropper` di Android):
```xml
<activity android:name="com.yalantis.ucrop.UCropActivity" android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
```
Set `minSdkVersion` ke minimal **21** di `android/app/build.gradle`.

**iOS** — `ios/Runner/Info.plist`, tambahkan:
```xml
<key>NSCameraUsageDescription</key>
<string>Aplikasi membutuhkan akses kamera untuk memotret makanan.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Aplikasi membutuhkan akses galeri untuk memilih foto makanan.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Aplikasi membutuhkan akses untuk menyimpan hasil crop foto.</string>
```

### 3. Isi API Key Gemini
Buka file `.env` di root project, ganti dengan API key dari
[Google AI Studio](https://aistudio.google.com/apikey):
```
GEMINI_API_KEY=isi_dengan_api_key_anda
```
Sesuai ketentuan kriteria submission, API key **tidak perlu** disematkan/hardcode
di dalam kode — reviewer bisa mengisi API key mereka sendiri di file `.env` ini.

> Cek juga `AppConstants.geminiModel` di `lib/core/constants.dart` — sesuaikan
> dengan nama model Gemini yang aktif saat ini di akun Anda (mis. `gemini-2.x-flash`),
> karena nama model dapat berubah/di-deprecate seiring waktu.

### 4. (Opsional, untuk kriteria Advanced) Konfigurasi Firebase ML
Model classifier berukuran ±21 MB — cukup besar untuk dibundel sebagai asset lokal
kalau ingin menjaga ukuran ZIP submission tetap kecil. Karena itu, kriteria Advanced
meminta model diunduh **secara dinamis** dari Firebase ML alih-alih dibundel.

1. Buat project di [Firebase Console](https://console.firebase.google.com), aktifkan **Machine Learning > Custom**.
2. Upload `assets/model/food_classifier.tflite` di sana, beri nama persis
   `food-classifier-v1` (atau ubah `AppConstants.firebaseModelName` agar sesuai).
3. Jalankan `flutterfire configure` (install dulu: `dart pub global activate flutterfire_cli`)
   untuk menghasilkan `google-services.json`, `GoogleService-Info.plist`, dan `lib/firebase_options.dart`.
4. Update `main.dart`: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
5. **Sebelum membuat ZIP submission**, hapus baris
   `assets/model/food_classifier.tflite` dari `pubspec.yaml` dan file modelnya,
   supaya ukuran ZIP tidak melebihi 25 MB. Aplikasi akan otomatis mengunduh
   model dari Firebase ML saat pertama kali dijalankan.

Bila Anda **tidak** ingin memakai Firebase ML, tidak masalah — kode ini otomatis
fallback memakai model asset lokal (`ModelProvider._copyAssetModelToLocal`), cukup
biarkan `.tflite` di `assets/model/` (dan pastikan ukuran ZIP akhir tetap < 25 MB).

### 5. Install dependencies & jalankan
```bash
flutter pub get
flutter run
```

---

## Arsitektur & pemetaan ke kriteria submission

### Kriteria 1 — Pengambilan Gambar
| Fitur | Lokasi kode |
|---|---|
| Pilih gambar dari galeri/kamera (`image_picker`) | `lib/screens/home_screen.dart` |
| Crop gambar (`image_cropper`) | `HomeScreen._cropAndProceed` |
| Custom camera + real-time camera feed (`camera`) | `lib/screens/camera_screen.dart` |

### Kriteria 2 — Machine Learning
| Fitur | Lokasi kode |
|---|---|
| Inferensi dengan TensorFlow Lite / LiteRT | `lib/services/classifier_isolate.dart` |
| Preprocessing gambar (decode, resize, YUV→RGB utk camera feed) | `lib/services/image_utils.dart` |
| Inferensi di background Isolate (UI tidak freeze) | `lib/services/classifier_isolate.dart` (`Isolate.spawn`) |
| Firebase ML — download model dinamis | `lib/services/model_provider.dart` |

### Kriteria 3 — Halaman Prediksi
| Fitur | Lokasi kode |
|---|---|
| Gambar, nama makanan, confidence score | `lib/screens/result_screen.dart` |
| Referensi resep dari TheMealDB API (search + ingredients + instructions) | `lib/services/mealdb_service.dart`, `lib/models/meal.dart` |
| Estimasi nutrisi dari Gemini API (kalori, karbohidrat, lemak, serat, protein) | `lib/services/gemini_service.dart` |

---

## Tentang model ML

Model `assets/model/food_classifier.tflite` diambil dari
[AIY Vision Classifier Food V1 (Kaggle)](https://www.kaggle.com/models/google/aiy/tfLite/vision-classifier-food-v1).

Spesifikasi (hasil inspeksi langsung terhadap file model):
- Input: gambar `192×192×3` RGB, ter-kuantisasi **UINT8**.
- Output: probabilitas untuk **2024 kelas** (indeks 0 = `__background__`), ter-kuantisasi UINT8 dengan scale `1/256`.
- Label sudah ter-embed di dalam file `.tflite` itu sendiri (`probability-labels-en.txt`),
  sudah diekstrak menjadi `assets/model/labels.txt`.

**Batasan model** (penting untuk diperhatikan di UI/UX, sudah tercermin di kode):
- Model **tidak bisa** menentukan apakah makanan aman dimakan.
- Model **tidak cocok** untuk menebak bahan-bahan makanan (bahan didapat dari MealDB, bukan model).
- Model **tidak bisa** memperkirakan nutrisi (nutrisi didapat dari Gemini API, bukan model).
- Model **tidak bisa** mendeteksi gambar non-makanan secara eksplisit — karena itu
  `FoodPrediction.isConfident` menampilkan peringatan bila confidence rendah.

Sample gambar uji (dari `assets.zip` yang diberikan) sudah saya cek: berisi
`nasi-lemak.jpg`, `beef-bourguignon.jpg`, `lasagna.jpg`, `sushi.jpg`, `satay.jpg`
(contoh makanan), serta `vase.jpg` dan `eiffel.jpg` (contoh **bukan** makanan, untuk
menguji batasan model di atas). Gunakan gambar-gambar ini untuk menguji aplikasi
sebelum submit.

---

## Known limitations / yang perlu Anda verifikasi sendiri

Karena kode ini disusun tanpa akses Flutter SDK untuk build & run langsung, mohon
lakukan pengujian menyeluruh sebelum submit:
- Jalankan `flutter analyze` dan perbaiki bila ada import/versi package yang
  perlu disesuaikan dengan versi Flutter/Dart Anda.
- Versi package di `pubspec.yaml` mengikuti versi stabil yang umum dipakai;
  jalankan `flutter pub outdated` untuk memastikan versi terbaru & kompatibel.
- Uji fitur kamera & real-time feed di **perangkat fisik** (emulator seringkali
  tidak mendukung kamera dengan baik).
- Sebelum membuat ZIP submission: jalankan `flutter clean`, hapus folder `build/`,
  dan perhatikan catatan ukuran model di bagian Firebase ML di atas.
