import 'package:intl/intl.dart';

final NumberFormat _currencyFmt = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹ ',
  decimalDigits: 2,
);
final DateFormat _shortDate = DateFormat('yyyy-MM-dd');
final DateFormat _prettyDate = DateFormat('dd MMM yyyy');

String formatCurrency(num value) => _currencyFmt.format(value);
String formatIsoDate(DateTime dt) => _shortDate.format(dt);
String formatPrettyDate(DateTime dt) => _prettyDate.format(dt);

DateTime parseDateFlexible(String raw) {
  final s = raw.trim();
  if (s.isEmpty) {
    throw const FormatException('Empty date');
  }

  // Try ISO first.
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    // Continue.
  }

  for (final pattern in [
    'dd/MM/yyyy',
    'd/M/yyyy',
    'dd-MM-yyyy',
    'd-M-yyyy',
    'MM/dd/yyyy',
    'M/d/yyyy',
  ]) {
    try {
      return DateFormat(pattern).parseStrict(s);
    } catch (_) {
      // Continue.
    }
  }

  throw FormatException('Invalid date: $raw');
}

DateTime monthStart(DateTime dt) => DateTime(dt.year, dt.month, 1);
DateTime monthEnd(DateTime dt) =>
    DateTime(dt.year, dt.month + 1, 0, 23, 59, 59);
DateTime yearStart(DateTime dt) => DateTime(dt.year, 1, 1);
DateTime yearEnd(DateTime dt) => DateTime(dt.year, 12, 31, 23, 59, 59);
