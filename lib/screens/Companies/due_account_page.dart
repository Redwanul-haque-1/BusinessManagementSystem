import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class DueAccountPage extends StatefulWidget {
  final Map<String, dynamic> company;
  final int month;
  final int year;
  final ApiService? apiService;

  const DueAccountPage({
    super.key,
    required this.company,
    required this.month,
    required this.year,
    this.apiService,
  });

  @override
  State<DueAccountPage> createState() => _DueAccountPageState();
}

class _DueAccountPageState extends State<DueAccountPage> {
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

  final List<Map<String, dynamic>> rows = [];
  late int selectedMonth;
  late int selectedYear;
  bool isLoading = true;
  bool isSaving = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    selectedMonth = widget.month;
    selectedYear = widget.year;
    _loadRows();
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
    (row['dueController'] as TextEditingController).dispose();
    (row['depositController'] as TextEditingController).dispose();
  }

  int get _companyId => widget.company['id'] is int
      ? widget.company['id'] as int
      : int.parse(widget.company['id'].toString());

  String get _companyName => widget.company['name']?.toString() ?? 'কোম্পানি';

  Future<void> _loadRows() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final saved = await apiService.getDueAccountRows(
        companyId: _companyId,
        month: selectedMonth,
        year: selectedYear,
      );
      if (!mounted) return;
      setState(() {
        for (final row in rows) {
          _disposeRow(row);
        }
        rows
          ..clear()
          ..addAll(saved.map(_rowFromData));
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

  Map<String, dynamic> _rowFromData(Map<String, dynamic> data) => {
    'date':
        DateTime.tryParse(data['date']?.toString() ?? '') ??
        DateTime(selectedYear, selectedMonth),
    'dueController': TextEditingController(text: _decimalText(data['due'])),
    'depositController': TextEditingController(
      text: _decimalText(data['deposit']),
    ),
    'isEditing': false,
  };

  void _addRow() {
    final now = DateTime.now();
    rows.add({
      'date': now.year == selectedYear && now.month == selectedMonth
          ? DateTime(now.year, now.month, now.day)
          : DateTime(selectedYear, selectedMonth),
      'dueController': TextEditingController(),
      'depositController': TextEditingController(),
      'isEditing': true,
    });
  }

  double _number(dynamic value) {
    final text = value is TextEditingController
        ? value.text
        : value?.toString();
    return double.tryParse(text?.replaceAll(',', '').trim() ?? '') ?? 0;
  }

  double _marketDue(Map<String, dynamic> row) =>
      _number(row['dueController']) - _number(row['depositController']);

  double get _totalMarketDue =>
      rows.fold(0, (total, row) => total + _marketDue(row));

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _decimalText(dynamic value) {
    if (value == null) return '';
    final parsed = double.tryParse(value.toString());
    return parsed == null ? value.toString() : _formatNumber(parsed);
  }

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _dateApiValue(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

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
    for (var index = 0; index < rows.length; index++) {
      for (final key in ['dueController', 'depositController']) {
        final value = (rows[index][key] as TextEditingController).text.trim();
        if (value.isNotEmpty &&
            double.tryParse(value.replaceAll(',', '')) == null) {
          _message('সারি ${index + 1}-এ সঠিক সংখ্যা লিখুন।');
          return;
        }
      }
    }
    setState(() => isSaving = true);
    try {
      await apiService.saveDueAccountRows(
        companyId: _companyId,
        month: selectedMonth,
        year: selectedYear,
        rows: [
          for (final row in rows)
            {
              'date': _dateApiValue(row['date'] as DateTime),
              'due': _number(row['dueController']),
              'deposit': _number(row['depositController']),
            },
        ],
      );
      if (!mounted) return;
      _message('বাকি হিসাব সংরক্ষণ হয়েছে।');
      await _loadRows();
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: TextButton(
              onPressed: editing && !isSaving ? () => _chooseDate(row) : null,
              child: Text(_dateText(row['date'] as DateTime)),
            ),
          ),
          _numberCell(
            row['dueController'] as TextEditingController,
            130,
            enabled: editing && !isSaving,
          ),
          _numberCell(
            row['depositController'] as TextEditingController,
            130,
            enabled: editing && !isSaving,
          ),
          SizedBox(
            width: 140,
            child: Text(
              _formatNumber(_marketDue(row)),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 100,
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
    const tableWidth = 620.0;
    return Scaffold(
      appBar: AppBar(
        title: Text('বাকি হিসাব — $_companyName'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
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
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
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
                                      _headerCell('বাকি', 130),
                                      _headerCell('জমা', 130),
                                      _headerCell('মার্কেট বাকি', 140),
                                      _headerCell('', 100),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Scrollbar(
                                    controller: verticalController,
                                    thumbVisibility: true,
                                    notificationPredicate: (notification) =>
                                        notification.metrics.axis ==
                                        Axis.vertical,
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
                                  padding: const EdgeInsets.all(12),
                                  color: Colors.white,
                                  child: Center(
                                    child: Text(
                                      'মোট মার্কেট বাকি: ${_formatNumber(_totalMarketDue)}',
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
