import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/features/compare/compare_controller.dart';
import 'package:homes/features/favorites/favorites_controller.dart';
import 'package:homes/features/listings/domain/property.dart';
import 'package:homes/features/listings/presentation/property_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'property card exposes price, facts, verification and accessible actions',
    (tester) async {
      const property = Property(
        id: '1',
        slug: 'home',
        title: 'Calm family home',
        description: '',
        purpose: 'rent',
        type: 'house',
        price: PropertyPrice(amount: 1500000, currency: 'UGX', period: 'month'),
        location: PropertyLocation(
          country: 'Uganda',
          region: 'Central',
          district: 'Kampala',
          area: 'Ntinda',
          address: '',
        ),
        media: [],
        amenities: [],
        tags: [],
        bedrooms: 3,
        bathrooms: 2,
        size: 180,
        sizeUnit: 'sqm',
        featured: false,
        verificationStatus: 'verified',
        status: 'published',
        viewCount: 1,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => FavoritesController()),
            ChangeNotifierProvider(create: (_) => CompareController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                child: PropertyCard(property: property, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('UGX 1,500,000 / month'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('3 beds · 2 baths · 180 sqm'), findsOneWidget);
      expect(find.byTooltip('Add to compare'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Favorite',
        ),
        findsOneWidget,
      );
    },
  );
}
