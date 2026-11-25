import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/sheet_pdf_actions.dart';
import '../../services/sheet_pdf_service.dart';

class StockProductListPage extends StatefulWidget {
  const StockProductListPage({
    super.key,
    required this.initialCompanyId,
    this.apiService,
  });

  final int initialCompanyId;
  final ApiService? apiService;

  @override
  State<StockProductListPage> createState() => _StockProductListPageState();
}

class _StockProductListPageState extends State<StockProductListPage> {
  late final ApiService apiService = widget.apiService ?? ApiService();
  final SheetPdfService _pdfService = SheetPdfService();

  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> stockRows = [];
  int? selectedCompanyId;
  Map<String, dynamic>? selectedCompany;
  String? latestUpdateDate;
  bool isLoadingCompanies = true;
  bool isLoadingRows = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  int _companyId(Map<String, dynamic> company) {
    final id = company['id'];
    return id is int ? id : int.parse(id.toString());
  }

  Future<void> _loadCompanies() async {
    setState(() {
      isLoadingCompanies = true;
      errorMessage = '';
    });
    try {
      final result = await apiService.getCompanies();
      if (!mounted) return;
      companies = result
          .whereType<Map>()
          .map((company) => Map<String, dynamic>.from(company))
          .toList();
      final initial = companies.where(
        (company) => _companyId(company) == widget.initialCompanyId,
      );
      final company = initial.isNotEmpty
          ? initial.first
          : (companies.isNotEmpty ? companies.first : null);
      setState(() {
        isLoadingCompanies = false;
        selectedCompany = company;
        selectedCompanyId = company == null ? null : _companyId(company);
      });
      if (company != null) {
        await _loadStockProducts(_companyId(company));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingCompanies = false;
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadStockProducts(int companyId) async {
    setState(() {
      isLoadingRows = true;
      errorMessage = '';
      stockRows = [];
      latestUpdateDate = null;
      selectedCompanyId = companyId;
      selectedCompany = companies.firstWhere(
        (company) => _companyId(company) == companyId,
      );
    });
    try {
      final result = await apiService.getStockProductList(companyId: companyId);
      if (!mounted) return;
      final loadedRows = result
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      setState(() {
        stockRows = loadedRows;
        latestUpdateDate = loadedRows
            .map((row) => row['latest_update_date']?.toString())
            .whereType<String>()
            .firstWhere((date) => date.isNotEmpty, orElse: () => '');
        if (latestUpdateDate!.isEmpty) latestUpdateDate = null;
        isLoadingRows = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingRows = false;
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _downloadPdf() async {
    final company = selectedCompany;
    if (company == null) return;
    final date = latestUpdateDate;
    if (date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('কোনো সংরক্ষিত স্টক আপডেট পাওয়া যায়নি।'),
        ),
      );
      return;
    }

    try {
      final bytes = await _pdfService.createStockProductListPdf(
        company: company,
        rows: stockRows,
        latestUpdateDate: date,
      );
      final companyId = _companyId(company);
      final fileName =
          'stock_products_${companyId}_latest_${date.replaceAll('-', '_')}';
      final savedPath = await savePdfToDownloads(name: fileName, bytes: bytes);
      if (!mounted) return;
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
            onPressed: () => sharePdf(name: fileName, bytes: bytes),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF তৈরি বা সংরক্ষণ করা যায়নি: $error')),
      );
    }
  }

  Widget _buildCompanyDropdown() {
    if (isLoadingCompanies) {
      return const LinearProgressIndicator();
    }
    if (companies.isEmpty) {
      return const Text('কোনো কোম্পানি পাওয়া যায়নি।');
    }
    return DropdownButtonFormField<int>(
      initialValue: selectedCompanyId,
      decoration: const InputDecoration(
        labelText: 'কোম্পানি নির্বাচন',
        border: OutlineInputBorder(),
      ),
      items: companies
          .map(
            (company) => DropdownMenuItem<int>(
              value: _companyId(company),
              child: Text(company['name']?.toString() ?? ''),
            ),
          )
          .toList(),
      onChanged: isLoadingRows
          ? null
          : (companyId) {
              if (companyId != null) _loadStockProducts(companyId);
            },
    );
  }

  Widget _buildTable() {
    if (stockRows.isEmpty) {
      return const Center(child: Text('এই কোম্পানিতে কোনো পণ্য যোগ করা নেই।'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ক্রমিক নং')),
            DataColumn(label: Text('তারিখ')),
            DataColumn(label: Text('পণ্যের নাম')),
            DataColumn(label: Text('স্টকের পরিমাণ'), numeric: true),
            DataColumn(label: Text('স্টকের মূল্য'), numeric: true),
            DataColumn(label: Text('ক্রয় মূল্য'), numeric: true),
            DataColumn(label: Text('বিক্রয় মূল্য'), numeric: true),
          ],
          rows: [
            for (var index = 0; index < stockRows.length; index++)
              DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(stockRows[index]['date']?.toString() ?? '—')),
                  DataCell(Text(stockRows[index]['name']?.toString() ?? '')),
                  DataCell(Text(_formatNumber(stockRows[index]['stock']))),
                  DataCell(Text(_formatNumber(stockRows[index]['total']))),
                  DataCell(Text(_formatNumber(stockRows[index]['price']))),
                  DataCell(
                    Text(
                      _formatNumber(
                        stockRows[index]['selling_price'] ??
                            stockRows[index]['price'],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '') ?? '');
    if (parsed == null) return '0';
    return parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টক পণ্যের তালিকা'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'PDF মেনু',
            onSelected: (_) => _downloadPdf(),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'latest',
                child: Text('সর্বশেষ আপডেটের PDF ডাউনলোড'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCompanyDropdown(),
            ),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (isLoadingRows) const LinearProgressIndicator(),
            if (!isLoadingRows && errorMessage.isEmpty)
              Expanded(child: _buildTable()),
            if (!isLoadingRows && errorMessage.isNotEmpty)
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: selectedCompanyId == null
                        ? _loadCompanies
                        : () => _loadStockProducts(selectedCompanyId!),
                    child: const Text('আবার চেষ্টা করুন'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
