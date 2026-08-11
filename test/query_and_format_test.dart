import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/utils/formatters.dart';
import 'package:homes/features/listings/data/listings_repository.dart';
import 'package:homes/features/listings/domain/property.dart';

void main() {
  test('builds allow-listed V1 listing query', () {
    final query = const ListingQuery(
      q: 'Ntinda',
      purpose: 'rent',
      maxPrice: 500000,
      bedrooms: 2,
      amenities: ['Parking', 'Security'],
      page: 2,
      sort: ListingSort.priceAsc,
    ).toQuery();
    expect(query['q'], 'Ntinda');
    expect(query['maxPrice'], '500000.0');
    expect(query['amenities'], 'Parking,Security');
    expect(query['sort'], 'price_asc');
    expect(query['page'], '2');
  });
  test('formats Uganda-first property money and period', () {
    expect(
      formatMoney(
        const PropertyPrice(amount: 1500000, currency: 'UGX', period: 'month'),
      ),
      'UGX 1,500,000 / month',
    );
  });
}
