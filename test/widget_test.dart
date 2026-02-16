// Basic Flutter widget test for SysAdmin Tools

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sysadmin_tools/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BullseyeApp()),
    );
    await tester.pumpAndSettle();

    // Verify the app renders with bottom navigation
    expect(find.text('Dashboard'), findsWidgets);
  });
}
