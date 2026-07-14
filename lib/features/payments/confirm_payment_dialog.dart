import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/model/payment.dart';
import '../../data/model/payment_mode.dart';
import '../../providers/providers.dart';

class ConfirmPaymentDialog extends ConsumerStatefulWidget {
  final List<CartItem> items;

  const ConfirmPaymentDialog({
    Key? key,
    required this.items,
  }) : super(key: key);

  @override
  ConsumerState<ConfirmPaymentDialog> createState() => _ConfirmPaymentDialogState();
}

class _ConfirmPaymentDialogState extends ConsumerState<ConfirmPaymentDialog> {
  DateTime _paymentDate = DateTime.now();
  PaymentMode _selectedMode = PaymentMode.cash;
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Pre-validation: ensure schemes are not closed/completed
      await ref.read(syncControllerProvider.notifier).syncNow();
      for (final item in widget.items) {
        final schemes = await ref.read(customerSchemesProvider(item.scheme.customerId).future);
        final freshScheme = schemes.firstWhere((s) => s.id == item.scheme.id, orElse: () => item.scheme);
        final status = (freshScheme.status ?? 'active').toLowerCase();
        if (status == 'closed' || status == 'completed') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot process payment: Scheme #${item.scheme.id} is already $status.')));
          }
          return;
        }
        
        final newTotalPaid = (freshScheme.totalPaid ?? 0.0) + (item.scheme.monthlyAmount * item.months);
        if (newTotalPaid > (item.scheme.monthlyAmount * 12)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot process payment: Scheme #${item.scheme.id} cannot exceed 12 months of payments.')));
          }
          return;
        }
        
        if (item.scheme.monthlyAmount <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot process payment: Invalid amount.')));
          }
          return;
        }
      }

      final repo = ref.read(paymentRepositoryProvider);
      final schemeRepo = ref.read(schemeRepositoryProvider);
      Payment? lastSavedPayment;
      
      for (final item in widget.items) {
        final monthlyAmount = item.scheme.monthlyAmount;
        for (int i = 1; i <= item.months; i++) {
          final newPayment = Payment(
            schemeId: item.scheme.id!,
            amount: monthlyAmount,
            paymentModes: [_selectedMode],
            paymentDate: _paymentDate.toIso8601String(),
            notes: item.months > 1 ? 'Month $i payment' : 'Monthly payment',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          );

          lastSavedPayment = await repo.addPayment(newPayment);
        }
        
        final newTotalPaid = (item.scheme.totalPaid ?? 0.0) + (monthlyAmount * item.months);
        final isCompleted = newTotalPaid >= (monthlyAmount * 12);
        
        await schemeRepo.updateSchemeTotals(
          item.scheme.id!, 
          newTotalPaid, 
          _paymentDate.toIso8601String()
        );
        
        if (isCompleted && item.scheme.status != 'completed') {
          await schemeRepo.updateSchemeStatus(
            item.scheme.id!, 
            'completed', 
            closedDate: DateTime.now().toIso8601String()
          );
        }
      }
      
      await ref.read(syncControllerProvider.notifier).syncNow(); // Post-sync everything
      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        context.pop(lastSavedPayment); // returns the payment to the caller
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.grey[50], // light grey background like image
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm Payment Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.items.fold(0.0, (sum, item) => sum + (item.scheme.monthlyAmount * item.months)).toStringAsFixed(0)}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: primaryColor, size: 28),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Date', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(_paymentDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Mode Title
            const Text(
              'Payment Mode',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),

            // Segmented Payment Modes
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  _buildModeOption('Cash', Icons.currency_rupee, PaymentMode.cash, Colors.green),
                  _buildVerticalDivider(),
                  _buildModeOption('Upi', Icons.g_mobiledata, PaymentMode.upi, Colors.blue),
                  _buildVerticalDivider(),
                  _buildModeOption('Card', Icons.credit_card, PaymentMode.card, Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Total Payable
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.lightGreen[200], // light green box
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Payable', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${widget.items.fold(0.0, (sum, item) => sum + (item.scheme.monthlyAmount * item.months)).toStringAsFixed(0)}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            ElevatedButton(
              onPressed: _isLoading ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Confirm ₹${widget.items.fold(0.0, (sum, item) => sum + (item.scheme.monthlyAmount * item.months)).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey[300],
    );
  }

  Widget _buildModeOption(String label, IconData icon, PaymentMode mode, Color iconColor) {
    final isSelected = _selectedMode == mode;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        borderRadius: BorderRadius.horizontal(
          left: mode == PaymentMode.cash ? const Radius.circular(24) : Radius.zero,
          right: mode == PaymentMode.card ? const Radius.circular(24) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.white,
            borderRadius: BorderRadius.horizontal(
              left: mode == PaymentMode.cash ? const Radius.circular(24) : Radius.zero,
              right: mode == PaymentMode.card ? const Radius.circular(24) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
