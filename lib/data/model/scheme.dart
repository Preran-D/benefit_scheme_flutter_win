class Scheme {
  final int? id;
  final int customerId;
  final double monthlyAmount;
  final double? totalPaid;
  final String? lastPaymentDate;
  final String? status;
  final String? notes;
  final String? closedDate;
  final String? createdAt;

  Scheme({
    this.id,
    required this.customerId,
    required this.monthlyAmount,
    this.totalPaid = 0.0,
    this.lastPaymentDate,
    this.status = "active",
    this.notes,
    this.closedDate,
    this.createdAt,
  });

  factory Scheme.fromMap(Map<String, dynamic> map) {
    return Scheme(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int? ?? 0,
      monthlyAmount: (map['monthly_amount'] as num?)?.toDouble() ?? 0.0,
      totalPaid: map['total_paid'] != null
          ? (map['total_paid'] as num).toDouble()
          : 0.0,
      lastPaymentDate: map['last_payment_date'] as String?,
      status: map['status'] as String? ?? "active",
      notes: map['notes'] as String?,
      closedDate: map['closed_date'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'monthly_amount': monthlyAmount,
      'total_paid': totalPaid,
      'last_payment_date': lastPaymentDate,
      'status': status,
      'notes': notes,
      'closed_date': closedDate,
      'created_at': createdAt,
    };
  }
}
