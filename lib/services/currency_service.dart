import 'package:supabase_flutter/supabase_flutter.dart';

class CurrencyService {
  static Future<double> getUsdRate() async {
    // Replace with your actual DB/API call
    final currency = await Supabase.instance.client
      .from('currency')
      .select('usd_rate')
      .eq('code', 'LBP')
      .single();
    return currency['usd_rate'] as double;
  }
}