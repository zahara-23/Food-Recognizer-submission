/// Hasil satu kali proses inferensi model klasifikasi makanan.
class FoodPrediction {
  final String label;
  final double confidence; // 0.0 - 1.0
  final int labelIndex;

  const FoodPrediction({
    required this.label,
    required this.confidence,
    required this.labelIndex,
  });

  /// Confidence dalam format persentase yang mudah dibaca, mis. "92.4%".
  String get confidencePercentText => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Model ini hanya bisa mengenali makanan, bukan menentukan apakah
  /// gambar tersebut benar-benar makanan. Kita anggap prediksi "tidak yakin"
  /// bila confidence terlalu rendah atau jatuh ke kelas latar belakang.
  bool get isConfident => confidence >= 0.4 && label != '__background__';

  @override
  String toString() => 'FoodPrediction(label: $label, confidence: $confidence)';
}
