import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/screens/test/cache_test_screen.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await Hive.openBox('cache_metadata');
  });

  testWidgets('CacheTestScreen stores and retrieves data', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CacheTestScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'test_key');
    await tester.enterText(find.byType(TextField).at(1), 'test_value');
    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retrieve'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Retrieved value:'), findsOneWidget);
  });
}
