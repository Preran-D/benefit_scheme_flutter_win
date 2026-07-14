import '../../data/model/customer.dart';
import '../../data/model/scheme.dart';
import '../../data/model/payment.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  Future<int> insertCustomer(Customer customer) async => 1;
  Future<List<Customer>> getAllCustomers() async => [];
  Future<int> insertScheme(Scheme scheme) async => 1;
  Future<List<Scheme>> getSchemesForCustomer(int customerId) async => [];
  Future<int> insertPayment(Payment payment) async => 1;
  Future<List<Payment>> getPaymentsForScheme(int schemeId) async => [];
  Future<List<Payment>> getAllPayments() async => [];
  Future<void> updateSchemeStatus(int schemeId, String status, {String? closedDate}) async {}
  Future<void> deleteScheme(int schemeId) async {}
  Future<void> updateScheme(int schemeId, double monthlyAmount, String createdAt) async {}
  Future<void> updateCustomer(Customer customer) async {}
  Future<void> deleteCustomer(int id) async {}
  Future<bool> hasPaymentsForCustomer(int customerId) async => false;
}
