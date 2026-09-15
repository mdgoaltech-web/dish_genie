import '../data/models/recipe.dart';

/// One "Smart Suggestion" on the Grocery tab: an ingredient the user has
/// not put on the list yet, taken from a recipe they actually generated or
/// saved. Nothing here is invented or hard-coded.
class GrocerySuggestion {
  const GrocerySuggestion({required this.item, required this.recipeTitle});

  final String item;
  final String recipeTitle;
}

/// Pure helper so the selection logic is unit-testable.
class GrocerySuggestions {
  GrocerySuggestions._();

  /// Picks up to [max] ingredients from [recipes] (in order) that are not
  /// already on the list according to [onList]. Ingredient names are
  /// de-duplicated case-insensitively; recipes without a title are skipped.
  static List<GrocerySuggestion> from(
    Iterable<Recipe?> recipes,
    bool Function(String name) onList, {
    int max = 4,
  }) {
    final out = <GrocerySuggestion>[];
    final seen = <String>{};
    for (final recipe in recipes) {
      if (recipe == null || recipe.title.trim().isEmpty) continue;
      for (final ingredient in recipe.ingredients) {
        final name = ingredient.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (seen.contains(key) || onList(name)) continue;
        seen.add(key);
        out.add(GrocerySuggestion(item: name, recipeTitle: recipe.title));
        if (out.length >= max) return out;
      }
    }
    return out;
  }
}
