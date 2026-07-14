import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../model/payment.dart';
import '../local/database_helper.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Payment>> getPaymentsForScheme(int schemeId) async {
    try {
      final response = await _supabase.from('payments').select().eq('scheme_id', schemeId);
      return response.map((json) => Payment.fromMap(json)).toList();
    } catch (e) {
      print('Payment Fetch Error: $e');
      return await _dbHelper.getPaymentsForScheme(schemeId);
    }
  }

  Future<List<Payment>> getRecentPayments() async {
    try {
      final response = await _supabase.from('payments').select().order('created_at', ascending: false).limit(50);
      return response.map((json) => Payment.fromMap(json)).toList();
    } catch (e) {
      return await _dbHelper.getAllPayments(); // Ensure this exists or fallback to empty
    }
  }

  Future<List<Payment>> getAllPayments() async {
    try {
      final response = await _supabase.from('payments').select();
      return response.map((json) => Payment.fromMap(json)).toList();
    } catch (e) {
      return await _dbHelper.getAllPayments();
    }
  }

  Future<Payment> addPayment(Payment payment) async {
    Payment finalPayment = payment;
    try {
      final insertMap = payment.toMap();
      insertMap.remove('id'); // Let Supabase generate the ID
      
      final response = await _supabase.from('payments').insert(insertMap).select().single();
      finalPayment = Payment.fromMap(response);
      
      // Update local SQLite with the true Supabase ID
      await _dbHelper.insertPayment(finalPayment);
    } catch (e, stacktrace) {
      print('Supabase addPayment error: $e');
      try {
        File('supabase_error.txt').writeAsStringSync('Error: $e\n$stacktrace');
      } catch(_) {}
      
      // Fallback: If offline, insert locally. (Note: ID will not sync correctly later if int based, but this prevents crash)
      final id = await _dbHelper.insertPayment(payment);
      finalPayment = Payment(
        id: id,
        schemeId: payment.schemeId,
        amount: payment.amount,
        paymentModes: payment.paymentModes,
        paymentDate: payment.paymentDate,
        notes: payment.notes,
        createdAt: payment.createdAt,
        updatedAt: payment.updatedAt,
      );
    }
    return finalPayment;
  }

  Future<void> updatePayment(Payment payment) async {
    try {
      final updateMap = payment.toMap();
      updateMap.remove('id');
      await _supabase.from('payments').update(updateMap).eq('id', payment.id!);
      // ignore missing local update for now if it doesn't exist
    } catch (e) {
      print('Supabase updatePayment error: $e');
    }
  }

  Future<void> deletePayment(int id) async {
    try {
      await _supabase.from('payments').delete().eq('id', id);
      // ignore missing local delete for now if it doesn't exist
    } catch (e) {
      print('Supabase deletePayment error: $e');
    }
  }
}
