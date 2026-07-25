import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/meal.dart';

/// Wrapper untuk TheMealDB API (gratis, tanpa API key).
/// Dipakai untuk menampilkan referensi resep berdasarkan nama makanan
/// hasil inferensi model ML (Kriteria 3 - Skilled).
class MealDbService {
  MealDbService._();

  /// Search meal by name -> GET /search.php?s={name}
  static Future<List<Meal>> searchMealByName(String foodName) async {
    final uri = Uri.parse('${AppConstants.mealDbBaseUrl}/search.php?s=$foodName');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('MealDB search gagal (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final meals = body['meals'] as List<dynamic>?;
    if (meals == null) return [];

    return meals.map((m) => Meal.fromJson(m as Map<String, dynamic>)).toList();
  }

  /// Lookup full meal details by id -> GET /lookup.php?i={id}
  static Future<Meal?> lookupMealById(String id) async {
    final uri = Uri.parse('${AppConstants.mealDbBaseUrl}/lookup.php?i=$id');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('MealDB lookup gagal (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final meals = body['meals'] as List<dynamic>?;
    if (meals == null || meals.isEmpty) return null;

    return Meal.fromJson(meals.first as Map<String, dynamic>);
  }

  /// Coba cari dengan nama lengkap hasil inferensi. Bila tidak ketemu
  /// (nama makanan dari model kadang sangat spesifik/lokal), coba lagi
  /// dengan kata pertama saja sebagai fallback pencarian yang lebih umum.
  static Future<List<Meal>> searchWithFallback(String foodName) async {
    final results = await searchMealByName(foodName);
    if (results.isNotEmpty) return results;

    final firstWord = foodName.split(' ').first;
    if (firstWord.isEmpty || firstWord == foodName) return [];

    return searchMealByName(firstWord);
  }
}
