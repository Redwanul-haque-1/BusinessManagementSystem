import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginCredentials {
  const LoginCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

abstract interface class LoginCredentialStore {
  Future<LoginCredentials?> read();
  Future<void> save(LoginCredentials credentials);
  Future<void> clear();
}

class SecureLoginCredentialStore implements LoginCredentialStore {
  const SecureLoginCredentialStore() : _storage = const FlutterSecureStorage();

  static const _emailKey = 'remembered_email';
  static const _passwordKey = 'remembered_password';

  final FlutterSecureStorage _storage;

  @override
  Future<LoginCredentials?> read() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || email.isEmpty || password == null) {
      return null;
    }
    return LoginCredentials(email: email, password: password);
  }

  @override
  Future<void> save(LoginCredentials credentials) async {
    await _storage.write(key: _emailKey, value: credentials.email);
    await _storage.write(key: _passwordKey, value: credentials.password);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}
