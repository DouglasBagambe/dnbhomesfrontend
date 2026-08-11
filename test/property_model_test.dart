import 'package:flutter_test/flutter_test.dart';
import 'package:homes/features/listings/domain/property.dart';

void main() {
  test('parses the V1 property contract without inventing verification', () {
    final property = Property.fromJson({
      '_id': 'p1',
      'slug': 'ntinda-home',
      'title': 'Ntinda home',
      'description': 'Description',
      'purpose': 'rent',
      'type': 'house',
      'price': {'amount': 1500000, 'currency': 'UGX', 'period': 'month'},
      'location': {
        'country': 'Uganda',
        'region': 'Central',
        'district': 'Kampala',
        'area': 'Ntinda',
        'address': 'Plot 1',
        'coordinates': {
          'type': 'Point',
          'coordinates': [32.6, .35],
        },
      },
      'media': [
        {'url': 'https://example.com/home.jpg', 'type': 'image'},
      ],
      'featured': true,
      'verificationStatus': 'unverified',
      'status': 'published',
      'viewCount': 4,
    });
    expect(property.price.amount, 1500000);
    expect(property.location.longitude, 32.6);
    expect(property.location.latitude, .35);
    expect(property.imageUrl, contains('home.jpg'));
    expect(property.verified, isFalse);
  });
  test('handles missing optional fields safely', () {
    final property = Property.fromJson(const {});
    expect(property.title, 'Untitled property');
    expect(property.media, isEmpty);
    expect(property.agent, isNull);
    expect(property.price.amount, 0);
  });
}
