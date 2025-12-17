import 'package:supabase_flutter/supabase_flutter.dart';

class CurrencyService {
  static Future<double> getUsdRate() async {
    // Replace with your actual DB/API call
    final currency = await Supabase.instance.client
      .from('currency')
      .select('usd_rate')
      .eq('code', 'LBP')
      .single();
    final raw = currency['usd_rate'];
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw Exception('Invalid usd_rate value: $raw');
  }
}