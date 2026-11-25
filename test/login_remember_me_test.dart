
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/screens/auth/login_page.dart';
import 'package:mobile_app/services/local_auth_services.dart';
import 'package:mobile_app/services/login_credential_store.dart';

class _MemoryCredentialStore implements LoginCredentialStore {
  LoginCredentials? credentials;

  @override
  Future<void> clear() async {
    credentials = null;
  }

  @override
  Future<LoginCredentials?> read() async => credentials;

  @override
  Future<void> save(LoginCredentials value) async {
    credentials = value;
  }
}

class _SuccessfulLocalAuthService extends LocalAuthService {
  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (email != 'admin@example.com' ||
        password != 'new-password') {
      throw const LocalAuthException(
        'ইমেইল অথবা পাসওয়ার্ড সঠিক নয়।',
      );
    }

    return {
      'id': 1,
      'name': 'সুপার অ্যাডমিন',
      'email': email,
      'message': 'লগইন সফল হয়েছে।',
    };
  }
}

void main() {
  testWidgets(
    'সংরক্ষিত তথ্য লগইন ফর্মে দেখায়',
    (tester) async {
      final credentialStore = _MemoryCredentialStore()
        ..credentials = const LoginCredentials(
          email: 'admin@example.com',
          password: 'saved-password',
        );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            credentialStore: credentialStore,
            authService: _SuccessfulLocalAuthService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      );

      expect(fields.first.controller!.text, 'admin@example.com');
      expect(fields.last.controller!.text, 'saved-password');

      expect(
        tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile),
        ).value,
        isTrue,
      );
    },
  );

  testWidgets(
    'সফল লগইনের পর মনে রাখুন নির্বাচিত থাকলে তথ্য সংরক্ষণ করে',
    (tester) async {
      final credentialStore = _MemoryCredentialStore();

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            credentialStore: credentialStore,
            authService: _SuccessfulLocalAuthService(),
            authenticatedBuilder: (_) => const Scaffold(
              body: Text('লগইন সফল'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);

      await tester.enterText(fields.first, 'admin@example.com');
      await tester.enterText(fields.last, 'new-password');

      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('লগইন'));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        credentialStore.credentials?.email,
        'admin@example.com',
      );
      expect(
        credentialStore.credentials?.password,
        'new-password',
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('লগইন সফল'), findsOneWidget);
    },
  );
}
