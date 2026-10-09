import 'package:flutter_test/flutter_test.dart';
import 'package:homes/features/compare/compare_controller.dart';
import 'package:homes/features/favorites/favorites_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homes/features/search/recent_searches.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('first recent search persists, deduplicates and survives reload',
      () async {
    final searches = RecentSearches();
    await searches.add(' Ntinda ');
    await searches.add('Kampala');
    await searches.add('ntinda');
    expect(await RecentSearches().getAll(), ['ntinda', 'Kampala']);
    for (var i = 0; i < 8; i++) {
      await searches.add('Area $i');
    }
    expect((await searches.getAll()).length, 6);
    await searches.clear();
    expect(await searches.getAll(), isEmpty);
    await searches.add('Kampala');
    expect(await searches.getAll(), ['Kampala']);
  });
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
