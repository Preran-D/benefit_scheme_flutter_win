import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/model/scheme.dart';
import '../../providers/providers.dart';

class SchemeDetailsScreen extends ConsumerWidget {
  final Scheme scheme;
  
  const SchemeDetailsScreen({super.key, required this.scheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(schemePaymentsProvider(scheme.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('Scheme Details'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Monthly Amount: ₹${scheme.monthlyAmount.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Total Paid: ₹${scheme.totalPaid?.toStringAsFixed(0) ?? 0}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Status: ${scheme.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(alignment: Alignment.centerLeft, child: Text('Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                if (payments.isEmpty) return const Center(child: Text('No payments recorded.'));
                return ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text('₹${payment.amount.toStringAsFixed(0)}'),
                      subtitle: Text(payment.paymentDate ?? 'Unknown Date'),
                      trailing: Chip(label: Text(payment.paymentModes.map((e) => e.name).join(', '))),
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
          context.push('/add_payment', extra: scheme);
        },
        icon: const Icon(Icons.payment),
        label: const Text('Record Payment'),
      ),
    );
  }
}
