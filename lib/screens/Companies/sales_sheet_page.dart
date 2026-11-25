import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/sheet_pdf_actions.dart';
import '../../services/sheet_pdf_service.dart';
import 'row_count_dialog.dart';

class SalesSheetPage extends StatefulWidget {
  final Map<String, dynamic> company;
  final int month;
  final int year;
  final DateTime? initialDate;
  final ApiService? apiService;

  const SalesSheetPage({
    super.key,
    required this.company,
    required this.month,
    required this.year,
    this.initialDate,
    this.apiService,
  });

  @override
  State<SalesSheetPage> createState() => _SalesSheetPageState();
}

class _SalesSheetPageState extends State<SalesSheetPage> {
  late final ApiService apiService = widget.apiService ?? ApiService();

  final List<String> monthNames = const [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];

  final List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> monthlyRows = [];
  List<Map<String, dynamic>> monthlySummaryRows = [];
  final SheetPdfService _pdfService = SheetPdfService();
  final discountController = TextEditingController();
  final summaryDamageController = TextEditingController();
  final otherExpenseController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool isDirty = false;
  bool summaryIsEditing = true;
  String errorMessage = '';
  int? salesSheetId;
  late DateTime selectedDate;
  List<String> productNames = [];
  Map<String, double> productSellingPrices = {};
  String selectedRoadAddress = '';

  String sheetTitle = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate =
        widget.initialDate?.year == widget.year &&
            widget.initialDate?.month == widget.month
        ? DateTime(
            widget.initialDate!.year,
            widget.initialDate!.month,
            widget.initialDate!.day,
          )
        : now.year == widget.year && now.month == widget.month
        ? DateTime(now.year, now.month, now.day)
        : DateTime(widget.year, widget.month);
    for (final controller in [
      discountController,
      summaryDamageController,
      otherExpenseController,
    ]) {
      controller.addListener(_rebuild);
    }
    loadSalesSheet();
  }

  @override
  void dispose() {
    for (final row in rows) {
      _disposeRow(row);
    }
    discountController.dispose();
    summaryDamageController.dispose();
    otherExpenseController.dispose();

    super.dispose();
  }

  void _disposeRow(Map<String, dynamic> row) {
    (row['nameController'] as TextEditingController).dispose();
    (row['neoyaController'] as TextEditingController).dispose();
    (row['perotController'] as TextEditingController).dispose();
    (row['dorController'] as TextEditingController).dispose();
    (row['damageController'] as TextEditingController).dispose();
  }

  String get companyName {
    return widget.company['name']?.toString() ?? 'কোম্পানি';
  }

  String get monthName {
    return monthNames[widget.month - 1];
  }

  String get selectedDateLabel {
    return 'তারিখ: ${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
  }

  Future<void> loadSalesSheet() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      monthlyRows = [];
      monthlySummaryRows = [];
    });

    try {
      final sheetFuture = apiService.getSalesSheet(
        companyId: _companyId,
        month: widget.month,
        year: widget.year,
      );
      final productsFuture = apiService.getCompanyProducts(
        companyId: _companyId,
      );
      final stockFuture = apiService.getStockSheet(
        companyId: _companyId,
        month: widget.month,
        year: widget.year,
      );
      final stockProductsFuture = apiService.getStockProductList(
        companyId: _companyId,
      );
      final salesSummaryFuture = apiService.getSalesSummaryRows(
        companyId: _companyId,
        month: widget.month,
        year: widget.year,
      );
      final results = await Future.wait([
        sheetFuture,
        productsFuture,
        stockFuture,
        stockProductsFuture,
        salesSummaryFuture,
      ]);
      final data = results[0] as Map<String, dynamic>;
      final products = results[1] as List<dynamic>;
      final stockData = results[2] as Map<String, dynamic>;
      final stockProducts = results[3] as List<Map<String, dynamic>>;
      final savedSummaries = (results[4] as List).cast<Map<String, dynamic>>();

      final loadedRows = _extractRows(data);

      if (!mounted) {
        return;
      }

      monthlyRows = loadedRows;
      monthlySummaryRows = savedSummaries;

      for (final row in rows) {
        _disposeRow(row);
      }

      rows.clear();
      isDirty = false;
      productNames = products
          .map((product) => product['name'].toString())
          .toList();
      final stockRows = (stockData['rows'] as List? ?? []).whereType<Map>().map(
        (item) => Map<String, dynamic>.from(item),
      );
      productSellingPrices = {
        for (final stockRow in stockRows)
          stockRow['name'].toString(): _toDouble(
            stockRow['selling_price'] ?? stockRow['price'],
          ),
      };
      for (final stockProduct in stockProducts) {
        productSellingPrices[stockProduct['name'].toString()] = _toDouble(
          stockProduct['selling_price'] ?? stockProduct['price'],
        );
      }
      final sheet = _extractSheet(data);
      salesSheetId = _toInt(sheet['id']);

      sheetTitle = sheet['title']?.toString() ?? '';

      final rowsForDay = loadedRows.where((row) {
        final rowDate = DateTime.tryParse(row['date']?.toString() ?? '');
        return rowDate != null &&
            rowDate.year == selectedDate.year &&
            rowDate.month == selectedDate.month &&
            rowDate.day == selectedDate.day;
      }).toList();
      selectedRoadAddress = rowsForDay
          .map((row) => row['address']?.toString().trim() ?? '')
          .firstWhere((address) => address.isNotEmpty, orElse: () => '');
      Map<String, dynamic>? selectedSummary;
      for (final summary in savedSummaries) {
        if (summary['date']?.toString() == _dateApiValue) {
          selectedSummary = summary;
          break;
        }
      }
      discountController.text = _decimalText(selectedSummary?['discount']);
      summaryDamageController.text = _decimalText(selectedSummary?['damage']);
      otherExpenseController.text = _decimalText(
        selectedSummary?['other_expense'],
      );
      summaryIsEditing = selectedSummary == null;

      if (rowsForDay.isEmpty) {
        _addRow();
      } else {
        for (var index = 0; index < rowsForDay.length; index++) {
          final source = rowsForDay[index];

          _addRow(
            initial: source,
            serialNo:
                _toInt(source['serial_no'] ?? source['serialNo']) ?? index + 1,
          );
        }
      }

      setState(() {
        isDirty = false;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int get _companyId {
    final value = widget.company['id'];

    if (value is int) {
      return value;
    }
    return int.parse(value.toString());
  }

  Future<void> _downloadPdf() async {
    final range = await choosePdfReportRange(context);
    if (range == null || !mounted) {
      return;
    }

    final reportRows = _pdfService.filterRows(
      monthlyRows,
      range: range,
      selectedDate: selectedDate,
    );
    if (range == PdfReportRange.daily && reportRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('এই তারিখের কোনো সংরক্ষিত হিসাব নেই।')),
      );
      return;
    }

    final reportSummaries = monthlySummaryRows
        .where((summary) {
          final summaryDate = DateTime.tryParse(
            summary['date']?.toString() ?? '',
          );
          if (summaryDate == null) return false;
          return range == PdfReportRange.monthly
              ? summaryDate.year == selectedDate.year &&
                    summaryDate.month == selectedDate.month
              : summaryDate.year == selectedDate.year &&
                    summaryDate.month == selectedDate.month &&
                    summaryDate.day == selectedDate.day;
        })
        .map((summary) {
          final summaryDate = summary['date']?.toString();
          final dayMoney = reportRows
              .where((row) => row['date']?.toString() == summaryDate)
              .fold<double>(0, (sum, row) => sum + _toDouble(row['taka']));
          final discount = _toDouble(summary['discount']);
          final damage = _toDouble(summary['damage']);
          final otherExpense = _toDouble(summary['other_expense']);
          return {
            ...summary,
            'money': dayMoney,
            'remaining': dayMoney - discount - damage - otherExpense,
          };
        })
        .toList();

    try {
      final bytes = await _pdfService.createSalesPdf(
        company: widget.company,
        monthName: monthName,
        year: widget.year,
        selectedDate: selectedDate,
        range: range,
        rows: reportRows,
        summaryRows: reportSummaries,
      );
      final reportDate =
          '${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}'
          '${range == PdfReportRange.daily ? '_${selectedDate.day.toString().padLeft(2, '0')}' : ''}';
      final fileName = 'sales_${_companyId}_$reportDate';
      final savedPath = await savePdfToDownloads(name: fileName, bytes: bytes);
      if (!mounted) {
        return;
      }
      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF সংরক্ষণ করা হয়নি।')));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF ডাউনলোড হয়েছে।'),
          action: SnackBarAction(
            label: 'শেয়ার',
            onPressed: () {
              sharePdf(name: fileName, bytes: bytes);
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF তৈরি বা সংরক্ষণ করা যায়নি: $error')),
      );
    }
  }

  Map<String, dynamic> _extractSheet(Map<String, dynamic> data) {
    final candidates = [data['sales_sheet'], data['salesSheet'], data['sheet']];

    for (final candidate in candidates) {
      if (candidate is Map) {
        return Map<String, dynamic>.from(candidate);
      }
    }

    return data;
  }

  List<Map<String, dynamic>> _extractRows(Map<String, dynamic> data) {
    final sheet = _extractSheet(data);

    final candidates = [sheet['rows'], data['rows']];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    return [];
  }

  void _addRow({Map<String, dynamic>? initial, int? serialNo}) {
    final neoyaController = TextEditingController(
      text: _decimalText(initial?['neoya']),
    );
    final perotController = TextEditingController(
      text: _decimalText(initial?['perot']),
    );
    final dorController = TextEditingController(
      text: _decimalText(initial?['dor']),
    );
    final row = <String, dynamic>{
      'id': initial?['id'],
      'serialNo': serialNo ?? rows.length + 1,
      'isLocked': initial != null,
      'nameController': TextEditingController(
        text: initial?['name']?.toString() ?? '',
      ),
      'neoyaController': neoyaController,
      'perotController': perotController,
      'dorController': dorController,
      'damageController': TextEditingController(
        text: _decimalText(initial?['damage']),
      ),
    };

    final controllers = [
      row['nameController'] as TextEditingController,
      row['damageController'] as TextEditingController,
    ];

    for (final controller in controllers) {
      controller.addListener(_rebuild);
    }

    for (final controller in [
      neoyaController,
      perotController,
      dorController,
    ]) {
      controller.addListener(_rebuild);
    }

    rows.add(row);
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
    isDirty = true;
  }

  void _removeRow(int index) {
    if (rows.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অন্তত একটি সারি রাখতে হবে।')),
      );
      return;
    }

    _disposeRow(rows[index]);
    isDirty = true;

    setState(() {
      rows.removeAt(index);

      for (var i = 0; i < rows.length; i++) {
        rows[i]['serialNo'] = i + 1;
      }
    });
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;
  }

  double _bikroy(Map<String, dynamic> row) {
    final neoya = _number(row['neoyaController'] as TextEditingController);

    final perot = _number(row['perotController'] as TextEditingController);

    final result = neoya - perot;

    return result < 0 ? 0 : result;
  }

  double _taka(Map<String, dynamic> row) {
    final amount =
        _bikroy(row) * _number(row['dorController'] as TextEditingController);
    return double.parse(amount.toStringAsFixed(2));
  }

  double get totalNeoya {
    return rows.fold(
      0,
      (sum, row) =>
          sum + _number(row['neoyaController'] as TextEditingController),
    );
  }

  double get totalPerot {
    return rows.fold(
      0,
      (sum, row) =>
          sum + _number(row['perotController'] as TextEditingController),
    );
  }

  double get totalBikroy {
    return rows.fold(0, (sum, row) => sum + _bikroy(row));
  }

  double get totalTaka {
    return rows.fold(0, (sum, row) => sum + _taka(row));
  }

  double get totalDamage {
    return rows.fold(
      0,
      (sum, row) =>
          sum + _number(row['damageController'] as TextEditingController),
    );
  }

  double get remainingSummaryMoney =>
      totalTaka -
      _number(discountController) -
      _number(summaryDamageController) -
      _number(otherExpenseController);

  Future<void> saveSheet() async {
    if (selectedRoadAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('এই দিনের জন্য রোড/ঠিকানা যোগ করুন।')),
      );
      return;
    }

    final preparedRows = <Map<String, dynamic>>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      final nameController = row['nameController'] as TextEditingController;

      final neoyaController = row['neoyaController'] as TextEditingController;

      final perotController = row['perotController'] as TextEditingController;

      final dorController = row['dorController'] as TextEditingController;

      final damageController = row['damageController'] as TextEditingController;

      final name = nameController.text.trim();
      final neoya = _number(neoyaController);
      final perot = _number(perotController);
      final dor = _number(dorController);
      final damage = _number(damageController);

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সারি ${i + 1}-এ নাম দিতে হবে।')),
        );
        return;
      }

      if (perot > neoya) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ফেরত নেওয়ার চেয়ে বেশি হতে পারে না।')),
        );
        return;
      }

      preparedRows.add({
        'serial_no': i + 1,
        'name': name,
        'address': selectedRoadAddress,
        'neoya': neoya,
        'perot': perot,
        'dor': dor,
        'damage': damage,
      });
    }

    for (final controller in [
      discountController,
      summaryDamageController,
      otherExpenseController,
    ]) {
      final value = controller.text.trim();
      if (value.isNotEmpty &&
          double.tryParse(value.replaceAll(',', '')) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('হিসাব সারাংশে সঠিক সংখ্যা লিখুন।')),
        );
        return;
      }
    }

    setState(() {
      isSaving = true;
    });

    try {
      if (salesSheetId == null) {
        final result = await apiService.saveSalesSheet(
          companyId: _companyId,
          month: widget.month,
          year: widget.year,
          selectedDate: _dateApiValue,
          title: sheetTitle.isEmpty ? null : sheetTitle,
          rows: preparedRows,
        );

        final savedSheet = _extractSheet(result);
        salesSheetId = _toInt(savedSheet['id']);
      } else {
        await apiService.updateSalesSheet(
          companyId: _companyId,
          salesSheetId: salesSheetId!,
          month: widget.month,
          year: widget.year,
          selectedDate: _dateApiValue,
          title: sheetTitle.isEmpty ? null : sheetTitle,
          rows: preparedRows,
        );
      }

      await apiService.saveSalesSummary(
        companyId: _companyId,
        month: widget.month,
        year: widget.year,
        date: _dateApiValue,
        discount: _number(discountController),
        damage: _number(summaryDamageController),
        otherExpense: _number(otherExpenseController),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বিক্রয় হিসাব সফলভাবে সংরক্ষণ হয়েছে।')),
      );

      await loadSalesSheet();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      if (e is OutOfStockException) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text(
              'এই পণ্যটির পর্যাপ্ত পরিমাণ স্টক নেই (Out of stock)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ঠিক আছে'),
              ),
            ],
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _numberField(
    TextEditingController controller, {
    double width = 95,
    bool enabled = true,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    );
  }

  Widget _readOnlyNumber(double value, {double width = 95}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        _formatNumber(value),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _headerCell(String text, {double width = 95}) {
    return Container(
      width: width,
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      color: Colors.white,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  String get _dateApiValue =>
      '${selectedDate.year.toString().padLeft(4, '0')}-'
      '${selectedDate.month.toString().padLeft(2, '0')}-'
      '${selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _selectDate() async {
    final firstDate = DateTime(widget.year, widget.month);
    final lastDate = DateTime(widget.year, widget.month + 1, 0);
    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'বিক্রয়ের দিন নির্বাচন করুন',
    );
    if (selected == null || !mounted || selected == selectedDate) {
      return;
    }

    final shouldChange =
        !isDirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('দিন পরিবর্তন করবেন?'),
                content: const Text(
                  'দিন পরিবর্তন করলে এই দিনের অসংরক্ষিত পরিবর্তন বাতিল হবে।',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('বাতিল'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('পরিবর্তন করুন'),
                  ),
                ],
              ),
            ) ==
            true;
    if (shouldChange != true || !mounted) {
      return;
    }

    setState(() {
      selectedDate = selected;
    });
    await loadSalesSheet();
  }

  Future<void> _addProduct() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ProductNameDialog(),
    );

    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    try {
      final product = await apiService.createCompanyProduct(
        companyId: _companyId,
        name: name,
      );
      final productName = product['name'].toString();
      if (!mounted) {
        return;
      }

      final blankRow = rows.cast<Map<String, dynamic>?>().firstWhere(
        (row) =>
            row != null &&
            (row['nameController'] as TextEditingController).text.isEmpty,
        orElse: () => null,
      );
      if (blankRow != null) {
        (blankRow['nameController'] as TextEditingController).text =
            productName;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        productNames = [...productNames, productName]..sort();
        isDirty = true;
      });
      final salePrice = productSellingPrices[productName];
      if (salePrice != null && blankRow != null) {
        (blankRow['dorController'] as TextEditingController).text =
            _formatNumber(salePrice);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _addRoadAddress() async {
    try {
      final addresses = await apiService.getCompanyAddresses(
        companyId: _companyId,
      );
      final knownAddresses = addresses
          .map((address) => address['address'].toString())
          .toList();
      if (!mounted) {
        return;
      }

      final address = await showDialog<String>(
        context: context,
        builder: (_) => _RoadAddressDialog(addresses: knownAddresses),
      );
      if (address == null || address.isEmpty || !mounted) {
        return;
      }

      var roadAddress = knownAddresses.firstWhere(
        (savedAddress) =>
            savedAddress.trim().toLowerCase() == address.toLowerCase(),
        orElse: () => '',
      );
      if (roadAddress.isEmpty) {
        final result = await apiService.createCompanyAddress(
          companyId: _companyId,
          address: address,
        );
        roadAddress = result['address'].toString();
      }
      if (!mounted) {
        return;
      }

      setState(() {
        selectedRoadAddress = roadAddress;
        isDirty = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _addRows() async {
    final count = await showRowCountDialog(context);
    if (count == null || !mounted) {
      return;
    }

    setState(() {
      for (var i = 0; i < count; i++) {
        _addRow();
      }
      isDirty = true;
    });
  }

  Widget _productField(Map<String, dynamic> row, bool enabled) {
    final controller = row['nameController'] as TextEditingController;
    final selectedValue = productNames.contains(controller.text)
        ? controller.text
        : null;

    return SizedBox(
      width: 180,
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            hint: const Text('পণ্য নির্বাচন'),
            items: productNames
                .map(
                  (name) => DropdownMenuItem<String>(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (value) {
                    if (value != null) {
                      controller.text = value;
                      if (row['id'] == null) {
                        final price = productSellingPrices[value];
                        if (price != null) {
                          (row['dorController'] as TextEditingController).text =
                              _formatNumber(price);
                        }
                      }
                    }
                  }
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _handleMenuSelection(String action) async {
    switch (action) {
      case 'date':
        await _selectDate();
        break;
      case 'pdf':
        await _downloadPdf();
        break;
      case 'product':
        await _addProduct();
        break;
      case 'address':
        await _addRoadAddress();
        break;
    }
  }

  PopupMenuButton<String> _menuButton() {
    return PopupMenuButton<String>(
      tooltip: 'মেনু',
      onSelected: _handleMenuSelection,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'date', child: Text('দিন নির্বাচন')),
        PopupMenuItem(value: 'pdf', child: Text('PDF ডাউনলোড')),
        PopupMenuItem(value: 'product', child: Text('পণ্য যোগ')),
        PopupMenuItem(value: 'address', child: Text('রোড/ঠিকানা যোগ')),
      ],
    );
  }

  Widget _buildDataRow(BuildContext context, int index) {
    final row = rows[index];
    final isRowLocked = row['isLocked'] as bool;

    final neoyaController = row['neoyaController'] as TextEditingController;

    final perotController = row['perotController'] as TextEditingController;

    final dorController = row['dorController'] as TextEditingController;

    final damageController = row['damageController'] as TextEditingController;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              '${row['serialNo']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _productField(row, row['id'] == null && !isRowLocked),
          _numberField(neoyaController, enabled: !isRowLocked),
          _numberField(dorController, enabled: !isRowLocked),
          _numberField(perotController, enabled: !isRowLocked),
          _readOnlyNumber(_bikroy(row)),
          _readOnlyNumber(_taka(row)),
          _numberField(damageController, enabled: !isRowLocked),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isRowLocked ? 'সম্পাদনা' : 'সম্পাদনা বন্ধ করুন',
                  icon: Icon(isRowLocked ? Icons.edit_outlined : Icons.check),
                  onPressed: isSaving
                      ? null
                      : () {
                          setState(() {
                            row['isLocked'] = !isRowLocked;
                            isDirty = true;
                          });
                        },
                ),
                IconButton(
                  tooltip: 'মুছে ফেলুন',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeRow(index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  String _decimalText(dynamic value) {
    if (value == null) {
      return '';
    }

    final number = double.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return _formatNumber(number);
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('বিক্রয় হিসাব'),
        centerTitle: true,
        actions: [_menuButton()],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
            ? _errorView()
            : Column(
                children: [
                  _sheetHeader(),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 917,
                        child: Column(
                          children: [
                            Container(
                              color: Colors.white,
                              child: Row(
                                children: [
                                  _headerCell('ক্রমিক', width: 55),
                                  _headerCell('নাম', width: 180),
                                  _headerCell('নেওয়া'),
                                  _headerCell('দর'),
                                  _headerCell('ফেরত'),
                                  _headerCell('বিক্রয়'),
                                  _headerCell('টাকা'),
                                  _headerCell('ড্যামেজ'),
                                  _headerCell('', width: 100),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Container(
                                      color: Colors.white,
                                      child: Column(
                                        children: List.generate(
                                          rows.length,
                                          (index) =>
                                              _buildDataRow(context, index),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      color: Colors.white,
                                      child: _totalsRow(),
                                    ),
                                    const SizedBox(height: 12),
                                    _summaryTable(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  _bottomButtons(),
                ],
              ),
      ),
    );
  }

  Widget _sheetHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(selectedDateLabel, style: const TextStyle(fontSize: 14)),
            ],
          ),
          Text('মাস: $monthName', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('সাল: ${widget.year}', style: const TextStyle(fontSize: 16)),
              if (selectedRoadAddress.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade500),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      selectedRoadAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(
            width: 55,
            child: Text(
              'মোট',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 180),

          SizedBox(
            width: 95,
            child: Text(
              _formatNumber(totalNeoya),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 95),

          SizedBox(
            width: 95,
            child: Text(
              _formatNumber(totalPerot),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          SizedBox(
            width: 95,
            child: Text(
              _formatNumber(totalBikroy),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          SizedBox(
            width: 95,
            child: Text(
              '৳ ${_formatNumber(totalTaka)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          SizedBox(
            width: 95,
            child: Text(
              _formatNumber(totalDamage),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 100),
        ],
      ),
    );
  }

  Widget _summaryTable() {
    const widths = [140.0, 130.0, 130.0, 180.0, 180.0, 100.0];
    return Container(
      width: 917,
      color: Colors.white,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'হিসাব সারাংশ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Row(
            children: [
              _headerCell('টাকা', width: widths[0]),
              _headerCell('ছাড়', width: widths[1]),
              _headerCell('ড্যামেজ', width: widths[2]),
              _headerCell('অন্যান্য খরচ', width: widths[3]),
              _headerCell('অবশিষ্ট টাকা', width: widths[4]),
              _headerCell('', width: widths[5]),
            ],
          ),
          Row(
            children: [
              _readOnlyNumber(totalTaka, width: widths[0]),
              _numberField(
                discountController,
                width: widths[1],
                enabled: summaryIsEditing && !isSaving,
              ),
              _numberField(
                summaryDamageController,
                width: widths[2],
                enabled: summaryIsEditing && !isSaving,
              ),
              _numberField(
                otherExpenseController,
                width: widths[3],
                enabled: summaryIsEditing && !isSaving,
              ),
              _readOnlyNumber(remainingSummaryMoney, width: widths[4]),
              SizedBox(
                width: widths[5],
                child: IconButton(
                  tooltip: summaryIsEditing ? 'সম্পাদনা সম্পন্ন' : 'এডিট',
                  onPressed: isSaving
                      ? null
                      : () => setState(
                          () => summaryIsEditing = !summaryIsEditing,
                        ),
                  icon: Icon(
                    summaryIsEditing ? Icons.check : Icons.edit_outlined,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSaving ? null : _addRows,
              icon: const Icon(Icons.add),
              label: const Text('নতুন সারি'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveSheet,
              icon: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(isSaving ? 'সংরক্ষণ হচ্ছে...' : 'সংরক্ষণ করুন'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadSalesSheet,
              child: const Text('আবার চেষ্টা করুন'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductNameDialog extends StatefulWidget {
  const _ProductNameDialog();

  @override
  State<_ProductNameDialog> createState() => _ProductNameDialogState();
}

class _ProductNameDialogState extends State<_ProductNameDialog> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    Navigator.pop(context, value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('কোম্পানির পণ্য যোগ করুন'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 150,
        decoration: const InputDecoration(
          labelText: 'পণ্যের নাম',
          hintText: 'পণ্যের নাম লিখুন',
        ),
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(
          onPressed: () => _submit(controller.text),
          child: const Text('যোগ করুন'),
        ),
      ],
    );
  }
}

class _RoadAddressDialog extends StatefulWidget {
  const _RoadAddressDialog({required this.addresses});

  final List<String> addresses;

  @override
  State<_RoadAddressDialog> createState() => _RoadAddressDialogState();
}

class _RoadAddressDialogState extends State<_RoadAddressDialog> {
  final TextEditingController controller = TextEditingController();
  String? selectedAddress;
  String? errorText;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final newAddress = controller.text.trim();
    final address = newAddress.isNotEmpty ? newAddress : selectedAddress;
    if (address == null || address.isEmpty) {
      setState(() {
        errorText = 'আগের রোড নির্বাচন করুন অথবা নতুন রোড লিখুন।';
      });
      return;
    }
    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('আজকের রোড/ঠিকানা'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.addresses.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: selectedAddress,
              decoration: const InputDecoration(
                labelText: 'আগের রোড নির্বাচন করুন',
              ),
              items: widget.addresses
                  .map(
                    (address) => DropdownMenuItem<String>(
                      value: address,
                      child: Text(address, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedAddress = value;
                  controller.clear();
                  errorText = null;
                });
              },
            ),
            const SizedBox(height: 8),
            const Text('অথবা নতুন রোড লিখুন'),
          ],
          TextField(
            controller: controller,
            autofocus: widget.addresses.isEmpty,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'রোড/ঠিকানা',
              hintText: 'রোড/ঠিকানা লিখুন',
              errorText: errorText,
            ),
            onChanged: (_) {
              if (errorText != null) {
                setState(() {
                  errorText = null;
                });
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('নির্বাচন করুন')),
      ],
    );
  }
}
