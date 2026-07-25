/// Representasi satu resep dari TheMealDB API
/// (endpoint search.php / lookup.php).
class Meal {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String instructions;
  final String? category;
  final String? area;
  final List<MealIngredient> ingredients;

  const Meal({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.instructions,
    required this.ingredients,
    this.category,
    this.area,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final ingredients = <MealIngredient>[];

    // TheMealDB menyimpan bahan & takaran sebagai strIngredient1..20
    // dan strMeasure1..20, bukan sebagai list, jadi harus dirangkai manual.
    for (var i = 1; i <= 20; i++) {
      final ingredient = (json['strIngredient$i'] as String?)?.trim();
      final measure = (json['strMeasure$i'] as String?)?.trim();
      if (ingredient != null && ingredient.isNotEmpty) {
        ingredients.add(
          MealIngredient(
            name: ingredient,
            measure: (measure == null || measure.isEmpty) ? '-' : measure,
          ),
        );
      }
    }

    return Meal(
      id: (json['idMeal'] ?? '').toString(),
      name: (json['strMeal'] ?? 'Tidak diketahui').toString(),
      thumbnailUrl: (json['strMealThumb'] ?? '').toString(),
      instructions: (json['strInstructions'] ?? '').toString(),
      category: json['strCategory']?.toString(),
      area: json['strArea']?.toString(),
      ingredients: ingredients,
    );
  }
}

class MealIngredient {
  final String name;
  final String measure;

  const MealIngredient({required this.name, required this.measure});
}
