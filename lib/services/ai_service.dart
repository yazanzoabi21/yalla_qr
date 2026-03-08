import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';

class AiService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Generates a product description using AI via the Supabase Edge Function.
  /// Throws a [String] error message on failure so the caller can display it.
  /// [language] accepts 'en' (English), 'ar' (Arabic), 'fr' (French). Defaults to 'en'.
  static Future<String> generateProductDescription({
    required String productName,
    String? categoryName,
    double? priceLbp,
    double? priceUsd,
    String language = 'en',
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-product-description',
        body: {
          'productName': productName,
          if (categoryName != null) 'categoryName': categoryName,
          if (priceLbp != null) 'priceLbp': priceLbp,
          if (priceUsd != null) 'priceUsd': priceUsd,
          'language': language,
        },
      );

      debugPrint('📨 [AiService] Response data: ${response.data}');

      if (response.data == null) {
        throw 'Empty response from Edge Function';
      }

      // Edge Function returned an error field
      if (response.data['error'] != null) {
        throw response.data['error'].toString();
      }

      final description = response.data['description'] as String?;
      if (description == null || description.isEmpty) {
        throw 'AI returned an empty description';
      }
      return description;
    } catch (e) {
      debugPrint('❌ [AiService] generateProductDescription error: $e');
      rethrow;
    }
  }

  /// Sends a chat message to the shopping assistant with the org's product catalog as context.
  /// [messages] is the conversation history: each map has 'role' (user/assistant) and 'content'.
  /// [products] is the list of products available in this store.
  /// [orgName] is the organization display name.
  /// Returns the assistant's reply text. Throws on failure.
  static Future<String> shopAssistant({
    required List<Map<String, String>> messages,
    required List<Product> products,
    required String orgName,
  }) async {
    try {
      final productPayload = products.map((p) => {
        'name': p.name,
        if (p.description != null) 'description': p.description!,
        if (p.priceLbp != null) 'priceLbp': p.priceLbp.toString(),
        if (p.priceUsd != null) 'priceUsd': p.priceUsd!.toStringAsFixed(2),
        'inStock': p.isAvailable,
      }).toList();

      final response = await _supabase.functions.invoke(
        'shop-assistant',
        body: {
          'messages': messages,
          'products': productPayload,
          'orgName': orgName,
        },
      );

      debugPrint('📨 [AiService] shopAssistant response: ${response.data}');

      if (response.data == null) throw 'Empty response from Edge Function';
      if (response.data['error'] != null) throw response.data['error'].toString();

      final reply = response.data['reply'] as String?;
      if (reply == null || reply.isEmpty) throw 'AI returned an empty reply';
      return reply;
    } catch (e) {
      debugPrint('❌ [AiService] shopAssistant error: $e');
      rethrow;
    }
  }
}
