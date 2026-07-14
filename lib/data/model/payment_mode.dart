enum PaymentMode {
  cash,
  upi,
  card;

  static PaymentMode fromString(String value) {
    return PaymentMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentMode.cash,
    );
  }
}
