import 'package:flutter_test/flutter_test.dart';
import 'package:Ankuram/main.dart';

void main() {
  testWidgets('Dance Attendance app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const DanceAttendanceApp());

    await tester.pump();

    expect(find.text('ANKURAM'), findsOneWidget);
    expect(find.text('BHARATANATYAM'), findsOneWidget);
  });
}