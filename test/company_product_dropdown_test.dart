import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/Companies/capital_account_page.dart';
import 'package:mobile_app/screens/Companies/company_account_page.dart';
import 'package:mobile_app/screens/Companies/company_dashboard_page.dart';
import 'package:mobile_app/screens/Companies/company_list_page.dart';
import 'package:mobile_app/screens/Companies/due_account_page.dart';
import 'package:mobile_app/screens/Companies/sales_sheet_page.dart';
import 'package:mobile_app/screens/Companies/stock_sheet_page.dart';
import 'package:mobile_app/screens/Companies/stock_product_list_page.dart';
import 'package:mobile_app/services/api_service.dart';

class _ProductApiService extends ApiService {
  final List<Map<String, dynamic>> products = [];
  final List<Map<String, dynamic>> addresses = [];
  final List<Map<String, dynamic>> savedRows = [];
  final List<Map<String, dynamic>> companies = [
    {'id': 7, 'name': 'Test company'},
  ];
  final List<Map<String, dynamic>> stockProductRows = [];
  final List<Map<String, dynamic>> companyAccountRows = [];
  final List<Map<String, dynamic>> dueAccountRows = [];
  final List<Map<String, dynamic>> salesSummaryRows = [];
  int? capitalSummaryMonth;
  int? capitalSummaryYear;
  Map<String, dynamic> stockSheetData = {'sheet': null, 'rows': []};
  Map<String, dynamic> salesSheetData = {'sheet': null, 'rows': []};

  @override
  Future<List<dynamic>> getCompanies() async =>
      List<Map<String, dynamic>>.from(companies);

  @override
  Future<List<Map<String, dynamic>>> getStockProductList({
    required int companyId,
  }) async => List<Map<String, dynamic>>.from(stockProductRows);

  @override
  Future<List<Map<String, dynamic>>> getCompanyAccountRows({
    required int companyId,
    required int month,
    required int year,
  }) async => List<Map<String, dynamic>>.from(companyAccountRows);

  @override
  Future<List<Map<String, dynamic>>> saveCompanyAccountRows({
    required int companyId,
    required int month,
    required int year,
    required List<Map<String, dynamic>> rows,
  }) async {
    companyAccountRows
      ..clear()
      ..addAll(rows.map((row) => Map<String, dynamic>.from(row)));
    return List<Map<String, dynamic>>.from(companyAccountRows);
  }

  @override
  Future<List<Map<String, dynamic>>> getDueAccountRows({
    required int companyId,
    required int month,
    required int year,
  }) async => List<Map<String, dynamic>>.from(dueAccountRows);

  @override
  Future<List<Map<String, dynamic>>> saveDueAccountRows({
    required int companyId,
    required int month,
    required int year,
    required List<Map<String, dynamic>> rows,
  }) async {
    dueAccountRows
      ..clear()
      ..addAll(rows.map((row) => Map<String, dynamic>.from(row)));
    return List<Map<String, dynamic>>.from(dueAccountRows);
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesSummaryRows({
    required int companyId,
    required int month,
    required int year,
  }) async => List<Map<String, dynamic>>.from(salesSummaryRows);

  @override
  Future<Map<String, dynamic>> saveSalesSummary({
    required int companyId,
    required int month,
    required int year,
    required String date,
    required double discount,
    required double damage,
    required double otherExpense,
  }) async {
    final row = {
      'date': date,
      'discount': discount,
      'damage': damage,
      'other_expense': otherExpense,
    };
    salesSummaryRows.removeWhere((summary) => summary['date'] == date);
    salesSummaryRows.add(row);
    return row;
  }

  @override
  Future<Map<String, dynamic>> getSalesSheet({
    required int companyId,
    required int month,
    required int year,
  }) async {
    return salesSheetData;
  }

  @override
  Future<Map<String, dynamic>> getStockSheet({
    required int companyId,
    required int month,
    required int year,
  }) async {
    return stockSheetData;
  }

  @override
  Future<Map<String, double>> getCapitalAccountSummary({
    required int companyId,
    required int month,
    required int year,
  }) async {
    capitalSummaryMonth = month;
    capitalSummaryYear = year;
    double number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    final stockRows = (stockSheetData['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final salesRows = (salesSheetData['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final purchasePriceByProduct = <String, double>{};
    for (final row in stockRows) {
      final name = row['name']?.toString().trim().toLowerCase() ?? '';
      if (name.isNotEmpty) {
        purchasePriceByProduct[name] = number(row['price']);
      }
    }
    final stockValue = stockRows.fold<double>(
      0,
      (sum, row) =>
          sum +
          (row['total'] == null
              ? number(row['stock']) * number(row['price'])
              : number(row['total'])),
    );
    final damageValue = salesRows.fold<double>(0, (sum, row) {
      final name = row['name']?.toString().trim().toLowerCase() ?? '';
      return sum + number(row['damage']) * (purchasePriceByProduct[name] ?? 0);
    });
    final marketDue = dueAccountRows.fold<double>(
      0,
      (sum, row) => sum + number(row['due']) - number(row['deposit']),
    );
    final undelivery = companyAccountRows.fold<double>(
      0,
      (sum, row) =>
          sum +
          number(row['online']) -
          number(row['lifting']) +
          number(row['incentive']),
    );
    return {
      'stockValue': stockValue,
      'marketDue': marketDue,
      'damageValue': damageValue,
      'undelivery': undelivery,
      'totalCapital': stockValue + marketDue + damageValue + undelivery,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getCompanyProducts({
    required int companyId,
  }) async {
    return List<Map<String, dynamic>>.from(products);
  }

  @override
  Future<Map<String, dynamic>> createCompanyProduct({
    required int companyId,
    required String name,
  }) async {
    final product = {'id': products.length + 1, 'name': name};
    products.add(product);
    return product;
  }

  @override
  Future<void> deleteCompanyProduct({
    required int companyId,
    required int productId,
  }) async {
    products.removeWhere((product) => product['id'] == productId);
  }

  @override
  Future<List<Map<String, dynamic>>> getCompanyAddresses({
    required int companyId,
  }) async {
    return List<Map<String, dynamic>>.from(addresses);
  }

  @override
  Future<Map<String, dynamic>> createCompanyAddress({
    required int companyId,
    required String address,
  }) async {
    final roadAddress = {'id': addresses.length + 1, 'address': address};
    addresses.add(roadAddress);
    return roadAddress;
  }

  @override
  Future<Map<String, dynamic>> saveSalesSheet({
    required int companyId,
    required int month,
    required int year,
    String? selectedDate,
    String? title,
    required List<Map<String, dynamic>> rows,
  }) async {
    savedRows
      ..clear()
      ..addAll(rows.map((row) => Map<String, dynamic>.from(row)));
    salesSheetData = {
      'sheet': {'id': 1},
      'rows': rows.map((row) => {...row, 'date': selectedDate}).toList(),
    };
    return {
      'sheet': {'id': 1},
      'rows': rows,
    };
  }

  @override
  Future<Map<String, dynamic>> updateSalesSheet({
    required int companyId,
    required int salesSheetId,
    required int month,
    required int year,
    String? selectedDate,
    String? title,
    required List<Map<String, dynamic>> rows,
  }) async {
    final otherDayRows = (salesSheetData['rows'] as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['date'] != selectedDate)
        .toList();
    final updatedRows = [
      ...otherDayRows,
      ...rows.map((row) => {...row, 'date': selectedDate}),
    ];
    salesSheetData = {
      'sheet': {'id': salesSheetId},
      'rows': updatedRows,
    };
    savedRows
      ..clear()
      ..addAll(rows.map((row) => Map<String, dynamic>.from(row)));
    return {
      'sheet': {'id': salesSheetId},
      'rows': rows,
    };
  }
}

class _SalesCalculationApiService extends _ProductApiService {
  _SalesCalculationApiService(this.rowDate);

  final String rowDate;

  @override
  Future<Map<String, dynamic>> getSalesSheet({
    required int companyId,
    required int month,
    required int year,
  }) async {
    return {
      'sheet': {'id': 1},
      'rows': [
        {
          'name': 'Rice',
          'address': 'Feni',
          'date': rowDate,
          'neoya': 3,
          'perot': 1,
          'dor': 5,
          'taka': 1234,
          'damage': 0,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> updateSalesSheet({
    required int companyId,
    required int salesSheetId,
    required int month,
    required int year,
    String? selectedDate,
    String? title,
    required List<Map<String, dynamic>> rows,
  }) async {
    savedRows
      ..clear()
      ..addAll(rows.map((row) => Map<String, dynamic>.from(row)));
    return {
      'sheet': {'id': salesSheetId},
      'rows': rows,
    };
  }
}

void main() {
  testWidgets('sales and stock sheets offer daily and monthly PDF reports', (
    WidgetTester tester,
  ) async {
    final apiService = _ProductApiService();
    final currentDate = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          initialDate: currentDate,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDF ডাউনলোড'), findsNothing);
    expect(find.textContaining('দিন:'), findsNothing);
    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    expect(find.text('PDF ডাউনলোড'), findsOneWidget);
    await tester.tap(find.text('PDF ডাউনলোড'));
    await tester.pumpAndSettle();
    expect(find.text('দৈনিক হিসাব'), findsOneWidget);
    expect(find.text('মাসিক হিসাব'), findsOneWidget);

    await tester.tap(find.text('মাসিক হিসাব'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDF ডাউনলোড'), findsNothing);
    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    expect(find.text('PDF ডাউনলোড'), findsOneWidget);
  });

  testWidgets('sales amount is calculated from bikroy and dor', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final currentDate = DateTime(2026, 10, 10);
    final rowDate =
        '${currentDate.year}-'
        '${currentDate.month.toString().padLeft(2, '0')}-'
        '${currentDate.day.toString().padLeft(2, '0')}';
    final apiService = _SalesCalculationApiService(rowDate);
    apiService.products.add({'id': 1, 'name': 'Rice'});

    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          initialDate: currentDate,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10'), findsNWidgets(3));
    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();

    expect(apiService.savedRows.single.containsKey('taka'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock value uses the persisted quantity at purchase price', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final currentDate = DateTime.now();
    final date =
        '${currentDate.year}-'
        '${currentDate.month.toString().padLeft(2, '0')}-'
        '${currentDate.day.toString().padLeft(2, '0')}';
    final apiService = _ProductApiService()
      ..products.add({'id': 1, 'name': 'Ice cream'})
      ..stockSheetData = {
        'sheet': {'id': 1},
        'rows': [
          {
            'name': 'Ice cream',
            'stock': 55,
            'price': 40,
            'selling_price': 55,
            'total': 2200,
            'date': date,
          },
        ],
      }
      ..salesSheetData = {
        'sheet': {'id': 1},
        'rows': [
          {
            'name': 'Ice cream',
            'neoya': 50,
            'perot': 0,
            'dor': 55,
            'date': date,
          },
        ],
      };

    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('স্টক হিসাব'), findsOneWidget);
    expect(find.text('৳ 2200'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'adding a sales product updates the dropdown and stock product list',
    (WidgetTester tester) async {
      final apiService = _ProductApiService();
      final company = {'id': 7, 'name': 'Test company'};
      final currentDate = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: SalesSheetPage(
            company: company,
            month: currentDate.month,
            year: currentDate.year,
            apiService: apiService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('মেনু'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('পণ্য যোগ'));
      await tester.pumpAndSettle();

      expect(find.text('কোম্পানির পণ্য যোগ করুন'), findsOneWidget);
      final productNameField = find.byType(TextField).last;
      await tester.enterText(productNameField, 'Rice');
      await tester.tap(find.text('যোগ করুন'));
      await tester.pumpAndSettle();

      expect(find.text('Rice'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: StockSheetPage(
            company: company,
            month: currentDate.month,
            year: currentDate.year,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('পণ্য যোগ করুন'), findsNothing);
      await tester.tap(find.byTooltip('মেনু'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('পণ্য যোগ'));
      await tester.pumpAndSettle();
      expect(find.text('আগে যোগ করা পণ্য'), findsOneWidget);
      expect(find.text('তালিকা থেকে পণ্য সরান'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice').last);
      await tester.pumpAndSettle();
      expect(find.text('নির্বাচিত পণ্য যোগ করুন'), findsOneWidget);
      await tester.tap(find.text('নির্বাচিত পণ্য যোগ করুন'));
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsOneWidget);

      await tester.tap(find.byTooltip('মেনু'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('পণ্য যোগ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rice তালিকা থেকে সরান'));
      await tester.pumpAndSettle();
      expect(apiService.products, isEmpty);
      expect(find.text('আগে যোগ করা পণ্য'), findsOneWidget);
      expect(find.text('Rice তালিকা থেকে সরান'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a product fills its latest stock selling price into the sales rate',
    (WidgetTester tester) async {
      final apiService = _ProductApiService()
        ..products.add({'id': 1, 'name': 'Rice'})
        ..stockProductRows.add({'name': 'Rice', 'selling_price': 18.75})
        ..stockSheetData = {
          'sheet': null,
          'rows': [
            {'name': 'Rice', 'selling_price': 12.5},
          ],
        };
      final currentDate = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: SalesSheetPage(
            company: {'id': 7, 'name': 'Test company'},
            month: currentDate.month,
            year: currentDate.year,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .any((field) => field.controller?.text == '18.75'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('adding a daily road displays beside year and saves with rows', (
    WidgetTester tester,
  ) async {
    final apiService = _ProductApiService();
    final currentDate = DateTime(2026, 10, 10);
    apiService.products.add({'id': 1, 'name': 'Rice'});

    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          initialDate: currentDate,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('রোড/ঠিকানা'), findsNothing);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('রোড/ঠিকানা যোগ'));
    await tester.pumpAndSettle();

    expect(find.text('আজকের রোড/ঠিকানা'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'উত্তর রোড');
    await tester.tap(find.text('নির্বাচন করুন'));
    await tester.pumpAndSettle();

    expect(find.text('উত্তর রোড'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();

    expect(apiService.savedRows.single['address'], 'উত্তর রোড');
    expect(find.text('উত্তর রোড'), findsOneWidget);

    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('দিন নির্বাচন'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('রোড/ঠিকানা যোগ'));
    await tester.pumpAndSettle();

    expect(find.text('আগের রোড নির্বাচন করুন'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('উত্তর রোড').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('নির্বাচন করুন'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();

    expect(apiService.addresses, hasLength(1));
    expect(apiService.savedRows.single['address'], 'উত্তর রোড');
    expect(find.text('উত্তর রোড'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('road display is specific to the selected day', (
    WidgetTester tester,
  ) async {
    final apiService = _ProductApiService()
      ..products.add({'id': 1, 'name': 'Rice'})
      ..salesSheetData = {
        'sheet': {'id': 1},
        'rows': [
          {
            'name': 'Rice',
            'address': 'Feni',
            'date': '2026-10-10',
            'neoya': 2,
            'perot': 0,
            'dor': 5,
            'damage': 0,
          },
          {
            'name': 'Rice',
            'address': 'Dagonbhuiya',
            'date': '2026-10-11',
            'neoya': 3,
            'perot': 0,
            'dor': 5,
            'damage': 0,
          },
        ],
      };

    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: 10,
          year: 2026,
          initialDate: DateTime(2026, 10, 10),
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('তারিখ: 10/10/2026'), findsOneWidget);
    expect(find.text('Feni'), findsOneWidget);
    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('দিন নির্বাচন'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Dagonbhuiya'), findsOneWidget);
    expect(find.text('Feni'), findsNothing);
    expect(find.text('তারিখ: 11/10/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date and management actions are only available in the menu', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final currentDate = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          apiService: _ProductApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('পণ্য যোগ'), findsNothing);
    expect(find.text('রোড/ঠিকানা যোগ'), findsNothing);
    expect(find.textContaining('দিন:'), findsNothing);
    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    expect(find.text('দিন নির্বাচন'), findsOneWidget);
    expect(find.text('PDF ডাউনলোড'), findsOneWidget);
    expect(find.text('পণ্য যোগ'), findsOneWidget);
    expect(find.text('রোড/ঠিকানা যোগ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales sheet adds the requested number of rows', (
    WidgetTester tester,
  ) async {
    final currentDate = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          apiService: _ProductApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('নতুন সারি'));
    await tester.pumpAndSettle();
    expect(find.text('কতটি নতুন সারি যোগ করবেন?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '3');
    await tester.tap(find.text('যোগ করুন'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock sheet adds the requested number of rows', (
    WidgetTester tester,
  ) async {
    final currentDate = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          apiService: _ProductApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('নতুন সারি'));
    await tester.pumpAndSettle();
    expect(find.text('কতটি নতুন সারি যোগ করবেন?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '2');
    await tester.tap(find.text('যোগ করুন'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales and stock headers show selected date beside company', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final currentDateLabel =
        'তারিখ: ${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          apiService: _ProductApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final salesDate = find.text(currentDateLabel);
    expect(salesDate, findsOneWidget);
    final salesHeader = find
        .ancestor(of: salesDate, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: salesHeader, matching: find.text('Test company')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          apiService: _ProductApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final stockDate = find.text(currentDateLabel);
    expect(stockDate, findsOneWidget);
    final stockHeader = find
        .ancestor(of: stockDate, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: stockHeader, matching: find.text('Test company')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock date picker limits selection to today', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          apiService: _ProductApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('দিন নির্বাচন'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.lastDate, DateTime(now.year, now.month, now.day));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock date selection shows that day date and stock rows', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final month = now.day > 1
        ? now.month
        : now.month == 1
        ? 12
        : now.month - 1;
    final year = now.day > 1
        ? now.year
        : now.month == 1
        ? now.year - 1
        : now.year;
    final selectedDate = now.day > 1
        ? DateTime(now.year, now.month, now.day)
        : DateTime(year, month);
    final alternateDate = selectedDate.day > 1
        ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day - 1)
        : DateTime(selectedDate.year, selectedDate.month, 2);
    String dateValue(DateTime date) =>
        '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    String dateLabel(DateTime date) =>
        'তারিখ: ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final apiService = _ProductApiService()
      ..products.addAll([
        {'id': 1, 'name': 'Rice'},
        {'id': 2, 'name': 'Onion'},
      ])
      ..stockSheetData = {
        'sheet': {'id': 1},
        'rows': [
          {
            'id': 1,
            'serial_no': 1,
            'name': 'Rice',
            'date': dateValue(selectedDate),
            'stock': 5,
            'price': 10,
            'selling_price': 15,
            'total': 50,
          },
          {
            'id': 2,
            'serial_no': 1,
            'name': 'Onion',
            'date': dateValue(alternateDate),
            'stock': 8,
            'price': 20,
            'selling_price': 25,
            'total': 160,
          },
        ],
      };
    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: month,
          year: year,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(dateLabel(selectedDate)), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('দিন নির্বাচন'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${alternateDate.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text(dateLabel(alternateDate)), findsOneWidget);
    expect(find.text('Onion'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('company account balances and total include signed amounts', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final apiService = _ProductApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyAccountPage(
          initialCompanyId: 7,
          initialMonth: now.month,
          initialYear: now.year,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('নতুন সারি'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন সারি'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '20000');
    await tester.enterText(fields.at(1), '15000');
    await tester.enterText(fields.at(2), '5000');
    await tester.enterText(fields.at(3), '10000');
    await tester.enterText(fields.at(4), '16000');
    await tester.enterText(fields.at(5), '1000');
    await tester.enterText(fields.at(6), '3000');
    await tester.enterText(fields.at(7), '5000');
    await tester.enterText(fields.at(8), '0');
    await tester.pumpAndSettle();

    expect(find.text('+10000'), findsOneWidget);
    expect(find.text('-5000'), findsOneWidget);
    expect(find.text('-2000'), findsOneWidget);
    expect(find.text('মোট ব্যালেন্স: +3000'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('মোট ব্যালেন্স: +3000')).textAlign,
      TextAlign.center,
    );

    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();
    expect(apiService.companyAccountRows, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('due account calculates market due as due minus deposit', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final apiService = _ProductApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: DueAccountPage(
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '10000');
    await tester.enterText(find.byType(TextField).at(1), '3000');
    await tester.pumpAndSettle();
    expect(find.text('7000'), findsOneWidget);
    expect(find.text('মোট মার্কেট বাকি: 7000'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('মোট মার্কেট বাকি: 7000')).textAlign,
      TextAlign.center,
    );

    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();
    expect(apiService.dueAccountRows.single['due'], 10000);
    expect(apiService.dueAccountRows.single['deposit'], 3000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('company list shows current monthly capital in a shadowed row', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final apiService = _ProductApiService()
      ..stockSheetData = {
        'sheet': null,
        'rows': [
          {'name': 'Rice', 'total': 12345},
        ],
      };
    await tester.pumpWidget(
      MaterialApp(home: CompanyListPage(apiService: apiService)),
    );
    await tester.pumpAndSettle();

    final capitalText = find.text('মূলধন: 12345');
    expect(capitalText, findsOneWidget);
    expect(apiService.capitalSummaryMonth, now.month);
    expect(apiService.capitalSummaryYear, now.year);
    final shadowedBadge = find.ancestor(
      of: capitalText,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            (decoration.boxShadow?.isNotEmpty ?? false);
      }),
    );
    expect(shadowedBadge, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capital totals follow due and company account formulas', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    _ProductApiService buildApiService({
      required double online,
      required double lifting,
      required double incentive,
    }) => _ProductApiService()
      ..stockSheetData = {
        'sheet': null,
        'rows': [
          {
            'name': 'Rice',
            'date': '2026-10-01',
            'stock': 10,
            'price': 11000,
            'total': 110000,
          },
        ],
      }
      ..salesSheetData = {
        'sheet': null,
        'rows': [
          {'name': 'Rice', 'date': '2026-10-01', 'damage': 100, 'dor': 20},
        ],
      }
      ..dueAccountRows.add({'due': 10000, 'deposit': 3000})
      ..companyAccountRows.add({
        'online': online,
        'lifting': lifting,
        'incentive': incentive,
      });

    await tester.pumpWidget(
      MaterialApp(
        home: CapitalAccountPage(
          key: const ValueKey('positive'),
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          apiService: buildApiService(
            online: 10000,
            lifting: 12000,
            incentive: 5000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+3000'), findsOneWidget);
    expect(find.text('1220000'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: CapitalAccountPage(
          key: const ValueKey('negative'),
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          apiService: buildApiService(
            online: 10000,
            lifting: 15000,
            incentive: 2000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('-3000'), findsOneWidget);
    expect(find.text('1214000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard menu and monthly cards show linked account totals', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = _ProductApiService()
      ..stockSheetData = {
        'sheet': null,
        'rows': [
          {
            'name': 'Rice',
            'date': '2026-10-01',
            'stock': 10,
            'price': 11000,
            'total': 110000,
          },
        ],
      }
      ..salesSheetData = {
        'sheet': null,
        'rows': [
          {'name': 'Rice', 'date': '2026-10-01', 'damage': 100, 'dor': 20},
        ],
      }
      ..dueAccountRows.add({'due': 10000, 'deposit': 3000})
      ..companyAccountRows.add({
        'online': 10000,
        'lifting': 12000,
        'incentive': 5000,
      });
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyDashboardPage(
          company: {'id': 7, 'name': 'Test company'},
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('দৈনিক সারসংক্ষেপ'), findsNothing);
    expect(find.text('আনডেলিভারি'), findsOneWidget);
    expect(find.text('+3000'), findsOneWidget);
    expect(find.text('মার্কেট বাকি'), findsOneWidget);
    expect(find.text('7000'), findsOneWidget);
    expect(find.text('মোট মূলধন'), findsOneWidget);
    expect(find.text('1220000'), findsOneWidget);
    expect(find.text('৳ 1100000'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('হিসাবের মেনু'));
    await tester.pumpAndSettle();
    expect(find.text('বাকি হিসাব'), findsOneWidget);
    expect(find.text('মূলধন হিসাব'), findsOneWidget);
    expect(find.text('কোম্পানি হিসাব'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales account summary calculates and saves manual deductions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final apiService = _ProductApiService()
      ..products.add({'id': 1, 'name': 'Rice'})
      ..salesSheetData = {
        'sheet': {'id': 1},
        'rows': [
          {
            'id': 9,
            'serial_no': 1,
            'name': 'Rice',
            'address': 'Road',
            'date': date,
            'neoya': 1000,
            'perot': 0,
            'dor': 50,
            'taka': 50000,
            'damage': 0,
          },
        ],
      };

    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          initialDate: now,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(7));
    await tester.enterText(fields.at(4), '1000');
    await tester.enterText(fields.at(5), '500');
    await tester.enterText(fields.at(6), '200');
    await tester.pumpAndSettle();
    expect(find.text('অবশিষ্ট টাকা'), findsOneWidget);
    expect(find.text('48300'), findsOneWidget);

    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();
    expect(apiService.salesSummaryRows.single['discount'], 1000);
    expect(apiService.salesSummaryRows.single['damage'], 500);
    expect(apiService.salesSummaryRows.single['other_expense'], 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a saved sales row enables changing its return amount', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final apiService = _ProductApiService()
      ..products.add({'id': 1, 'name': 'Rice'})
      ..salesSheetData = {
        'sheet': {'id': 1},
        'rows': [
          {
            'id': 9,
            'serial_no': 1,
            'name': 'Rice',
            'address': 'Road',
            'date': date,
            'neoya': 10,
            'perot': 2,
            'dor': 5,
            'taka': 40,
            'damage': 1,
          },
        ],
      };
    await tester.pumpWidget(
      MaterialApp(
        home: SalesSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: now.month,
          year: now.year,
          initialDate: now,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('সম্পাদনা'));
    await tester.pumpAndSettle();
    final returnField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.controller?.text == '2' &&
          widget.enabled == true,
    );
    expect(returnField, findsOneWidget);
    await tester.enterText(returnField, '4');
    await tester.pumpAndSettle();
    expect(find.text('6'), findsNWidgets(2));
    expect(find.text('30'), findsNWidgets(3));

    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();
    expect(apiService.savedRows.single['perot'], 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock product dialog fits narrow screen with keyboard open', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = _ProductApiService()
      ..products.add({
        'id': 1,
        'name': 'A very long product name that needs to be truncated',
      });
    final currentDate = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          apiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('মেনু'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('পণ্য যোগ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'নতুন পণ্য');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
  });

  testWidgets(
    'stock product list shows inventory and one latest-update PDF action',
    (WidgetTester tester) async {
      final apiService = _ProductApiService()
        ..stockProductRows.add({
          'name': 'Oil',
          'date': '2026-10-12',
          'stock': '25.00',
          'total': '250.00',
          'price': '10.00',
          'selling_price': '15.00',
          'latest_update_date': '2026-10-12',
        });

      await tester.pumpWidget(
        MaterialApp(
          home: StockProductListPage(
            initialCompanyId: 7,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('স্টক পণ্যের তালিকা'), findsOneWidget);
      expect(find.text('Test company'), findsOneWidget);
      expect(find.text('ক্রমিক নং'), findsOneWidget);
      expect(find.text('স্টকের পরিমাণ'), findsOneWidget);
      expect(find.text('Oil'), findsOneWidget);
      expect(find.text('2026-10-12'), findsOneWidget);

      await tester.tap(find.byTooltip('PDF মেনু'));
      await tester.pumpAndSettle();
      expect(find.text('সর্বশেষ আপডেটের PDF ডাউনলোড'), findsOneWidget);
      expect(find.text('বর্তমান ডেটার PDF ডাউনলোড'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('row count rejects values above 100', (
    WidgetTester tester,
  ) async {
    final currentDate = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: StockSheetPage(
          company: {'id': 7, 'name': 'Test company'},
          month: currentDate.month,
          year: currentDate.year,
          apiService: _ProductApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন সারি'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '101');
    await tester.tap(find.text('যোগ করুন'));
    await tester.pumpAndSettle();

    expect(find.text('১ থেকে ১০০-এর মধ্যে সারির সংখ্যা দিন।'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
