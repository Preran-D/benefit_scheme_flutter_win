import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repository/customer_repository.dart';
import '../data/repository/scheme_repository.dart';
import '../data/repository/payment_repository.dart';
import '../data/model/customer.dart';
import '../data/model/scheme.dart';
import '../data/model/payment.dart';

export 'cart_provider.dart';

// Repositories
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

final schemeRepositoryProvider = Provider<SchemeRepository>((ref) {
  return SchemeRepository();
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

// Sync Controller
class SyncState {
  final DateTime lastSync;
  final bool isSyncing;
  SyncState({required this.lastSync, this.isSyncing = false});
}

class SyncController extends Notifier<SyncState> {
  Timer? _timer;

  @override
  SyncState build() {
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      syncNow();
    });
    
    ref.onDispose(() {
      _timer?.cancel();
    });
    
    return SyncState(lastSync: DateTime.now());
  }

  Future<void> syncNow() async {
    state = SyncState(lastSync: state.lastSync, isSyncing: true);
    
    // Invalidate all remote data providers
    ref.invalidate(customersProvider);
    ref.invalidate(recentPaymentsProvider);
    ref.invalidate(allPaymentsProvider);
    ref.invalidate(allSchemesProvider);
    
    // Invalidate family providers (this drops all cached instances)
    ref.invalidate(customerSchemesProvider);
    ref.invalidate(schemePaymentsProvider);
    
    // Simulate a brief delay to show the sync UI
    await Future.delayed(const Duration(milliseconds: 800));
    
    state = SyncState(lastSync: DateTime.now(), isSyncing: false);
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(() {
  return SyncController();
});

// Data Providers
final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomers();
});

final recentPaymentsProvider = FutureProvider<List<Payment>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getRecentPayments();
});

final allPaymentsProvider = FutureProvider<List<Payment>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getAllPayments();
});

final schemePaymentsProvider = FutureProvider.family<List<Payment>, int>((ref, schemeId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getPaymentsForScheme(schemeId);
});

final customerSchemesProvider = FutureProvider.family<List<Scheme>, int>((ref, customerId) async {
  final repo = ref.watch(schemeRepositoryProvider);
  return repo.getSchemesForCustomer(customerId);
});

final allSchemesProvider = FutureProvider<List<Scheme>>((ref) async {
  final repo = ref.watch(schemeRepositoryProvider);
  return repo.getAllSchemes();
});
