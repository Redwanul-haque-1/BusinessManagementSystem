import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/sheet_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = SheetPdfService();
  final selectedDate = DateTime(2026, 5, 2);

  final rows = <Map<String, dynamic>>[
    {
      'date': '2026-05-02',
      'name': 'চাল',
      'neoya': 10,
      'perot': 2,
      'bikroy': 8,
      'dor': 4,
      'taka': 32,
      'damage': 1,
      'stock': 3,
      'price': 10,
      'total': 30,
    },
    {
      'date': '2026-05-02T12:30:00',
      'name': 'ডাল',
      'neoya': 5,
      'perot': 1,
      'dor': 2,
      'damage': 2,
      'stock': 2,
      'price': 7.5,
    },
    {
      'date': '2026-05-03',
      'name': 'তেল',
      'neoya': 1,
      'perot': 0,
      'dor': 10,
      'damage': 0,
      'stock': 1,
      'price': 20,
    },
    {
      'date': null,
      'name': 'পুরনো রেকর্ড',
      'neoya': 0,
      'perot': 0,
      'dor': 0,
      'damage': 0,
      'stock': 4,
      'price': 2,
    },
    {
      'date': '2026-06-02',
      'name': 'ভিন্ন মাস',
      'neoya': 0,
      'perot': 0,
      'dor': 0,
      'damage': 0,
      'stock': 4,
      'price': 2,
    },
  ];

  test('daily and monthly reports filter the expected dates', () {
    final dailyRows = service.filterRows(
      rows,
      range: PdfReportRange.daily,
      selectedDate: selectedDate,
    );
    final monthlyRows = service.filterRows(
      rows,
      range: PdfReportRange.monthly,
      selectedDate: selectedDate,
    );

    expect(dailyRows.map((row) => row['name']), ['চাল', 'ডাল']);
    expect(monthlyRows.map((row) => row['name']), [
      'চাল',
      'ডাল',
      'তেল',
      'পুরনো রেকর্ড',
    ]);
  });

  test('sales and stock totals use persisted values and calculation rules', () {
    final salesTotals = service.calculateSalesTotals(rows.take(2).toList());
    final stockTotals = service.calculateStockTotals(rows.take(2).toList());

    expect(salesTotals, {
      'neoya': 15,
      'perot': 3,
      'bikroy': 12,
      'taka': 40,
      'damage': 3,
    });
    expect(stockTotals, {'stock': 5, 'total': 45});
    expect(service.calculateStockTotals(rows.take(2).toList()), {
      'stock': 5,
      'total': 45,
    });
  });

  test('stock product list PDF includes the latest update date', () async {
    final products = [
      {
        'date': '2026-05-02',
        'name': 'তেল',
        'stock': 25,
        'total': 250,
        'price': 10,
        'selling_price': 15,
      },
    ];
    final latest = await service.createStockProductListPdf(
      company: {'name': 'বাংলা কোম্পানি'},
      rows: products,
      latestUpdateDate: '2026-05-02',
    );

    expect(
      latin1.decode(latest, allowInvalid: true).startsWith('%PDF-'),
      isTrue,
    );
  });

  test(
    'Bengali stock PDF embeds the Bengali font and paginates 1000+ rows',
    () async {
      final salesBytes = await service.createSalesPdf(
        company: {'name': 'বাংলা কোম্পানি', 'address': 'ফেনী'},
        monthName: 'মে',
        year: 2026,
        selectedDate: selectedDate,
        range: PdfReportRange.daily,
        rows: rows.take(2).toList(),
        summaryRows: [
          {
            'date': '2026-05-02',
            'money': 50000,
            'discount': 1000,
            'damage': 500,
            'other_expense': 200,
            'remaining': 48300,
          },
        ],
      );
      final salesPdf = latin1.decode(salesBytes, allowInvalid: true);
      expect(salesPdf.startsWith('%PDF-'), isTrue);
      expect(salesPdf, contains('/Subtype/Image'));

      final largeRows = List<Map<String, dynamic>>.generate(
        1001,
        (index) => {
          'date': '2026-05-02',
          'serial_no': index + 1,
          'name': 'পণ্য ${index + 1}',
          'stock': 2,
          'price': 15,
          'total': 30,
        },
      );

      final bytes = await service.createStockPdf(
        company: {'name': 'বাংলা কোম্পানি', 'address': 'ফেনী'},
        monthName: 'মে',
        year: 2026,
        selectedDate: selectedDate,
        range: PdfReportRange.monthly,
        rows: largeRows,
      );
      final pdf = latin1.decode(bytes, allowInvalid: true);
      final pageCount = RegExp(r'/Type\s*/Page(?!s)\b').allMatches(pdf).length;

      expect(pdf.startsWith('%PDF-'), isTrue);
      expect(pdf, contains('/FontFile2'));
      expect(pageCount, greaterThan(20));
    },
  );
}
