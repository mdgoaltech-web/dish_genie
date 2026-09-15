import 'package:dish_genie/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('servings label is singular for 1 and plural otherwise', () {
    final l = AppLocalizationsEn();
    expect(l.recipeServingsCount(1), '1 serving');
    expect(l.recipeServingsCount(2), '2 servings');
    expect(l.recipeServingsCount(4), '4 servings');
  });
}
