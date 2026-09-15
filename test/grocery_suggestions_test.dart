import 'package:dish_genie/data/models/recipe.dart';
import 'package:dish_genie/services/grocery_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe recipe(String title, List<String> ingredients) => Recipe.fromJson({
  'id': title.toLowerCase(),
  'title': title,
  'ingredients': [
    for (final i in ingredients) {'name': i, 'quantity': '1', 'unit': ''},
  ],
});

void main() {
  test('suggestions come only from real recipes and skip listed items', () {
    final generated = recipe('Baked Eggs', ['Eggs', 'Feta', 'Spinach']);
    final saved = recipe('Pasta', ['Pasta', 'eggs', 'Tomatoes', 'Basil']);
    final onList = {'feta'};
    final out = GrocerySuggestions.from(
      [null, generated, saved],
      (n) => onList.contains(n.toLowerCase()),
    );
    expect(out.map((s) => s.item).toList(), ['Eggs', 'Spinach', 'Pasta', 'Tomatoes']);
    expect(out.first.recipeTitle, 'Baked Eggs');
    expect(out.last.recipeTitle, 'Pasta');
  });

  test('no recipes means no suggestions (nothing is invented)', () {
    expect(GrocerySuggestions.from(const [null], (_) => false), isEmpty);
  });
}
