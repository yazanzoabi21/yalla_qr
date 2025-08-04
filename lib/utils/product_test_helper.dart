// Test script to verify camera and product functionality
// This is just for testing purposes

import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../services/product_service.dart';

class ProductTestHelper {
  /// Test camera capture functionality
  static Future<void> testCameraCapture(BuildContext context) async {
    try {
      debugPrint('🧪 Testing camera capture...');
      
      // Test camera permission
      final hasPermission = await CameraService.requestCameraPermission();
      if (!hasPermission) {
        debugPrint('❌ Camera permission not granted');
        return;
      }
      
      // Test image capture
      final imageFile = await CameraService.captureImageFromCamera();
      if (imageFile != null) {
        debugPrint('✅ Image captured successfully: ${imageFile.path}');
        
        // Test image upload
        final imageUrl = await CameraService.uploadImageToSupabase(
          imageFile, 
          'test_image_${DateTime.now().millisecondsSinceEpoch}.jpg'
        );
        debugPrint('✅ Image uploaded successfully: $imageUrl');
        
        return;
      }
      
      debugPrint('❌ No image captured');
    } catch (e) {
      debugPrint('❌ Camera test failed: $e');
    }
  }

  /// Test product creation with image
  static Future<void> testProductCreation() async {
    try {
      debugPrint('🧪 Testing product creation...');
      
      // Create a test product
      final product = await ProductService.createProduct(
        name: 'Test Product ${DateTime.now().millisecondsSinceEpoch}',
        description: 'This is a test product created automatically',
        priceLbp: 50000,
        priceUsd: 33.33,
        subCategoryId: 1, // Make sure this sub-category exists
      );
      
      debugPrint('✅ Product created successfully: ${product.name} (ID: ${product.id})');
      
      // Test product retrieval
      final products = await ProductService.getProductsBySubCategory(1);
      debugPrint('✅ Retrieved ${products.length} products for sub-category 1');
      
    } catch (e) {
      debugPrint('❌ Product creation test failed: $e');
    }
  }

  /// Test full workflow: capture image + create product
  static Future<void> testFullWorkflow(BuildContext context, int subCategoryId) async {
    try {
      debugPrint('🧪 Testing full workflow...');
      
      // Step 1: Capture image
      final imageFile = await CameraService.showImageSourceDialog(context);
      if (imageFile == null) {
        debugPrint('❌ No image selected');
        return;
      }
      
      // Step 2: Upload image
      final imageUrl = await CameraService.uploadImageToSupabase(
        imageFile, 
        'workflow_test_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );
      
      // Step 3: Create product with image
      final product = await ProductService.createProduct(
        name: 'Workflow Test Product',
        description: 'Product created through full workflow test',
        priceLbp: 75000,
        priceUsd: 50.0,
        imageUrl: imageUrl,
        subCategoryId: subCategoryId,
      );
      
      debugPrint('✅ Full workflow completed successfully!');
      debugPrint('   Product: ${product.name}');
      debugPrint('   Image: ${product.imageUrl}');
      
    } catch (e) {
      debugPrint('❌ Full workflow test failed: $e');
    }
  }
}
