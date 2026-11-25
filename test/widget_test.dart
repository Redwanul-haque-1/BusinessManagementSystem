
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/auth/signup_page.dart';
import 'package:mobile_app/services/local_auth_services.dart';

class FakeLocalAuthService extends LocalAuthService {
  FakeLocalAuthService() : super();

  @override
  Future<bool> hasAnyUser() async {
    return false;
  }

  @override
  Future<Map<String, dynamic>> registerFirstAdmin({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    return {
      'message': 'সুপার অ্যাডমিন অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে।',
      'name': name,
      'email': email,
    };
  }
}

void main() {
  testWidgets(
    'সাইন আপ পেজ দেখায় এবং খালি ঘরের validation পরীক্ষা করে',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            authService: FakeLocalAuthService(),
          ),
        ),
      );

      // Account check uses a fake service, not the real database.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('সুপার অ্যাডমিন সাইন আপ'),
        findsOneWidget,
      );

      expect(
        find.text('সুপার অ্যাডমিন অ্যাকাউন্ট তৈরি করুন'),
        findsOneWidget,
      );

      expect(
        find.text('অ্যাকাউন্ট তৈরি করুন'),
        findsOneWidget,
      );

      // Submit the empty form.
      final signupButton = find.text('অ্যাকাউন্ট তৈরি করুন');

      await tester.ensureVisible(signupButton);
      await tester.pumpAndSettle();
      
      await tester.tap(signupButton);
      await tester.pumpAndSettle();
      expect(
        find.text('নাম লিখুন।'),
        findsOneWidget,
      );

      expect(
        find.text('ইমেইল ঠিকানা লিখুন।'),
        findsOneWidget,
      );

      expect(
        find.text('পাসওয়ার্ড লিখুন।'),
        findsOneWidget,
      );

      expect(
        find.text('আবার পাসওয়ার্ড লিখুন।'),
        findsOneWidget,
      );
    },
  );
}
