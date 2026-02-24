import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker_mobile/app.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const TrackerMobileApp());
    await tester.pump();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
