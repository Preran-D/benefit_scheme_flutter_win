import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final allPaymentsAsync = ref.watch(allPaymentsProvider);
    final allSchemesAsync = ref.watch(allSchemesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Cards, Line Chart, Table)
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI Cards Row
                  Row(
                    children: [
                      // My Balance
                      Expanded(
                        flex: 2,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Collections', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    allPaymentsAsync.when(
                                      data: (payments) {
                                        final total = payments.fold(0.0, (sum, item) => sum + item.amount);
                                        return Text(
                                          NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total),
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                        );
                                      },
                                      loading: () => const Text('...', style: TextStyle(fontSize: 32)),
                                      error: (_, __) => const Text('Error', style: TextStyle(fontSize: 32)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('+6.7%', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 4),
                                    const Text('compare to last month', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => context.push('/customers'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Add Customer'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => context.push('/payments'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('View Payments', style: TextStyle(color: Colors.black87)),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Monthly Income
                      Expanded(
                        flex: 1,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(backgroundColor: Colors.green.withOpacity(0.1), radius: 16, child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 16)),
                                const SizedBox(height: 16),
                                const Text('Monthly Income', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                allPaymentsAsync.when(
                                  data: (payments) {
                                    final now = DateTime.now();
                                    final monthly = payments.where((p) {
                                      final dt = DateTime.tryParse(p.paymentDate ?? '');
                                      return dt != null && dt.month == now.month && dt.year == now.year;
                                    }).fold(0.0, (sum, item) => sum + item.amount);
                                    return Text(
                                      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(monthly),
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    );
                                  },
                                  loading: () => const Text('...', style: TextStyle(fontSize: 24)),
                                  error: (_, __) => const Text('Error', style: TextStyle(fontSize: 24)),
                                ),
                                const SizedBox(height: 4),
                                const Text('+9.8% compared to last month', style: TextStyle(color: Colors.green, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Active Schemes
                      Expanded(
                        flex: 1,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), radius: 16, child: const Icon(Icons.credit_card, color: Colors.orange, size: 16)),
                                const SizedBox(height: 16),
                                const Text('Active Schemes', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                allSchemesAsync.when(
                                  data: (schemes) {
                                    return Text(
                                      schemes.length.toString(),
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    );
                                  },
                                  loading: () => const Text('...', style: TextStyle(fontSize: 24)),
                                  error: (_, __) => const Text('Error', style: TextStyle(fontSize: 24)),
                                ),
                                const SizedBox(height: 4),
                                const Text('-2.1% compared to last month', style: TextStyle(color: Colors.red, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Statistics Line Chart
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text('Total income', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 16),
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text('Total expenses', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                        if (value >= 0 && value < 12) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(months[value.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: const [
                                      FlSpot(0, 3), FlSpot(1, 4), FlSpot(2, 3.5), FlSpot(3, 5), 
                                      FlSpot(4, 4), FlSpot(5, 6), FlSpot(6, 4.5), FlSpot(7, 5),
                                      FlSpot(8, 4), FlSpot(9, 6), FlSpot(10, 5), FlSpot(11, 7),
                                    ],
                                    isCurved: true,
                                    color: Colors.green,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  LineChartBarData(
                                    spots: const [
                                      FlSpot(0, 1), FlSpot(1, 2), FlSpot(2, 1.5), FlSpot(3, 3), 
                                      FlSpot(4, 2), FlSpot(5, 4), FlSpot(6, 2.5), FlSpot(7, 3),
                                      FlSpot(8, 2), FlSpot(9, 4), FlSpot(10, 3), FlSpot(11, 4),
                                    ],
                                    isCurved: true,
                                    color: Colors.orange,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Averages
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Average income', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const Text('₹10,389.49', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  const Text('+9.8% compare to last month', style: TextStyle(color: Colors.green, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(width: 100),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Average expenses', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const Text('₹6,726.92', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  const Text('+8.7% compare to last month', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Transactions and Invoices (Preview)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Transaction and invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.search, size: 16),
                                    label: const Text('Search'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.filter_alt, size: 16),
                                    label: const Text('Filter'),
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          allPaymentsAsync.when(
                            data: (payments) {
                              final recent = payments.take(5).toList();
                              if (recent.isEmpty) return const Text('No transactions yet.');
                              return DataTable(
                                headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.grey.withOpacity(0.1)),
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: recent.map((p) {
                                  final dt = DateTime.tryParse(p.paymentDate ?? '');
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(dt != null ? DateFormat('MMM dd, yyyy').format(dt) : '-')),
                                      DataCell(Text('₹ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                      const DataCell(Text('Completed', style: TextStyle(color: Colors.green))),
                                    ]
                                  );
                                }).toList()
                              );
                            },
                            loading: () => const CircularProgressIndicator(),
                            error: (_, __) => const Text('Error loading transactions'),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Pie Chart Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('All expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Daily', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const Text('₹682.20', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Weekly', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const Text('₹2,183.26', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Monthly', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const Text('₹6,638.72', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 60,
                                    sections: [
                                      PieChartSectionData(color: Colors.green, value: 46, title: '', radius: 15),
                                      PieChartSectionData(color: Colors.red, value: 56, title: '', radius: 25),
                                      PieChartSectionData(color: Colors.orange, value: 48, title: '', radius: 20),
                                      PieChartSectionData(color: Colors.blue, value: 63, title: '', radius: 30),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Food & health', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    const Text('₹985.90', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildLegendRow(Colors.green, 'Entertainments', '46%'),
                          _buildLegendRow(Colors.red, 'Platform', '56%'),
                          _buildLegendRow(Colors.orange, 'Shopping', '48%'),
                          _buildLegendRow(Colors.blue, 'Food & health', '63%'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Promo Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8BC34A), Color(0xFF4CAF50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Secure Your Future with Our Comprehensive Retirement Plans!',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green[800],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Learn more'),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String title, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(percentage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
