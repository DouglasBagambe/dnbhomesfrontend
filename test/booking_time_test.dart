import 'package:flutter_test/flutter_test.dart';
import 'package:homes/features/bookings/data/bookings_repository.dart';

void main() {
  test('Uganda viewing wall time becomes UTC independently of device timezone',
      () {
    expect(ugandaViewingTime(DateTime(2026, 10, 11, 10, 30)),
        DateTime.utc(2026, 10, 11, 7, 30));
    expect(ugandaViewingTime(DateTime.utc(2026, 10, 11, 1)),
        DateTime.utc(2026, 10, 10, 22));
  });
}
