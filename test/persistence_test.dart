import 'package:flutter_test/flutter_test.dart';
import 'package:homes/features/compare/compare_controller.dart';
import 'package:homes/features/favorites/favorites_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('compare remains capped at two', () async {
    final controller = CompareController();
    await Future<void>.delayed(Duration.zero);
    expect(await controller.toggle('1'), isTrue);
    expect(await controller.toggle('2'), isTrue);
    expect(await controller.toggle('3'), isFalse);
    expect(controller.ids, ['1', '2']);
  });
  test('favorites update immediately and persist', () async {
    final controller = FavoritesController();
    await Future<void>.delayed(Duration.zero);
    await controller.toggle('p1');
    expect(controller.contains('p1'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('homes_favorites_v1'), contains('p1'));
  });
}
