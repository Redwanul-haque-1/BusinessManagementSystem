import 'dart:io' show Directory, Platform;
import 'dart:isolate' show Isolate;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class SqliteDatabaseService {
  SqliteDatabaseService._internal();

  static final SqliteDatabaseService instance =
      SqliteDatabaseService._internal();

  static const String databaseName = 'bms_offline.db';
  static const int databaseVersion = 5;

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    // Keep each platform's database inside its private application storage.
    // On Windows, avoid sqflite_common_ffi's development default
    // (.dart_tool/sqflite_common_ffi/databases).
    final String databaseDirectory;

    if (Platform.isWindows) {
      Directory appSupportDirectory;
      try {
        appSupportDirectory = await getApplicationSupportDirectory();
      } on MissingPluginException {
        // Flutter widget/unit tests do not register platform plugins.
        appSupportDirectory = Directory(
          p.join(
            Directory.systemTemp.path,
            'mobile_app_test_${Isolate.current.hashCode}',
          ),
        );
      }
      final databaseFolder = Directory(
        p.join(appSupportDirectory.path, 'databases'),
      );
      await databaseFolder.create(recursive: true);
      databaseDirectory = databaseFolder.path;
    } else {
      // Android retains its existing native SQLite database location.
      databaseDirectory = await getDatabasesPath();
    }

    final databasePath = p.join(databaseDirectory, databaseName);

    return openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // 1. Users and Super Admin accounts
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            email_verified_at TEXT,
            password TEXT NOT NULL,
            remember_token TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        // 2. Companies
        await db.execute('''
          CREATE TABLE companies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            address TEXT,
            phone TEXT,
            is_active INTEGER NOT NULL DEFAULT 1
              CHECK (is_active IN (0, 1)),
            created_by INTEGER NOT NULL,
            created_at TEXT,
            updated_at TEXT,
            deleted_at TEXT,
            FOREIGN KEY (created_by)
              REFERENCES users(id)
              ON UPDATE CASCADE
              ON DELETE RESTRICT
          )
        ''');

        // 3. Company addresses
        await db.execute('''
          CREATE TABLE company_addresses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            address TEXT NOT NULL,
            created_at TEXT,
            updated_at TEXT,
            UNIQUE (company_id, address),
            FOREIGN KEY (company_id)
              REFERENCES companies(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE
          )
        ''');

        // 4. Products belonging to companies
        await db.execute('''
          CREATE TABLE company_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            created_at TEXT,
            updated_at TEXT,
            UNIQUE (company_id, name),
            FOREIGN KEY (company_id)
              REFERENCES companies(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE
          )
        ''');

        // 5. Monthly sales sheets
        await db.execute('''
          CREATE TABLE sales_sheets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            month INTEGER NOT NULL,
            year INTEGER NOT NULL,
            title TEXT,
            created_at TEXT,
            updated_at TEXT,
            UNIQUE (company_id, month, year),
            FOREIGN KEY (company_id)
              REFERENCES companies(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE
          )
        ''');

        // 6. Individual sales records
        // Decimal amounts are stored as TEXT to preserve their
        // exact decimal representation during migration.
        await db.execute('''
          CREATE TABLE sales_rows (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sales_sheet_id INTEGER NOT NULL,
            serial_no INTEGER NOT NULL,
            date TEXT,
            name TEXT NOT NULL,
            address TEXT,
            neoya TEXT NOT NULL DEFAULT '0.00',
            perot TEXT NOT NULL DEFAULT '0.00',
            bikroy TEXT NOT NULL DEFAULT '0.00',
            dor TEXT NOT NULL DEFAULT '0.00',
            taka TEXT NOT NULL DEFAULT '0.00',
            damage TEXT NOT NULL DEFAULT '0.00',
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (sales_sheet_id)
              REFERENCES sales_sheets(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE
          )
        ''');

        // 7. Monthly stock sheets
        await db.execute('''
          CREATE TABLE stock_sheets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            month INTEGER NOT NULL,
            year INTEGER NOT NULL,
            title TEXT,
            created_at TEXT,
            updated_at TEXT,
            UNIQUE (company_id, month, year),
            FOREIGN KEY (company_id)
              REFERENCES companies(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE
          )
        ''');

        // 8. Individual stock records
        await db.execute('''
          CREATE TABLE stock_rows (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_sheet_id INTEGER NOT NULL,
            serial_no INTEGER NOT NULL,
            date TEXT,
            name TEXT NOT NULL,
            stock TEXT NOT NULL DEFAULT '0.00',
            price TEXT NOT NULL DEFAULT '0.00',
            selling_price TEXT NOT NULL DEFAULT '0.00',
            total TEXT NOT NULL DEFAULT '0.00',
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (stock_sheet_id)
              REFERENCES stock_sheets(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE sales_stock_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sales_row_id INTEGER NOT NULL,
            stock_row_id INTEGER NOT NULL,
            quantity TEXT NOT NULL,
            created_at TEXT,
            FOREIGN KEY (sales_row_id)
              REFERENCES sales_rows(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE,
            FOREIGN KEY (stock_row_id)
              REFERENCES stock_rows(id)
              ON UPDATE CASCADE
              ON DELETE CASCADE
          )
        ''');

        await _createFinancialTables(db);

        // Indexes for faster related-record lookups
        await db.execute('''
          CREATE INDEX idx_company_addresses_company
          ON company_addresses(company_id)
        ''');

        await db.execute('''
          CREATE INDEX idx_company_products_company
          ON company_products(company_id)
        ''');

        await db.execute('''
          CREATE INDEX idx_sales_sheets_company
          ON sales_sheets(company_id)
        ''');

        await db.execute('''
          CREATE INDEX idx_sales_rows_sheet
          ON sales_rows(sales_sheet_id)
        ''');

        await db.execute('''
          CREATE INDEX idx_stock_sheets_company
          ON stock_sheets(company_id)
        ''');

        await db.execute('''
          CREATE INDEX idx_stock_rows_sheet
          ON stock_rows(stock_sheet_id)
        ''');

        await db.execute('''
          CREATE INDEX idx_sales_stock_movements_sales_row
          ON sales_stock_movements(sales_row_id)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE stock_rows ADD COLUMN selling_price TEXT NOT NULL DEFAULT '0.00'",
          );
          await db.execute('UPDATE stock_rows SET selling_price = price');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE sales_stock_movements (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sales_row_id INTEGER NOT NULL,
              stock_row_id INTEGER NOT NULL,
              quantity TEXT NOT NULL,
              created_at TEXT,
              FOREIGN KEY (sales_row_id)
                REFERENCES sales_rows(id)
                ON UPDATE CASCADE
                ON DELETE CASCADE,
              FOREIGN KEY (stock_row_id)
                REFERENCES stock_rows(id)
                ON UPDATE CASCADE
                ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE INDEX idx_sales_stock_movements_sales_row
            ON sales_stock_movements(sales_row_id)
          ''');
        }
        if (oldVersion < 4) {
          await db.execute(
            '''
            UPDATE stock_rows
            SET stock = printf(
                  '%.2f',
                  CAST(stock AS REAL) + COALESCE((
                    SELECT SUM(
                      CAST(movements.quantity AS REAL) -
                      (
                        MAX(
                          0,
                          CAST(sales_rows.neoya AS REAL) -
                            CAST(sales_rows.perot AS REAL)
                        ) + CAST(sales_rows.damage AS REAL)
                      )
                    )
                    FROM sales_stock_movements AS movements
                    INNER JOIN sales_rows
                      ON sales_rows.id = movements.sales_row_id
                    WHERE movements.stock_row_id = stock_rows.id
                  ), 0)
                ),
                total = printf(
                  '%.2f',
                  (
                    CAST(stock AS REAL) + COALESCE((
                      SELECT SUM(
                        CAST(movements.quantity AS REAL) -
                        (
                          MAX(
                            0,
                            CAST(sales_rows.neoya AS REAL) -
                              CAST(sales_rows.perot AS REAL)
                          ) + CAST(sales_rows.damage AS REAL)
                        )
                      )
                      FROM sales_stock_movements AS movements
                      INNER JOIN sales_rows
                        ON sales_rows.id = movements.sales_row_id
                      WHERE movements.stock_row_id = stock_rows.id
                    ), 0)
                  ) * CAST(price AS REAL)
                ),
                updated_at = ?
            WHERE id IN (
              SELECT stock_row_id FROM sales_stock_movements
            )
          ''',
            [DateTime.now().toIso8601String()],
          );

          await db.execute('''
            UPDATE sales_stock_movements
            SET quantity = (
              SELECT printf(
                '%.2f',
                MAX(
                  0,
                  CAST(sales_rows.neoya AS REAL) -
                    CAST(sales_rows.perot AS REAL)
                ) + CAST(sales_rows.damage AS REAL)
              )
              FROM sales_rows
              WHERE sales_rows.id = sales_stock_movements.sales_row_id
            )
            WHERE sales_row_id IN (SELECT id FROM sales_rows)
          ''');
        }
        if (oldVersion < 5) {
          await _createFinancialTables(db);
        }
      },
    );
  }

  Future<void> _createFinancialTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_account_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        date TEXT NOT NULL,
        online TEXT NOT NULL DEFAULT '0.00',
        lifting TEXT NOT NULL DEFAULT '0.00',
        incentive TEXT NOT NULL DEFAULT '0.00',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (company_id)
          REFERENCES companies(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_company_account_rows_company_month
      ON company_account_rows(company_id, year, month)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS due_account_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        date TEXT NOT NULL,
        due TEXT NOT NULL DEFAULT '0.00',
        deposit TEXT NOT NULL DEFAULT '0.00',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (company_id)
          REFERENCES companies(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_due_account_rows_company_month
      ON due_account_rows(company_id, year, month)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_summary_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        date TEXT NOT NULL,
        discount TEXT NOT NULL DEFAULT '0.00',
        damage TEXT NOT NULL DEFAULT '0.00',
        other_expense TEXT NOT NULL DEFAULT '0.00',
        created_at TEXT,
        updated_at TEXT,
        UNIQUE (company_id, year, month, date),
        FOREIGN KEY (company_id)
          REFERENCES companies(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_summary_rows_company_month
      ON sales_summary_rows(company_id, year, month)
    ''');
  }
}
