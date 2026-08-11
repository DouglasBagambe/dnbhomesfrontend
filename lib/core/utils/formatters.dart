import 'package:intl/intl.dart';
import '../../features/listings/domain/property.dart';

String formatMoney(PropertyPrice price) {
  final amount = NumberFormat.decimalPattern(
    'en_UG',
  ).format(price.amount.round());
  final suffix = switch (price.period) {
    'month' => ' / month',
    'week' => ' / week',
    'night' => ' / night',
    _ => '',
  };
  return '${price.currency} $amount$suffix';
}

String titleCase(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
