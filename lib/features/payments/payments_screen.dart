import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../data/model/payment.dart';
import 'edit_payment_dialog.dart';
import 'delete_payment_dialog.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();
  final Set<String> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    final recentPaymentsAsyncValue = ref.watch(recentPaymentsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Tabs
              Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  return AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) {
                      final isDailyTab = tabController.index == 0;
                      
                      final dailyTotal = recentPaymentsAsyncValue.maybeWhen(
                        data: (payments) {
                          final filtered = payments.where((p) {
                            final dt = DateTime.tryParse(p.paymentDate ?? '');
                            if (dt == null) return false;
                            return dt.year == _selectedDate.year && dt.month == _selectedDate.month && dt.day == _selectedDate.day;
                          }).toList();
                          return filtered.fold(0.0, (sum, p) => sum + p.amount);
                        },
                        orElse: () => 0.0,
                      );

                      return SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTabBar(context),
                            if (isDailyTab)
                              Row(
                                children: [
                                  _buildDatePicker(context),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Total: ₹${dailyTotal.toStringAsFixed(0)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(width: 300, child: _buildSearchBar(isSmallScreen)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              Expanded(
                child: recentPaymentsAsyncValue.when(
                  data: (payments) {
                    return TabBarView(
                      children: [
                        _buildDailyPaymentsTab(payments, isSmallScreen),
                        _buildAllPaymentsTab(payments, isSmallScreen),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: 260,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: TabBar(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: primaryColor.withValues(alpha: 0.6),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(text: 'Daily'),
          Tab(text: 'All Payments'),
        ],
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildDailyPaymentsTab(List<Payment> allPayments, bool isSmallScreen) {
    final filtered = allPayments.where((p) {
      final dt = DateTime.tryParse(p.paymentDate ?? '');
      if (dt == null) return false;
      return dt.year == _selectedDate.year && dt.month == _selectedDate.month && dt.day == _selectedDate.day;
    }).toList();

    final primaryColor = Theme.of(context).colorScheme.primary;
    final totalAmount = filtered.fold(0.0, (sum, p) => sum + p.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildPaymentsTable(filtered, isSmallScreen, emptyMessage: 'No payments found for this date.')),
      ],
    );
  }

  Widget _buildAllPaymentsTab(List<Payment> allPayments, bool isSmallScreen) {
    final filtered = allPayments.where((p) => 
      (p.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
      p.schemeId.toString().contains(_searchQuery)
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildPaymentsTable(filtered, isSmallScreen, emptyMessage: 'No payments match your search.')),
      ],
    );
  }

  Widget _buildPaymentsTable(List<Payment> payments, bool isSmallScreen, {required String emptyMessage}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final customersAsyncValue = ref.watch(customersProvider);
    final schemesAsyncValue = ref.watch(allSchemesProvider);

    String getCustomerName(int schemeId) {
      final schemes = schemesAsyncValue.value ?? [];
      final customers = customersAsyncValue.value ?? [];
      try {
        final scheme = schemes.firstWhere((s) => s.id == schemeId);
        final customer = customers.firstWhere((c) => c.id == scheme.customerId);
        return customer.name;
      } catch (e) {
        return 'Unknown';
      }
    }

    if (payments.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: primaryColor.withValues(alpha: 0.1))),
        color: Theme.of(context).cardTheme.color,
        child: Center(child: Text(emptyMessage, style: TextStyle(color: primaryColor.withValues(alpha: 0.5)))),
      );
    }
    
    // Group payments by Customer Name and Date
    final Map<String, List<Payment>> groupedPayments = {};
    for (final payment in payments) {
      final dt = DateTime.parse(payment.paymentDate ?? DateTime.now().toString());
      final dateStr = DateFormat('yyyy-MM-dd').format(dt);
      final customerName = getCustomerName(payment.schemeId);
      final key = '$customerName|$dateStr';
      groupedPayments.putIfAbsent(key, () => []).add(payment);
    }

    final List<DataRow> tableRows = [];

    for (final entry in groupedPayments.entries) {
      final key = entry.key;
      final group = entry.value;

      if (group.length == 1) {
        final payment = group.first;
        final dt = DateTime.parse(payment.paymentDate ?? DateTime.now().toString());
        final modes = payment.paymentModes.map((m) => m.name).join(', ');
        tableRows.add(DataRow(
          cells: [
            DataCell(Text(DateFormat(isSmallScreen ? 'dd MMM yy' : 'dd MMM yyyy, hh:mm a').format(dt))),
            DataCell(Text(payment.schemeId.toString())),
            DataCell(Text('₹ ${payment.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text(modes.toUpperCase())),
            DataCell(Text(getCustomerName(payment.schemeId))),
            DataCell(
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: isSmallScreen ? 18 : 24, color: primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') {
                    showDialog(context: context, builder: (context) => EditPaymentDialog(payment: payment));
                  } else if (value == 'delete') {
                    showDialog(context: context, builder: (context) => DeletePaymentDialog(payment: payment));
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: primaryColor), const SizedBox(width: 8), const Text('Edit')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ),
          ],
        ));
      } else {
        // Parent Row
        final dt = DateTime.parse(group.first.paymentDate ?? DateTime.now().toString());
        final totalAmount = group.fold(0.0, (sum, p) => sum + p.amount);
        final allModes = group.expand((p) => p.paymentModes).toSet().map((m) => m.name).join(', ');
        final customerName = getCustomerName(group.first.schemeId);
        final isExpanded = _expandedGroups.contains(key);

        tableRows.add(DataRow(
          color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.05)),
          cells: [
            DataCell(Text(DateFormat(isSmallScreen ? 'dd MMM yy' : 'dd MMM yyyy').format(dt), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('${group.length} payments', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic))),
            DataCell(Text('₹ ${totalAmount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text(allModes.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(
              IconButton(
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: primaryColor),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedGroups.remove(key);
                    } else {
                      _expandedGroups.add(key);
                    }
                  });
                },
              ),
            ),
          ],
        ));

        // Child Rows
        if (isExpanded) {
          for (final payment in group) {
            final dtChild = DateTime.parse(payment.paymentDate ?? DateTime.now().toString());
            final modesChild = payment.paymentModes.map((m) => m.name).join(', ');
            tableRows.add(DataRow(
              color: WidgetStateProperty.all(Colors.grey[50]),
              cells: [
                DataCell(Padding(padding: const EdgeInsets.only(left: 16), child: Text(DateFormat(isSmallScreen ? 'hh:mm a' : 'dd MMM yyyy, hh:mm a').format(dtChild), style: const TextStyle(color: Colors.grey)))),
                DataCell(Text(payment.schemeId.toString(), style: const TextStyle(color: Colors.grey))),
                DataCell(Text('₹ ${payment.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor.withValues(alpha: 0.7)))),
                DataCell(Text(modesChild.toUpperCase(), style: const TextStyle(color: Colors.grey))),
                DataCell(Text(customerName, style: const TextStyle(color: Colors.grey))),
                DataCell(
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: isSmallScreen ? 18 : 24, color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        showDialog(context: context, builder: (context) => EditPaymentDialog(payment: payment));
                      } else if (value == 'delete') {
                        showDialog(context: context, builder: (context) => DeletePaymentDialog(payment: payment));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: primaryColor), const SizedBox(width: 8), const Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ),
              ],
            ));
          }
        }
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: primaryColor.withValues(alpha: 0.1))),
      color: Theme.of(context).cardTheme.color,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.resolveWith((states) => primaryColor.withValues(alpha: 0.03)),
                  dataRowMinHeight: isSmallScreen ? 48 : 60,
                  dataRowMaxHeight: isSmallScreen ? 48 : 60,
                  headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: primaryColor.withValues(alpha: 0.8), fontSize: isSmallScreen ? 12 : 14),
                  dataTextStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: Colors.black87),
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Scheme ID')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Modes')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: tableRows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(bool isSmallScreen) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search payments...',
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }
}
