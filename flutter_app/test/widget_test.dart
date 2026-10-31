import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_advisor/core/widgets/async_view.dart';
import 'package:finance_advisor/features/auth/login_page.dart';

void main() {
  test('money formatting', () {
    expect(money(12.5), '\$12.50');
    expect(toD('3.2'), 3.2);
    expect(toD(null), 0);
  });

  testWidgets('login form validates input', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginPage())));
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('EmptyState shows message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: EmptyState('Nothing here'))));
    expect(find.text('Nothing here'), findsOneWidget);
  });
}
