import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/model/customer.dart';
import '../../data/model/scheme.dart';
import '../../providers/providers.dart';


class AddSchemeDialog extends ConsumerStatefulWidget {
  final Customer customer;
  const AddSchemeDialog({super.key, required this.customer});

  @override
  ConsumerState<AddSchemeDialog> createState() => _AddSchemeDialogState();
}

class _AddSchemeDialogState extends ConsumerState<AddSchemeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<double> _suggestions = [500, 1000, 1500, 2000, 3000, 5000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveScheme() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final newScheme = Scheme(
        customerId: widget.customer.id!,
        monthlyAmount: double.parse(_amountController.text),
        createdAt: _selectedDate.toIso8601String(),
      );

      try {
        final repo = ref.read(schemeRepositoryProvider);
        await repo.addScheme(newScheme);
        await ref.read(syncControllerProvider.notifier).syncNow();
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Scheme',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              
              // Customer Info Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.customer.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customer.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          'Setting up new scheme',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Amount Input
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Monthly Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                onChanged: (val) => setState(() {}), // Trigger rebuild to update suggestion chips and button state
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Amount is required';
                  final amount = double.tryParse(val);
                  if (amount == null) return 'Enter a valid number';
                  if (amount < 500) return 'Amount must be at least ₹500';
                  if (amount % 100 != 0) return 'Amount must be a multiple of ₹100';
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Suggestions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((amount) {
                  final isSelected = _amountController.text == amount.toStringAsFixed(0);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _amountController.text = amount.toStringAsFixed(0);
                        // Move cursor to the end
                        _amountController.selection = TextSelection.fromPosition(TextPosition(offset: _amountController.text.length));
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? primaryColor : Colors.grey[300]!),
                      ),
                      child: Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Date Picker
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
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
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || _amountController.text.isEmpty) ? null : _saveScheme,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Confirm & Create Scheme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
