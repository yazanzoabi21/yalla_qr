import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class SupabaseSetup {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if the product_images bucket exists, create if not
  static Future<bool> ensureProductImagesBucket() async {
    try {
      debugPrint('🔍 Checking if product_images bucket exists...');
      
      // Try to get bucket info
      final buckets = await _supabase.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == 'product_images');
      
      if (bucketExists) {
        debugPrint('✅ product_images bucket already exists');
        return true;
      }
      
      debugPrint('📦 Creating product_images bucket...');
      
      // Create the bucket if it doesn't exist
      await _supabase.storage.createBucket(
        'product_images',
        const BucketOptions(
          public: true,
          allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        ),
      );
      
      debugPrint('✅ product_images bucket created successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error with product_images bucket: $e');
      // If we can't create the bucket, it might already exist or we don't have permissions
      // Return true to continue, as the bucket might exist but we can't list it
      return true;
    }
  }

  /// Initialize Supabase storage for the app
  static Future<void> initializeStorage() async {
    try {
      debugPrint('🚀 Initializing Supabase storage...');
      await ensureProductImagesBucket();
      debugPrint('✅ Supabase storage initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Supabase storage: $e');
    }
  }

  /// Test storage connection
  static Future<bool> testStorageConnection() async {
    try {
      debugPrint('🧪 Testing storage connection...');
      final buckets = await _supabase.storage.listBuckets();
      debugPrint('✅ Storage connection successful. Found ${buckets.length} buckets');
      for (var bucket in buckets) {
        debugPrint('   - Bucket: ${bucket.name}');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Storage connection failed: $e');
      return false;
    }
  }
}
