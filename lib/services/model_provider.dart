import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

/// Bertanggung jawab menyediakan berkas model (.tflite) yang siap dipakai
/// oleh interpreter, baik dari:
///  1. Firebase ML (diunduh secara dinamis dari cloud - Kriteria 2 Advanced), atau
///  2. Fallback: model bawaan yang dibundel sebagai asset lokal,
///     dipakai bila Firebase belum dikonfigurasi atau perangkat sedang offline.
class ModelProvider {
  ModelProvider._();

  /// Set `true` untuk memaksa selalu memakai model asset lokal
  /// (mis. saat development sebelum Firebase project disiapkan).
  static const bool forceLocalAsset = false;

  static Future<String> getModelPath() async {
    if (!forceLocalAsset) {
      try {
        final firebaseModelPath = await _downloadFromFirebaseMl();
        if (firebaseModelPath != null) {
          developer.log('Model dimuat dari Firebase ML', name: 'ModelProvider');
          return firebaseModelPath;
        }
      } catch (e) {
        developer.log(
          'Gagal mengunduh model dari Firebase ML, fallback ke asset lokal: $e',
          name: 'ModelProvider',
        );
      }
    }
    return _copyAssetModelToLocal();
  }

  /// Mengunduh model custom dari Firebase ML Model Downloader.
  /// Model harus terlebih dahulu di-upload melalui Firebase Console
  /// (Machine Learning > Custom) dengan nama sesuai [AppConstants.firebaseModelName].
  static Future<String?> _downloadFromFirebaseMl() async {
    final model = await FirebaseModelDownloader.instance.getModel(
      AppConstants.firebaseModelName,
      FirebaseModelDownloadType.localModelUpdateInBackground,
      FirebaseModelDownloadConditions(
        androidChargingRequired: false,
        androidWifiRequired: false,
        androidDeviceIdleRequired: false,
        iosAllowsCellularAccess: true,
      ),
    );
    return model.file.path;
  }

  /// Menyalin model bawaan dari assets ke direktori dokumen aplikasi,
  /// karena `Interpreter.fromAsset` tidak selalu kompatibel bila
  /// interpreter dijalankan pada isolate terpisah (butuh path absolut).
  static Future<String> _copyAssetModelToLocal() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/food_classifier.tflite');

    if (!await file.exists()) {
      final byteData = await rootBundle.load(AppConstants.modelAssetPath);
      await file.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    }
    return file.path;
  }

  static Future<List<String>> loadLabels() async {
    final raw = await rootBundle.loadString(AppConstants.labelsAssetPath);
    return raw.split('\n').map((e) => e.trim()).toList();
  }
}
