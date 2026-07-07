import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_alarm_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PrayerAlarmApp());

    // Verify that the app starts (it will show loading first)
    expect(find.byType(PrayerAlarmApp), findsOneWidget);
  });
}