import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/sheet_pdf_actions.dart';
import '../../services/sheet_pdf_service.dart';
import 'row_count_dialog.dart';
import 'stock_product_list_page.dart';

class StockSheetPage extends StatefulWidget {
  final Map<String, dynamic> company;
  final int month;
  final int year;
  final ApiService? apiService;

  const StockSheetPage({
    super.key,
    required this.company,
    required this.month,
    required this.year,
    this.apiService,
  });

  @override
  State<StockSheetPage> createState() => _StockSheetPageState();
}

class _StockSheetPageState extends State<StockSheetPage> {
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
  final SheetPdfService _pdfService = SheetPdfService();

  bool isLoading = true;
  bool isSaving = false;
  bool isDirty = false;
  String errorMessage = '';
  int? stockSheetId;
  String sheetTitle = '';
  late DateTime selectedDate;
  List<String> productNames = [];
  List<Map<String, dynamic>> companyProducts = [];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedDate = now.year == widget.year && now.month == widget.month
        ? DateTime(now.year, now.month, now.day)
        : DateTime(widget.year, widget.month);
    loadStockSheet();
  }

  @override
  void dispose() {
    for (final row in rows) {
      _disposeRow(row);
    }

    super.dispose();
  }

  void _disposeRow(Map<String, dynamic> row) {
    (row['nameController'] as TextEditingController).dispose();
    (row['stockController'] as TextEditingController).dispose();
    (row['priceController'] as TextEditingController).dispose();
    (row['sellingPriceController'] as TextEditingController).dispose();
  }

  int get _companyId {
    final value = widget.company['id'];
    return value is int ? value : int.parse(value.toString());
  }

  String get selectedDateLabel {
    return 'তারিখ: ${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
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

    try {
      final bytes = await _pdfService.createStockPdf(
        company: widget.company,
        monthName: monthName,
        year: widget.year,
        selectedDate: selectedDate,
        range: range,
        rows: reportRows,
      );
      final reportDate =
          '${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}'
          '${range == PdfReportRange.daily ? '_${selectedDate.day.toString().padLeft(2, '0')}' : ''}';
      final fileName = 'stock_${_companyId}_$reportDate';
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

  Future<void> loadStockSheet() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      monthlyRows = [];
    });

    try {
      final sheetFuture = apiService.getStockSheet(
        companyId: _companyId,
        month: widget.month,
        year: widget.year,
      );
      final productsFuture = apiService.getCompanyProducts(
        companyId: _companyId,
      );
      final results = await Future.wait([sheetFuture, productsFuture]);
      final data = results[0] as Map<String, dynamic>;
      final products = results[1] as List<dynamic>;
      final sheet = data['sheet'] is Map
          ? Map<String, dynamic>.from(data['sheet'] as Map)
          : <String, dynamic>{};
      final loadedRows = (data['rows'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      if (!mounted) {
        return;
      }

      monthlyRows = loadedRows;

      for (final row in rows) {
        _disposeRow(row);
      }
      rows.clear();
      isDirty = false;
      companyProducts = products
          .map((product) => Map<String, dynamic>.from(product as Map))
          .toList();
      productNames = companyProducts
          .map((product) => product['name'].toString())
          .toList();

      stockSheetId = _toInt(sheet['id']);
      sheetTitle = sheet['title']?.toString() ?? '';

      final rowsForDay = loadedRows.where((row) {
        final rowDate = DateTime.tryParse(row['date']?.toString() ?? '');
        return rowDate != null &&
            rowDate.year == selectedDate.year &&
            rowDate.month == selectedDate.month &&
            rowDate.day == selectedDate.day;
      }).toList();

      if (rowsForDay.isEmpty) {
        _addRow();
      } else {
        for (var index = 0; index < rowsForDay.length; index++) {
          _addRow(
            initial: rowsForDay[index],
            serialNo:
                _toInt(
                  rowsForDay[index]['serial_no'] ??
                      rowsForDay[index]['serialNo'],
                ) ??
                index + 1,
            locked: true,
          );
        }
      }

      setState(() {
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

  String get companyName {
    return widget.company['name']?.toString() ?? 'কোম্পানি';
  }

  String get monthName {
    return monthNames[widget.month - 1];
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
    isDirty = true;
  }

  void _addRow({
    Map<String, dynamic>? initial,
    int? serialNo,
    bool locked = false,
  }) {
    final row = <String, dynamic>{
      'id': initial?['id'],
      'serialNo': serialNo ?? rows.length + 1,
      'isLocked': locked,
      'nameController': TextEditingController(
        text: initial?['name']?.toString() ?? '',
      ),

      'stockController': TextEditingController(
        text: _decimalText(initial?['stock']),
      ),

      'priceController': TextEditingController(
        text: _decimalText(initial?['price']),
      ),
      'sellingPriceController': TextEditingController(
        text: _decimalText(initial?['selling_price']),
      ),
    };

    final controllers = [
      row['nameController'] as TextEditingController,
      row['stockController'] as TextEditingController,
      row['priceController'] as TextEditingController,
      row['sellingPriceController'] as TextEditingController,
    ];

    for (final controller in controllers) {
      controller.addListener(_rebuild);
    }

    rows.add(row);
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

  void _removeRow(int index) {
    if (rows.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অন্তত একটি সারি রাখতে হবে।')),
      );
      return;
    }

    _disposeRow(rows[index]);

    setState(() {
      isDirty = true;
      rows.removeAt(index);

      for (var i = 0; i < rows.length; i++) {
        rows[i]['serialNo'] = i + 1;
      }
    });
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;
  }

  double _rowTotal(Map<String, dynamic> row) {
    final stock = _number(row['stockController'] as TextEditingController);

    final price = _number(row['priceController'] as TextEditingController);

    return stock * price;
  }

  double _rowStockValue(Map<String, dynamic> row) {
    return _rowTotal(row);
  }

  double get totalStock {
    return rows.fold(
      0,
      (sum, row) =>
          sum + _number(row['stockController'] as TextEditingController),
    );
  }

  double get totalStockValue {
    return rows.fold(0.0, (sum, row) => sum + _rowTotal(row));
  }

  Future<void> _copyLastMonth() async {
    final hasDraftData = rows.any((row) {
      return (row['nameController'] as TextEditingController).text
              .trim()
              .isNotEmpty ||
          (row['stockController'] as TextEditingController).text
              .trim()
              .isNotEmpty ||
          (row['priceController'] as TextEditingController).text
              .trim()
              .isNotEmpty;
    });

    if (hasDraftData) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('বর্তমান তথ্য বদলাবেন?'),
          content: const Text(
            'গত মাসের স্টক কপি করলে নির্বাচিত দিনের খসড়া তথ্য বদলে যাবে।',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('বাতিল'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('কপি করুন'),
            ),
          ],
        ),
      );

      if (shouldReplace != true) {
        return;
      }
    }

    final previous = widget.month == 1
        ? (month: 12, year: widget.year - 1)
        : (month: widget.month - 1, year: widget.year);

    setState(() {
      isSaving = true;
    });

    try {
      final data = await apiService.getStockSheet(
        companyId: _companyId,
        month: previous.month,
        year: previous.year,
      );
      final copiedRows = (data['rows'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      if (!mounted) {
        return;
      }

      if (copiedRows.isEmpty) {
        setState(() {
          isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('গত মাসের কোনো সংরক্ষিত স্টক হিসাব পাওয়া যায়নি।'),
          ),
        );
        return;
      }

      for (final row in rows) {
        _disposeRow(row);
      }
      rows.clear();

      for (var index = 0; index < copiedRows.length; index++) {
        final previousRow = copiedRows[index];
        _addRow(
          initial: {
            'name': previousRow['name'],
            'stock': previousRow['stock'],
            'price': previousRow['price'],
          },
          serialNo: index + 1,
        );
      }

      setState(() {
        isSaving = false;
        isDirty = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${monthNames[previous.month - 1]} মাসের স্টক নির্বাচিত দিনের '
            'খসড়ায় কপি হয়েছে।',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return value == null ? null : int.tryParse(value.toString());
  }

  Future<void> saveSheet() async {
    if (_selectedDateIsInFuture) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ভবিষ্যতের তারিখে স্টক হিসাব করা যাবে না।'),
        ),
      );
      return;
    }

    final preparedRows = <Map<String, dynamic>>[];

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final name = (row['nameController'] as TextEditingController).text.trim();
      final stockText = (row['stockController'] as TextEditingController).text
          .trim();
      final priceText = (row['priceController'] as TextEditingController).text
          .trim();
      final sellingPriceText =
          (row['sellingPriceController'] as TextEditingController).text.trim();
      final stock = double.tryParse(stockText.replaceAll(',', ''));
      final price = double.tryParse(priceText.replaceAll(',', ''));
      final sellingPrice = double.tryParse(
        sellingPriceText.replaceAll(',', ''),
      );

      if (name.isEmpty ||
          stock == null ||
          price == null ||
          sellingPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'সারি ${index + 1}-এ নাম, স্টক, ক্রয় মূল্য ও বিক্রয় মূল্য সঠিকভাবে দিন।',
            ),
          ),
        );
        return;
      }

      if (stock < 0 || price < 0 || sellingPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('সারি ${index + 1}-এর সংখ্যা ০ বা তার বেশি হতে হবে।'),
          ),
        );
        return;
      }

      preparedRows.add({
        'serial_no': index + 1,
        'name': name,
        'stock': stock,
        'price': price,
        'selling_price': sellingPrice,
      });
    }

    setState(() {
      isSaving = true;
    });

    try {
      late final Map<String, dynamic> result;
      if (stockSheetId == null) {
        result = await apiService.saveStockSheet(
          companyId: _companyId,
          month: widget.month,
          year: widget.year,
          selectedDate: _dateApiValue,
          title: sheetTitle.isEmpty ? null : sheetTitle,
          rows: preparedRows,
        );
      } else {
        result = await apiService.updateStockSheet(
          companyId: _companyId,
          stockSheetId: stockSheetId!,
          month: widget.month,
          year: widget.year,
          selectedDate: _dateApiValue,
          title: sheetTitle.isEmpty ? null : sheetTitle,
          rows: preparedRows,
        );
      }

      final savedSheet = result['sheet'];
      final savedSheetId = savedSheet is Map ? _toInt(savedSheet['id']) : null;

      if (savedSheetId == null) {
        throw Exception('সংরক্ষিত স্টকের হিসাবের পরিচিতি পাওয়া যায়নি।');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
        isDirty = false;
        stockSheetId = savedSheetId;
        for (final row in rows) {
          row['isLocked'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('স্টক হিসাব সফলভাবে সংরক্ষণ হয়েছে।')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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

  Widget _headerCell(String text, {double width = 120}) {
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

  bool get _selectedDateIsInFuture {
    final now = DateTime.now();
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).isAfter(DateTime(now.year, now.month, now.day));
  }

  Future<void> _selectDate() async {
    final firstDate = DateTime(widget.year, widget.month);
    final monthLastDate = DateTime(widget.year, widget.month + 1, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (firstDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ভবিষ্যতের তারিখে স্টক হিসাব করা যাবে না।'),
        ),
      );
      return;
    }
    final lastDate = monthLastDate.isAfter(today) ? today : monthLastDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(lastDate) ? lastDate : selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'স্টকের দিন নির্বাচন করুন',
    );

    if (selected == null || !mounted || selected == selectedDate) {
      return;
    }

    final shouldChange =
        !isDirty ||
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('দিন পরিবর্তন করবেন?'),
                content: const Text(
                  'দিন পরিবর্তন করলে এই দিনের অসংরক্ষিত পরিবর্তন বাতিল হবে।',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('বাতিল'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('পরিবর্তন করুন'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!shouldChange || !mounted) {
      return;
    }

    setState(() {
      selectedDate = selected;
    });
    await loadStockSheet();
  }

  Future<String?> _promptForValue(String title, String label) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _PromptValueDialog(title: title, label: label),
    );
  }

  Future<void> _addProduct() async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ProductPickerDialog(
        products: companyProducts,
        onRemoveProduct: _removeCompanyProduct,
      ),
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final isExistingProduct = productNames.contains(name);
    var selectedName = name;
    if (!isExistingProduct) {
      try {
        final product = await apiService.createCompanyProduct(
          companyId: _companyId,
          name: name,
        );
        selectedName = product['name'].toString();
        if (!mounted) {
          return;
        }
        setState(() {
          productNames = {...productNames, selectedName}.toList()..sort();
          companyProducts = [...companyProducts, product];
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
        return;
      }
    }

    var index = rows.indexWhere((row) {
      return (row['nameController'] as TextEditingController).text
              .trim()
              .isEmpty &&
          !(row['isLocked'] as bool);
    });
    if (index == -1) {
      setState(() => _addRow());
      index = rows.length - 1;
    }
    final row = rows[index];
    row['isLocked'] = false;
    (row['nameController'] as TextEditingController).text = selectedName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isExistingProduct ? 'পণ্য সারিতে যোগ হয়েছে।' : 'পণ্য যোগ হয়েছে।',
        ),
      ),
    );
  }

  Future<bool> _removeCompanyProduct(Map<String, dynamic> product) async {
    final productId = _toInt(product['id']);
    if (productId == null) {
      throw Exception('পণ্যটির পরিচয় পাওয়া যায়নি।');
    }

    try {
      await apiService.deleteCompanyProduct(
        companyId: _companyId,
        productId: productId,
      );
      if (!mounted) {
        return false;
      }
      setState(() {
        companyProducts.removeWhere((item) => item['id'] == product['id']);
        productNames = companyProducts
            .map((item) => item['name'].toString())
            .toList();
      });
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _addRoadAddress() async {
    final address = await _promptForValue(
      'রোড/ঠিকানা যোগ করুন',
      'রোড/ঠিকানার নাম',
    );
    if (address == null || address.isEmpty || !mounted) {
      return;
    }
    try {
      await apiService.createCompanyAddress(
        companyId: _companyId,
        address: address,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('রোড/ঠিকানা যোগ হয়েছে।')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
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
      case 'copy':
        await _copyLastMonth();
        break;
      case 'stockProducts':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockProductListPage(initialCompanyId: _companyId),
          ),
        );
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
        PopupMenuItem(value: 'copy', child: Text('গত মাসের স্টক কপি')),
        PopupMenuItem(
          value: 'stockProducts',
          child: Text('স্টক পণ্যের তালিকা'),
        ),
      ],
    );
  }

  Widget _productField(Map<String, dynamic> row, bool enabled) {
    final controller = row['nameController'] as TextEditingController;
    final selectedValue = productNames.contains(controller.text)
        ? controller.text
        : null;

    return SizedBox(
      width: 220,
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
                    }
                  }
                : null,
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller, {
    double width = 120,
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

  Widget _readOnlyNumber(double value, {double width = 140}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: value < 1000 ? Colors.red.shade100 : Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '৳ ${_formatNumber(value)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDataRow(int index) {
    final row = rows[index];
    final locked = row['isLocked'] as bool;

    final stockController = row['stockController'] as TextEditingController;

    final priceController = row['priceController'] as TextEditingController;
    final sellingPriceController =
        row['sellingPriceController'] as TextEditingController;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 65,
            child: Text(
              '${row['serialNo']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          _productField(row, !locked),
          _numberField(stockController, width: 130, enabled: !locked),
          _numberField(priceController, width: 130, enabled: !locked),
          _numberField(sellingPriceController, width: 130, enabled: !locked),

          _readOnlyNumber(_rowStockValue(row), width: 150),

          SizedBox(
            width: 96,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: locked ? 'সম্পাদনা' : 'সম্পাদনা বন্ধ করুন',
                  icon: Icon(locked ? Icons.edit_outlined : Icons.check),
                  onPressed: isSaving
                      ? null
                      : () {
                          setState(() {
                            row['isLocked'] = !locked;
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

  Widget _totalsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(
            width: 65,
            child: Text(
              'মোট',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 220),

          SizedBox(
            width: 130,
            child: Text(
              _formatNumber(totalStock),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 130),

          SizedBox(width: 130, child: const SizedBox.shrink()),

          SizedBox(
            width: 150,
            child: Text(
              '৳ ${_formatNumber(totalStockValue)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 96),
        ],
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
          const SizedBox(height: 3),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('মাস: $monthName', style: const TextStyle(fontSize: 16)),
              Text('সাল: ${widget.year}', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Row(
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
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'সংরক্ষণ হচ্ছে...' : 'সংরক্ষণ করুন'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টক হিসাব'),
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
                        width: 933,
                        child: Column(
                          children: [
                            Container(
                              color: Colors.white,
                              child: Row(
                                children: [
                                  _headerCell('ক্রমিক', width: 65),
                                  _headerCell('পণ্যের নাম', width: 220),
                                  _headerCell('স্টকের পরিমাণ', width: 130),
                                  _headerCell('ক্রয় মূল্য', width: 130),
                                  _headerCell('বিক্রয় মূল্য', width: 130),
                                  _headerCell('স্টকের মূল্য', width: 150),
                                  _headerCell('', width: 96),
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
                                          (index) => _buildDataRow(index),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      color: Colors.white,
                                      child: _totalsRow(),
                                    ),
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
              onPressed: loadStockSheet,
              child: const Text('আবার চেষ্টা করুন'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptValueDialog extends StatefulWidget {
  const _PromptValueDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_PromptValueDialog> createState() => _PromptValueDialogState();
}

class _PromptValueDialogState extends State<_PromptValueDialog> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('যোগ করুন')),
      ],
    );
  }
}

class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog({
    required this.products,
    required this.onRemoveProduct,
  });

  final List<Map<String, dynamic>> products;
  final Future<bool> Function(Map<String, dynamic> product) onRemoveProduct;

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  final TextEditingController controller = TextEditingController();
  late List<Map<String, dynamic>> products = List.from(widget.products);
  String? selectedProduct;
  final Set<int> removingProductIds = {};

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = controller.text.trim();
    final selectedName = name.isNotEmpty ? name : selectedProduct;
    if (selectedName != null) {
      Navigator.pop(context, selectedName);
    }
  }

  Future<void> _removeProduct(Map<String, dynamic> product) async {
    final productId = int.tryParse(product['id'].toString());
    if (productId == null || removingProductIds.contains(productId)) {
      return;
    }

    setState(() => removingProductIds.add(productId));
    final removed = await widget.onRemoveProduct(product);
    if (!mounted) {
      return;
    }
    setState(() {
      removingProductIds.remove(productId);
      if (removed) {
        products.removeWhere((item) => item['id'] == product['id']);
        if (!products.any((item) => item['name'] == selectedProduct)) {
          selectedProduct = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productItemWidth = (MediaQuery.sizeOf(context).width - 160)
        .clamp(100.0, 200.0)
        .toDouble();
    return AlertDialog(
      scrollable: true,
      constraints: const BoxConstraints(maxWidth: 400),
      title: const Text('পণ্য যোগ করুন'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedProduct,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'আগে যোগ করা পণ্য'),
              hint: Text(
                products.isEmpty ? 'কোনো পণ্য নেই' : 'পণ্য নির্বাচন করুন',
              ),
              items: products.map((product) {
                final name = product['name'].toString();
                final productId = int.tryParse(product['id'].toString());
                final isRemoving =
                    productId != null && removingProductIds.contains(productId);
                return DropdownMenuItem<String>(
                  value: name,
                  child: SizedBox(
                    width: productItemWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          tooltip: '$name তালিকা থেকে সরান',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: isRemoving
                              ? null
                              : () => _removeProduct(product),
                          icon: isRemoving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: products.isEmpty
                  ? null
                  : (name) => setState(() {
                      selectedProduct = name;
                    }),
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'নতুন পণ্যের নাম'),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(
            selectedProduct == null
                ? 'নতুন পণ্য যোগ করুন'
                : 'নির্বাচিত পণ্য যোগ করুন',
          ),
        ),
      ],
    );
  }
}
