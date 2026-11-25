import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'capital_account_page.dart';
import 'company_account_page.dart';
import 'due_account_page.dart';
import 'sales_sheet_page.dart';
import 'stock_sheet_page.dart';

class CompanyDashboardPage extends StatefulWidget {
  final Map<String, dynamic> company;
  final ApiService? apiService;

  const CompanyDashboardPage({
    super.key,
    required this.company,
    this.apiService,
  });

  @override
  State<CompanyDashboardPage> createState() => _CompanyDashboardPageState();
}

class _CompanyDashboardPageState extends State<CompanyDashboardPage> {
  late int selectedMonth;
  late int selectedYear;
  late DateTime selectedDashboardDate;
  late final ApiService apiService = widget.apiService ?? ApiService();

  bool isLoadingSummary = true;
  String summaryError = '';

  double totalPerotValue = 0;
  double totalTaka = 0;
  double totalOrderValue = 0;
  double totalDamageValue = 0;
  double totalStockValue = 0;
  double totalMarketDue = 0;
  double totalUndelivery = 0;
  double totalCapital = 0;

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

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedMonth = now.month;
    selectedYear = now.year;
    selectedDashboardDate = DateTime(now.year, now.month, now.day);
    _loadDashboardSummary();
  }

  int get _companyId {
    final value = widget.company['id'];
    return value is int ? value : int.parse(value.toString());
  }

  List<Map<String, dynamic>> _extractRows(Map<String, dynamic> data) {
    final rows = data['rows'];
    if (rows is! List) {
      return [];
    }

    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
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

  void _keepSelectedDateInMonth() {
    final lastDay = DateTime(selectedYear, selectedMonth + 1, 0).day;
    selectedDashboardDate = DateTime(
      selectedYear,
      selectedMonth,
      selectedDashboardDate.day > lastDay ? lastDay : selectedDashboardDate.day,
    );
  }

  Future<void> _loadDashboardSummary() async {
    setState(() {
      isLoadingSummary = true;
      summaryError = '';
    });

    try {
      final results = await Future.wait<Object>([
        apiService.getSalesSheet(
          companyId: _companyId,
          month: selectedMonth,
          year: selectedYear,
        ),
        apiService.getCapitalAccountSummary(
          companyId: _companyId,
          month: selectedMonth,
          year: selectedYear,
        ),
      ]);

      final salesRows = _extractRows(results[0] as Map<String, dynamic>);
      final capitalSummary = results[1] as Map<String, double>;

      double perotValue = 0;
      double taka = 0;
      double orderValue = 0;
      for (final row in salesRows) {
        final rowNeoya = _toDouble(row['neoya']);
        final rowPerot = _toDouble(row['perot']);
        final rowDor = _toDouble(row['dor']);
        final rowBikroy = rowNeoya - rowPerot;
        final calculatedBikroy = rowBikroy < 0 ? 0.0 : rowBikroy;

        final rowOrderValue = _money(rowNeoya * rowDor);
        perotValue += _money(rowPerot * rowDor);
        final rowSalesValue = _money(calculatedBikroy * rowDor);
        taka += rowSalesValue;
        orderValue += rowOrderValue;
      }

      final damageValue = capitalSummary['damageValue'] ?? 0;
      final stockValue = capitalSummary['stockValue'] ?? 0;
      final marketDue = capitalSummary['marketDue'] ?? 0;
      final undelivery = capitalSummary['undelivery'] ?? 0;
      final capital = capitalSummary['totalCapital'] ?? 0;

      if (!mounted) {
        return;
      }

      setState(() {
        totalPerotValue = perotValue;
        totalTaka = taka;
        totalOrderValue = orderValue;
        totalDamageValue = damageValue;
        totalStockValue = stockValue;
        totalMarketDue = marketDue;
        totalUndelivery = undelivery;
        totalCapital = capital;
        isLoadingSummary = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingSummary = false;
        summaryError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get companyName {
    return widget.company['name']?.toString() ?? 'কোম্পানি';
  }

  Future<void> _selectDashboardDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDashboardDate,
      firstDate: DateTime(selectedYear, selectedMonth),
      lastDate: DateTime(selectedYear, selectedMonth + 1, 0),
      helpText: 'হিসাবের দিন নির্বাচন করুন',
    );
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      selectedDashboardDate = selected;
    });
    _loadDashboardSummary();
  }

  Future<void> _openAccountPage(String action) async {
    final Widget page;
    switch (action) {
      case 'due':
        page = DueAccountPage(
          company: widget.company,
          month: selectedMonth,
          year: selectedYear,
          apiService: apiService,
        );
        break;
      case 'capital':
        page = CapitalAccountPage(
          company: widget.company,
          month: selectedMonth,
          year: selectedYear,
          apiService: apiService,
        );
        break;
      case 'company':
        page = CompanyAccountPage(
          initialCompanyId: _companyId,
          initialMonth: selectedMonth,
          initialYear: selectedYear,
          apiService: apiService,
        );
        break;
      default:
        return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) _loadDashboardSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(companyName),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'হিসাবের মেনু',
            onSelected: _openAccountPage,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'due', child: Text('বাকি হিসাব')),
              PopupMenuItem(value: 'capital', child: Text('মূলধন হিসাব')),
              PopupMenuItem(value: 'company', child: Text('কোম্পানি হিসাব')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Company header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.company['address'] != null)
                        Text(
                          widget.company['address'].toString(),
                          style: const TextStyle(fontSize: 15),
                        ),
                      if (widget.company['phone'] != null)
                        Text(
                          widget.company['phone'].toString(),
                          style: const TextStyle(fontSize: 15),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Month and year
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'মাস',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(monthNames[index]),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          selectedMonth = value;
                          _keepSelectedDateInMonth();
                        });
                        _loadDashboardSummary();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'সাল',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(11, (index) {
                        final year = DateTime.now().year - 5 + index;

                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          selectedYear = value;
                          _keepSelectedDateInMonth();
                        });
                        _loadDashboardSummary();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _selectDashboardDate,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'দিন নির্বাচন: '
                        '${selectedDashboardDate.day.toString().padLeft(2, '0')}/'
                        '${selectedDashboardDate.month.toString().padLeft(2, '0')}/'
                        '${selectedDashboardDate.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isLoadingSummary)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),

              if (summaryError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    summaryError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              // Summary title
              const Text(
                'মাসিক সারসংক্ষেপ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              // Summary cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _summaryCard(
                    title: 'মোট ফেরত মূল্য',
                    value: '৳ ${_formatNumber(totalPerotValue)}',
                    icon: Icons.assignment_return_outlined,
                  ),
                  _summaryCard(
                    title: 'মোট অর্ডার মূল্য',
                    value: '৳ ${_formatNumber(totalOrderValue)}',
                    icon: Icons.shopping_cart_outlined,
                  ),
                  _summaryCard(
                    title: 'মোট টাকা',
                    value: '৳ ${_formatNumber(totalTaka)}',
                    icon: Icons.payments_outlined,
                  ),
                  _summaryCard(
                    title: 'মোট ড্যামেজ মূল্য',
                    value: '৳ ${_formatNumber(totalDamageValue)}',
                    icon: Icons.warning_amber_outlined,
                  ),
                  _summaryCard(
                    title: 'মোট স্টক মূল্য',
                    value: '৳ ${_formatNumber(totalStockValue)}',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _summaryCard(
                    title: 'মার্কেট বাকি',
                    value: _formatNumber(totalMarketDue),
                    icon: Icons.receipt_long_outlined,
                  ),
                  _summaryCard(
                    title: 'আনডেলিভারি',
                    value: _signedNumber(totalUndelivery),
                    icon: Icons.swap_horiz,
                  ),
                  _summaryCard(
                    title: 'মোট মূলধন',
                    value: _formatNumber(totalCapital),
                    icon: Icons.account_balance,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Sales Sheet button
              // Sales Sheet button
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SalesSheetPage(
                          company: widget.company,
                          month: selectedMonth,
                          year: selectedYear,
                          initialDate: selectedDashboardDate,
                        ),
                      ),
                    );
                    if (mounted) {
                      _loadDashboardSummary();
                    }
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text(
                    'বিক্রয় হিসাব',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Stock Sheet button
              SizedBox(
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockSheetPage(
                          company: widget.company,
                          month: selectedMonth,
                          year: selectedYear,
                        ),
                      ),
                    );
                    if (mounted) {
                      _loadDashboardSummary();
                    }
                  },
                  icon: const Icon(Icons.inventory),
                  label: const Text(
                    'স্টক হিসাব',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 28),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _signedNumber(double value) =>
      '${value < 0 ? '-' : '+'}${_formatNumber(value.abs())}';
}
