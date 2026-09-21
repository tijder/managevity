import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/screens/login_screen.dart';
import 'package:managevity/services/sportivity_api.dart';
import 'package:managevity/utils/errors.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  testWidgets('empty fields: no call, but a message per field', (tester) async {
    final api = FakeSportivityApi();
    await tester.pumpWidget(
      testApp(const LoginScreen(), api: api, credentials: FakeCredentialStore()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2));
    expect(api.session, isNull);
  });

  testWidgets("wrong password: the server's text is shown, nothing is stored", (tester) async {
    final store = FakeCredentialStore();
    final api = FakeSportivityApi(
      loginError: const SportivityException(
        AppError.loginFailed,
        serverMessage: 'Inloggegevens onjuist',
        statusCode: 401,
      ),
    );
    await tester.pumpWidget(testApp(const LoginScreen(), api: api, credentials: store));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'robin@example.org');
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Inloggegevens onjuist'), findsOneWidget);
    expect(store.login, isNull);
    expect(store.session, isNull);
  });

  testWidgets('forgot password without a username asks for that first', (tester) async {
    await tester.pumpWidget(
      testApp(const LoginScreen(), api: FakeSportivityApi(), credentials: FakeCredentialStore()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    expect(find.text('Enter your email or username first.'), findsOneWidget);
  });
}
