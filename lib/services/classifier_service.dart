import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;

import '../core/constants.dart';
import '../models/food_prediction.dart';
import 'classifier_isolate.dart';
import 'image_utils.dart';
import 'model_provider.dart';

/// API utama yang dipakai oleh UI untuk melakukan klasifikasi makanan.
/// Menyembunyikan detail: dari mana model didapat (Firebase ML / asset),
/// bagaimana preprocessing dilakukan, dan bagaimana inferensi dijalankan
/// di Isolate terpisah.
class ClassifierService {
  ClassifierService._();
  static final ClassifierService instance = ClassifierService._();

  ClassifierIsolate? _isolate;
  List<String> _labels = [];
  bool _isReady = false;

  bool get isReady => _isReady;

  /// Harus dipanggil sekali (mis. di splash/home screen) sebelum
  /// melakukan klasifikasi pertama kali.
  Future<void> initialize() async {
    if (_isReady) return;

    final modelPath = await ModelProvider.getModelPath();
    _labels = await ModelProvider.loadLabels();

    _isolate = await ClassifierIsolate.spawn(
      modelPath: modelPath,
      inputSize: AppConstants.inputImageSize,
      numThreads: AppConstants.numThreads,
    );

    _isReady = true;
  }

  /// Klasifikasi dari gambar statis (hasil kamera/galeri/crop).
  Future<FoodPrediction> classifyImageFile(File imageFile) async {
    _ensureReady();
    final decoded = await ImageUtils.decodeStaticImage(imageFile.path);
    if (decoded == null) {
      throw Exception('Gagal membaca gambar, file tidak valid.');
    }
    return _runInference(decoded);
  }

  /// Klasifikasi real-time dari camera feed (per-frame).
  Future<FoodPrediction> classifyCameraImage(CameraImage cameraImage) async {
    _ensureReady();
    final converted = ImageUtils.convertCameraImage(cameraImage);
    return _runInference(converted);
  }

  Future<FoodPrediction> _runInference(image_lib.Image decodedImage) async {
    final inputBytes = ImageUtils.imageToByteListUint8(decodedImage);
    final result = await _isolate!.classify(inputBytes);

    if (result.error != null) {
      throw Exception('Inferensi gagal: ${result.error}');
    }

    return _toPrediction(result.outputQuantized);
  }

  /// Mengubah output kuantisasi UINT8 (0-255) menjadi probabilitas (0-1)
  /// menggunakan parameter kuantisasi model (scale = 1/256, zero point = 0),
  /// lalu mengambil kelas dengan probabilitas tertinggi (argmax).
  FoodPrediction _toPrediction(List<int> quantizedOutput) {
    const scale = 1 / 256.0;

    int bestIndex = 0;
    int bestValue = -1;
    for (int i = 0; i < quantizedOutput.length; i++) {
      if (quantizedOutput[i] > bestValue) {
        bestValue = quantizedOutput[i];
        bestIndex = i;
      }
    }

    final confidence = bestValue * scale;
    final label = (bestIndex >= 0 && bestIndex < _labels.length)
        ? _labels[bestIndex]
        : 'Tidak diketahui';

    return FoodPrediction(
      label: label,
      confidence: confidence.clamp(0.0, 1.0),
      labelIndex: bestIndex,
    );
  }

  void _ensureReady() {
    if (!_isReady || _isolate == null) {
      throw StateError(
        'ClassifierService belum di-initialize. Panggil initialize() terlebih dahulu.',
      );
    }
  }

  void dispose() {
    _isolate?.dispose();
    _isReady = false;
  }
}
