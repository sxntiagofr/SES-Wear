import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/main.dart';

void main() {
  testWidgets('SES Wear inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const SESWearApp());

    expect(find.text('Mi armario'), findsNothing);
  });
}
