import 'package:flutter_test/flutter_test.dart';
// import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/services/sqlite_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ApiService service;
  late Database db;
  late int companyId;

  setUp(() async {
    service = ApiService();
    db = await SqliteDatabaseService.instance.database;

    // Clear local fixture data in foreign-key order; no production app data is
    // involved in these automated tests.
    await db.delete('sales_rows');
    await db.delete('stock_rows');
    await db.delete('sales_sheets');
    await db.delete('stock_sheets');
    await db.delete('company_products');
    await db.delete('company_addresses');
    await db.delete('companies');
    await db.delete('users');

    await db.insert('users', {
      'name': 'Test Admin',
      'email': 'test-admin@example.invalid',
      'password': 'test-only-hash',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final company = await service.createCompany(
      name: 'Offline Test Company',
      address: 'Main Road',
      phone: '01000000000',
    );
    companyId = company['id'] as int;
  });

  test('company, products, and addresses are stored in SQLite', () async {
    final companies = await service.getCompanies();
    expect(companies, hasLength(1));
    expect(companies.first['name'], 'Offline Test Company');

    final product = await service.createCompanyProduct(
      companyId: companyId,
      name: 'Rice',
    );
    expect(product['name'], 'Rice');
    expect(
      await service.getCompanyProducts(companyId: companyId),
      hasLength(1),
    );

    final address = await service.createCompanyAddress(
      companyId: companyId,
      address: 'North Road',
    );
    expect(address['address'], 'North Road');
    final companyAddresses = await service.getCompanyAddresses(
      companyId: companyId,
    );
    expect(companyAddresses.map((row) => row['address']), ['North Road']);
  });

  test('deleting a company product removes it from the product list', () async {
    final product = await service.createCompanyProduct(
      companyId: companyId,
      name: 'Rice',
    );
    await service.createCompanyProduct(companyId: companyId, name: 'rice');

    await service.deleteCompanyProduct(
      companyId: companyId,
      productId: product['id'] as int,
    );

    final products = await service.getCompanyProducts(companyId: companyId);
    expect(products, hasLength(1));
    expect(products.single['name'], 'rice');
  });

  test(
    'monthly account rows persist independently by company and month',
    () async {
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final companyRows = await service.saveCompanyAccountRows(
        companyId: companyId,
        month: now.month,
        year: now.year,
        rows: [
          {'date': date, 'online': 10000, 'lifting': 12000, 'incentive': 5000},
        ],
      );
      expect(companyRows, hasLength(1));
      expect(
        double.parse(companyRows.single['online'] as String) -
            double.parse(companyRows.single['lifting'] as String) +
            double.parse(companyRows.single['incentive'] as String),
        3000,
      );
      expect(
        await service.getCompanyAccountRows(
          companyId: companyId,
          month: now.month == 12 ? 1 : now.month + 1,
          year: now.month == 12 ? now.year + 1 : now.year,
        ),
        isEmpty,
      );

      final dueRows = await service.saveDueAccountRows(
        companyId: companyId,
        month: now.month,
        year: now.year,
        rows: [
          {'date': date, 'due': 10000, 'deposit': 3000},
        ],
      );
      expect(dueRows, hasLength(1));
      expect(
        double.parse(dueRows.single['due'] as String) -
            double.parse(dueRows.single['deposit'] as String),
        7000,
      );
      await service.saveSalesSummary(
        companyId: companyId,
        month: now.month,
        year: now.year,
        date: date,
        discount: 1000,
        damage: 500,
        otherExpense: 200,
      );
      final summaries = await service.getSalesSummaryRows(
        companyId: companyId,
        month: now.month,
        year: now.year,
      );
      expect(summaries, hasLength(1));
      expect(summaries.single['discount'], '1000.00');
      expect(summaries.single['damage'], '500.00');
      expect(summaries.single['other_expense'], '200.00');
    },
  );

  test(
    'monthly capital summary sums that month and values damage at cost',
    () async {
      await service.saveStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-01',
        rows: [
          {'name': 'Rice', 'stock': 10, 'price': 100},
          {'name': 'Onion', 'stock': 4, 'price': 50},
        ],
      );
      await service.saveStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {'name': 'Rice', 'stock': 5, 'price': 200},
        ],
      );
      await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-03',
        rows: [
          {
            'name': 'Rice',
            'address': 'Main Road',
            'neoya': 0,
            'perot': 0,
            'dor': 9999,
            'damage': 2,
          },
          {
            'name': 'Onion',
            'address': 'Main Road',
            'neoya': 0,
            'perot': 0,
            'dor': 8888,
            'damage': 3,
          },
        ],
      );
      await service.saveStockSheet(
        companyId: companyId,
        month: 11,
        year: 2026,
        selectedDate: '2026-11-01',
        rows: [
          {'name': 'Rice', 'stock': 1, 'price': 999},
        ],
      );
      await service.saveDueAccountRows(
        companyId: companyId,
        month: 10,
        year: 2026,
        rows: [
          {'date': '2026-10-01', 'due': 10000, 'deposit': 3000},
        ],
      );
      await service.saveCompanyAccountRows(
        companyId: companyId,
        month: 10,
        year: 2026,
        rows: [
          {
            'date': '2026-10-01',
            'online': 10000,
            'lifting': 12000,
            'incentive': 5000,
          },
        ],
      );

      final summary = await service.getCapitalAccountSummary(
        companyId: companyId,
        month: 10,
        year: 2026,
      );

      expect(summary['stockValue'], 1650);
      expect(summary['damageValue'], 550);
      expect(summary['marketDue'], 7000);
      expect(summary['undelivery'], 3000);
      expect(summary['totalCapital'], 12200);
    },
  );

  test('saving a sales day does not erase another day in the month', () async {
    await service.saveStockSheet(
      companyId: companyId,
      month: 10,
      year: 2026,
      selectedDate: '2026-10-01',
      rows: [
        {'name': 'Customer A', 'stock': 100, 'price': 1},
        {'name': 'Customer B', 'stock': 100, 'price': 1},
      ],
    );
    await service.saveSalesSheet(
      companyId: companyId,
      month: 10,
      year: 2026,
      selectedDate: '2026-10-02',
      rows: [
        {
          'serial_no': 1,
          'name': 'Customer A',
          'address': 'Main Road',
          'neoya': 10,
          'perot': 2,
          'dor': 5,
          'damage': 1,
        },
      ],
    );
    await service.saveSalesSheet(
      companyId: companyId,
      month: 10,
      year: 2026,
      selectedDate: '2026-10-03',
      rows: [
        {
          'serial_no': 1,
          'name': 'Customer B',
          'address': 'North Road',
          'neoya': 8,
          'perot': 1,
          'dor': 4,
          'damage': 0,
        },
      ],
    );
    final existing = await service.getSalesSheet(
      companyId: companyId,
      month: 10,
      year: 2026,
    );
    expect(existing['rows'], hasLength(2));

    final sheet = existing['sheet'] as Map<String, dynamic>;
    await service.updateSalesSheet(
      companyId: companyId,
      salesSheetId: sheet['id'] as int,
      month: 10,
      year: 2026,
      selectedDate: '2026-10-02',
      rows: [
        {
          'serial_no': 1,
          'name': 'Customer A',
          'address': 'Updated Road',
          'neoya': 12,
          'perot': 2,
          'dor': 5,
          'damage': 1,
        },
      ],
    );

    final updated = await service.getSalesSheet(
      companyId: companyId,
      month: 10,
      year: 2026,
    );
    final rows = (updated['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(2));
    expect(rows.any((row) => row['address'] == 'Updated Road'), isTrue);
    expect(rows.any((row) => row['name'] == 'Customer B'), isTrue);
    expect(
      rows.firstWhere((row) => row['address'] == 'Updated Road')['taka'],
      '50.00',
    );
  });

  test('stock sheets persist computed totals locally', () async {
    final saved = await service.saveStockSheet(
      companyId: companyId,
      month: 10,
      year: 2026,
      selectedDate: '2026-10-04',
      rows: [
        {
          'serial_no': 1,
          'name': 'Rice',
          'stock': 4,
          'price': 25,
          'selling_price': 40,
        },
      ],
    );
    expect((saved['sheet'] as Map<String, dynamic>)['id'], isA<int>());

    final loaded = await service.getStockSheet(
      companyId: companyId,
      month: 10,
      year: 2026,
    );
    final rows = (loaded['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(1));
    expect(rows.single['total'], '100.00');
    expect(rows.single['selling_price'], '40.00');
    expect(rows.single['date'], '2026-10-04');
  });

  test('stock sheets reject future dates without creating a sheet', () async {
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final date =
        '${futureDate.year.toString().padLeft(4, '0')}-'
        '${futureDate.month.toString().padLeft(2, '0')}-'
        '${futureDate.day.toString().padLeft(2, '0')}';

    await expectLater(
      service.saveStockSheet(
        companyId: companyId,
        month: futureDate.month,
        year: futureDate.year,
        selectedDate: date,
        rows: [
          {'name': 'Rice', 'stock': 10, 'price': 20, 'selling_price': 25},
        ],
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('ভবিষ্যতের তারিখে স্টক হিসাব করা যাবে না।'),
        ),
      ),
    );

    final sheet = await service.getStockSheet(
      companyId: companyId,
      month: futureDate.month,
      year: futureDate.year,
    );
    expect(sheet['rows'], isEmpty);
  });

  test(
    'stock product list aggregates entries and sales across dates',
    () async {
      await service.createCompanyProduct(companyId: companyId, name: 'Onion');
      await service.saveStockSheet(
        companyId: companyId,
        month: 11,
        year: 2026,
        selectedDate: '2026-11-02',
        rows: [
          {'name': 'Onion', 'stock': 500, 'price': 40, 'selling_price': 55},
          {'name': 'onion', 'stock': 500, 'price': 40, 'selling_price': 55},
        ],
      );
      await service.saveStockSheet(
        companyId: companyId,
        month: 11,
        year: 2026,
        selectedDate: '2026-11-03',
        rows: [
          {'name': 'Onion', 'stock': 250, 'price': 42, 'selling_price': 58},
        ],
      );

      var products = await service.getStockProductList(companyId: companyId);
      expect(products, hasLength(1));
      expect(products.single['stock'], '1250.00');
      expect(products.single['total'], '50500.00');
      expect(products.single['price'], '42.00');
      expect(products.single['selling_price'], '58.00');
      expect(products.single['date'], '2026-11-03');

      await service.saveSalesSheet(
        companyId: companyId,
        month: 11,
        year: 2026,
        selectedDate: '2026-11-04',
        rows: [
          {'name': 'ONION', 'neoya': 300, 'perot': 0, 'damage': 50, 'dor': 58},
        ],
      );
      products = await service.getStockProductList(companyId: companyId);
      expect(products.single['stock'], '900.00');
      expect(products.single['total'], '36000.00');
      expect(products.single['price'], '42.00');
      expect(products.single['selling_price'], '58.00');
      expect(products.single['date'], '2026-11-03');

      await expectLater(
        service.saveSalesSheet(
          companyId: companyId,
          month: 11,
          year: 2026,
          selectedDate: '2026-11-05',
          rows: [
            {'name': 'Onion', 'neoya': 950, 'perot': 0, 'damage': 0, 'dor': 58},
          ],
        ),
        throwsA(isA<OutOfStockException>()),
      );
      products = await service.getStockProductList(companyId: companyId);
      expect(products.single['stock'], '900.00');
    },
  );

  test(
    'sales deduct taken quantities and prevent insufficient stock',
    () async {
      await service.createCompanyProduct(companyId: companyId, name: 'Oil');
      await service.createCompanyProduct(companyId: companyId, name: 'Rice');
      await service.saveStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-01',
        rows: [
          {
            'serial_no': 1,
            'name': 'Oil',
            'stock': 100,
            'price': 40,
            'selling_price': 55,
          },
          {
            'serial_no': 2,
            'name': 'Rice',
            'stock': 8,
            'price': 5,
            'selling_price': 7,
          },
        ],
      );

      await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {'name': 'Oil', 'neoya': 50, 'perot': 10, 'dor': 55, 'damage': 5},
        ],
      );

      var listed = await service.getStockProductList(companyId: companyId);
      final oil = listed.firstWhere((row) => row['name'] == 'Oil');
      final rice = listed.firstWhere((row) => row['name'] == 'Rice');
      expect(oil['stock'], '55.00');
      expect(oil['total'], '2200.00');
      expect(oil['date'], '2026-10-01');
      expect(rice['stock'], '8.00');
      expect(rice['date'], '2026-10-01');
      expect(rice['latest_update_date'], '2026-10-01');

      final stockSheet = await service.getStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
      );
      final stockSheetRows = (stockSheet['rows'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        stockSheetRows.firstWhere((row) => row['name'] == 'Oil')['stock'],
        '55.00',
      );
      expect(
        stockSheetRows.firstWhere((row) => row['name'] == 'Oil')['total'],
        '2200.00',
      );

      await expectLater(
        service.saveSalesSheet(
          companyId: companyId,
          month: 10,
          year: 2026,
          selectedDate: '2026-10-03',
          rows: [
            {'name': 'Oil', 'neoya': 50, 'perot': 0, 'dor': 55, 'damage': 6},
          ],
        ),
        throwsA(isA<OutOfStockException>()),
      );
      listed = await service.getStockProductList(companyId: companyId);
      expect(
        listed.firstWhere((row) => row['name'] == 'Oil')['stock'],
        '55.00',
      );
      final sales = await service.getSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
      );
      expect(sales['rows'], hasLength(1));

      await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-03',
        rows: [
          {'name': 'Oil', 'neoya': 55, 'perot': 0, 'dor': 55, 'damage': 0},
        ],
      );
      listed = await service.getStockProductList(companyId: companyId);
      expect(listed.firstWhere((row) => row['name'] == 'Oil')['stock'], '0.00');
      await expectLater(
        service.saveSalesSheet(
          companyId: companyId,
          month: 10,
          year: 2026,
          selectedDate: '2026-10-04',
          rows: [
            {'name': 'Oil', 'neoya': 1, 'perot': 0, 'dor': 55, 'damage': 0},
          ],
        ),
        throwsA(isA<OutOfStockException>()),
      );
      listed = await service.getStockProductList(companyId: companyId);
      expect(listed.firstWhere((row) => row['name'] == 'Oil')['stock'], '0.00');
    },
  );

  test(
    'sales validate and deduct each product against its own stock only',
    () async {
      await service.createCompanyProduct(companyId: companyId, name: 'Oil');
      await service.createCompanyProduct(
        companyId: companyId,
        name: 'Biscuits',
      );
      await service.saveStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-01',
        rows: [
          {'name': 'Oil', 'stock': 10, 'price': 40},
          {'name': 'Biscuits', 'stock': 100, 'price': 5},
        ],
      );

      await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {'name': 'Oil', 'neoya': 7, 'perot': 2, 'damage': 1, 'dor': 55},
          {'name': 'Biscuits', 'neoya': 50, 'perot': 5, 'damage': 3, 'dor': 10},
        ],
      );

      var products = await service.getStockProductList(companyId: companyId);
      expect(
        products.firstWhere((row) => row['name'] == 'Oil')['stock'],
        '4.00',
      );
      expect(
        products.firstWhere((row) => row['name'] == 'Biscuits')['stock'],
        '52.00',
      );
      expect(
        products.firstWhere((row) => row['name'] == 'Oil')['total'],
        '160.00',
      );
      expect(
        products.firstWhere((row) => row['name'] == 'Biscuits')['total'],
        '260.00',
      );

      await expectLater(
        service.saveSalesSheet(
          companyId: companyId,
          month: 10,
          year: 2026,
          selectedDate: '2026-10-03',
          rows: [
            {'name': 'Oil', 'neoya': 5, 'perot': 0, 'damage': 0, 'dor': 55},
          ],
        ),
        throwsA(isA<OutOfStockException>()),
      );

      products = await service.getStockProductList(companyId: companyId);
      expect(
        products.firstWhere((row) => row['name'] == 'Oil')['stock'],
        '4.00',
      );
      expect(
        products.firstWhere((row) => row['name'] == 'Biscuits')['stock'],
        '52.00',
      );
    },
  );

  test(
    'editing a sales day replaces its stock movement, not double deducts',
    () async {
      await service.createCompanyProduct(companyId: companyId, name: 'Rice');
      await service.saveStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-01',
        rows: [
          {'name': 'Rice', 'stock': 50, 'price': 2},
        ],
      );
      final saved = await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {'name': 'Rice', 'neoya': 25, 'perot': 5, 'dor': 3, 'damage': 2},
        ],
      );
      final sheet = saved['sheet'] as Map<String, dynamic>;
      await service.updateSalesSheet(
        companyId: companyId,
        salesSheetId: sheet['id'] as int,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {'name': 'Rice', 'neoya': 25, 'perot': 10, 'dor': 3, 'damage': 3},
        ],
      );

      final listed = await service.getStockProductList(companyId: companyId);
      expect(listed.single['stock'], '32.00');
      expect(listed.single['total'], '64.00');
    },
  );

  test(
    'sales edits deduct only product-specific changes and aggregate new rows',
    () async {
      for (final name in ['Oil', 'Onion', 'Garlic']) {
        await service.createCompanyProduct(companyId: companyId, name: name);
      }
      await service.saveStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-01',
        rows: [
          {'name': 'Oil', 'stock': 500, 'price': 2},
          {'name': 'Onion', 'stock': 500, 'price': 3},
          {'name': 'Garlic', 'stock': 50, 'price': 4},
        ],
      );

      final saved = await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {'name': 'Oil', 'neoya': 400, 'perot': 0, 'damage': 0},
          {'name': 'Oil', 'neoya': 100, 'perot': 0, 'damage': 0},
        ],
      );
      final sheetId = (saved['sheet'] as Map<String, dynamic>)['id'] as int;
      var products = await service.getStockProductList(companyId: companyId);
      expect(
        products.firstWhere((row) => row['name'] == 'Oil')['stock'],
        '0.00',
      );

      await service.updateSalesSheet(
        companyId: companyId,
        salesSheetId: sheetId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {'name': 'Oil', 'neoya': 400, 'perot': 0, 'damage': 0},
          {'name': 'Oil', 'neoya': 100, 'perot': 0, 'damage': 0},
          {'name': 'Onion', 'neoya': 95, 'perot': 0, 'damage': 0},
        ],
      );

      products = await service.getStockProductList(companyId: companyId);
      expect(
        products.firstWhere((row) => row['name'] == 'Oil')['stock'],
        '0.00',
      );
      expect(
        products.firstWhere((row) => row['name'] == 'Onion')['stock'],
        '405.00',
      );

      await expectLater(
        service.saveSalesSheet(
          companyId: companyId,
          month: 10,
          year: 2026,
          selectedDate: '2026-10-03',
          rows: [
            {'name': 'Garlic', 'neoya': 30, 'perot': 0, 'damage': 0},
            {'name': 'Garlic', 'neoya': 30, 'perot': 0, 'damage': 0},
          ],
        ),
        throwsA(isA<OutOfStockException>()),
      );
      products = await service.getStockProductList(companyId: companyId);
      expect(
        products.firstWhere((row) => row['name'] == 'Garlic')['stock'],
        '50.00',
      );

      await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-03',
        rows: [
          {'name': 'Garlic', 'neoya': 20, 'perot': 0, 'damage': 0},
          {'name': 'Garlic', 'neoya': 20, 'perot': 0, 'damage': 0},
        ],
      );
      products = await service.getStockProductList(companyId: companyId);
      expect(
        products.firstWhere((row) => row['name'] == 'Garlic')['stock'],
        '10.00',
      );
    },
  );

  test(
    'upgrades previous sales movements to sale plus damage quantity',
    () async {
      await service.createCompanyProduct(
        companyId: companyId,
        name: 'Ice cream',
      );
      await service.saveStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-01',
        rows: [
          {'name': 'Ice cream', 'stock': 100, 'price': 40, 'selling_price': 55},
        ],
      );
      await service.saveSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
        selectedDate: '2026-10-02',
        rows: [
          {
            'name': 'Ice cream',
            'neoya': 50,
            'perot': 10,
            'damage': 5,
            'dor': 55,
          },
        ],
      );

      final sales = await service.getSalesSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
      );
      final salesRows = (sales['rows'] as List).cast<Map<String, dynamic>>();
      final saleRowId = salesRows.single['id'] as int;
      final stock = await service.getStockSheet(
        companyId: companyId,
        month: 10,
        year: 2026,
      );
      final stockRows = (stock['rows'] as List).cast<Map<String, dynamic>>();
      final stockRowId = stockRows.single['id'] as int;

      await db.update(
        'stock_rows',
        {'stock': '50.00', 'total': '2000.00'},
        where: 'id = ?',
        whereArgs: [stockRowId],
      );
      await db.update(
        'sales_stock_movements',
        {'quantity': '50.00'},
        where: 'sales_row_id = ?',
        whereArgs: [saleRowId],
      );

      await db.setVersion(3);
      await db.close();
      db = await SqliteDatabaseService.instance.database;

      final upgraded = await service.getStockProductList(companyId: companyId);
      expect(upgraded.single['stock'], '55.00');
      expect(upgraded.single['total'], '2200.00');
      final movement = await db.query(
        'sales_stock_movements',
        where: 'sales_row_id = ?',
        whereArgs: [saleRowId],
      );
      expect(movement.single['quantity'], '45.00');
    },
  );
}
