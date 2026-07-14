import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/model/customer.dart';
import '../../providers/providers.dart';

class AddCustomerDialog extends ConsumerStatefulWidget {
  /// When non-null, the dialog operates in "edit" mode.
  final Customer? editingCustomer;

  const AddCustomerDialog({super.key, this.editingCustomer});

  @override
  ConsumerState<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends ConsumerState<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  bool get _isEditing => widget.editingCustomer != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.editingCustomer!.name;
      _phoneController.text = widget.editingCustomer!.phone ?? '';
      _addressController.text = widget.editingCustomer!.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final repo = ref.read(customerRepositoryProvider);
      final name = _nameController.text.trim();

      // Business Rule: Unique Name (excluding self when editing)
      final existingCustomers = ref.read(customersProvider).value ?? [];
      final duplicate = existingCustomers.any((c) =>
          c.name.trim().toLowerCase() == name.toLowerCase() &&
          c.id != widget.editingCustomer?.id);
      if (duplicate) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A customer named "$name" already exists.'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      try {
        if (_isEditing) {
          final updated = Customer(
            id: widget.editingCustomer!.id,
            name: name,
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          );
          await repo.updateCustomer(updated);
        } else {
          final newCustomer = Customer(
            name: name,
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          );
          await repo.addCustomer(newCustomer);
        }
        await ref.read(syncControllerProvider.notifier).syncNow();
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showAddressSelectionDialog() async {
    final asyncCustomers = ref.read(customersProvider);
    final customers = asyncCustomers.value ?? [];

    final addresses = customers
        .map((c) => c.address?.trim())
        .where((a) => a != null && a.isNotEmpty)
        .map((a) => a!)
        .toSet()
        .toList()
      ..sort();

    if (addresses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No existing addresses found.')),
        );
      }
      return;
    }

    final selectedAddress = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Existing Address'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Colors.green),
                  title: Text(address),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () => Navigator.of(context).pop(address),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedAddress != null) {
      setState(() => _addressController.text = selectedAddress);
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
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                _isEditing ? 'Edit Customer' : 'Add Customer',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter customer name',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.grey[700]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
                  filled: false,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                  prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[700]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
                  filled: false,
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter address',
                  prefixIcon: Icon(Icons.home_outlined, color: Colors.grey[700]),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.green),
                    tooltip: 'Select from existing addresses',
                    onPressed: _showAddressSelectionDialog,
                    splashRadius: 24,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
                  filled: false,
                ),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer,
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
                      : Text(
                          _isEditing ? 'Save Changes' : 'Confirm & Save Customer',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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


