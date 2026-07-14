import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/model/customer.dart';
import '../../data/model/scheme.dart';
import '../../services/printer/printer_service.dart';
import '../../services/printer/label_renderer.dart';
import '../../services/printer/brother_ql_printer.dart';

class PrintPreviewDialog extends ConsumerStatefulWidget {
  final Customer customer;
  final Scheme scheme;

  const PrintPreviewDialog({
    super.key,
    required this.customer,
    required this.scheme,
  });

  @override
  ConsumerState<PrintPreviewDialog> createState() => _PrintPreviewDialogState();
}

class _PrintPreviewDialogState extends ConsumerState<PrintPreviewDialog> {
  bool _isPrinting = false;
  bool _isTestingConnection = false;
  bool? _connectionResult;
  String? _connectionMessage;
  bool _showSettings = false;
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _testConnection(String ip) async {
    setState(() {
      _isTestingConnection = true;
      _connectionResult = null;
      _connectionMessage = null;
    });
    try {
      final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 3));
      socket.destroy();
      setState(() {
        _connectionResult = true;
        _connectionMessage = 'Connected to $ip:9100';
      });
    } catch (e) {
      setState(() {
        _connectionResult = false;
        _connectionMessage = e.toString().replaceFirst('SocketException: ', '');
      });
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _printLabel() async {
    final ip = ref.read(printerServiceProvider).ipAddress.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure printer IP first (tap ⚙ above)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPrinting = true);
    try {
      final dateStr = widget.scheme.createdAt != null
          ? DateFormat('dd MMM yyyy').format(DateTime.parse(widget.scheme.createdAt!))
          : '—';

      // 1. Render label as 720 × 236 bitmap (matches Android PrinterHelper layout)
      final labelImage = await LabelRenderer.render(
        name: widget.customer.name,
        schemeId: '${widget.scheme.id}',
        date: dateStr,
        amount: widget.scheme.monthlyAmount.toStringAsFixed(0),
        schemeNumber: widget.scheme.id.toString(),
      );

      // 2. Send raster commands to Brother QL-810W via TCP port 9100
      final success = await BrotherQLPrinter.printImage(
        ipAddress: ip,
        labelImage: labelImage,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Label printed!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Print failed – check printer is on and reachable at $ip'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerServiceProvider);
    final darkGreen = const Color(0xFF1B4D16);
    final lightBackground = const Color(0xFFF7F7F0);

    // Sync IP controller when state loads
    if (_ipController.text.isEmpty && printerState.ipAddress.isNotEmpty) {
      _ipController.text = printerState.ipAddress;
    }

    final dateStr = widget.scheme.createdAt != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(widget.scheme.createdAt!))
        : '—';

    return Dialog(
      backgroundColor: lightBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Print Preview',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: darkGreen,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: printerState.isReachable ? Colors.green[600] : Colors.red[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            printerState.isReachable
                                ? 'Printer Online · ${printerState.ipAddress}'
                                : printerState.ipAddress.isEmpty
                                    ? 'No printer configured'
                                    : 'Printer Offline · ${printerState.ipAddress}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: printerState.isReachable ? darkGreen : Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Refresh button
                      Container(
                        decoration: BoxDecoration(
                          color: darkGreen.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Check connection',
                          icon: Icon(Icons.refresh_rounded, color: darkGreen, size: 20),
                          onPressed: () => ref.read(printerServiceProvider.notifier).checkReachability(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Settings toggle
                      Container(
                        decoration: BoxDecoration(
                          color: darkGreen.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Printer settings',
                          icon: Icon(
                            _showSettings ? Icons.close : Icons.settings_rounded,
                            color: darkGreen,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _showSettings = !_showSettings),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── Settings Panel (collapsible) ─────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showSettings
                    ? _PrinterSettingsPanel(
                        ipController: _ipController,
                        isTestingConnection: _isTestingConnection,
                        connectionResult: _connectionResult,
                        connectionMessage: _connectionMessage,
                        darkGreen: darkGreen,
                        onTest: () => _testConnection(_ipController.text.trim()),
                        onSave: () {
                          final ip = _ipController.text.trim();
                          if (ip.isNotEmpty) {
                            ref.read(printerServiceProvider.notifier).updatePrinterIp(ip);
                            setState(() => _showSettings = false);
                          }
                        },
                      )
                    : const SizedBox.shrink(),
              ),

              // ─── Label Preview ─────────────────────────────────────────
              Text(
                'Label Preview (62mm × 20mm)',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.25), width: 1.5),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[350]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customer.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Divider(color: Colors.black87, thickness: 1.2, height: 14),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${widget.scheme.monthlyAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                Text(
                                  '#${widget.scheme.id}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      QrImageView(
                        data: '${widget.scheme.id}',
                        version: QrVersions.auto,
                        size: 76,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ─── Print Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (printerState.ipAddress.isEmpty || _isPrinting)
                      ? null
                      : _printLabel,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_rounded, size: 22),
                  label: Text(
                    _isPrinting ? 'Sending to printer...' : 'Print Label',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                ),
              ),



              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                  child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible settings panel for configuring the printer IP.
class _PrinterSettingsPanel extends StatelessWidget {
  final TextEditingController ipController;
  final bool isTestingConnection;
  final bool? connectionResult;
  final String? connectionMessage;
  final Color darkGreen;
  final VoidCallback onTest;
  final VoidCallback onSave;

  const _PrinterSettingsPanel({
    required this.ipController,
    required this.isTestingConnection,
    required this.connectionResult,
    required this.connectionMessage,
    required this.darkGreen,
    required this.onTest,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Printer Settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the static IP Address of your Brother QL-810W printer.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ipController,
            decoration: InputDecoration(
              labelText: 'Printer IP Address',
              hintText: 'e.g. 192.168.29.169',
              prefixIcon: const Icon(Icons.wifi_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isTestingConnection ? null : onTest,
                  icon: isTestingConnection
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 16),
                  label: Text(isTestingConnection ? 'Testing...' : 'Test Connection'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          if (connectionResult != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  connectionResult! ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: connectionResult! ? Colors.green[600] : Colors.red[600],
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    connectionResult! ? '✓ Connection Successful' : '✗ Connection Failed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: connectionResult! ? Colors.green[700] : Colors.red[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (connectionMessage != null) ...[
              const SizedBox(height: 2),
              Text(
                connectionMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: connectionResult! ? Colors.green[600] : Colors.red[500],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
