import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile_app/services/sqlite_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('creates all BMS tables', () async {
    final db = await SqliteDatabaseService.instance.database;

    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name",
    );

    final tables = result.map((row) => row['name'] as String).toSet();

    expect(
      tables,
      containsAll([
        'users',
        'companies',
        'company_addresses',
        'company_products',
        'sales_sheets',
        'sales_rows',
        'stock_sheets',
        'stock_rows',
        'sales_stock_movements',
      ]),
    );
    final stockColumns = await db.rawQuery('PRAGMA table_info(stock_rows)');
    expect(
      stockColumns.map((row) => row['name']),
      containsAll(['price', 'selling_price', 'total']),
    );

    await db.close();
  });
}
