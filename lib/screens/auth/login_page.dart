
import 'package:flutter/material.dart';

import '../../services/local_auth_services.dart';
import '../../services/login_credential_store.dart';
import '../Companies/company_list_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final LoginCredentialStore? credentialStore;
  final LocalAuthService? authService;

  // Optional destination for tests or custom navigation.
  final WidgetBuilder? authenticatedBuilder;

  const LoginPage({
    super.key,
    this.credentialStore,
    this.authService,
    this.authenticatedBuilder,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  late final LocalAuthService _authService =
      widget.authService ?? LocalAuthService();

  LoginCredentialStore get _credentialStore =>
      widget.credentialStore ?? const SecureLoginCredentialStore();

  bool hidePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final credentials = await _credentialStore.read();

      if (!mounted || credentials == null) return;

      setState(() {
        emailController.text = credentials.email;
        passwordController.text = credentials.password;
        rememberMe = true;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সংরক্ষিত লগইন তথ্য পড়া যায়নি।'),
        ),
      );
    }
  }

  Future<String?> _saveRememberedCredentials() async {
    try {
      if (rememberMe) {
        await _credentialStore.save(
          LoginCredentials(
            email: emailController.text.trim(),
            password: passwordController.text,
          ),
        );
      } else {
        await _credentialStore.clear();
      }

      return null;
    } catch (_) {
      return 'লগইন তথ্য সংরক্ষণ করা যায়নি।';
    }
  }

  Future<void> login() async {
    if (isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Authentication uses local SQLite, not the Railway API.
      final result = await _authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final credentialError = await _saveRememberedCredentials();

      if (!mounted) return;

      final message = credentialError == null
          ? result['message'] as String? ?? 'লগইন সফল হয়েছে।'
          : 'লগইন সফল হয়েছে। $credentialError';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: widget.authenticatedBuilder ??
              (_) => const CompanyListPage(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst(
            'Exception: ',
            '',
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সুপার অ্যাডমিন লগইন'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.business, size: 70),
                const SizedBox(height: 20),
                const Text(
                  'সুপার অ্যাডমিন লগইন',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ইমেইল',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
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

                TextFormField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!isLoading) login();
                  },
                  decoration: InputDecoration(
                    labelText: 'পাসওয়ার্ড',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      tooltip: hidePassword
                          ? 'পাসওয়ার্ড দেখুন'
                          : 'পাসওয়ার্ড লুকান',
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

                    return null;
                  },
                ),
                const SizedBox(height: 8),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('মনে রাখুন'),
                  value: rememberMe,
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() {
                            rememberMe = value ?? false;
                          });
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 15),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'লগইন',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 15),

                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const SignupPage(),
                            ),
                          );
                        },
                  child: const Text(
                    'অ্যাকাউন্ট নেই? সাইন আপ করুন',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
