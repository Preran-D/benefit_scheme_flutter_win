import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/model/payment.dart';
import '../../util/printer_helper.dart';
import '../../data/model/payment.dart';

class PaymentDetailsScreen extends StatelessWidget {
  final Payment payment;
  const PaymentDetailsScreen({Key? key, required this.payment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            const Text('Payment Successful!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receipt No: ${payment.id}', style: const TextStyle(fontSize: 16)),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Amount Paid: ₹${payment.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Mode: ${payment.paymentModes.map((e) => e.name).join(', ')}'),
                    const SizedBox(height: 8),
                    Text('Date: ${payment.paymentDate}'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                PrinterHelper.printReceipt(payment);
              },
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.pop();
              },
              child: const Text('Done'),
            )
          ],
        ),
      ),
    );
  }
}
