import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum PdfReportRange { daily, monthly }

class SheetPdfService {
  static const String _fontAsset = 'assets/fonts/NotoSansBengali.ttf';
  static const String _rasterFontFamily = 'BmsPdfBengali';
  static const double _rasterScale = 3;
  static Future<void>? _fontRegistration;

  List<Map<String, dynamic>> filterRows(
    List<Map<String, dynamic>> rows, {
    required PdfReportRange range,
    required DateTime selectedDate,
  }) {
    return rows.where((row) {
      final date = DateTime.tryParse(row['date']?.toString() ?? '');
      if (date == null) {
        return range == PdfReportRange.monthly;
      }

      if (range == PdfReportRange.monthly) {
        return date.year == selectedDate.year &&
            date.month == selectedDate.month;
      }

      return date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
    }).toList();
  }

  Map<String, double> calculateSalesTotals(List<Map<String, dynamic>> rows) {
    var neoya = 0.0;
    var perot = 0.0;
    var bikroy = 0.0;
    var taka = 0.0;
    var damage = 0.0;

    for (final row in rows) {
      final rowNeoya = _toDouble(row['neoya']);
      final rowPerot = _toDouble(row['perot']);
      final rowBikroy = row['bikroy'] == null
          ? _money(rowNeoya - rowPerot)
          : _toDouble(row['bikroy']);
      final rowDor = _toDouble(row['dor']);

      neoya += rowNeoya;
      perot += rowPerot;
      bikroy += rowBikroy;
      taka += row['taka'] == null
          ? _money(rowBikroy * rowDor)
          : _toDouble(row['taka']);
      damage += _toDouble(row['damage']);
    }

    return {
      'neoya': _money(neoya),
      'perot': _money(perot),
      'bikroy': _money(bikroy),
      'taka': _money(taka),
      'damage': _money(damage),
    };
  }

  Map<String, double> calculateStockTotals(List<Map<String, dynamic>> rows) {
    var stock = 0.0;
    var total = 0.0;

    for (final row in rows) {
      final rowStock = _toDouble(row['stock']);
      stock += rowStock;
      total += row['total'] == null
          ? rowStock * _toDouble(row['price'])
          : _toDouble(row['total']);
    }

    return {'stock': _money(stock), 'total': _money(total)};
  }

  Future<Uint8List> createSalesPdf({
    required Map<String, dynamic> company,
    required String monthName,
    required int year,
    required DateTime selectedDate,
    required PdfReportRange range,
    required List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> summaryRows = const [],
  }) async {
    final font = await _loadFont();
    final totals = calculateSalesTotals(rows);
    final reportPeriod =
        _periodLabel(
          range: range,
          monthName: monthName,
          year: year,
          selectedDate: selectedDate,
        ) +
        _roadAddressLabel(rows);
    final tableRows = <List<dynamic>>[
      [
        'ক্রমিক',
        'তারিখ',
        'নাম',
        'নেওয়া',
        'দর',
        'ফেরত',
        'বিক্রয়',
        'টাকা',
        'ড্যামেজ',
      ],
      for (var index = 0; index < rows.length; index++)
        _salesRow(rows[index], index + 1),
      [
        '',
        '',
        'মোট',
        _formatNumber(totals['neoya']!),
        '',
        _formatNumber(totals['perot']!),
        _formatNumber(totals['bikroy']!),
        _formatNumber(totals['taka']!),
        _formatNumber(totals['damage']!),
      ],
    ];
    final summaryTableRows = <List<dynamic>>[
      ['তারিখ', 'টাকা', 'ছাড়', 'ড্যামেজ', 'অন্যান্য খরচ', 'অবশিষ্ট টাকা'],
      for (final row in summaryRows)
        [
          _formatDate(row['date']),
          _formatNumber(_toDouble(row['money'])),
          _formatNumber(_toDouble(row['discount'])),
          _formatNumber(_toDouble(row['damage'])),
          _formatNumber(_toDouble(row['other_expense'])),
          _formatNumber(_toDouble(row['remaining'])),
        ],
      if (summaryRows.length > 1)
        [
          'মোট',
          _formatNumber(
            summaryRows.fold<double>(
              0,
              (sum, row) => sum + _toDouble(row['money']),
            ),
          ),
          _formatNumber(
            summaryRows.fold<double>(
              0,
              (sum, row) => sum + _toDouble(row['discount']),
            ),
          ),
          _formatNumber(
            summaryRows.fold<double>(
              0,
              (sum, row) => sum + _toDouble(row['damage']),
            ),
          ),
          _formatNumber(
            summaryRows.fold<double>(
              0,
              (sum, row) => sum + _toDouble(row['other_expense']),
            ),
          ),
          _formatNumber(
            summaryRows.fold<double>(
              0,
              (sum, row) => sum + _toDouble(row['remaining']),
            ),
          ),
        ],
    ];

    return _createPdf(
      font: font,
      company: company,
      title: 'বিক্রয় হিসাব',
      reportPeriod: reportPeriod,
      rows: rows,
      columnWidths: {
        0: const pw.FixedColumnWidth(38),
        1: const pw.FixedColumnWidth(67),
        2: const pw.FlexColumnWidth(1.3),
        3: const pw.FixedColumnWidth(55),
        4: const pw.FixedColumnWidth(55),
        5: const pw.FixedColumnWidth(55),
        6: const pw.FixedColumnWidth(58),
        7: const pw.FixedColumnWidth(62),
        8: const pw.FixedColumnWidth(55),
      },
      tableRows: tableRows,
      additionalTableRows: summaryRows.isEmpty ? const [] : summaryTableRows,
      additionalTableTitle: 'হিসাব সারাংশ',
      additionalColumnWidths: {
        0: const pw.FixedColumnWidth(72),
        1: const pw.FixedColumnWidth(82),
        2: const pw.FixedColumnWidth(82),
        3: const pw.FixedColumnWidth(82),
        4: const pw.FixedColumnWidth(112),
        5: const pw.FixedColumnWidth(100),
      },
    );
  }

  Future<Uint8List> createStockPdf({
    required Map<String, dynamic> company,
    required String monthName,
    required int year,
    required DateTime selectedDate,
    required PdfReportRange range,
    required List<Map<String, dynamic>> rows,
  }) async {
    final font = await _loadFont();
    final totals = calculateStockTotals(rows);
    final reportPeriod = _periodLabel(
      range: range,
      monthName: monthName,
      year: year,
      selectedDate: selectedDate,
    );
    final tableRows = <List<dynamic>>[
      [
        'ক্রমিক',
        'তারিখ',
        'পণ্যের নাম',
        'স্টক',
        'ক্রয় মূল্য',
        'বিক্রয় মূল্য',
        'স্টকের মূল্য',
      ],
      for (var index = 0; index < rows.length; index++)
        _stockRow(rows[index], index + 1),
      [
        '',
        '',
        'মোট',
        _formatNumber(totals['stock']!),
        '',
        '',
        _formatNumber(totals['total']!),
      ],
    ];

    return _createPdf(
      font: font,
      company: company,
      title: 'স্টক হিসাব',
      reportPeriod: reportPeriod,
      rows: rows,
      columnWidths: {
        0: const pw.FixedColumnWidth(48),
        1: const pw.FixedColumnWidth(80),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(90),
        4: const pw.FixedColumnWidth(95),
        5: const pw.FixedColumnWidth(95),
        6: const pw.FixedColumnWidth(120),
      },
      tableRows: tableRows,
    );
  }

  Future<Uint8List> createStockProductListPdf({
    required Map<String, dynamic> company,
    required List<Map<String, dynamic>> rows,
    required String latestUpdateDate,
  }) async {
    final tableRows = <List<dynamic>>[
      [
        'ক্রমিক নং',
        'তারিখ',
        'পণ্যের নাম',
        'স্টকের পরিমাণ',
        'স্টকের মূল্য',
        'ক্রয় মূল্য',
        'বিক্রয় মূল্য',
      ],
      for (var index = 0; index < rows.length; index++)
        [
          '${index + 1}',
          _formatDate(rows[index]['date']),
          rows[index]['name']?.toString() ?? '',
          _formatNumber(_toDouble(rows[index]['stock'])),
          _formatNumber(_toDouble(rows[index]['total'])),
          _formatNumber(_toDouble(rows[index]['price'])),
          _formatNumber(
            _toDouble(rows[index]['selling_price'] ?? rows[index]['price']),
          ),
        ],
    ];
    final dateLabel = 'সর্বশেষ আপডেটের তারিখ: ${_formatDate(latestUpdateDate)}';

    return _createPdf(
      font: await _loadFont(),
      company: company,
      title: 'স্টক পণ্যের তালিকা',
      reportPeriod: dateLabel,
      rows: rows,
      columnWidths: {
        0: const pw.FixedColumnWidth(55),
        1: const pw.FixedColumnWidth(80),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(90),
        4: const pw.FixedColumnWidth(100),
        5: const pw.FixedColumnWidth(90),
        6: const pw.FixedColumnWidth(90),
      },
      tableRows: tableRows,
      boldLastRow: false,
    );
  }

  Future<pw.Font> _loadFont() async {
    final fontData = await rootBundle.load(_fontAsset);
    return pw.Font.ttf(fontData);
  }

  Future<Uint8List> _createPdf({
    required pw.Font font,
    required Map<String, dynamic> company,
    required String title,
    required String reportPeriod,
    required List<Map<String, dynamic>> rows,
    required Map<int, pw.TableColumnWidth> columnWidths,
    required List<List<dynamic>> tableRows,
    List<List<dynamic>> additionalTableRows = const [],
    Map<int, pw.TableColumnWidth>? additionalColumnWidths,
    String? additionalTableTitle,
    bool boldLastRow = true,
  }) async {
    await _ensureRasterFont();
    final shapedRows = <List<dynamic>>[];
    for (var rowIndex = 0; rowIndex < tableRows.length; rowIndex++) {
      final row = <dynamic>[];
      for (final cell in tableRows[rowIndex]) {
        final isBold =
            rowIndex == 0 || (boldLastRow && rowIndex == tableRows.length - 1);
        row.add(
          await _textWidget(
            cell.toString(),
            fontSize: rowIndex == 0 ? 8 : 7,
            bold: isBold,
          ),
        );
      }
      shapedRows.add(row);
    }
    final additionalShapedRows = <List<dynamic>>[];
    for (var rowIndex = 0; rowIndex < additionalTableRows.length; rowIndex++) {
      final row = <dynamic>[];
      for (final cell in additionalTableRows[rowIndex]) {
        final isBold =
            rowIndex == 0 ||
            (boldLastRow && rowIndex == additionalTableRows.length - 1);
        row.add(
          await _textWidget(
            cell.toString(),
            fontSize: rowIndex == 0 ? 8 : 7,
            bold: isBold,
          ),
        );
      }
      additionalShapedRows.add(row);
    }

    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final companyName = company['name']?.toString() ?? 'কোম্পানি';
    final companyAddress = company['address']?.toString().trim() ?? '';
    final companyPhone = company['phone']?.toString().trim() ?? '';
    final companyDetails = [
      if (companyAddress.isNotEmpty) companyAddress,
      if (companyPhone.isNotEmpty) companyPhone,
    ].join('    ');
    final titleWidget = await _textWidget(title, fontSize: 17, bold: true);
    final companyWidget = await _textWidget(
      companyName,
      fontSize: 12,
      bold: true,
    );
    final detailsWidget = companyDetails.isEmpty
        ? null
        : await _textWidget(companyDetails, fontSize: 9);
    final periodWidget = await _textWidget(reportPeriod, fontSize: 10);
    final pageLabelWidget = await _textWidget('পৃষ্ঠা ', fontSize: 8);
    final additionalTitleWidget = additionalTableTitle == null
        ? null
        : await _textWidget(additionalTableTitle, fontSize: 10, bold: true);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: rows.length + additionalTableRows.length + 5,
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              titleWidget,
              pw.SizedBox(height: 4),
              companyWidget,
              detailsWidget ?? pw.SizedBox(),
              periodWidget,
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pageLabelWidget,
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            context: context,
            data: shapedRows,
            columnWidths: columnWidths,
            headerCount: 1,
            headerStyle: pw.TextStyle(font: font, fontSize: 8),
            cellStyle: pw.TextStyle(font: font, fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 5,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xffe5e7eb),
            ),
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xff9ca3af),
              width: 0.5,
            ),
          ),
          if (additionalShapedRows.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            additionalTitleWidget!,
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              context: context,
              data: additionalShapedRows,
              columnWidths: additionalColumnWidths,
              headerCount: 1,
              headerStyle: pw.TextStyle(font: font, fontSize: 8),
              cellStyle: pw.TextStyle(font: font, fontSize: 7),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 5,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xffe5e7eb),
              ),
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xff9ca3af),
                width: 0.5,
              ),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  Future<void> _ensureRasterFont() {
    return _fontRegistration ??= () async {
      final fontData = await rootBundle.load(_fontAsset);
      final loader = FontLoader(_rasterFontFamily)
        ..addFont(Future<ByteData>.value(fontData));
      await loader.load();
    }();
  }

  Future<pw.Widget> _textWidget(
    String text, {
    required double fontSize,
    bool bold = false,
  }) async {
    if (!_containsBengali(text)) {
      return pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );
    }

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _rasterFontFamily,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: const Color(0xff000000),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final width = painter.width.ceilToDouble().clamp(1.0, double.infinity);
    final height = painter.height.ceilToDouble().clamp(1.0, double.infinity);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(_rasterScale, _rasterScale);
    painter.paint(canvas, ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * _rasterScale).ceil(),
      (height * _rasterScale).ceil(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (png == null) {
      throw StateError('বাংলা PDF লেখা রেন্ডার করা যায়নি।');
    }

    return pw.Image(
      pw.MemoryImage(png.buffer.asUint8List()),
      width: width,
      height: height,
      fit: pw.BoxFit.contain,
    );
  }

  bool _containsBengali(String text) {
    return text.runes.any((rune) => rune >= 0x0980 && rune <= 0x09ff);
  }

  List<String> _salesRow(Map<String, dynamic> row, int serial) {
    final neoya = _toDouble(row['neoya']);
    final perot = _toDouble(row['perot']);
    final bikroy = row['bikroy'] == null
        ? _money(neoya - perot)
        : _toDouble(row['bikroy']);
    final dor = _toDouble(row['dor']);
    final taka = row['taka'] == null
        ? _money(bikroy * dor)
        : _toDouble(row['taka']);

    return [
      '${row['serial_no'] ?? serial}',
      _formatDate(row['date']),
      row['name']?.toString() ?? '',
      _formatNumber(neoya),
      _formatNumber(dor),
      _formatNumber(perot),
      _formatNumber(bikroy),
      _formatNumber(taka),
      _formatNumber(_toDouble(row['damage'])),
    ];
  }

  List<String> _stockRow(Map<String, dynamic> row, int serial) {
    final stock = _toDouble(row['stock']);
    final price = _toDouble(row['price']);
    final sellingPrice = _toDouble(row['selling_price'] ?? row['price']);
    final total = row['total'] == null
        ? stock * price
        : _toDouble(row['total']);
    return [
      '${row['serial_no'] ?? serial}',
      _formatDate(row['date']),
      row['name']?.toString() ?? '',
      _formatNumber(stock),
      _formatNumber(price),
      _formatNumber(sellingPrice),
      _formatNumber(total),
    ];
  }

  String _periodLabel({
    required PdfReportRange range,
    required String monthName,
    required int year,
    required DateTime selectedDate,
  }) {
    if (range == PdfReportRange.daily) {
      return 'দৈনিক হিসাব: ${_formatDate(selectedDate)}';
    }
    return 'মাসিক হিসাব: $monthName $year';
  }

  String _roadAddressLabel(List<Map<String, dynamic>> rows) {
    final addresses = rows
        .map((row) => row['address']?.toString().trim() ?? '')
        .where((address) => address.isNotEmpty)
        .toSet();
    if (addresses.isEmpty) {
      return '';
    }
    return '\nরোড/ঠিকানা: ${addresses.join(', ')}';
  }

  String _formatDate(dynamic value) {
    final date = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    if (date == null) {
      return '';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
  }

  double _money(double value) => double.parse(value.toStringAsFixed(2));

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}
