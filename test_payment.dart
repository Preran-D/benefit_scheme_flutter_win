import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/data/model/payment.dart';
import 'lib/data/model/payment_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  final supabase = Supabase.instance.client;
  final payment = Payment(
    schemeId: 104, // use an existing scheme id
    amount: 500,
    paymentModes: [PaymentMode.cash],
    paymentDate: DateTime.now().toIso8601String(),
  );

  final insertMap = payment.toMap();
  insertMap.remove('id');

  try {
    final response = await supabase
        .from('payments')
        .insert(insertMap)
        .select()
        .single();
    debugPrint('Success: $response');
  } catch (e) {
    debugPrint('ERROR: $e');
  }
}
