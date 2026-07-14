import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/model/customer.dart';
import '../../providers/providers.dart';
import '../../data/model/scheme.dart';
import '../schemes/scheme_details_screen.dart';
import 'package:intl/intl.dart';

class CustomerDetailsScreen extends ConsumerWidget {
  final Customer customer;
  
  const CustomerDetailsScreen({Key? key, required this.customer}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemesAsync = ref.watch(customerSchemesProvider(customer.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Edit customer
            },
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone: ${customer.phone ?? 'N/A'}', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Address: ${customer.address ?? 'N/A'}', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Active Schemes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: schemesAsync.when(
              data: (schemes) {
                if (schemes.isEmpty) {
                  return const Center(child: Text('No schemes found for this customer.'));
                }
                return ListView.builder(
                  itemCount: schemes.length,
                  itemBuilder: (context, index) {
                    final scheme = schemes[index];
                    return ListTile(
                      leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                      title: Text('₹${scheme.monthlyAmount.toStringAsFixed(0)} / month'),
                      subtitle: Text('Status: ${scheme.status}'),
                      trailing: Text('Paid: ₹${scheme.totalPaid?.toStringAsFixed(0) ?? 0}'),
                      onTap: () {
                        context.push('/scheme_details', extra: scheme);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/add_scheme', extra: customer);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Scheme'),
      ),
    );
  }
}
