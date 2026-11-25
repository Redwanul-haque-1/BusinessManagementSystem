
import 'package:flutter/material.dart';

import '../../services/local_auth_services.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  final LocalAuthService? authService;

  const SignupPage({
    super.key,
    this.authService,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  late final LocalAuthService _localAuthService =
    widget.authService ?? LocalAuthService();

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool isLoading = false;
  bool isCheckingAccount = true;
  bool hasExistingAccount = false;
  String? accountCheckError;

  @override
  void initState() {
    super.initState();
    _checkExistingAccount();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingAccount() async {
    setState(() {
      isCheckingAccount = true;
      accountCheckError = null;
    });

    try {
      final exists = await _localAuthService.hasAnyUser();

      if (!mounted) return;

      setState(() {
        hasExistingAccount = exists;
        isCheckingAccount = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isCheckingAccount = false;
        accountCheckError =
            'অ্যাকাউন্ট যাচাই করা যায়নি। আবার চেষ্টা করুন।';
      });
    }
  }

  void _openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  }

  Future<void> signup() async {
    if (isLoading || isCheckingAccount || hasExistingAccount) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final result = await _localAuthService.registerFirstAdmin(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        passwordConfirmation: confirmPasswordController.text,
      );

      if (!mounted) return;

      setState(() {
        hasExistingAccount = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] as String? ??
                'অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে।',
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Signup is complete. Proceed to the Login screen.
      _openLogin();
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst(
            'Exception: ',
            '',
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // Refresh the account state in case another operation
      // created the first account.
      await _checkExistingAccount();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildAccountExistsMessage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 72,
          color: Colors.green,
        ),
        const SizedBox(height: 20),
        const Text(
          'সুপার অ্যাডমিন অ্যাকাউন্ট তৈরি করা আছে',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'এই ডিভাইসে ইতিমধ্যে একটি অ্যাকাউন্ট আছে। '
          'নিরাপত্তার জন্য নতুন অ্যাকাউন্ট তৈরি করা যাবে না।',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _openLogin,
            child: const Text(
              'লগইন করুন',
              style: TextStyle(fontSize: 17),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.business, size: 65),
          const SizedBox(height: 16),
          const Text(
            'সুপার অ্যাডমিন অ্যাকাউন্ট তৈরি করুন',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'এই ডিভাইসে প্রথম অ্যাকাউন্টটি তৈরি করুন।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 28),

          // Name
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'পূর্ণ নাম',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'নাম লিখুন।';
              }

              if (value.trim().length > 150) {
                return 'নাম সর্বোচ্চ ১৫০ অক্ষরের হতে পারবে।';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'ইমেইল',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return 'ইমেইল ঠিকানা লিখুন।';
              }

              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(email)) {
                return 'সঠিক ইমেইল ঠিকানা লিখুন।';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: passwordController,
            obscureText: hidePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'পাসওয়ার্ড',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    hidePassword = !hidePassword;
                  });
                },
                icon: Icon(
                  hidePassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'পাসওয়ার্ড লিখুন।';
              }

              if (value.length < 8) {
                return 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm password
          TextFormField(
            controller: confirmPasswordController,
            obscureText: hideConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!isLoading) signup();
            },
            decoration: InputDecoration(
              labelText: 'পাসওয়ার্ড নিশ্চিত করুন',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    hideConfirmPassword = !hideConfirmPassword;
                  });
                },
                icon: Icon(
                  hideConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'আবার পাসওয়ার্ড লিখুন।';
              }

              if (value != passwordController.text) {
                return 'পাসওয়ার্ড দুটি মিলছে না।';
              }

              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : signup,
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'অ্যাকাউন্ট তৈরি করুন',
                      style: TextStyle(fontSize: 17),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: isLoading ? null : _openLogin,
            child: const Text('আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সুপার অ্যাডমিন সাইন আপ'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: isCheckingAccount
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('অ্যাকাউন্ট যাচাই করা হচ্ছে...'),
                        ],
                      ),
                    )
                  : accountCheckError != null
                      ? Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              accountCheckError!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _checkExistingAccount,
                              child: const Text('আবার চেষ্টা করুন'),
                            ),
                            TextButton(
                              onPressed: _openLogin,
                              child: const Text('লগইন পেজে যান'),
                            ),
                          ],
                        )
                      : hasExistingAccount
                          ? _buildAccountExistsMessage()
                          : _buildSignupForm(),
            ),
          ),
        ),
      ),
    );
  }
}
