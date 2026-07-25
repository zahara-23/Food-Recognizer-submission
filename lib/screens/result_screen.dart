import 'dart:io';

import 'package:flutter/material.dart';

import '../models/food_prediction.dart';
import '../models/meal.dart';
import '../models/nutrition_info.dart';
import '../services/classifier_service.dart';
import '../services/gemini_service.dart';
import '../services/mealdb_service.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/section_card.dart';
import '../widgets/state_views.dart';

/// Halaman Prediksi (Kriteria 3): menampilkan gambar yang diambil pengguna,
/// nama makanan hasil inferensi, confidence score, referensi resep dari
/// MealDB API, serta estimasi nutrisi dari Gemini API.
class ResultScreen extends StatefulWidget {
  final File imageFile;

  const ResultScreen({super.key, required this.imageFile});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  FoodPrediction? _prediction;
  String? _predictionError;

  List<Meal> _meals = [];
  bool _isLoadingMeals = true;
  String? _mealsError;

  NutritionInfo? _nutrition;
  bool _isLoadingNutrition = true;
  String? _nutritionError;

  @override
  void initState() {
    super.initState();
    _classify();
  }

  Future<void> _classify() async {
    setState(() => _predictionError = null);
    try {
      final prediction = await ClassifierService.instance.classifyImageFile(widget.imageFile);
      if (!mounted) return;
      setState(() => _prediction = prediction);
      _loadMealReference(prediction.label);
      _loadNutrition(prediction.label);
    } catch (e) {
      if (mounted) setState(() => _predictionError = e.toString());
    }
  }

  Future<void> _loadMealReference(String foodName) async {
    setState(() {
      _isLoadingMeals = true;
      _mealsError = null;
    });
    try {
      final meals = await MealDbService.searchWithFallback(foodName);
      if (!mounted) return;
      setState(() => _meals = meals);
    } catch (e) {
      if (mounted) setState(() => _mealsError = 'Gagal memuat referensi resep: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMeals = false);
    }
  }

  Future<void> _loadNutrition(String foodName) async {
    setState(() {
      _isLoadingNutrition = true;
      _nutritionError = null;
    });
    try {
      final nutrition = await GeminiService.getNutritionInfo(foodName);
      if (!mounted) return;
      setState(() => _nutrition = nutrition);
    } catch (e) {
      if (mounted) setState(() => _nutritionError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingNutrition = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Identifikasi')),
      body: _predictionError != null
          ? ErrorView(message: _predictionError!, onRetry: _classify)
          : _prediction == null
              ? const LoadingView(message: 'Menganalisis gambar...')
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final prediction = _prediction!;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.2,
            child: Image.file(widget.imageFile, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prediction.label,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ConfidenceBadge(confidence: prediction.confidence),
                if (!prediction.isConfident) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Model kurang yakin dengan hasil ini. Coba ambil ulang '
                    'gambar dengan pencahayaan lebih baik atau posisi lebih dekat.',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          _buildNutritionSection(),
          _buildRecipeSection(),
        ],
      ),
    );
  }

  Widget _buildNutritionSection() {
    return SectionCard(
      title: 'Estimasi Nutrisi (Gemini AI)',
      icon: Icons.local_fire_department_outlined,
      child: _isLoadingNutrition
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LoadingView(message: 'Menghitung estimasi nutrisi...'),
            )
          : _nutritionError != null
              ? ErrorView(
                  message: _nutritionError!,
                  onRetry: () => _loadNutrition(_prediction!.label),
                )
              : _nutrition == null
                  ? const Text('Tidak ada data nutrisi.')
                  : _NutritionGrid(nutrition: _nutrition!),
    );
  }

  Widget _buildRecipeSection() {
    return SectionCard(
      title: 'Referensi Resep (TheMealDB)',
      icon: Icons.restaurant_menu,
      child: _isLoadingMeals
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LoadingView(message: 'Mencari resep terkait...'),
            )
          : _mealsError != null
              ? ErrorView(
                  message: _mealsError!,
                  onRetry: () => _loadMealReference(_prediction!.label),
                )
              : _meals.isEmpty
                  ? const Text(
                      'Tidak ditemukan resep yang cocok untuk makanan ini di TheMealDB.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _meals.take(3).map((m) => _MealTile(meal: m)).toList(),
                    ),
    );
  }
}

class _NutritionGrid extends StatelessWidget {
  final NutritionInfo nutrition;

  const _NutritionGrid({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Kalori', '${nutrition.caloriesKcal.toStringAsFixed(0)} kkal', Icons.local_fire_department),
      ('Karbohidrat', '${nutrition.carbohydrateGram.toStringAsFixed(1)} g', Icons.rice_bowl),
      ('Lemak', '${nutrition.fatGram.toStringAsFixed(1)} g', Icons.opacity),
      ('Serat', '${nutrition.fiberGram.toStringAsFixed(1)} g', Icons.grass),
      ('Protein', '${nutrition.proteinGram.toStringAsFixed(1)} g', Icons.egg_alt),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        return Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF3EC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(item.$3, size: 20, color: const Color(0xFFE8622C)),
              const SizedBox(height: 6),
              Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(item.$1, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MealTile extends StatelessWidget {
  final Meal meal;

  const _MealTile({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _MealDetailSheet(meal: meal),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: meal.thumbnailUrl.isNotEmpty
                  ? Image.network(meal.thumbnailUrl, width: 64, height: 64, fit: BoxFit.cover)
                  : Container(width: 64, height: 64, color: Colors.grey.shade200),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.category ?? '-'} • ${meal.area ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lihat bahan & langkah pembuatan',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE8622C)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealDetailSheet extends StatelessWidget {
  final Meal meal;

  const _MealDetailSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meal.thumbnailUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(meal.thumbnailUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Text(meal.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${meal.category ?? '-'} • ${meal.area ?? '-'}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              const Text('Bahan-bahan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...meal.ingredients.map(
                (ing) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.black45),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${ing.name} - ${ing.measure}')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Langkah Pembuatan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(meal.instructions, style: const TextStyle(height: 1.5)),
            ],
          ),
        );
      },
    );
  }
}
