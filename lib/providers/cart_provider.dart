import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/model/customer.dart';
import '../data/model/scheme.dart';

class CartItem {
  final Customer customer;
  final Scheme scheme;
  final int months;
  
  CartItem({
    required this.customer,
    required this.scheme,
    this.months = 1,
  });

  CartItem copyWith({
    Customer? customer,
    Scheme? scheme,
    int? months,
  }) {
    return CartItem(
      customer: customer ?? this.customer,
      scheme: scheme ?? this.scheme,
      months: months ?? this.months,
    );
  }
}

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [];
  }

  void addScheme(Customer customer, Scheme scheme) {
    final existingIndex = state.indexWhere((item) => item.scheme.id == scheme.id);
    if (existingIndex >= 0) {
      return;
    }
    
    state = [...state, CartItem(customer: customer, scheme: scheme)];
  }

  void removeScheme(int schemeId) {
    state = state.where((item) => item.scheme.id != schemeId).toList();
  }

  void updateMonths(int schemeId, int newMonths) {
    state = state.map((item) {
      if (item.scheme.id == schemeId) {
        return item.copyWith(months: newMonths);
      }
      return item;
    }).toList();
  }

  void clearCart() {
    state = [];
  }

  double get totalAmount {
    return state.fold(0, (sum, item) => sum + (item.scheme.monthlyAmount * item.months));
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(() {
  return CartNotifier();
});
