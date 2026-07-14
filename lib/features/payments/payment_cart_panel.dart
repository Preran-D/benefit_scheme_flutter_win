import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/model/payment.dart';
import '../../data/model/payment_mode.dart';
import '../../providers/providers.dart';

class PaymentCartPanel extends ConsumerStatefulWidget {
  final VoidCallback onClearAll;
  final VoidCallback onConfirm;

  const PaymentCartPanel({
    super.key,
    required this.onClearAll,
    required this.onConfirm,
  });

  @override
  ConsumerState<PaymentCartPanel> createState() => _PaymentCartPanelState();
}

class _PaymentCartPanelState extends ConsumerState<PaymentCartPanel> {
  int _step = 0;
  DateTime _paymentDate = DateTime.now();
  final Set<PaymentMode> _selectedModes = {PaymentMode.cash};
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _processPayment() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(syncControllerProvider.notifier).syncNow();
      for (final item in cartItems) {
        final schemes = await ref.read(customerSchemesProvider(item.scheme.customerId).future);
        final freshScheme = schemes.firstWhere((s) => s.id == item.scheme.id, orElse: () => item.scheme);
        final status = (freshScheme.status ?? 'active').toLowerCase();
        if (status == 'closed' || status == 'completed') {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot process payment: Scheme #${item.scheme.id} is already $status.')));
          return;
        }
        
        final newTotalPaid = (freshScheme.totalPaid ?? 0.0) + (item.scheme.monthlyAmount * item.months);
        if (newTotalPaid > (item.scheme.monthlyAmount * 12)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot process: Payment for Scheme #${item.scheme.id} exceeds total allowed amount.')));
          return;
        }
      }

      final repo = ref.read(paymentRepositoryProvider);
      
      for (final item in cartItems) {
        final amount = item.scheme.monthlyAmount * item.months;
        final newPayment = Payment(
          schemeId: item.scheme.id!,
          amount: amount,
          paymentModes: _selectedModes.toList(),
          paymentDate: _paymentDate.toIso8601String(),
          notes: 'Months paid: ${item.months}',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await repo.addPayment(newPayment);
      }

      ref.read(cartProvider.notifier).clearCart();
      ref.invalidate(recentPaymentsProvider);
      ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        widget.onConfirm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final cartItems = ref.watch(cartProvider);
    final totalAmount = ref.read(cartProvider.notifier).totalAmount;

    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.grey[50],
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: _step == 0 ? 520 : 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            if (_step == 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${cartItems.length} Scheme${cartItems.length == 1 ? '' : 's'}  •  ₹${totalAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    TextButton(
                      onPressed: widget.onClearAll,
                      style: TextButton.styleFrom(foregroundColor: primaryColor),
                      child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Confirm Payment Details',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Body
            if (_step == 0) ...[
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) => _buildCartItem(context, cartItems[index], ref),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      width: double.infinity,
                      decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Text('Total Amount', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('₹${totalAmount.toStringAsFixed(0)}', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Date Picker
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[300]!)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: primaryColor, size: 28),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Payment Date', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(DateFormat('dd MMM yyyy').format(_paymentDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Mode
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Mode', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: PaymentMode.values.map((mode) {
                              final isSelected = _selectedModes.contains(mode);
                              return ChoiceChip(
                                label: Text(mode.name.toUpperCase()),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedModes.add(mode);
                                    } else {
                                      if (_selectedModes.length > 1) {
                                        _selectedModes.remove(mode);
                                      }
                                    }
                                  });
                                },
                                selectedColor: primaryColor.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? primaryColor : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                checkmarkColor: primaryColor,
                                backgroundColor: Colors.grey[100],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? primaryColor.withValues(alpha: 0.5) : Colors.transparent,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],

            if (_step == 0) Divider(height: 1, color: Colors.grey[200]),

            // Bottom bar
            if (_step == 0) ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(color: Colors.lightGreen[300], borderRadius: BorderRadius.circular(24)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total Amount', style: TextStyle(color: primaryColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: cartItems.isEmpty ? null : () => setState(() => _step = 1),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                      child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => setState(() => _step = 0),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                        child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _processPayment,
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                        child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirm Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final paymentsAsync = ref.watch(schemePaymentsProvider(item.scheme.id!));

    int existingPayments = 0;
    if (paymentsAsync.hasValue) {
      existingPayments = paymentsAsync.value?.length ?? 0;
    }

    final maxMonths = 12 - existingPayments;
    final totalForItem = item.scheme.monthlyAmount * item.months;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Scheme icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 2),
                  Text('${item.scheme.id}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('₹${totalForItem.toStringAsFixed(0)}', style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    ref.read(cartProvider.notifier).removeScheme(item.scheme.id!);
                    if (ref.read(cartProvider).isEmpty) {
                      widget.onClearAll();
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 18),
                  ),
                ),
                const SizedBox(width: 10),

                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (item.months > 1) ref.read(cartProvider.notifier).updateMonths(item.scheme.id!, item.months - 1);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          child: Icon(Icons.remove, size: 16, color: item.months > 1 ? Colors.black54 : Colors.grey[300]),
                        ),
                      ),
                      SizedBox(
                        width: 26,
                        child: Text('${item.months}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (item.months < maxMonths) ref.read(cartProvider.notifier).updateMonths(item.scheme.id!, item.months + 1);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: item.months < maxMonths ? primaryColor : Colors.grey[300]),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
