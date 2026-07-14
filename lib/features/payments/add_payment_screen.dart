import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/model/scheme.dart';
import '../../data/model/payment.dart';
import '../../data/model/payment_mode.dart';
import '../../providers/providers.dart';
import '../schemes/scheme_details_screen.dart';

class AddPaymentDialog extends ConsumerStatefulWidget {
  final Scheme scheme;
  const AddPaymentDialog({Key? key, required this.scheme}) : super(key: key);

  @override
  ConsumerState<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  PaymentMode _selectedMode = PaymentMode.cash;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.scheme.monthlyAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final amount = double.parse(_amountController.text);
      final newPayment = Payment(
        schemeId: widget.scheme.id!,
        amount: amount,
        paymentModes: [_selectedMode],
        paymentDate: DateTime.now().toIso8601String(),
        notes: _notesController.text,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      try {
        // Pre-validation: ensure scheme is not closed/completed
        await ref.read(syncControllerProvider.notifier).syncNow();
        final schemes = await ref.read(customerSchemesProvider(widget.scheme.customerId).future);
        final freshScheme = schemes.firstWhere((s) => s.id == widget.scheme.id, orElse: () => widget.scheme);
        final status = (freshScheme.status ?? 'active').toLowerCase();
        if (status == 'closed' || status == 'completed') {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot process payment: Scheme is already $status.')));
          return;
        }

        final repo = ref.read(paymentRepositoryProvider);
        final savedPayment = await repo.addPayment(newPayment);
        
        await ref.read(syncControllerProvider.notifier).syncNow(); // Post-sync
        
        if (mounted) {
          context.pop(savedPayment);
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Process Payment'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Scheme ID: ${widget.scheme.id}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PaymentMode>(
                value: _selectedMode,
                decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                items: PaymentMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() { _selectedMode = val; });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => context.pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _processPayment,
          icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payment),
          label: const Text('Confirm Payment'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        )
      ],
    );
  }
}
