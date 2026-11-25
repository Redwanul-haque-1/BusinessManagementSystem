import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class CompanyAccountPage extends StatefulWidget {
  final int? initialCompanyId;
  final int? initialMonth;
  final int? initialYear;
  final ApiService? apiService;

  const CompanyAccountPage({
    super.key,
    this.initialCompanyId,
    this.initialMonth,
    this.initialYear,
    this.apiService,
  });

  @override
  State<CompanyAccountPage> createState() => _CompanyAccountPageState();
}

class _CompanyAccountPageState extends State<CompanyAccountPage> {
  late final ApiService apiService = widget.apiService ?? ApiService();
  final horizontalController = ScrollController();
  final verticalController = ScrollController();
  final monthNames = const [
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

  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> rows = [];
  int? selectedCompanyId;
  late int selectedMonth;
  late int selectedYear;
  bool isLoading = true;
  bool isSaving = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = widget.initialMonth ?? now.month;
    selectedYear = widget.initialYear ?? now.year;
    selectedCompanyId = widget.initialCompanyId;
    _loadCompanies();
  }

  @override
  void dispose() {
    for (final row in rows) {
      _disposeRow(row);
    }
    horizontalController.dispose();
    verticalController.dispose();
    super.dispose();
  }

  void _disposeRow(Map<String, dynamic> row) {
    (row['onlineController'] as TextEditingController).dispose();
    (row['liftingController'] as TextEditingController).dispose();
    (row['incentiveController'] as TextEditingController).dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final result = await apiService.getCompanies();
      companies = result
          .whereType<Map>()
          .map((company) => Map<String, dynamic>.from(company))
          .toList();
      if (!companies.any((company) => company['id'] == selectedCompanyId)) {
        selectedCompanyId = companies.isEmpty
            ? null
            : companies.first['id'] as int;
      }
      await _loadRows();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadRows() async {
    if (selectedCompanyId == null) {
      setState(() {
        _replaceRows([]);
        isLoading = false;
      });
      return;
    }
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final result = await apiService.getCompanyAccountRows(
        companyId: selectedCompanyId!,
        month: selectedMonth,
        year: selectedYear,
      );
      if (!mounted) return;
      setState(() {
        _replaceRows([for (final item in result) _rowFromData(item)]);
        if (rows.isEmpty) _addRow();
        isLoading = false;
        isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _replaceRows(List<Map<String, dynamic>> nextRows) {
    for (final row in rows) {
      _disposeRow(row);
    }
    rows = nextRows;
  }

  Map<String, dynamic> _rowFromData(Map<String, dynamic> data) => {
    'id': data['id'],
    'date':
        DateTime.tryParse(data['date']?.toString() ?? '') ??
        DateTime(selectedYear, selectedMonth),
    'onlineController': TextEditingController(
      text: _decimalText(data['online']),
    ),
    'liftingController': TextEditingController(
      text: _decimalText(data['lifting']),
    ),
    'incentiveController': TextEditingController(
      text: _decimalText(data['incentive']),
    ),
    'isEditing': false,
  };

  void _addRow() {
    final now = DateTime.now();
    final date = now.year == selectedYear && now.month == selectedMonth
        ? DateTime(now.year, now.month, now.day)
        : DateTime(selectedYear, selectedMonth);
    rows.add({
      'date': date,
      'onlineController': TextEditingController(),
      'liftingController': TextEditingController(),
      'incentiveController': TextEditingController(),
      'isEditing': true,
    });
  }

  double _number(dynamic value) {
    final raw = value is TextEditingController ? value.text : value?.toString();
    return double.tryParse(raw?.replaceAll(',', '').trim() ?? '') ?? 0;
  }

  double _balance(Map<String, dynamic> row) =>
      _number(row['onlineController']) -
      _number(row['liftingController']) +
      _number(row['incentiveController']);

  double get _totalBalance =>
      rows.fold(0, (total, row) => total + _balance(row));

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _signedNumber(double value) =>
      '${value < 0 ? '-' : '+'}${_formatNumber(value.abs())}';

  String _decimalText(dynamic value) {
    if (value == null) return '';
    final parsed = double.tryParse(value.toString());
    return parsed == null ? value.toString() : _formatNumber(parsed);
  }

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _chooseDate(Map<String, dynamic> row) async {
    final firstDate = DateTime(selectedYear, selectedMonth);
    final lastDate = DateTime(selectedYear, selectedMonth + 1, 0);
    final currentDate = row['date'] as DateTime;
    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate.isBefore(firstDate)
          ? firstDate
          : currentDate.isAfter(lastDate)
          ? lastDate
          : currentDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected == null || !mounted) return;
    setState(() => row['date'] = selected);
  }

  Future<void> _save() async {
    if (selectedCompanyId == null) return;
    for (var index = 0; index < rows.length; index++) {
      for (final key in [
        'onlineController',
        'liftingController',
        'incentiveController',
      ]) {
        final value = (rows[index][key] as TextEditingController).text.trim();
        if (value.isNotEmpty &&
            double.tryParse(value.replaceAll(',', '')) == null) {
          _showMessage('সারি ${index + 1}-এ সঠিক সংখ্যা লিখুন।');
          return;
        }
      }
    }
    setState(() => isSaving = true);
    try {
      await apiService.saveCompanyAccountRows(
        companyId: selectedCompanyId!,
        month: selectedMonth,
        year: selectedYear,
        rows: [
          for (var index = 0; index < rows.length; index++)
            {
              'serial_no': index + 1,
              'date': _dateApiValue(rows[index]['date'] as DateTime),
              'online': _number(rows[index]['onlineController']),
              'lifting': _number(rows[index]['liftingController']),
              'incentive': _number(rows[index]['incentiveController']),
            },
        ],
      );
      if (!mounted) return;
      _showMessage('কোম্পানি হিসাব সংরক্ষণ হয়েছে।');
      await _loadRows();
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _dateApiValue(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _headerCell(String text, double width) => Container(
    width: width,
    height: 54,
    alignment: Alignment.center,
    color: Colors.white,
    padding: const EdgeInsets.all(6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );

  Widget _numberCell(
    TextEditingController controller,
    double width, {
    required bool enabled,
  }) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        ),
      ),
    ),
  );

  Widget _buildRow(Map<String, dynamic> row, int index) {
    final editing = row['isEditing'] as bool;
    const dateWidth = 120.0;
    const numberWidth = 120.0;
    const balanceWidth = 130.0;
    const actionWidth = 100.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: dateWidth,
            child: TextButton(
              onPressed: editing && !isSaving ? () => _chooseDate(row) : null,
              child: Text(_dateText(row['date'] as DateTime)),
            ),
          ),
          _numberCell(
            row['onlineController'] as TextEditingController,
            numberWidth,
            enabled: editing && !isSaving,
          ),
          _numberCell(
            row['liftingController'] as TextEditingController,
            numberWidth,
            enabled: editing && !isSaving,
          ),
          _numberCell(
            row['incentiveController'] as TextEditingController,
            numberWidth,
            enabled: editing && !isSaving,
          ),
          SizedBox(
            width: balanceWidth,
            child: Text(
              _signedNumber(_balance(row)),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: actionWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: editing ? 'সম্পাদনা সম্পন্ন' : 'এডিট',
                  onPressed: isSaving
                      ? null
                      : () => setState(() => row['isEditing'] = !editing),
                  icon: Icon(editing ? Icons.check : Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'মুছে ফেলুন',
                  onPressed: isSaving
                      ? null
                      : () {
                          _disposeRow(row);
                          setState(() => rows.removeAt(index));
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tableWidth = 710.0;
    return Scaffold(
      appBar: AppBar(title: const Text('কোম্পানি হিসাব'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedCompanyId,
                decoration: const InputDecoration(
                  labelText: 'কোম্পানি',
                  border: OutlineInputBorder(),
                ),
                items: companies
                    .map(
                      (company) => DropdownMenuItem<int>(
                        value: company['id'] as int,
                        child: Text(company['name']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => selectedCompanyId = value);
                        _loadRows();
                      },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: selectedMonth,
                      decoration: const InputDecoration(labelText: 'মাস'),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(monthNames[index]),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedMonth = value);
                        _loadRows();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(labelText: 'সাল'),
                      items: List.generate(11, (index) {
                        final year = DateTime.now().year - 5 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text('$year'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedYear = value);
                        _loadRows();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : selectedCompanyId == null
                    ? const Center(child: Text('কোনো কোম্পানি পাওয়া যায়নি।'))
                    : Scrollbar(
                        controller: horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              children: [
                                Container(
                                  color: Colors.white,
                                  child: Row(
                                    children: [
                                      _headerCell('তারিখ', 120),
                                      _headerCell('অনলাইন', 120),
                                      _headerCell('লিফটিং', 120),
                                      _headerCell('ইনসেনটিভ', 120),
                                      _headerCell('ব্যালেন্স', 130),
                                      _headerCell('', 100),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Scrollbar(
                                    controller: verticalController,
                                    thumbVisibility: true,
                                    child: ListView.builder(
                                      controller: verticalController,
                                      itemCount: rows.length,
                                      itemBuilder: (context, index) =>
                                          _buildRow(rows[index], index),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: tableWidth,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  color: Colors.white,
                                  child: Center(
                                    child: Text(
                                      'মোট ব্যালেন্স: ${_signedNumber(_totalBalance)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSaving || isLoading
                          ? null
                          : () => setState(_addRow),
                      icon: const Icon(Icons.add),
                      label: const Text('নতুন সারি'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isSaving || isLoading ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isSaving ? 'সংরক্ষণ হচ্ছে...' : 'সংরক্ষণ করুন',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
