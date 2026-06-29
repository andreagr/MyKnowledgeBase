import 'package:flutter_test/flutter_test.dart';
import 'package:local_company_rag/app/app.dart';
import 'package:local_company_rag/app/branding.dart';

void main() {
  testWidgets('App starts with title', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text(AppBranding.name), findsOneWidget);
  });
}
