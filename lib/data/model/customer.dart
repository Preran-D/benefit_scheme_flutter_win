class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? address;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.address,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
    };
  }
}
