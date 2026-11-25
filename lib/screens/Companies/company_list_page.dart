import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'company_dashboard_page.dart';

class CompanyListPage extends StatefulWidget {
  final ApiService? apiService;

  const CompanyListPage({super.key, this.apiService});

  @override
  State<CompanyListPage> createState() => _CompanyListPageState();
}

class _CompanyListPageState extends State<CompanyListPage> {
  late final ApiService apiService = widget.apiService ?? ApiService();

  List<dynamic> companies = [];
  List<dynamic> filteredCompanies = [];
  final Map<int, double> monthlyCapitalByCompany = {};
  final Map<int, String> monthlyCapitalErrors = {};
  final Set<int> loadingCapitalCompanyIds = {};

  bool isLoading = true;
  String errorMessage = '';

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    searchController.addListener(filterCompanies);
    loadCompanies();
  }

  @override
  void dispose() {
    searchController.removeListener(filterCompanies);
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadCompanies() async {
    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await apiService.getCompanies();

      if (!mounted) {
        return;
      }

      setState(() {
        companies = result;
        filteredCompanies = List<dynamic>.from(result);
        monthlyCapitalByCompany.clear();
        monthlyCapitalErrors.clear();
        isLoading = false;
      });

      filterCompanies();
      await _loadCompanyMonthlyCapital(result);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  int _companyId(Map<String, dynamic> company) {
    final value = company['id'];
    return value is int ? value : int.parse(value.toString());
  }

  Future<void> _loadCompanyMonthlyCapital(List<dynamic> companyRows) async {
    final now = DateTime.now();
    final companiesById = companyRows
        .map((company) => Map<String, dynamic>.from(company as Map))
        .toList();
    final companyIds = companiesById.map(_companyId).toSet();
    if (!mounted) return;
    setState(() {
      loadingCapitalCompanyIds
        ..clear()
        ..addAll(companyIds);
      for (final companyId in companyIds) {
        monthlyCapitalByCompany.remove(companyId);
        monthlyCapitalErrors.remove(companyId);
      }
    });

    final results = await Future.wait<MapEntry<int, Object?>>(
      companiesById.map((company) async {
        final companyId = _companyId(company);
        try {
          final summary = await apiService.getCapitalAccountSummary(
            companyId: companyId,
            month: now.month,
            year: now.year,
          );
          return MapEntry<int, Object?>(
            companyId,
            summary['totalCapital'] ?? 0,
          );
        } catch (error) {
          return MapEntry<int, Object?>(
            companyId,
            error.toString().replaceFirst('Exception: ', ''),
          );
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      loadingCapitalCompanyIds.clear();
      for (final result in results) {
        final value = result.value;
        if (value is num) {
          monthlyCapitalByCompany[result.key] = value.toDouble();
          monthlyCapitalErrors.remove(result.key);
        } else {
          monthlyCapitalByCompany.remove(result.key);
          monthlyCapitalErrors[result.key] =
              value?.toString() ?? 'অজানা ত্রুটি';
        }
      }
    });
  }

  String _formatCapital(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  Widget _capitalSummaryBadge(int companyId) {
    if (loadingCapitalCompanyIds.contains(companyId)) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('মূলধন হিসাব লোড হচ্ছে...'),
        ],
      );
    }

    final error = monthlyCapitalErrors[companyId];
    if (error != null) {
      return Tooltip(
        message: error,
        child: const Text(
          'মূলধন হিসাব লোড হয়নি',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        'মূলধন: '
        '${_formatCapital(monthlyCapitalByCompany[companyId] ?? 0)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void filterCompanies() {
    if (!mounted) {
      return;
    }

    final searchText = searchController.text.trim().toLowerCase();

    setState(() {
      if (searchText.isEmpty) {
        filteredCompanies = List<dynamic>.from(companies);
        return;
      }

      filteredCompanies = companies.where((company) {
        final name = company['name']?.toString().toLowerCase() ?? '';

        final address = company['address']?.toString().toLowerCase() ?? '';

        final phone = company['phone']?.toString().toLowerCase() ?? '';

        return name.contains(searchText) ||
            address.contains(searchText) ||
            phone.contains(searchText);
      }).toList();
    });
  }

  Future<void> openAddCompanyPage() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return AddCompanyPage(apiService: apiService);
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await loadCompanies();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কোম্পানি সফলভাবে তৈরি হয়েছে।')),
      );
    }
  }

  Future<void> openEditCompanyPage(Map<String, dynamic> company) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return EditCompanyPage(apiService: apiService, company: company);
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await loadCompanies();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কোম্পানির তথ্য সফলভাবে আপডেট হয়েছে।')),
      );
    }
  }

  Future<void> deactivateCompany(Map<String, dynamic> company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('কোম্পানি নিষ্ক্রিয় করুন'),
          content: Text(
            'আপনি কি "${company['name']}" কোম্পানিটি নিষ্ক্রিয় করতে চান?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('নিষ্ক্রিয় করুন'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await apiService.updateCompany(
        companyId: company['id'] as int,
        name: company['name']?.toString() ?? '',
        address: company['address']?.toString(),
        phone: company['phone']?.toString(),
        isActive: false,
      );

      if (!mounted) {
        return;
      }

      await loadCompanies();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('কোম্পানি সফলভাবে নিষ্ক্রিয় করা হয়েছে।'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> deleteCompany(Map<String, dynamic> company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('কোম্পানি মুছে ফেলুন'),
          content: Text(
            '"${company['name']}" কোম্পানিটি মুছে ফেললে এটি আর সক্রিয় তালিকায় থাকবে না।\n\nআপনি কি নিশ্চিত?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('মুছে ফেলুন'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await apiService.deleteCompany(companyId: company['id'] as int);

      if (!mounted) {
        return;
      }

      await loadCompanies();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কোম্পানি সফলভাবে মুছে ফেলা হয়েছে।')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> openCompanyDashboard(Map<String, dynamic> company) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CompanyDashboardPage(company: company),
      ),
    );
    if (mounted) await _loadCompanyMonthlyCapital(companies);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('কোম্পানি তালিকা'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'কোম্পানি খুঁজুন',
                hintText: 'নাম, ঠিকানা বা ফোন',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: loadCompanies,
              child: isLoading
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : errorMessage.isNotEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Center(
                          child: ElevatedButton(
                            onPressed: loadCompanies,
                            child: const Text('আবার চেষ্টা করুন'),
                          ),
                        ),
                      ],
                    )
                  : filteredCompanies.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'কোনো কোম্পানি পাওয়া যায়নি।',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filteredCompanies.length,
                      itemBuilder: (context, index) {
                        final company = Map<String, dynamic>.from(
                          filteredCompanies[index],
                        );

                        final address = company['address']?.toString() ?? '';

                        final phone = company['phone']?.toString() ?? '';
                        final companyId = _companyId(company);
                        final contactDetails = [
                          if (address.isNotEmpty) address,
                          if (phone.isNotEmpty) phone,
                        ].join('\n');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: const CircleAvatar(
                              radius: 26,
                              child: Icon(Icons.business, size: 28),
                            ),
                            title: Text(
                              company['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (contactDetails.isNotEmpty)
                                    Text(contactDetails),
                                  if (contactDetails.isNotEmpty)
                                    const SizedBox(height: 8),
                                  _capitalSummaryBadge(companyId),
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await openEditCompanyPage(company);
                                } else if (value == 'deactivate') {
                                  await deactivateCompany(company);
                                } else if (value == 'delete') {
                                  await deleteCompany(company);
                                }
                              },
                              itemBuilder: (context) {
                                return const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 10),
                                        Text('এডিট'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'deactivate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.block),
                                        SizedBox(width: 10),
                                        Text('নিষ্ক্রিয় করুন'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete),
                                        SizedBox(width: 10),
                                        Text('মুছে ফেলুন'),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                            isThreeLine: true,
                            onTap: () => openCompanyDashboard(company),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddCompanyPage,
        icon: const Icon(Icons.add),
        label: const Text('নতুন কোম্পানি যোগ করুন'),
      ),
    );
  }
}

// ============================================================
// ADD COMPANY PAGE
// ============================================================

class AddCompanyPage extends StatefulWidget {
  final ApiService apiService;

  const AddCompanyPage({super.key, required this.apiService});

  @override
  State<AddCompanyPage> createState() => _AddCompanyPageState();
}

class _AddCompanyPageState extends State<AddCompanyPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> saveCompany() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await widget.apiService.createCompany(
        name: nameController.text.trim(),
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন কোম্পানি'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                const Icon(Icons.business, size: 70),

                const SizedBox(height: 20),

                const Text(
                  'নতুন কোম্পানি যোগ করুন',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                TextFormField(
                  controller: nameController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(
                    labelText: 'কোম্পানির নাম',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'কোম্পানির নাম দিন।';
                    }

                    if (value.trim().length > 150) {
                      return 'কোম্পানির নাম সর্বোচ্চ ১৫০ অক্ষরের হতে পারে।';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: addressController,
                  enabled: !isSaving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ঠিকানা',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: phoneController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'ফোন',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : saveCompany,
                    child: isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(),
                          )
                        : const Text(
                            'কোম্পানি যোগ করুন',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text('বাতিল'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EDIT COMPANY PAGE
// ============================================================

class EditCompanyPage extends StatefulWidget {
  final ApiService apiService;
  final Map<String, dynamic> company;

  const EditCompanyPage({
    super.key,
    required this.apiService,
    required this.company,
  });

  @override
  State<EditCompanyPage> createState() => _EditCompanyPageState();
}

class _EditCompanyPageState extends State<EditCompanyPage> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController addressController;
  late final TextEditingController phoneController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.company['name']?.toString() ?? '',
    );

    addressController = TextEditingController(
      text: widget.company['address']?.toString() ?? '',
    );

    phoneController = TextEditingController(
      text: widget.company['phone']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> updateCompany() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await widget.apiService.updateCompany(
        companyId: widget.company['id'] as int,
        name: nameController.text.trim(),
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('কোম্পানি এডিট'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                const Icon(Icons.edit, size: 70),

                const SizedBox(height: 20),

                const Text(
                  'কোম্পানির তথ্য পরিবর্তন করুন',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                TextFormField(
                  controller: nameController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(
                    labelText: 'কোম্পানির নাম',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'কোম্পানির নাম দিন।';
                    }

                    if (value.trim().length > 150) {
                      return 'কোম্পানির নাম সর্বোচ্চ ১৫০ অক্ষরের হতে পারে।';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: addressController,
                  enabled: !isSaving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ঠিকানা',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: phoneController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'ফোন',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : updateCompany,
                    child: isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(),
                          )
                        : const Text(
                            'পরিবর্তন সংরক্ষণ করুন',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text('বাতিল'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
