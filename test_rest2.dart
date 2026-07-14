import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  final env = File('.env').readAsStringSync();
  String url = '';
  String key = '';
  for (var line in env.split('\n')) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1].trim();
    if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.split('=')[1].trim();
  }

  final body = {
    "scheme_id": 104,
    "amount": 500,
    "payment_modes": "[\"cash\"]",
    "notes": "test insert"
  };

  final request = await HttpClient().postUrl(Uri.parse('$url/rest/v1/payments'));
  request.headers.add('apikey', key);
  request.headers.add('Authorization', 'Bearer $key');
  request.headers.add('Content-Type', 'application/json');
  request.headers.add('Prefer', 'return=representation');
  request.write(jsonEncode(body));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  debugPrint('Status: ${response.statusCode}');
  debugPrint('Response: $responseBody');
}
