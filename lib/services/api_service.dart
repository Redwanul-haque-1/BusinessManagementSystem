import 'package:sqflite/sqflite.dart';

import 'local_auth_services.dart';
import 'local_company_services.dart';
import 'sqlite_database_service.dart';

class OutOfStockException implements Exception {
  const OutOfStockException();

  @override
  String toString() => 'এই পণ্যটির পর্যাপ্ত পরিমাণ স্টক নেই (Out of stock)';
}

/// Local data facade retained under the old ApiService name so existing
/// screens and widget tests keep their public method signatures. All operations
/// are performed against the device's SQLite database; no HTTP/Railway calls
/// are made from this service.
class ApiService {
  ApiService({
    SqliteDatabaseService? databaseService,
    LocalAuthService? authService,
    LocalCompanyService? companyService,
  }) : _databaseService = databaseService ?? SqliteDatabaseService.instance,
       _authService =
           authService ??
           LocalAuthService(
             databaseService: databaseService ?? SqliteDatabaseService.instance,
           ),
       _companyService =
           companyService ??
           LocalCompanyService(
             databaseService: databaseService ?? SqliteDatabaseService.instance,
           );

  final SqliteDatabaseService _databaseService;
  final LocalAuthService _authService;
  final LocalCompanyService _companyService;

  // -------------------------------------------------------------------------
  // Local authentication compatibility methods
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) {
    return _authService.registerFirstAdmin(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    // Login validation and password verification are entirely local.
    return _authService.login(email: email, password: password);
  }

  Future<Map<String, dynamic>> getUser() async {
    final db = await _databaseService.database;
    final users = await db.query('users', limit: 1);
    if (users.isEmpty) {
      throw Exception('সুপার অ্যাডমিন অ্যাকাউন্ট পাওয়া যায়নি।');
    }
    final user = Map<String, dynamic>.from(users.first);
    user.remove('password');
    user.remove('remember_token');
    return user;
  }

  Future<Map<String, dynamic>> logout() async => {
    'message': 'এই ডিভাইস থেকে লগআউট হয়েছে।',
  };

  // -------------------------------------------------------------------------
  // Companies
  // -------------------------------------------------------------------------

  Future<List<dynamic>> getCompanies() async => _companyService.getCompanies();

  Future<Map<String, dynamic>> createCompany({
    required String name,
    String? address,
    String? phone,
  }) async {
    final id = await _companyService.createCompany(
      name: name,
      address: address,
      phone: phone,
    );
    final db = await _databaseService.database;
    final rows = await db.query(
      'companies',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> updateCompany({
    required int companyId,
    required String name,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    await _companyService.updateCompany(
      companyId: companyId,
      name: name,
      address: address,
      phone: phone,
      isActive: isActive,
    );
    final db = await _databaseService.database;
    final rows = await db.query(
      'companies',
      where: 'id = ?',
      whereArgs: [companyId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('কোম্পানিটি পাওয়া যায়নি।');
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> deleteCompany({required int companyId}) async {
    await _companyService.deleteCompany(companyId: companyId);
    return {'message': 'কোম্পানিটি সংরক্ষিত তথ্যসহ নিষ্ক্রিয় করা হয়েছে।'};
  }

  // -------------------------------------------------------------------------
  // Company products and addresses
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCompanyProducts({
    required int companyId,
  }) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'company_products',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createCompanyProduct({
    required int companyId,
    required String name,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw Exception('পণ্যের নাম লিখুন।');
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    try {
      final id = await db.insert('company_products', {
        'company_id': companyId,
        'name': cleanName,
        'created_at': now,
        'updated_at': now,
      });
      final rows = await db.query(
        'company_products',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Map<String, dynamic>.from(rows.first);
    } on DatabaseException {
      throw Exception(
        'এই পণ্যটি আগে থেকেই তালিকায় আছে অথবা কোম্পানিটি পাওয়া যায়নি।',
      );
    }
  }

  Future<void> deleteCompanyProduct({
    required int companyId,
    required int productId,
  }) async {
    final db = await _databaseService.database;
    final deletedRows = await db.delete(
      'company_products',
      where: 'id = ? AND company_id = ?',
      whereArgs: [productId, companyId],
    );
    if (deletedRows == 0) {
      throw Exception('পণ্যটি তালিকায় পাওয়া যায়নি।');
    }
  }

  Future<List<Map<String, dynamic>>> getCompanyAddresses({
    required int companyId,
  }) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'company_addresses',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'address COLLATE NOCASE ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createCompanyAddress({
    required int companyId,
    required String address,
  }) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) throw Exception('রোড/ঠিকানা লিখুন।');
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    try {
      final id = await db.insert('company_addresses', {
        'company_id': companyId,
        'address': cleanAddress,
        'created_at': now,
        'updated_at': now,
      });
      final rows = await db.query(
        'company_addresses',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Map<String, dynamic>.from(rows.first);
    } on DatabaseException {
      // If another screen already inserted the same address, return it.
      final existing = await db.query(
        'company_addresses',
        where: 'company_id = ? AND address = ?',
        whereArgs: [companyId, cleanAddress],
        limit: 1,
      );
      if (existing.isNotEmpty) return Map<String, dynamic>.from(existing.first);
      throw Exception('রোড/ঠিকানা সংরক্ষণ করা যায়নি। কোম্পানিটি যাচাই করুন।');
    }
  }

  // -------------------------------------------------------------------------
  // Monthly company and due accounts
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCompanyAccountRows({
    required int companyId,
    required int month,
    required int year,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final rows = await db.query(
      'company_account_rows',
      where: 'company_id = ? AND month = ? AND year = ?',
      whereArgs: [companyId, month, year],
      orderBy: 'date ASC, id ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> saveCompanyAccountRows({
    required int companyId,
    required int month,
    required int year,
    required List<Map<String, dynamic>> rows,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      await txn.delete(
        'company_account_rows',
        where: 'company_id = ? AND month = ? AND year = ?',
        whereArgs: [companyId, month, year],
      );
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final date = _dateOnly(
          row['date']?.toString(),
          year: year,
          month: month,
        );
        _validateAccountRowDate(date, month: month, year: year);
        await txn.insert('company_account_rows', {
          'company_id': companyId,
          'month': month,
          'year': year,
          'date': date,
          'online': _numberText(row['online']),
          'lifting': _numberText(row['lifting']),
          'incentive': _numberText(row['incentive']),
          'created_at': now,
          'updated_at': now,
        });
      }
      final savedRows = await txn.query(
        'company_account_rows',
        where: 'company_id = ? AND month = ? AND year = ?',
        whereArgs: [companyId, month, year],
        orderBy: 'date ASC, id ASC',
      );
      return savedRows.map((row) => Map<String, dynamic>.from(row)).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getDueAccountRows({
    required int companyId,
    required int month,
    required int year,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final rows = await db.query(
      'due_account_rows',
      where: 'company_id = ? AND month = ? AND year = ?',
      whereArgs: [companyId, month, year],
      orderBy: 'date ASC, id ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> saveDueAccountRows({
    required int companyId,
    required int month,
    required int year,
    required List<Map<String, dynamic>> rows,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      await txn.delete(
        'due_account_rows',
        where: 'company_id = ? AND month = ? AND year = ?',
        whereArgs: [companyId, month, year],
      );
      for (final row in rows) {
        final date = _dateOnly(
          row['date']?.toString(),
          year: year,
          month: month,
        );
        _validateAccountRowDate(date, month: month, year: year);
        await txn.insert('due_account_rows', {
          'company_id': companyId,
          'month': month,
          'year': year,
          'date': date,
          'due': _numberText(row['due']),
          'deposit': _numberText(row['deposit']),
          'created_at': now,
          'updated_at': now,
        });
      }
      final savedRows = await txn.query(
        'due_account_rows',
        where: 'company_id = ? AND month = ? AND year = ?',
        whereArgs: [companyId, month, year],
        orderBy: 'date ASC, id ASC',
      );
      return savedRows.map((row) => Map<String, dynamic>.from(row)).toList();
    });
  }

  Future<Map<String, double>> getCapitalAccountSummary({
    required int companyId,
    required int month,
    required int year,
  }) async {
    _validateMonthYear(month, year);
    final results = await Future.wait<Object>([
      getStockSheet(companyId: companyId, month: month, year: year),
      getSalesSheet(companyId: companyId, month: month, year: year),
      getDueAccountRows(companyId: companyId, month: month, year: year),
      getCompanyAccountRows(companyId: companyId, month: month, year: year),
    ]);
    final stockData = results[0] as Map<String, dynamic>;
    final salesData = results[1] as Map<String, dynamic>;
    final stockRows = (stockData['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final salesRows = (salesData['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final dueRows = results[2] as List<Map<String, dynamic>>;
    final companyRows = results[3] as List<Map<String, dynamic>>;

    final lastDay = DateTime(year, month + 1, 0).day;
    final monthEnd =
        '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${lastDay.toString().padLeft(2, '0')}';
    final db = await _databaseService.database;
    final historicalStockRows = await db.rawQuery(
      'SELECT stock_rows.name, stock_rows.price '
      'FROM stock_rows '
      'INNER JOIN stock_sheets '
      'ON stock_sheets.id = stock_rows.stock_sheet_id '
      'WHERE stock_sheets.company_id = ? AND stock_rows.date <= ? '
      'ORDER BY stock_rows.date DESC, stock_rows.created_at DESC, '
      'stock_rows.id DESC',
      [companyId, monthEnd],
    );
    final purchasePriceByProduct = <String, double>{};
    for (final row in historicalStockRows) {
      final name = row['name']?.toString().trim().toLowerCase() ?? '';
      if (name.isNotEmpty) {
        purchasePriceByProduct.putIfAbsent(name, () => _asDouble(row['price']));
      }
    }

    final stockValue = stockRows.fold<double>(
      0,
      (sum, row) =>
          sum +
          (row['total'] == null
              ? _asDouble(row['stock']) * _asDouble(row['price'])
              : _asDouble(row['total'])),
    );
    final damageValue = salesRows.fold<double>(0, (sum, row) {
      final name = row['name']?.toString().trim().toLowerCase() ?? '';
      final damage =
          _asDouble(row['damage']) * (purchasePriceByProduct[name] ?? 0);
      return sum + double.parse(damage.toStringAsFixed(2));
    });
    final marketDue = dueRows.fold<double>(
      0,
      (sum, row) => sum + _asDouble(row['due']) - _asDouble(row['deposit']),
    );
    final undelivery = companyRows.fold<double>(
      0,
      (sum, row) =>
          sum +
          _asDouble(row['online']) -
          _asDouble(row['lifting']) +
          _asDouble(row['incentive']),
    );

    return {
      'stockValue': stockValue,
      'marketDue': marketDue,
      'damageValue': damageValue,
      'undelivery': undelivery,
      'totalCapital': stockValue + marketDue + damageValue + undelivery,
    };
  }

  Future<List<Map<String, dynamic>>> getSalesSummaryRows({
    required int companyId,
    required int month,
    required int year,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final rows = await db.query(
      'sales_summary_rows',
      where: 'company_id = ? AND month = ? AND year = ?',
      whereArgs: [companyId, month, year],
      orderBy: 'date ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> saveSalesSummary({
    required int companyId,
    required int month,
    required int year,
    required String date,
    required double discount,
    required double damage,
    required double otherExpense,
  }) async {
    _validateMonthYear(month, year);
    final cleanDate = _dateOnly(date, year: year, month: month);
    _validateAccountRowDate(cleanDate, month: month, year: year);
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final values = <String, Object?>{
        'discount': _numberText(discount),
        'damage': _numberText(damage),
        'other_expense': _numberText(otherExpense),
        'updated_at': now,
      };
      final existing = await txn.query(
        'sales_summary_rows',
        where: 'company_id = ? AND month = ? AND year = ? AND date = ?',
        whereArgs: [companyId, month, year, cleanDate],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('sales_summary_rows', {
          'company_id': companyId,
          'month': month,
          'year': year,
          'date': cleanDate,
          ...values,
          'created_at': now,
        });
      } else {
        await txn.update(
          'sales_summary_rows',
          values,
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
      final savedRows = await txn.query(
        'sales_summary_rows',
        where: 'company_id = ? AND month = ? AND year = ? AND date = ?',
        whereArgs: [companyId, month, year, cleanDate],
        limit: 1,
      );
      return Map<String, dynamic>.from(savedRows.first);
    });
  }

  // -------------------------------------------------------------------------
  // Sales sheets
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> getSalesSheet({
    required int companyId,
    required int month,
    required int year,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final sheets = await db.query(
      'sales_sheets',
      where: 'company_id = ? AND month = ? AND year = ?',
      whereArgs: [companyId, month, year],
      limit: 1,
    );
    if (sheets.isEmpty) {
      return {'sheet': <String, dynamic>{}, 'rows': <Map<String, dynamic>>[]};
    }
    final sheet = Map<String, dynamic>.from(sheets.first);
    final rows = await db.query(
      'sales_rows',
      where: 'sales_sheet_id = ?',
      whereArgs: [sheet['id']],
      orderBy: 'date ASC, serial_no ASC, id ASC',
    );
    return {
      'sheet': sheet,
      'rows': rows.map((row) => Map<String, dynamic>.from(row)).toList(),
    };
  }

  Future<Map<String, dynamic>> saveSalesSheet({
    required int companyId,
    required int month,
    required int year,
    String? selectedDate,
    String? title,
    required List<Map<String, dynamic>> rows,
  }) async {
    return _writeSalesSheet(
      companyId: companyId,
      month: month,
      year: year,
      selectedDate: selectedDate,
      title: title,
      rows: rows,
    );
  }

  Future<Map<String, dynamic>> updateSalesSheet({
    required int companyId,
    required int salesSheetId,
    required int month,
    required int year,
    String? selectedDate,
    String? title,
    required List<Map<String, dynamic>> rows,
  }) async {
    return _writeSalesSheet(
      companyId: companyId,
      month: month,
      year: year,
      selectedDate: selectedDate,
      title: title,
      rows: rows,
      sheetId: salesSheetId,
    );
  }

  Future<Map<String, dynamic>> _writeSalesSheet({
    required int companyId,
    required int month,
    required int year,
    required String? selectedDate,
    required String? title,
    required List<Map<String, dynamic>> rows,
    int? sheetId,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final date = _dateOnly(selectedDate, year: year, month: month);
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final sheet = await _getOrCreateSheet(
        txn,
        table: 'sales_sheets',
        companyId: companyId,
        month: month,
        year: year,
        title: title,
        sheetId: sheetId,
      );
      final id = sheet['id'] as int;

      final oldRows = await txn.query(
        'sales_rows',
        where: 'sales_sheet_id = ? AND date = ?',
        whereArgs: [id, date],
      );

      final oldSalesRowIds = <int>[];
      final legacyReductionByProduct = <String, double>{};
      for (final row in oldRows) {
        final salesRowId = row['id'] as int;
        oldSalesRowIds.add(salesRowId);
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final movements = await txn.query(
          'sales_stock_movements',
          columns: ['id'],
          where: 'sales_row_id = ?',
          whereArgs: [salesRowId],
          limit: 1,
        );
        if (movements.isEmpty) {
          final saleQuantity =
              (_asDouble(row['neoya']) - _asDouble(row['perot']))
                  .clamp(0, double.infinity)
                  .toDouble();
          final consumedQuantity = saleQuantity + _asDouble(row['damage']);
          final key = name.toLowerCase();
          legacyReductionByProduct.update(
            key,
            (quantity) => quantity + consumedQuantity,
            ifAbsent: () => consumedQuantity,
          );
        }
      }

      await _restoreStockForSalesRows(txn, oldSalesRowIds);
      await _restoreLegacyStock(txn, companyId, legacyReductionByProduct);

      final stockRowsByProduct = await _stockRowsByProduct(txn, companyId);
      final remainingByStockRowId = <int, double>{};
      final stockRowById = <int, Map<String, Object?>>{};
      for (final stockRows in stockRowsByProduct.values) {
        for (final stockRow in stockRows) {
          final stockRowId = stockRow['id'] as int;
          stockRowById[stockRowId] = stockRow;
          remainingByStockRowId[stockRowId] = _asDouble(stockRow['stock']);
        }
      }

      final newReductionByProduct = <String, double>{};
      for (final row in rows) {
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        final neoya = _asDouble(row['neoya']);
        final perot = _asDouble(row['perot']);
        final damage = _asDouble(row['damage']);
        if (neoya < 0 || perot < 0 || damage < 0 || perot > neoya) {
          throw Exception('নেওয়া, ফেরত ও ড্যামেজের পরিমাণ সঠিকভাবে দিন।');
        }
        final saleQuantity = neoya - perot;
        newReductionByProduct.update(
          key,
          (quantity) => quantity + saleQuantity + damage,
          ifAbsent: () => saleQuantity + damage,
        );
      }

      for (final entry in newReductionByProduct.entries) {
        final available = (stockRowsByProduct[entry.key] ?? []).fold<double>(
          0,
          (sum, stockRow) => sum + _asDouble(stockRow['stock']),
        );
        if (entry.value > available) {
          throw const OutOfStockException();
        }
      }

      // Replace only this selected day's rows. Rows from other days of the
      // month are retained so daily edits never erase earlier entries.
      await txn.delete(
        'sales_rows',
        where: 'sales_sheet_id = ? AND date = ?',
        whereArgs: [id, date],
      );

      final updatedStockRowIds = <int>{};
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final neoya = _numberText(row['neoya']);
        final perot = _numberText(row['perot']);
        final dor = _numberText(row['dor']);
        final damage = _numberText(row['damage']);
        final saleQty = (_asDouble(neoya) - _asDouble(perot))
            .clamp(0, double.infinity)
            .toDouble();
        final salesRowId = await txn.insert('sales_rows', {
          'sales_sheet_id': id,
          'serial_no': _asInt(row['serial_no']) ?? index + 1,
          'date': date,
          'name': name,
          'address': _clean(row['address']?.toString()),
          'neoya': neoya,
          'perot': perot,
          'bikroy': _numberText(saleQty),
          'dor': dor,
          'taka': _numberText(saleQty * _asDouble(dor)),
          'damage': damage,
          'created_at': now,
          'updated_at': now,
        });
        var quantityToAllocate = saleQty + _asDouble(damage);
        for (final stockRow in stockRowsByProduct[name.toLowerCase()] ?? []) {
          if (quantityToAllocate <= 0) break;
          final stockRowId = stockRow['id'] as int;
          final remaining = remainingByStockRowId[stockRowId] ?? 0;
          if (remaining <= 0) continue;
          final allocated = remaining < quantityToAllocate
              ? remaining
              : quantityToAllocate;
          remainingByStockRowId[stockRowId] = remaining - allocated;
          quantityToAllocate -= allocated;
          updatedStockRowIds.add(stockRowId);
          await txn.insert('sales_stock_movements', {
            'sales_row_id': salesRowId,
            'stock_row_id': stockRowId,
            'quantity': _numberText(allocated),
            'created_at': now,
          });
        }
      }

      for (final stockRowId in updatedStockRowIds) {
        final stockRow = stockRowById[stockRowId]!;
        final stock = remainingByStockRowId[stockRowId]!;
        await txn.update(
          'stock_rows',
          {
            'stock': _numberText(stock),
            'total': _numberText(stock * _asDouble(stockRow['price'])),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [stockRowId],
        );
      }

      final updated = Map<String, dynamic>.from(sheet);
      updated['title'] = title ?? sheet['title'];
      updated['updated_at'] = now;
      return {'sheet': updated, 'rows': await _salesRows(txn, id)};
    });
  }

  Future<void> _restoreStockForSalesRows(
    Transaction txn,
    Iterable<int> salesRowIds,
  ) async {
    for (final salesRowId in salesRowIds) {
      final movements = await txn.query(
        'sales_stock_movements',
        where: 'sales_row_id = ?',
        whereArgs: [salesRowId],
      );
      for (final movement in movements) {
        final stockRowId = movement['stock_row_id'] as int;
        final stockRows = await txn.query(
          'stock_rows',
          where: 'id = ?',
          whereArgs: [stockRowId],
          limit: 1,
        );
        if (stockRows.isEmpty) continue;
        final stockRow = stockRows.first;
        final stock =
            _asDouble(stockRow['stock']) + _asDouble(movement['quantity']);
        await txn.update(
          'stock_rows',
          {
            'stock': _numberText(stock),
            'total': _numberText(stock * _asDouble(stockRow['price'])),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [stockRowId],
        );
      }
    }
  }

  Future<void> _restoreLegacyStock(
    Transaction txn,
    int companyId,
    Map<String, double> reductionsByProduct,
  ) async {
    if (reductionsByProduct.isEmpty) return;
    final rowsByProduct = await _stockRowsByProduct(txn, companyId);
    for (final entry in reductionsByProduct.entries) {
      final stockRows = rowsByProduct[entry.key];
      if (stockRows == null || stockRows.isEmpty) continue;
      final stockRow = stockRows.first;
      final stock = _asDouble(stockRow['stock']) + entry.value;
      await txn.update(
        'stock_rows',
        {
          'stock': _numberText(stock),
          'total': _numberText(stock * _asDouble(stockRow['price'])),
        },
        where: 'id = ?',
        whereArgs: [stockRow['id']],
      );
    }
  }

  Future<Map<String, List<Map<String, Object?>>>> _stockRowsByProduct(
    Transaction txn,
    int companyId,
  ) async {
    final rows = await txn.rawQuery(
      'SELECT stock_rows.* FROM stock_rows '
      'INNER JOIN stock_sheets '
      'ON stock_sheets.id = stock_rows.stock_sheet_id '
      'WHERE stock_sheets.company_id = ? '
      'ORDER BY stock_rows.date DESC, stock_rows.created_at DESC, stock_rows.id DESC',
      [companyId],
    );
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final name = row['name']?.toString().trim().toLowerCase() ?? '';
      if (name.isNotEmpty) {
        grouped
            .putIfAbsent(name, () => <Map<String, Object?>>[])
            .add(Map<String, Object?>.from(row));
      }
    }
    return grouped;
  }

  Future<List<Map<String, dynamic>>> getStockProductList({
    required int companyId,
  }) async {
    final db = await _databaseService.database;
    final products = await db.query(
      'company_products',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final rows = await db.rawQuery(
      'SELECT stock_rows.* FROM stock_rows '
      'INNER JOIN stock_sheets '
      'ON stock_sheets.id = stock_rows.stock_sheet_id '
      'WHERE stock_sheets.company_id = ? '
      'ORDER BY stock_rows.date DESC, stock_rows.created_at DESC, stock_rows.id DESC',
      [companyId],
    );
    final latestByName = <String, Map<String, dynamic>>{};
    final stockByName = <String, double>{};
    final totalByName = <String, double>{};
    String? latestDate;
    for (final row in rows) {
      final date = row['date']?.toString();
      if (date != null &&
          (latestDate == null || date.compareTo(latestDate) > 0)) {
        latestDate = date;
      }
      final name = row['name']?.toString().trim().toLowerCase() ?? '';
      if (name.isNotEmpty) {
        latestByName.putIfAbsent(name, () => Map<String, dynamic>.from(row));
        stockByName.update(
          name,
          (stock) => stock + _asDouble(row['stock']),
          ifAbsent: () => _asDouble(row['stock']),
        );
        totalByName.update(
          name,
          (total) => total + _asDouble(row['stock']) * _asDouble(row['price']),
          ifAbsent: () => _asDouble(row['stock']) * _asDouble(row['price']),
        );
      }
    }

    return products.map((product) {
      final latest =
          latestByName[product['name'].toString().trim().toLowerCase()];
      return {
        'name': product['name'],
        'date': latest?['date'],
        'stock': _numberText(
          stockByName[product['name'].toString().trim().toLowerCase()] ?? 0,
        ),
        'total': _numberText(
          totalByName[product['name'].toString().trim().toLowerCase()] ?? 0,
        ),
        'price': latest?['price'] ?? '0.00',
        'selling_price': latest?['selling_price'] ?? '0.00',
        'latest_update_date': latestDate,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> deleteSalesSheet({
    required int companyId,
    required int salesSheetId,
  }) async {
    final db = await _databaseService.database;
    final count = await db.transaction((txn) async {
      final sheets = await txn.query(
        'sales_sheets',
        columns: ['id', 'month', 'year'],
        where: 'id = ? AND company_id = ?',
        whereArgs: [salesSheetId, companyId],
        limit: 1,
      );
      if (sheets.isEmpty) return 0;
      final salesRows = await txn.query(
        'sales_rows',
        columns: ['id'],
        where: 'sales_sheet_id = ?',
        whereArgs: [salesSheetId],
      );
      await _restoreStockForSalesRows(
        txn,
        salesRows.map((row) => row['id'] as int),
      );
      await txn.delete(
        'sales_summary_rows',
        where: 'company_id = ? AND month = ? AND year = ?',
        whereArgs: [companyId, sheets.first['month'], sheets.first['year']],
      );
      return txn.delete(
        'sales_sheets',
        where: 'id = ? AND company_id = ?',
        whereArgs: [salesSheetId, companyId],
      );
    });
    if (count == 0) throw Exception('বিক্রয় হিসাবটি পাওয়া যায়নি।');
    return {'message': 'বিক্রয় হিসাব মুছে ফেলা হয়েছে।'};
  }

  // -------------------------------------------------------------------------
  // Stock sheets
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> getStockSheet({
    required int companyId,
    required int month,
    required int year,
  }) async {
    _validateMonthYear(month, year);
    final db = await _databaseService.database;
    final sheets = await db.query(
      'stock_sheets',
      where: 'company_id = ? AND month = ? AND year = ?',
      whereArgs: [companyId, month, year],
      limit: 1,
    );
    if (sheets.isEmpty) {
      return {'sheet': <String, dynamic>{}, 'rows': <Map<String, dynamic>>[]};
    }
    final sheet = Map<String, dynamic>.from(sheets.first);
    final rows = await db.query(
      'stock_rows',
      where: 'stock_sheet_id = ?',
      whereArgs: [sheet['id']],
      orderBy: 'date ASC, serial_no ASC, id ASC',
    );
    return {
      'sheet': sheet,
      'rows': rows.map((row) => Map<String, dynamic>.from(row)).toList(),
    };
  }

  Future<Map<String, dynamic>> saveStockSheet({
    required int companyId,
    required int month,
    required int year,
    String? selectedDate,
    String? title,
    required List<Map<String, dynamic>> rows,
  }) async {
    return _writeStockSheet(
      companyId: companyId,
      month: month,
      year: year,
      selectedDate: selectedDate,
      title: title,
      rows: rows,
    );
  }

  Future<Map<String, dynamic>> updateStockSheet({
    required int companyId,
    required int stockSheetId,
    required int month,
    required int year,
    String? selectedDate,
    String? title,
    required List<Map<String, dynamic>> rows,
  }) async {
    return _writeStockSheet(
      companyId: companyId,
      month: month,
      year: year,
      selectedDate: selectedDate,
      title: title,
      rows: rows,
      sheetId: stockSheetId,
    );
  }

  Future<Map<String, dynamic>> _writeStockSheet({
    required int companyId,
    required int month,
    required int year,
    required String? selectedDate,
    required String? title,
    required List<Map<String, dynamic>> rows,
    int? sheetId,
  }) async {
    _validateMonthYear(month, year);
    final date = _dateOnly(selectedDate, year: year, month: month);
    final selectedDay = DateTime.parse(date);
    final nowDate = DateTime.now();
    final today = DateTime(nowDate.year, nowDate.month, nowDate.day);
    if (selectedDay.isAfter(today)) {
      throw Exception('ভবিষ্যতের তারিখে স্টক হিসাব করা যাবে না।');
    }
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final sheet = await _getOrCreateSheet(
        txn,
        table: 'stock_sheets',
        companyId: companyId,
        month: month,
        year: year,
        title: title,
        sheetId: sheetId,
      );
      final id = sheet['id'] as int;

      // Replace only this date's rows, preserving other saved days.
      await txn.delete(
        'stock_rows',
        where: 'stock_sheet_id = ? AND date = ?',
        whereArgs: [id, date],
      );

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final stock = _numberText(row['stock']);
        final price = _numberText(row['price']);
        final sellingPrice = _numberText(row['selling_price']);
        await txn.insert('stock_rows', {
          'stock_sheet_id': id,
          'serial_no': _asInt(row['serial_no']) ?? index + 1,
          'date': date,
          'name': name,
          'stock': stock,
          'price': price,
          'selling_price': sellingPrice,
          'total': _numberText(_asDouble(stock) * _asDouble(price)),
          'created_at': now,
          'updated_at': now,
        });
      }

      final updated = Map<String, dynamic>.from(sheet);
      updated['title'] = title ?? sheet['title'];
      updated['updated_at'] = now;
      return {'sheet': updated, 'rows': await _stockRows(txn, id)};
    });
  }

  // -------------------------------------------------------------------------
  // Shared database helpers
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> _getOrCreateSheet(
    Transaction txn, {
    required String table,
    required int companyId,
    required int month,
    required int year,
    required String? title,
    int? sheetId,
  }) async {
    if (sheetId != null) {
      final rows = await txn.query(
        table,
        where: 'id = ? AND company_id = ? AND month = ? AND year = ?',
        whereArgs: [sheetId, companyId, month, year],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('হিসাবের শিটটি পাওয়া যায়নি।');
      final existing = Map<String, dynamic>.from(rows.first);
      final updates = <String, Object?>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updates['title'] = title;
      await txn.update(table, updates, where: 'id = ?', whereArgs: [sheetId]);
      existing.addAll(updates);
      return existing;
    }

    final existingRows = await txn.query(
      table,
      where: 'company_id = ? AND month = ? AND year = ?',
      whereArgs: [companyId, month, year],
      limit: 1,
    );
    if (existingRows.isNotEmpty) {
      final existing = Map<String, dynamic>.from(existingRows.first);
      final updates = <String, Object?>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updates['title'] = title;
      await txn.update(
        table,
        updates,
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
      existing.addAll(updates);
      return existing;
    }

    final now = DateTime.now().toIso8601String();
    final id = await txn.insert(table, {
      'company_id': companyId,
      'month': month,
      'year': year,
      'title': title,
      'created_at': now,
      'updated_at': now,
    });
    return {
      'id': id,
      'company_id': companyId,
      'month': month,
      'year': year,
      'title': title,
      'created_at': now,
      'updated_at': now,
    };
  }

  Future<List<Map<String, dynamic>>> _salesRows(
    Transaction txn,
    int sheetId,
  ) async {
    final rows = await txn.query(
      'sales_rows',
      where: 'sales_sheet_id = ?',
      whereArgs: [sheetId],
      orderBy: 'date ASC, serial_no ASC, id ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> _stockRows(
    Transaction txn,
    int sheetId,
  ) async {
    final rows = await txn.query(
      'stock_rows',
      where: 'stock_sheet_id = ?',
      whereArgs: [sheetId],
      orderBy: 'date ASC, serial_no ASC, id ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _validateMonthYear(int month, int year) {
    if (month < 1 || month > 12 || year < 1900 || year > 9999) {
      throw Exception('মাস বা সাল সঠিক নয়।');
    }
  }

  void _validateAccountRowDate(
    String date, {
    required int month,
    required int year,
  }) {
    final parsed = DateTime.parse(date);
    if (parsed.month != month || parsed.year != year) {
      throw Exception('তারিখ নির্বাচিত মাস ও বছরের মধ্যে হতে হবে।');
    }
  }

  String _dateOnly(String? input, {required int year, required int month}) {
    final cleaned = input?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    }
    final parsed = DateTime.tryParse(cleaned);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }
    // Accept an already date-only value even if the platform parser rejects it.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleaned)) return cleaned;
    throw Exception('তারিখ সঠিক নয়।');
  }

  String _numberText(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '');
    if (parsed == null || !parsed.isFinite) return '0.00';
    return parsed.toStringAsFixed(2);
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    return value == null ? null : int.tryParse(value.toString());
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
