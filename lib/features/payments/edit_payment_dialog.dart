import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/model/payment.dart';
import '../../data/model/payment_mode.dart';
import '../../providers/providers.dart';

class EditPaymentDialog extends ConsumerStatefulWidget {
  final Payment payment;

  const EditPaymentDialog({Key? key, required this.payment}) : super(key: key);

  @override
  ConsumerState<EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends ConsumerState<EditPaymentDialog> {
  late DateTime _paymentDate;
  late Set<PaymentMode> _selectedModes;
  late TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _paymentDate = DateTime.tryParse(widget.payment.paymentDate ?? '') ?? DateTime.now();
    _selectedModes = widget.payment.paymentModes.isNotEmpty ? widget.payment.paymentModes.toSet() : {PaymentMode.cash};
    _notesController = TextEditingController(text: widget.payment.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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

  Future<void> _updatePayment() async {
    setState(() => _isLoading = true);

    try {
      final updatedPayment = Payment(
        id: widget.payment.id,
        schemeId: widget.payment.schemeId,
        amount: widget.payment.amount,
        paymentDate: _paymentDate.toIso8601String(),
        paymentModes: _selectedModes.toList(),
        notes: _notesController.text.trim(),
        createdAt: widget.payment.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      final repo = ref.read(paymentRepositoryProvider);
      await repo.updatePayment(updatedPayment);
      ref.invalidate(recentPaymentsProvider);
      ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment updated successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating payment: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.grey[50],
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Payment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Amount Display (Read Only)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.payment.amount.toStringAsFixed(0)}',
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
                  borderRadius: BorderRadius.circular(16),
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
                        Text(
                          DateFormat('dd MMM yyyy').format(_paymentDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Mode Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                        selectedColor: primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? primaryColor : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes Field
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => context.pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
