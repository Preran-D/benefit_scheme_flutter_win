import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/customer.dart';
import '../local/database_helper.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _supabase.from('customers').select();
      final remoteCustomers = response.map((json) => Customer.fromMap(json)).toList();
      return remoteCustomers;
    } catch (e) {
      debugPrint('Customer Fetch Error: $e');
      return await _dbHelper.getAllCustomers();
    }
  }

  Future<Customer> addCustomer(Customer customer) async {
    Customer finalCustomer = customer;
    try {
      final insertMap = customer.toMap();
      insertMap.remove('id');
      final response = await _supabase.from('customers').insert(insertMap).select().single();
      finalCustomer = Customer.fromMap(response);
      await _dbHelper.insertCustomer(finalCustomer);
    } catch (e) {
      debugPrint('Supabase addCustomer error: $e');
      final id = await _dbHelper.insertCustomer(customer);
      finalCustomer = Customer(id: id, name: customer.name, phone: customer.phone, address: customer.address);
    }
    return finalCustomer;
  }

  /// Updates name, phone and address of an existing customer.
  Future<void> updateCustomer(Customer customer) async {
    try {
      await _supabase.from('customers').update({
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
      }).eq('id', customer.id!);
      await _dbHelper.updateCustomer(customer);
    } catch (e) {
      debugPrint('Supabase updateCustomer error: $e');
      await _dbHelper.updateCustomer(customer);
    }
  }

  /// Deletes a customer. The DB will block this if payment history exists.
  Future<void> deleteCustomer(int id) async {
    try {
      await _supabase.from('customers').delete().eq('id', id);
      await _dbHelper.deleteCustomer(id);
    } catch (e) {
      debugPrint('Supabase deleteCustomer error: $e');
      await _dbHelper.deleteCustomer(id);
    }
  }

  /// Returns true if the customer has any recorded payments across all their schemes.
  /// Used to enforce the deletion block rule (BUSINESS_RULES §1).
  Future<bool> hasPayments(int customerId) async {
    try {
      // Join: schemes → payments where scheme belongs to this customer
      final response = await _supabase
          .from('payments')
          .select('id, schemes!inner(customer_id)')
          .eq('schemes.customer_id', customerId)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('hasPayments error: $e');
      return await _dbHelper.hasPaymentsForCustomer(customerId);
    }
  }
}

