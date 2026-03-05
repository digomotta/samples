import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_app/main.dart';

void main() {
  testWidgets('App renders', (tester) async {
    await tester.pumpWidget(const ShoppingApp());
    expect(find.text('SuperStore'), findsOneWidget);
  });
}
