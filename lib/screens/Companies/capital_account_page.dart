import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class CapitalAccountPage extends StatefulWidget {
  final Map<String, dynamic> company;
  final int month;
  final int year;
  final ApiService? apiService;

  const CapitalAccountPage({
    super.key,
    required this.company,
    required this.month,
    required this.year,
    this.apiService,
  });

  @override
  State<CapitalAccountPage> createState() => _CapitalAccountPageState();
}

class _CapitalAccountPageState extends State<CapitalAccountPage> {
  late final ApiService apiService = widget.apiService ?? ApiService();
  final horizontalController = ScrollController();

  bool isLoading = true;
  String errorMessage = '';
  double stockValue = 0;
  double marketDue = 0;
  double damageValue = 0;
  double undelivery = 0;
  double totalCapital = 0;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  @override
  void dispose() {
    horizontalController.dispose();
    super.dispose();
  }

  int get _companyId => widget.company['id'] is int
      ? widget.company['id'] as int
      : int.parse(widget.company['id'].toString());

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _signedNumber(double value) =>
      '${value < 0 ? '-' : '+'}${_formatNumber(value.abs())}';

  Future<void> _loadTotals() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final summary = await apiService.getCapitalAccountSummary(
        companyId: _companyId,
        month: widget.month,
        year: widget.year,
      );
      if (!mounted) return;
      setState(() {
        stockValue = summary['stockValue'] ?? 0;
        marketDue = summary['marketDue'] ?? 0;
        damageValue = summary['damageValue'] ?? 0;
        undelivery = summary['undelivery'] ?? 0;
        totalCapital = summary['totalCapital'] ?? 0;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _headerCell(String text, double width) => Container(
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

  Widget _valueCell(String text, double width, {bool bold = false}) => SizedBox(
    width: width,
    height: 58,
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const tableWidth = 900.0;
    return Scaffold(
      appBar: AppBar(title: const Text('মূলধন হিসাব'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.company['name'] ?? 'কোম্পানি'} — '
                '${widget.month.toString().padLeft(2, '0')}/${widget.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (isLoading) const LinearProgressIndicator(),
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
                    : Scrollbar(
                        controller: horizontalController,
                        thumbVisibility: true,
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
                                      _headerCell('স্টকের মূল্য', 170),
                                      _headerCell('মার্কেট বাকি', 170),
                                      _headerCell('ড্যামেজ', 150),
                                      _headerCell('আনডেলিভারি', 170),
                                      _headerCell('মোট মূলধন', 240),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: tableWidth,
                                  color: Colors.white,
                                  child: Row(
                                    children: [
                                      _valueCell(
                                        _formatNumber(stockValue),
                                        170,
                                      ),
                                      _valueCell(_formatNumber(marketDue), 170),
                                      _valueCell(
                                        _formatNumber(damageValue),
                                        150,
                                      ),
                                      _valueCell(
                                        _signedNumber(undelivery),
                                        170,
                                      ),
                                      _valueCell(
                                        _formatNumber(totalCapital),
                                        240,
                                        bold: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
