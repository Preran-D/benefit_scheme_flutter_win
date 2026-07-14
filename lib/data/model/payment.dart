import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'payment_mode.dart';

class Payment {
  final int? id;
  final int schemeId;
  final String? paymentDate;
  final double amount;
  final List<PaymentMode> paymentModes;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  Payment({
    this.id,
    required this.schemeId,
    this.paymentDate,
    required this.amount,
    required this.paymentModes,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    // In SQLite, payment_modes is likely stored as a JSON string
    List<PaymentMode> parsedModes = [];
    if (map['payment_modes'] != null) {
      try {
        final modesData = map['payment_modes'];
        if (modesData is String) {
          // Coming from SQLite
          final List<dynamic> jsonList = jsonDecode(modesData);
          parsedModes = jsonList.map((e) => PaymentMode.fromString(e as String)).toList();
        } else if (modesData is List) {
          // Coming from Supabase (already parsed as List by the SDK)
          parsedModes = modesData.map((e) => PaymentMode.fromString(e.toString())).toList();
        }
      } catch (e) {
        parsedModes = [PaymentMode.cash];
      }
    }

    try {
      return Payment(
        id: map['id'] as int?,
        schemeId: map['scheme_id'] as int? ?? 0,
        paymentDate: map['payment_date'] as String?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        paymentModes: parsedModes,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String?,
        updatedAt: map['updated_at'] as String?,
      );
    } catch (e) {
      debugPrint('Payment.fromMap crash on map: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'scheme_id': schemeId,
      'payment_date': paymentDate,
      'amount': amount,
      // Supabase expects a List for text arrays.
      'payment_modes': paymentModes.map((e) => e.name).toList(),
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
