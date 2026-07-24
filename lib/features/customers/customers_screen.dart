import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../data/model/customer.dart';
import '../../data/model/scheme.dart';
import '../../providers/providers.dart';
import '../payments/payment_cart_panel.dart';
import 'add_customer_screen.dart';
import '../schemes/add_scheme_screen.dart';
import '../schemes/print_preview_dialog.dart';

abstract class ListItem {}

class HeaderItem extends ListItem {
  final String letter;
  HeaderItem(this.letter);
}

class CustomerItem extends ListItem {
  final Customer customer;
  CustomerItem(this.customer);
}

class CustomersScreen extends ConsumerStatefulWidget {
  final String view;
  const CustomersScreen({super.key, this.view = 'list'});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';
  Customer? _selectedCustomer;
  String _schemeStatusFilter = 'all';

  final Set<String> _selectedAddresses = {};
  final Set<String> _expandedAddresses = {};

  Future<void> _bulkAddPay() async {
    final allSchemesAsync = ref.read(allSchemesProvider);
    final customersAsync = ref.read(customersProvider);

    if (allSchemesAsync.value == null || customersAsync.value == null) return;

    for (final address in _selectedAddresses) {
      // Find all customers with this address
      final matchedCustomers = customersAsync.value!
          .where((c) => (c.address ?? 'No Address') == address)
          .toList();
      for (final customer in matchedCustomers) {
        final customerSchemes = allSchemesAsync.value!
            .where(
              (s) =>
                  s.customerId == customer.id &&
                  (s.status?.toLowerCase() != 'completed' &&
                      s.status?.toLowerCase() != 'closed'),
            )
            .toList();
        for (final scheme in customerSchemes) {
          ref.read(cartProvider.notifier).addScheme(customer, scheme);
        }
      }
    }

    setState(() {
      _selectedAddresses.clear();
    });

    _showPaymentCart();
  }

  void _showPaymentCart() {
    showDialog(
      context: context,
      builder: (ctx) => PaymentCartPanel(
        onConfirm: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherit from MainScreen
      body: widget.view == 'summary'
          ? _SummaryTab(
              onCustomerSelected: (customer) {
                setState(() {
                  _selectedCustomer = customer;
                });
                context.go('/customers?view=list');
              },
            )
          : _buildMainCustomersView(),
    );
  }

  Widget _buildMainCustomersView() {
    final cartItems = ref.watch(cartProvider);
    final totalAmount = ref.read(cartProvider.notifier).totalAmount;
    ref.watch(customersProvider);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row with Title, Search, and Add Button
            Row(
              children: [
                SizedBox(
                  width: 450,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_selectedAddresses.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _bulkAddPay,
                          icon: const Icon(Icons.payment, size: 18),
                          label: Text(
                            'Add Pay (${_selectedAddresses.length})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                          ),
                        ),
                      if (_selectedAddresses.isNotEmpty)
                        const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Future.delayed(Duration.zero, () {
                            if (!mounted) return;
                            showDialog(
                              context: context,
                              builder: (_) => const AddCustomerDialog(),
                            );
                          });
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text(
                          'Add Customer',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Split View: 3 Columns
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 1000;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Column: Tabbed View (Customer / Address)
                          Container(
                            width: isSmallScreen
                                ? 340
                                : (constraints.maxWidth * 0.40) - 12,
                            margin: const EdgeInsets.only(right: 24),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              color: Colors.white,
                              clipBehavior: Clip.antiAlias,
                              margin: EdgeInsets.zero,
                              child: DefaultTabController(
                                length: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TabBar(
                                      overlayColor: WidgetStateProperty.all(
                                        Colors.transparent,
                                      ),
                                      indicatorColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      labelColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      unselectedLabelColor: Colors.grey[600],
                                      tabs: const [
                                        Tab(text: 'Customer'),
                                        Tab(text: 'Address'),
                                      ],
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          _buildCustomerTab(),
                                          _buildAddressTab(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Middle Column: Customer Schemes or Placeholder
                          SizedBox(
                            width: isSmallScreen
                                ? 500
                                : constraints.maxWidth -
                                      (constraints.maxWidth * 0.40) -
                                      12 -
                                      24,
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              color: Colors.white,
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: _selectedCustomer != null
                                  ? _CustomerSchemesPanel(
                                      customer: _selectedCustomer!,
                                      schemeStatusFilter: _schemeStatusFilter,
                                      onSchemeStatusFilterChanged: (filter) =>
                                          setState(() {
                                            _schemeStatusFilter = filter;
                                          }),
                                      onRecordPaymentRequested: (scheme) {
                                        Future.delayed(Duration.zero, () {
                                          ref
                                              .read(cartProvider.notifier)
                                              .addScheme(
                                                _selectedCustomer!,
                                                scheme,
                                              );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Scheme added to cart!',
                                              ),
                                            ),
                                          );
                                        });
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_search_rounded,
                                            size: 80,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'Select a Customer',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Choose a customer from the list to view their schemes',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        if (cartItems.isNotEmpty)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(32),
                color: Theme.of(context).colorScheme.primary,
                child: InkWell(
                  onTap: _showPaymentCart,
                  borderRadius: BorderRadius.circular(32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cartItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Schemes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '₹${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerTab() {
    final customersAsyncValue = ref.watch(customersProvider);
    return customersAsyncValue.when(
      data: (customers) {
        final filtered = customers
            .where(
              (c) =>
                  c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (c.phone != null && c.phone!.contains(_searchQuery)),
            )
            .toList();

        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No customers found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        List<ListItem> listItems = [];
        String currentLetter = '';
        for (var customer in filtered) {
          String firstLetter = customer.name.isNotEmpty
              ? customer.name[0].toUpperCase()
              : '';
          if (firstLetter != currentLetter) {
            listItems.add(HeaderItem(firstLetter));
            currentLetter = firstLetter;
          }
          listItems.add(CustomerItem(customer));
        }

        return ListView.builder(
          itemCount: listItems.length,
          itemBuilder: (context, index) {
            final item = listItems[index];

            if (item is HeaderItem) {
              return Container(
                padding: const EdgeInsets.only(left: 24, top: 16, bottom: 8),
                color: Colors.grey[50],
                child: Text(
                  item.letter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            } else if (item is CustomerItem) {
              final customer = item.customer;
              final isSelected = _selectedCustomer?.id == customer.id;

              return Column(
                children: [
                  ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.only(
                      left: 24,
                      right: 8,
                      top: 4,
                      bottom: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[200],
                      foregroundColor: isSelected
                          ? Colors.white
                          : Colors.grey[700],
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      customer.phone ?? 'No phone',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCustomer = customer;
                      });
                    },
                    trailing: _CustomerActionMenu(customer: customer),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildAddressTab() {
    final customersAsyncValue = ref.watch(customersProvider);
    final allSchemesAsync = ref.watch(allSchemesProvider);

    return customersAsyncValue.when(
      data: (customers) {
        final schemes = allSchemesAsync.value ?? [];

        final filtered = customers
            .where(
              (c) =>
                  c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (c.address != null &&
                      c.address!.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      )),
            )
            .toList();

        // Group by address
        final Map<String, List<Customer>> groupedByAddress = {};
        for (var customer in filtered) {
          final address =
              (customer.address == null || customer.address!.trim().isEmpty)
              ? 'No Address'
              : customer.address!;
          groupedByAddress.putIfAbsent(address, () => []).add(customer);
        }

        if (groupedByAddress.isEmpty) {
          return const Center(
            child: Text(
              'No addresses found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final sortedAddresses = groupedByAddress.keys.toList()..sort();

        return ListView.builder(
          itemCount: sortedAddresses.length,
          itemBuilder: (context, index) {
            final address = sortedAddresses[index];
            final groupCustomers = groupedByAddress[address]!;
            final isExpanded = _expandedAddresses.contains(address);
            final isChecked = _selectedAddresses.contains(address);

            return Column(
              children: [
                Container(
                  color: isExpanded ? Colors.grey[50] : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Checkbox(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedAddresses.add(address);
                          } else {
                            _selectedAddresses.remove(address);
                          }
                        });
                      },
                      activeColor: Colors.green[800],
                    ),
                    title: Text(
                      address,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green[900],
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.green[800],
                      ),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedAddresses.remove(address);
                          } else {
                            _expandedAddresses.add(address);
                          }
                        });
                      },
                    ),
                  ),
                ),
                if (isExpanded)
                  ...groupCustomers.expand((customer) {
                    final customerSchemes = schemes
                        .where(
                          (s) =>
                              s.customerId == customer.id &&
                              (s.status?.toLowerCase() != 'completed' &&
                                  s.status?.toLowerCase() != 'closed'),
                        )
                        .toList();
                    if (customerSchemes.isEmpty) {
                      return [
                        ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 72,
                            right: 24,
                          ),
                          title: Text(
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'No active schemes',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCustomer = customer;
                            });
                          },
                        ),
                      ];
                    }
                    return customerSchemes.map((scheme) {
                      final isSelected = _selectedCustomer?.id == customer.id;
                      final startDate = scheme.createdAt != null
                          ? 'Started on ${DateFormat('dd MMM yyyy').format(DateTime.parse(scheme.createdAt!))}'
                          : '';
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.only(
                          left: 72,
                          right: 24,
                          top: 4,
                          bottom: 4,
                        ),
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green[50],
                              child: Text(
                                customer.name.isNotEmpty
                                    ? customer.name[0].toUpperCase()
                                    : '',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '₹${scheme.monthlyAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 44.0),
                          child: Text(
                            startDate,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCustomer = customer;
                          });
                        },
                      );
                    });
                  }),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _CustomerSchemesPanel extends ConsumerStatefulWidget {
  final Customer customer;
  final String schemeStatusFilter;
  final Function(String) onSchemeStatusFilterChanged;
  final Function(Scheme) onRecordPaymentRequested;

  const _CustomerSchemesPanel({
    required this.customer,
    required this.schemeStatusFilter,
    required this.onSchemeStatusFilterChanged,
    required this.onRecordPaymentRequested,
  });

  @override
  ConsumerState<_CustomerSchemesPanel> createState() =>
      _CustomerSchemesPanelState();
}

class _CustomerSchemesPanelState extends ConsumerState<_CustomerSchemesPanel> {
  bool _isTableView = false;

  @override
  Widget build(BuildContext context) {
    final schemesAsync = ref.watch(
      customerSchemesProvider(widget.customer.id!),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[100],
                child: Text(
                  widget.customer.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.customer.phone ?? 'N/A',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Future.delayed(Duration.zero, () {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) =>
                          AddSchemeDialog(customer: widget.customer),
                    );
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Scheme'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Schemes List
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Schemes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Status: ',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.schemeStatusFilter,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('Closed'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            widget.onSchemeStatusFilterChanged(val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.grid_view_rounded,
                            size: 16,
                            color: !_isTableView
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[500],
                          ),
                          onPressed: () => setState(() => _isTableView = false),
                          tooltip: 'Card View',
                        ),
                        Container(
                          width: 1,
                          height: 16,
                          color: Colors.grey[300],
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.table_chart_rounded,
                            size: 16,
                            color: _isTableView
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[500],
                          ),
                          onPressed: () => setState(() => _isTableView = true),
                          tooltip: 'Table View',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: schemesAsync.when(
            data: (schemes) {
              final filteredSchemes = widget.schemeStatusFilter == 'all'
                  ? schemes
                  : schemes
                        .where(
                          (s) =>
                              (s.status ?? 'active').toLowerCase() ==
                              widget.schemeStatusFilter.toLowerCase(),
                        )
                        .toList();

              if (filteredSchemes.isEmpty) {
                return Center(
                  child: Text(
                    'No ${widget.schemeStatusFilter} schemes found.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              if (_isTableView) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = constraints.maxWidth > 800
                        ? constraints.maxWidth
                        : 800.0;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          itemCount: filteredSchemes.length + 1,
                          separatorBuilder: (context, index) => index == 0
                              ? const SizedBox(height: 0)
                              : Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Container(
                                color: Colors.grey[800],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'SL',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Scheme',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Started',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Total Paid',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Status',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Actions',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final scheme = filteredSchemes[index - 1];
                            return _SchemeTableRow(
                              index: index,
                              scheme: scheme,
                              customer: widget.customer,
                              onRecordPaymentRequested: () =>
                                  widget.onRecordPaymentRequested(scheme),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              }

              final activeSchemes = filteredSchemes
                  .where(
                    (s) => (s.status ?? 'active').toLowerCase() == 'active',
                  )
                  .toList();
              final completedSchemes = filteredSchemes
                  .where(
                    (s) => (s.status ?? 'active').toLowerCase() == 'completed',
                  )
                  .toList();
              final closedSchemes = filteredSchemes
                  .where(
                    (s) => (s.status ?? 'active').toLowerCase() == 'closed',
                  )
                  .toList();

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                children: [
                  if (activeSchemes.isNotEmpty)
                    _buildSchemeGroup(
                      'Active Schemes',
                      activeSchemes,
                      true,
                      Colors.green,
                    ),
                  if (completedSchemes.isNotEmpty)
                    _buildSchemeGroup(
                      'Completed Schemes',
                      completedSchemes,
                      false,
                      Colors.blue,
                    ),
                  if (closedSchemes.isNotEmpty)
                    _buildSchemeGroup(
                      'Closed Schemes',
                      closedSchemes,
                      false,
                      Colors.red,
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildSchemeGroup(
    String title,
    List<Scheme> schemes,
    bool initiallyExpanded,
    Color color,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${schemes.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: schemes.map((scheme) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SchemeCard(
              scheme: scheme,
              customer: widget.customer,
              onRecordPaymentRequested: () =>
                  widget.onRecordPaymentRequested(scheme),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Small icon + label action button used in scheme list rows.
class _SchemeActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _SchemeActionButton({
    required this.icon,
    this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Future.delayed(Duration.zero, onTap),
      child: Container(
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
            : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 5),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              )
            : Icon(icon, size: 18, color: color),
      ),
    );
  }
}

/// Dialog that shows the payment history for a scheme.
class _SchemeHistoryDialog extends ConsumerWidget {
  final Scheme scheme;
  const _SchemeHistoryDialog({required this.scheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final paymentsAsync = ref.watch(schemePaymentsProvider(scheme.id!));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Static header — always visible immediately ──────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${scheme.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scheme #${scheme.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${scheme.monthlyAmount.toStringAsFixed(0)} / month  •  Payment History',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Static summary chips row — skeleton while loading ───────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: paymentsAsync.when(
                data: (payments) {
                  final totalPaid = payments.fold(0.0, (s, p) => s + p.amount);
                  return Row(
                    children: [
                      _InfoChip(
                        label: '${payments.length} payments',
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        label: '₹${totalPaid.toStringAsFixed(0)} total',
                        color: Colors.green[700]!,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        label: '${12 - payments.length} left',
                        color: Colors.orange[700]!,
                      ),
                    ],
                  );
                },
                loading: () => Row(
                  children: [
                    _SkeletonChip(),
                    const SizedBox(width: 8),
                    _SkeletonChip(),
                    const SizedBox(width: 8),
                    _SkeletonChip(),
                  ],
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            // ── Table header — always visible ───────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFD3EBC6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            // ── Table body — loading indicator only here ─────────────────
            Flexible(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF8BA582)),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: paymentsAsync.when(
                  data: (payments) {
                    if (payments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No payments recorded yet',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: payments.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: const Color(0xFF8BA582).withValues(alpha: 0.4),
                      ),
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        String formattedDate = payment.paymentDate ?? 'Unknown';
                        try {
                          if (payment.paymentDate != null) {
                            formattedDate = DateFormat(
                              'dd MMM yyyy',
                            ).format(DateTime.parse(payment.paymentDate!));
                          }
                        } catch (_) {}
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '₹${payment.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 32),
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 14),
                        Text(
                          'Loading payments…',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        SizedBox(height: 32),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder chip shown while payments are loading.
class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _CloseSchemeDialog extends StatefulWidget {
  final Scheme scheme;
  const _CloseSchemeDialog({required this.scheme});

  @override
  State<_CloseSchemeDialog> createState() => _CloseSchemeDialogState();
}

class _CloseSchemeDialogState extends State<_CloseSchemeDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    DateTime minDate = DateTime(2020);
    if (widget.scheme.lastPaymentDate != null) {
      minDate = DateTime.parse(widget.scheme.lastPaymentDate!);
    } else if (widget.scheme.createdAt != null) {
      minDate = DateTime.parse(widget.scheme.createdAt!);
    }
    if (_selectedDate.isBefore(minDate)) {
      _selectedDate = minDate;
    }
    final maxDate = DateTime.now();
    if (_selectedDate.isAfter(maxDate)) {
      _selectedDate = maxDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Close Scheme',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to close Scheme #${widget.scheme.id}? This cannot be undone.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Closing Date',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              DateTime minDate = DateTime(2020);
              if (widget.scheme.lastPaymentDate != null) {
                minDate = DateTime.parse(widget.scheme.lastPaymentDate!);
              } else if (widget.scheme.createdAt != null) {
                minDate = DateTime.parse(widget.scheme.createdAt!);
              }

              final maxDate = DateTime.now();
              if (minDate.isAfter(maxDate)) {
                minDate = maxDate; // fallback safety
              }

              if (_selectedDate.isBefore(minDate)) {
                _selectedDate = minDate;
              }

              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: minDate,
                lastDate: maxDate,
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          // Use the dialog's context correctly here to avoid !_debugLocked error
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(_selectedDate),
          child: const Text('Confirm Close'),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green[600]!;
        break;
      case 'closed':
        color = Colors.red[600]!;
        break;
      case 'completed':
        color = Colors.blue[600]!;
        break;
      default:
        color = Colors.grey[600]!;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SchemeCard extends ConsumerWidget {
  final Scheme scheme;
  final Customer customer;
  final VoidCallback onRecordPaymentRequested;

  const _SchemeCard({
    required this.scheme,
    required this.customer,
    required this.onRecordPaymentRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    ref.watch(schemePaymentsProvider(scheme.id!));
    final status = (scheme.status ?? 'active').toLowerCase();

    final dateStr = scheme.createdAt != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(scheme.createdAt!))
        : 'Unknown Date';

    final closedDateStr = scheme.closedDate != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(scheme.closedDate!))
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Scheme icon with ID
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '${scheme.id}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${scheme.monthlyAmount.toStringAsFixed(0)} / month',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatusBadge(status: status),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        closedDateStr != null
                            ? '•  Started $dateStr • Closed $closedDateStr'
                            : '•  Started $dateStr',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons row (dynamically rendered based on payment count)
          _SchemeActionsRow(
            scheme: scheme,
            customer: customer,
            status: status,
            onRecordPaymentRequested: onRecordPaymentRequested,
          ),
        ],
      ),
    );
  }
}

class _SchemeTableRow extends StatelessWidget {
  final int index;
  final Scheme scheme;
  final Customer customer;
  final VoidCallback onRecordPaymentRequested;

  const _SchemeTableRow({
    required this.index,
    required this.scheme,
    required this.customer,
    required this.onRecordPaymentRequested,
  });

  @override
  Widget build(BuildContext context) {
    final status = (scheme.status ?? 'active').toLowerCase();
    final dateStr = scheme.createdAt != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(scheme.createdAt!))
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$index',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '#${scheme.id}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(dateStr, style: TextStyle(color: Colors.grey[700])),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '₹${(scheme.totalPaid ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              status == 'active'
                  ? 'Active'
                  : (status == 'closed' ? 'Closed' : 'Completed'),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: status == 'closed' ? Colors.red[800] : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: _SchemeActionsRow(
                scheme: scheme,
                customer: customer,
                status: status,
                onRecordPaymentRequested: onRecordPaymentRequested,
                iconOnly: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeActionsRow extends ConsumerWidget {
  final Scheme scheme;
  final Customer customer;
  final String status;
  final VoidCallback onRecordPaymentRequested;
  final bool iconOnly;

  const _SchemeActionsRow({
    required this.scheme,
    required this.customer,
    required this.status,
    required this.onRecordPaymentRequested,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final paymentsAsync = ref.watch(schemePaymentsProvider(scheme.id!));

    return paymentsAsync.when(
      data: (payments) {
        final paymentCount = payments.length;
        final canEditOrDelete = paymentCount == 0;
        final isClosedOrCompleted = status == 'closed' || status == 'completed';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pay button
            if (!isClosedOrCompleted) ...[
              _SchemeActionButton(
                icon: Icons.add_card_rounded,
                label: iconOnly
                    ? null
                    : (paymentCount == 0 ? 'Add First Payment' : 'Pay'),
                color: primaryColor,
                onTap: () async {
                  // Pre-validation
                  await ref.read(syncControllerProvider.notifier).syncNow();
                  final schemes = await ref.read(
                    customerSchemesProvider(scheme.customerId).future,
                  );

                  final freshScheme = schemes.firstWhere(
                    (s) => s.id == scheme.id,
                    orElse: () => scheme,
                  );
                  final freshStatus = (freshScheme.status ?? 'active')
                      .toLowerCase();
                  if (freshStatus == 'closed' || freshStatus == 'completed') {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cannot pay: This scheme was recently closed.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  onRecordPaymentRequested();
                },
              ),
              const SizedBox(width: 8),
            ],
            // Reopen scheme button
            if (status == 'closed') ...[
              _SchemeActionButton(
                icon: Icons.restore_rounded,
                label: iconOnly ? null : 'Reopen',
                color: Colors.green[600]!,
                onTap: () async {
                  // Pre-validation
                  await ref.read(syncControllerProvider.notifier).syncNow();
                  final schemes = await ref.read(
                    customerSchemesProvider(scheme.customerId).future,
                  );

                  final freshScheme = schemes.firstWhere(
                    (s) => s.id == scheme.id,
                    orElse: () => scheme,
                  );
                  final freshStatus = (freshScheme.status ?? 'active')
                      .toLowerCase();
                  if (freshStatus != 'closed') {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cannot reopen: This scheme is not closed.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  if (context.mounted) {
                    try {
                      final repo = ref.read(schemeRepositoryProvider);
                      await repo.updateSchemeStatus(
                        scheme.id!,
                        'active',
                        clearClosedDate: true,
                      );
                      await ref
                          .read(syncControllerProvider.notifier)
                          .syncNow(); // Post-sync
                    } catch (e) {
                      if (context.mounted) {
                        String errorMsg = e.toString();
                        if (errorMsg.contains('PostgrestException')) {
                          final match = RegExp(
                            r'message:\s*([^,]+)',
                          ).firstMatch(errorMsg);
                          if (match != null) errorMsg = match.group(1)!;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $errorMsg')),
                        );
                      }
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            // History button (only if >0 payments)
            if (paymentCount > 0) ...[
              _SchemeActionButton(
                icon: Icons.history_rounded,
                label: iconOnly ? null : 'History',
                color: Colors.blue[700]!,
                onTap: () async {
                  await ref.read(syncControllerProvider.notifier).syncNow();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => _SchemeHistoryDialog(scheme: scheme),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            // Print button (icon-only)
            _SchemeActionButton(
              icon: Icons.print_rounded,
              color: Colors.teal[700]!,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      PrintPreviewDialog(customer: customer, scheme: scheme),
                );
              },
            ),
            const SizedBox(width: 8),
            // Close scheme button
            if (status != 'closed' && paymentCount > 0) ...[
              _SchemeActionButton(
                icon: Icons.block_rounded,
                label: iconOnly ? null : 'Close',
                color: Colors.red[600]!,
                onTap: () async {
                  // Pre-validation
                  await ref.read(syncControllerProvider.notifier).syncNow();
                  final schemes = await ref.read(
                    customerSchemesProvider(scheme.customerId).future,
                  );

                  final freshScheme = schemes.firstWhere(
                    (s) => s.id == scheme.id,
                    orElse: () => scheme,
                  );
                  final freshStatus = (freshScheme.status ?? 'active')
                      .toLowerCase();
                  if (freshStatus == 'closed') {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cannot close: This scheme is already closed.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  if (context.mounted) {
                    final result = await showDialog<DateTime?>(
                      context: context,
                      builder: (_) => _CloseSchemeDialog(scheme: scheme),
                    );
                    if (result != null) {
                      try {
                        final repo = ref.read(schemeRepositoryProvider);
                        await repo.updateSchemeStatus(
                          scheme.id!,
                          'closed',
                          closedDate: result.toIso8601String(),
                        );
                        await ref
                            .read(syncControllerProvider.notifier)
                            .syncNow(); // Post-sync
                      } catch (e) {
                        if (context.mounted) {
                          String errorMsg = e.toString();
                          if (errorMsg.contains('PostgrestException')) {
                            final match = RegExp(
                              r'message:\s*([^,]+)',
                            ).firstMatch(errorMsg);
                            if (match != null) errorMsg = match.group(1)!;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $errorMsg')),
                          );
                        }
                      }
                    }
                  }
                },
              ),
              const SizedBox(width: 4),
            ],
            // Menu for Edit/Delete
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'More options',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  await ref.read(syncControllerProvider.notifier).syncNow();
                  final payments = await ref.read(
                    schemePaymentsProvider(scheme.id!).future,
                  );

                  DateTime? firstPaymentDate;
                  if (payments.isNotEmpty) {
                    final validPayments = payments
                        .where((p) => p.paymentDate != null)
                        .toList();
                    if (validPayments.isNotEmpty) {
                      validPayments.sort(
                        (a, b) => DateTime.parse(
                          a.paymentDate!,
                        ).compareTo(DateTime.parse(b.paymentDate!)),
                      );
                      firstPaymentDate = DateTime.parse(
                        validPayments.first.paymentDate!,
                      );
                    }
                  }

                  if (context.mounted) {
                    await showDialog(
                      context: context,
                      builder: (_) => _EditSchemeDialog(
                        scheme: scheme,
                        hasPayments: payments.isNotEmpty,
                        firstPaymentDate: firstPaymentDate,
                      ),
                    );
                    await ref
                        .read(syncControllerProvider.notifier)
                        .syncNow(); // Post-sync
                  }
                } else if (value == 'delete') {
                  if (!canEditOrDelete) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cannot delete scheme with existing payments',
                        ),
                      ),
                    );
                    return;
                  }

                  await ref.read(syncControllerProvider.notifier).syncNow();
                  final payments = await ref.read(
                    schemePaymentsProvider(scheme.id!).future,
                  );

                  if (payments.isNotEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cannot delete: A payment was recently added on another device.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  if (context.mounted) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Delete Scheme?'),
                        content: const Text(
                          'Are you sure you want to delete this scheme? This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(dialogCtx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(schemeRepositoryProvider)
                          .deleteScheme(scheme.id!);
                      await ref
                          .read(syncControllerProvider.notifier)
                          .syncNow(); // Post-sync
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  enabled: true,
                  child: const Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: canEditOrDelete,
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox(),
    );
  }
}

class _EditSchemeDialog extends ConsumerStatefulWidget {
  final Scheme scheme;
  final bool hasPayments;
  final DateTime? firstPaymentDate;
  const _EditSchemeDialog({
    required this.scheme,
    required this.hasPayments,
    this.firstPaymentDate,
  });
  @override
  ConsumerState<_EditSchemeDialog> createState() => _EditSchemeDialogState();
}

class _EditSchemeDialogState extends ConsumerState<_EditSchemeDialog> {
  late TextEditingController _amountController;
  late DateTime _startedDate;
  final _formKey = GlobalKey<FormState>();
  final List<double> _suggestions = [500, 1000, 2000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.scheme.monthlyAmount.toStringAsFixed(0),
    );
    _startedDate = widget.scheme.createdAt != null
        ? DateTime.parse(widget.scheme.createdAt!)
        : DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Edit Scheme',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hasPayments)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.amber[800],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amount locked: Delete the payments first to change the scheme amount.',
                        style: TextStyle(
                          color: Colors.amber[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextFormField(
              controller: _amountController,
              enabled: !widget.hasPayments,
              decoration: InputDecoration(
                labelText: 'Monthly Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: widget.hasPayments,
                fillColor: widget.hasPayments ? Colors.grey[100] : null,
              ),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                final amount = double.tryParse(val);
                if (amount == null) return 'Invalid';
                if (amount < 500) return 'Min ₹500';
                if (amount % 100 != 0) return 'Must be multiple of ₹100';
                return null;
              },
              onChanged: (val) => setState(() {}),
            ),
            if (!widget.hasPayments) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((amount) {
                  final isSelected =
                      _amountController.text == amount.toStringAsFixed(0);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _amountController.text = amount.toStringAsFixed(0);
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Started Date',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final maxDate = widget.firstPaymentDate ?? DateTime.now();
                final safeMaxDate = maxDate.isBefore(DateTime.now())
                    ? maxDate
                    : DateTime.now();

                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startedDate.isBefore(safeMaxDate)
                      ? _startedDate
                      : safeMaxDate,
                  firstDate: DateTime(2020),
                  lastDate: safeMaxDate,
                );
                if (picked != null) setState(() => _startedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMM yyyy').format(_startedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final amount = double.parse(_amountController.text);
            await ref
                .read(schemeRepositoryProvider)
                .updateScheme(
                  widget.scheme.id!,
                  amount,
                  _startedDate.toIso8601String(),
                );
            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}

/// A stateful action menu that checks payment history before allowing deletion.
class _CustomerActionMenu extends ConsumerStatefulWidget {
  final Customer customer;
  const _CustomerActionMenu({required this.customer});

  @override
  ConsumerState<_CustomerActionMenu> createState() =>
      _CustomerActionMenuState();
}

class _CustomerActionMenuState extends ConsumerState<_CustomerActionMenu> {
  bool? _hasPayments;

  @override
  void initState() {
    super.initState();
    _checkPayments();
  }

  Future<void> _checkPayments() async {
    if (widget.customer.id == null) return;
    final result = await ref
        .read(customerRepositoryProvider)
        .hasPayments(widget.customer.id!);
    if (mounted) setState(() => _hasPayments = result);
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer?'),
        content: Text(
          'Are you sure you want to delete "${widget.customer.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(customerRepositoryProvider)
            .deleteCustomer(widget.customer.id!);
        await ref.read(syncControllerProvider.notifier).syncNow();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${widget.customer.name}" deleted.'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
      splashRadius: 20,
      onSelected: (value) {
        if (value == 'edit') {
          Future.delayed(Duration.zero, () {
            if (!context.mounted) return;
            showDialog(
              context: context,
              builder: (context) =>
                  AddCustomerDialog(editingCustomer: widget.customer),
            );
          });
        } else if (value == 'delete') {
          _confirmAndDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              const Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          enabled: _hasPayments == false, // disabled if true or null
          child: Tooltip(
            message: _hasPayments == true
                ? 'Cannot delete: customer has payment history'
                : '',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: _hasPayments == false
                      ? Colors.red[400]
                      : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: _hasPayments == false
                        ? Colors.red[400]
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryTab extends ConsumerStatefulWidget {
  final Function(Customer) onCustomerSelected;
  const _SummaryTab({required this.onCustomerSelected});

  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  String _searchQuery = '';
  int _sortColumnIndex = 1; // Default to Customer Name
  bool _sortAscending = true; // A-Z

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  Widget _buildHeaderCell(String label, int flex, int columnIndex) {
    final isSortedColumn = _sortColumnIndex == columnIndex;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onSort(columnIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isSortedColumn) ...[
                const SizedBox(width: 4),
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schemesAsync = ref.watch(allSchemesProvider);
    final customersAsync = ref.watch(customersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by Customer or Scheme #...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 20,
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: schemesAsync.when(
              data: (schemes) {
                return customersAsync.when(
                  data: (customers) {
                    // Create customer map for O(1) lookup
                    final customerMap = {for (var c in customers) c.id: c};

                    // Filter schemes
                    final filteredSchemes = schemes.where((s) {
                      final c = customerMap[s.customerId];
                      final cName = c?.name.toLowerCase() ?? '';
                      final schemeIdStr = s.id?.toString() ?? '';
                      final query = _searchQuery.toLowerCase();
                      return cName.contains(query) ||
                          schemeIdStr.contains(query);
                    }).toList();
                    // Sort schemes dynamically
                    filteredSchemes.sort((a, b) {
                      final cA = customerMap[a.customerId];
                      final cB = customerMap[b.customerId];
                      int comparison = 0;

                      switch (_sortColumnIndex) {
                        case 0: // SL
                        case 2: // Scheme ID
                          comparison = (a.id ?? 0).compareTo(b.id ?? 0);
                          break;
                        case 1: // Customer Name
                          comparison = (cA?.name ?? '').compareTo(
                            cB?.name ?? '',
                          );
                          break;
                        case 3: // Started Date
                          comparison = (a.createdAt ?? '').compareTo(
                            b.createdAt ?? '',
                          );
                          break;
                        case 4: // Months
                          final monthsA = a.monthlyAmount > 0
                              ? (a.totalPaid ?? 0) / a.monthlyAmount
                              : 0;
                          final monthsB = b.monthlyAmount > 0
                              ? (b.totalPaid ?? 0) / b.monthlyAmount
                              : 0;
                          comparison = monthsA.compareTo(monthsB);
                          break;
                        case 5: // Total Paid
                          comparison = (a.totalPaid ?? 0).compareTo(
                            b.totalPaid ?? 0,
                          );
                          break;
                        case 6: // Status
                          comparison = (a.status ?? '').compareTo(
                            b.status ?? '',
                          );
                          break;
                        case 7: // Closed Date
                          comparison = (a.closedDate ?? '').compareTo(
                            b.closedDate ?? '',
                          );
                          break;
                      }

                      return _sortAscending ? comparison : -comparison;
                    });

                    if (filteredSchemes.isEmpty) {
                      return const Center(
                        child: Text(
                          'No schemes found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table Header
                        Container(
                          color: Colors.grey[800],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              _buildHeaderCell('SL', 1, 0),
                              _buildHeaderCell('Customer Name', 3, 1),
                              _buildHeaderCell('Scheme', 1, 2),
                              _buildHeaderCell('Started', 2, 3),
                              _buildHeaderCell('Months', 2, 4),
                              _buildHeaderCell('Total Paid', 2, 5),
                              _buildHeaderCell('Status', 1, 6),
                              _buildHeaderCell('Closed Date', 2, 7),
                            ],
                          ),
                        ),
                        // Table Body
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredSchemes.length,
                            itemBuilder: (context, index) {
                              final scheme = filteredSchemes[index];
                              final c = customerMap[scheme.customerId];
                              final cName = c?.name ?? 'Unknown';

                              final dateStr = scheme.createdAt != null
                                  ? DateFormat(
                                      'dd MMM yyyy',
                                    ).format(DateTime.parse(scheme.createdAt!))
                                  : '-';

                              final closedDateStr = scheme.closedDate != null
                                  ? DateFormat(
                                      'dd MMM yyyy',
                                    ).format(DateTime.parse(scheme.closedDate!))
                                  : '-';

                              final status = (scheme.status ?? 'active')
                                  .toLowerCase();
                              final bgColor = status == 'active'
                                  ? const Color(0xFFE8F8F5) // light green tint
                                  : status == 'closed'
                                  ? const Color(0xFFFDEDED) // light red tint
                                  : Colors.white;

                              final monthsPaid = scheme.monthlyAmount > 0
                                  ? (scheme.totalPaid ?? 0) /
                                        scheme.monthlyAmount
                                  : 0;
                              final monthsStr = '${monthsPaid.toInt()} / 12';

                              return InkWell(
                                onTap: c != null
                                    ? () => widget.onCustomerSelected(c)
                                    : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          cName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '#${scheme.id}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          dateStr,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          monthsStr,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '₹${(scheme.totalPaid ?? 0).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          status == 'active'
                                              ? 'Active'
                                              : (status == 'closed'
                                                    ? 'Closed'
                                                    : 'Completed'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: status == 'closed'
                                                ? Colors.red[800]
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          closedDateStr,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
      ],
    );
  }
}
