import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 100, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Reports Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Daily, Monthly, and Yearly collection summaries will appear here.'),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Report...')));
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export Monthly Report'),
            )
          ],
        ),
      ),
    );
  }
}
