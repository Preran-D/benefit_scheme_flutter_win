import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterState {
  final String ipAddress;
  final String modelName;
  final bool isReachable;

  PrinterState({this.ipAddress = '', this.modelName = 'QL-810W', this.isReachable = false});
  
  PrinterState copyWith({String? ipAddress, String? modelName, bool? isReachable}) {
    return PrinterState(
      ipAddress: ipAddress ?? this.ipAddress,
      modelName: modelName ?? this.modelName,
      isReachable: isReachable ?? this.isReachable,
    );
  }
}

class PrinterService extends Notifier<PrinterState> {
  @override
  PrinterState build() {
    _initPrinterSettings();
    return PrinterState();
  }

  Future<void> _initPrinterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String savedIp = prefs.getString('printer_ip') ?? '';
    
    // Migration Logic matching Android implementation
    if (savedIp.isEmpty || savedIp == "192.168.1.100") {
      savedIp = "192.168.29.169";
      await prefs.setString('printer_ip', savedIp);
    }
    
    final savedModel = prefs.getString('printer_model') ?? 'QL-810W';
    state = state.copyWith(ipAddress: savedIp, modelName: savedModel);
    
    await checkReachability();
  }

  Future<void> updatePrinterIp(String newIp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', newIp);
    state = state.copyWith(ipAddress: newIp);
    await checkReachability();
  }

  Future<bool> checkReachability() async {
    if (state.ipAddress.isEmpty) {
      state = state.copyWith(isReachable: false);
      return false;
    }
    
    try {
      // Connect to port 9100 (standard raw printing port)
      final socket = await Socket.connect(state.ipAddress, 9100, timeout: const Duration(seconds: 2));
      socket.destroy();
      state = state.copyWith(isReachable: true);
      return true;
    } catch (e) {
      state = state.copyWith(isReachable: false);
      return false;
    }
  }
}

final printerServiceProvider = NotifierProvider<PrinterService, PrinterState>(() {
  return PrinterService();
});
