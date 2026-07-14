import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/scheme.dart';
import '../local/database_helper.dart';

class SchemeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Scheme>> getSchemesForCustomer(int customerId) async {
    try {
      final response = await _supabase.from('schemes').select().eq('customer_id', customerId);
      return response.map((json) => Scheme.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Scheme Fetch Error: $e');
      return await _dbHelper.getSchemesForCustomer(customerId);
    }
  }

  Future<List<Scheme>> getAllSchemes() async {
    try {
      final response = await _supabase.from('schemes').select();
      return response.map((json) => Scheme.fromMap(json)).toList();
    } catch (e) {
      return []; // Add fallback if needed
    }
  }

  Future<Scheme> addScheme(Scheme scheme) async {
    Scheme finalScheme = scheme;
    try {
      final insertMap = scheme.toMap();
      insertMap.remove('id');
      
      final response = await _supabase.from('schemes').insert(insertMap).select().single();
      finalScheme = Scheme.fromMap(response);
      
      await _dbHelper.insertScheme(finalScheme);
    } catch (e) {
      debugPrint('Supabase addScheme error: $e');
      final id = await _dbHelper.insertScheme(scheme);
      finalScheme = Scheme(
        id: id,
        customerId: scheme.customerId,
        monthlyAmount: scheme.monthlyAmount,
        totalPaid: scheme.totalPaid,
        lastPaymentDate: scheme.lastPaymentDate,
        status: scheme.status,
        notes: scheme.notes,
        closedDate: scheme.closedDate,
        createdAt: scheme.createdAt,
      );
    }
    return finalScheme;
  }

  Future<void> updateSchemeStatus(int schemeId, String status, {String? closedDate, bool clearClosedDate = false}) async {
    final Map<String, dynamic> updateData = {'status': status};
    if (clearClosedDate) {
      updateData['closed_date'] = null;
    } else if (closedDate != null) {
      updateData['closed_date'] = closedDate;
    }
    
    try {
      await _supabase.from('schemes').update(updateData).eq('id', schemeId);
    } catch (e) {
      debugPrint('Update scheme status error: $e');
      rethrow;
    }
    try {
      await _dbHelper.updateSchemeStatus(schemeId, status, closedDate: closedDate);
    } catch (_) {}
  }

  Future<void> deleteScheme(int schemeId) async {
    try {
      await _supabase.from('schemes').delete().eq('id', schemeId);
    } catch (e) {
      debugPrint('Delete scheme error: $e');
    }
    try {
      await _dbHelper.deleteScheme(schemeId);
    } catch (_) {}
  }

  Future<void> updateScheme(int schemeId, double monthlyAmount, String createdAt) async {
    try {
      await _supabase.from('schemes').update({
        'monthly_amount': monthlyAmount,
        'created_at': createdAt,
      }).eq('id', schemeId);
    } catch (e) {
      debugPrint('Update scheme error: $e');
    }
    try {
      await _dbHelper.updateScheme(schemeId, monthlyAmount, createdAt);
    } catch (_) {}
  }

  Future<void> updateSchemeTotals(int schemeId, double newTotalPaid, String lastPaymentDate) async {
    try {
      await _supabase.from('schemes').update({
        'total_paid': newTotalPaid,
        'last_payment_date': lastPaymentDate,
      }).eq('id', schemeId);
    } catch (e) {
      debugPrint('Update scheme totals error: $e');
    }
    // Also update SQLite locally if needed
  }
}
