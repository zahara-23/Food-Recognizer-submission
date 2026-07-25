class AppConstants {
  AppConstants._();

  // --- Model ML ---
  static const String modelAssetPath = 'assets/model/food_classifier.tflite';
  static const String labelsAssetPath = 'assets/model/labels.txt';
  static const int inputImageSize = 192; // model dilatih dengan input 192x192
  static const int numThreads = 4;

  /// Nama model custom di Firebase ML Console (Kriteria 2 - Advanced).
  /// Upload berkas assets/model/food_classifier.tflite ke Firebase console
  /// pada menu Machine Learning > Custom, lalu isi nama yang sama di sini.
  static const String firebaseModelName = 'food-classifier-v1';

  // --- MealDB API (gratis, tanpa API key) ---
  static const String mealDbBaseUrl = 'https://www.themealdb.com/api/json/v1/1';

  // --- Gemini API ---
  // Model generatif ringan & cepat untuk structured output nutrisi.
  static const String geminiModel = 'gemini-3.5-flash-lite';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
}
