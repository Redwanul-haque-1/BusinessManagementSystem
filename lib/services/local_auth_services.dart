import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';

import 'sqlite_database_service.dart';

class LocalAuthException implements Exception {
  const LocalAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalAuthService {
  LocalAuthService({
    SqliteDatabaseService? databaseService,
  }) : _databaseService =
            databaseService ?? SqliteDatabaseService.instance;

  final SqliteDatabaseService _databaseService;

  // Password hashing configuration.
  // Memory is measured in 1 kB blocks by this package.
  static const int _memoryCost = 19 * 1024;
  static const int _iterations = 2;
  static const int _parallelism = 1;
  static const int _hashLength = 32;

  static final Argon2id _argon2 = Argon2id(
    memory: _memoryCost,
    parallelism: _parallelism,
    iterations: _iterations,
    hashLength: _hashLength,
  );

  /// Checks whether a local account already exists.
  Future<bool> hasAnyUser() async {
    final db = await _databaseService.database;

    final users = await db.query(
      'users',
      columns: ['id'],
      limit: 1,
    );

    return users.isNotEmpty;
  }

  /// Creates the first Super Admin account on this device.
  /// Additional Signup is disabled after the first account.
  Future<Map<String, dynamic>> registerFirstAdmin({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanName.isEmpty) {
      throw const LocalAuthException(
        'নাম লিখুন।',
      );
    }

    if (cleanEmail.isEmpty) {
      throw const LocalAuthException(
        'ইমেইল ঠিকানা লিখুন।',
      );
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(cleanEmail)) {
      throw const LocalAuthException(
        'সঠিক ইমেইল ঠিকানা লিখুন।',
      );
    }

    if (cleanName.length > 150) {
      throw const LocalAuthException(
        'নাম সর্বোচ্চ ১৫০ অক্ষরের হতে পারবে।',
      );
    }

    if (password.length < 8) {
      throw const LocalAuthException(
        'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।',
      );
    }

    if (password != passwordConfirmation) {
      throw const LocalAuthException(
        'পাসওয়ার্ড দুটি মিলছে না।',
      );
    }

    // Generate a cryptographically secure random salt.
    final random = math.Random.secure();

    final salt = List<int>.generate(
      16,
      (_) => random.nextInt(256),
      growable: false,
    );

    // Store the derived password hash, never the plaintext password.
    final secretKey = await _argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final hashBytes = await secretKey.extractBytes();

    // PHC-style Argon2id representation.
    final encodedPassword =
        '\$argon2id\$v=19'
        '\$m=$_memoryCost,t=$_iterations,p=$_parallelism'
        '\$${_encodeBytes(salt)}'
        '\$${_encodeBytes(hashBytes)}';

    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    try {
      await db.transaction((txn) async {
        // Check inside the transaction to prevent a second account.
        final existingUsers = await txn.query(
          'users',
          columns: ['id'],
          limit: 1,
        );

        if (existingUsers.isNotEmpty) {
          throw const LocalAuthException(
            'সুপার অ্যাডমিন অ্যাকাউন্ট আগে থেকেই আছে। '
            'নতুন অ্যাকাউন্ট তৈরি করা যাবে না।',
          );
        }

        await txn.insert('users', {
          'name': cleanName,
          'email': cleanEmail,
          'password': encodedPassword,
          'created_at': now,
          'updated_at': now,
        });
      });
    } on LocalAuthException {
      rethrow;
    } catch (_) {
      throw const LocalAuthException(
        'অ্যাকাউন্ট তৈরি করা যায়নি। আবার চেষ্টা করুন।',
      );
    }

    return {
      'message': 'সুপার অ্যাডমিন অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে।',
      'name': cleanName,
      'email': cleanEmail,
    };
  }

  /// Authenticates a user using the local SQLite database.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const LocalAuthException(
        'ইমেইল ও পাসওয়ার্ড লিখুন।',
      );
    }

    final db = await _databaseService.database;

    final users = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (users.isEmpty) {
      throw const LocalAuthException(
        'ইমেইল অথবা পাসওয়ার্ড সঠিক নয়।',
      );
    }

    final user = users.first;
    final storedPassword = user['password'];

    if (storedPassword is! String ||
        !await _verifyPassword(password, storedPassword)) {
      throw const LocalAuthException(
        'ইমেইল অথবা পাসওয়ার্ড সঠিক নয়।',
      );
    }

    return {
      'id': user['id'],
      'name': user['name'],
      'email': user['email'],
      'message': 'লগইন সফল হয়েছে।',
    };
  }

  /// Verifies a password against the stored Argon2id hash.
  Future<bool> _verifyPassword(
    String password,
    String storedPassword,
  ) async {
    try {
      final parts = storedPassword.split('\$');

      // Expected format:
      // $argon2id$v=19$m=19456,t=2,p=1$salt$hash
      if (parts.length != 6 ||
          parts[0].isNotEmpty ||
          parts[1] != 'argon2id' ||
          parts[2] != 'v=19' ||
          parts[3] !=
              'm=$_memoryCost,t=$_iterations,p=$_parallelism') {
        return false;
      }

      final salt = _decodeBytes(parts[4]);
      final expectedHash = _decodeBytes(parts[5]);

      if (salt.length != 16 ||
          expectedHash.length != _hashLength) {
        return false;
      }

      final secretKey = await _argon2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );

      final actualHash = await secretKey.extractBytes();

      if (actualHash.length != expectedHash.length) {
        return false;
      }

      // Compare every byte instead of returning on the first mismatch.
      var difference = 0;

      for (var i = 0; i < actualHash.length; i++) {
        difference |= actualHash[i] ^ expectedHash[i];
      }

      return difference == 0;
    } catch (_) {
      return false;
    }
  }

  String _encodeBytes(List<int> bytes) {
    // Standard Base64 without padding.
    return base64.encode(bytes).replaceAll('=', '');
  }

  List<int> _decodeBytes(String value) {
    final paddingLength = (4 - value.length % 4) % 4;

    return base64.decode(
      value + ('=' * paddingLength),
    );
  }
}