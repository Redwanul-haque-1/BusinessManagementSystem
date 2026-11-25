
import 'package:sqflite/sqflite.dart';

import 'sqlite_database_service.dart';

class LocalCompanyException implements Exception {
  const LocalCompanyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalCompanyService {
  LocalCompanyService({
    SqliteDatabaseService? databaseService,
  }) : _databaseService =
            databaseService ?? SqliteDatabaseService.instance;

  final SqliteDatabaseService _databaseService;

  /// Returns companies that have not been deleted.
  /// Active and inactive companies are both included.
  Future<List<Map<String, dynamic>>> getCompanies() async {
    final db = await _databaseService.database;

    return db.query(
      'companies',
      where: 'deleted_at IS NULL',
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  /// Creates a company for the locally registered Super Admin.
  Future<int> createCompany({
    required String name,
    String? address,
    String? phone,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw const LocalCompanyException(
        'কোম্পানির নাম লিখুন।',
      );
    }

    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    try {
      return await db.transaction<int>((txn) async {
        final users = await txn.query(
          'users',
          columns: ['id'],
          limit: 1,
        );

        if (users.isEmpty) {
          throw const LocalCompanyException(
            'প্রথমে সুপার অ্যাডমিন অ্যাকাউন্ট তৈরি করুন।',
          );
        }

        final creatorId = users.first['id'] as int;

        return txn.insert('companies', {
          'name': cleanName,
          'address': _cleanOptionalValue(address),
          'phone': _cleanOptionalValue(phone),
          'is_active': 1,
          'created_by': creatorId,
          'created_at': now,
          'updated_at': now,
          'deleted_at': null,
        });
      });
    } on LocalCompanyException {
      rethrow;
    } on DatabaseException {
      throw const LocalCompanyException(
        'এই নামে কোম্পানি আগে থেকেই থাকতে পারে। '
        'নাম যাচাই করে আবার চেষ্টা করুন।',
      );
    }
  }

  /// Updates an existing company without deleting related data.
  Future<void> updateCompany({
    required int companyId,
    required String name,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw const LocalCompanyException(
        'কোম্পানির নাম লিখুন।',
      );
    }

    final db = await _databaseService.database;

    final values = <String, Object?>{
      'name': cleanName,
      'address': _cleanOptionalValue(address),
      'phone': _cleanOptionalValue(phone),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (isActive != null) {
      values['is_active'] = isActive ? 1 : 0;
    }

    try {
      final affected = await db.update(
        'companies',
        values,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [companyId],
      );

      if (affected == 0) {
        throw const LocalCompanyException(
          'কোম্পানিটি পাওয়া যায়নি। তালিকা হালনাগাদ করুন।',
        );
      }
    } on LocalCompanyException {
      rethrow;
    } on DatabaseException {
      throw const LocalCompanyException(
        'কোম্পানির তথ্য সংরক্ষণ করা যায়নি। '
        'নাম যাচাই করে আবার চেষ্টা করুন।',
      );
    }
  }

  /// Deactivates a company while retaining its records.
  Future<void> deactivateCompany({
    required int companyId,
  }) async {
    await _updateCompanyStatus(
      companyId: companyId,
      isActive: false,
    );
  }

  /// Reactivates a previously deactivated company.
  Future<void> activateCompany({
    required int companyId,
  }) async {
    await _updateCompanyStatus(
      companyId: companyId,
      isActive: true,
    );
  }

  Future<void> _updateCompanyStatus({
    required int companyId,
    required bool isActive,
  }) async {
    final db = await _databaseService.database;

    final affected = await db.update(
      'companies',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [companyId],
    );

    if (affected == 0) {
      throw const LocalCompanyException(
        'কোম্পানিটি পাওয়া যায়নি। তালিকা হালনাগাদ করুন।',
      );
    }
  }

  /// Soft-deletes a company.
  /// Related sales, stock and product records are retained.
  Future<void> deleteCompany({
    required int companyId,
  }) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    final affected = await db.update(
      'companies',
      {
        'is_active': 0,
        'deleted_at': now,
        'updated_at': now,
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [companyId],
    );

    if (affected == 0) {
      throw const LocalCompanyException(
        'কোম্পানিটি পাওয়া যায়নি অথবা আগেই মুছে ফেলা হয়েছে।',
      );
    }
  }

  String? _cleanOptionalValue(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}
