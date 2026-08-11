import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/bookings/data/bookings_repository.dart';

void main() {
  test('accepts a valid future viewing request', () {
    ViewingRequestInput(
      propertyId: 'p1',
      guestName: 'Jane Doe',
      guestEmail: 'jane@example.com',
      guestPhone: '+256700000000',
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
    ).validate();
  });
  test('rejects invalid contact and past requests', () {
    expect(
      () => ViewingRequestInput(
        propertyId: 'p1',
        guestName: 'J',
        guestEmail: 'invalid',
        guestPhone: '1',
        scheduledAt: DateTime.now(),
      ).validate(),
      throwsA(isA<ApiFailure>()),
    );
  });
}
