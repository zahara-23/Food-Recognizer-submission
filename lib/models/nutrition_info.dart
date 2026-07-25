/// Estimasi kandungan gizi suatu makanan (per porsi umum),
/// dihasilkan oleh Gemini API dalam format terstruktur (JSON).
class NutritionInfo {
  final double caloriesKcal;
  final double carbohydrateGram;
  final double fatGram;
  final double fiberGram;
  final double proteinGram;
  final String? note;

  const NutritionInfo({
    required this.caloriesKcal,
    required this.carbohydrateGram,
    required this.fatGram,
    required this.fiberGram,
    required this.proteinGram,
    this.note,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    double _num(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return NutritionInfo(
      caloriesKcal: _num(json['calories'] ?? json['kalori']),
      carbohydrateGram: _num(json['carbohydrate'] ?? json['karbohidrat']),
      fatGram: _num(json['fat'] ?? json['lemak']),
      fiberGram: _num(json['fiber'] ?? json['serat']),
      proteinGram: _num(json['protein']),
      note: json['note']?.toString(),
    );
  }
}
