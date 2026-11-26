import 'package:flutter_test/flutter_test.dart';
import 'package:green_window/main.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const GreenWindowApp());

    expect(find.text('Green Window'), findsOneWidget);
  });
}
