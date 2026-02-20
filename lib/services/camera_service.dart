import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check and request camera permissions
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        debugPrint('Camera permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        debugPrint('Camera permission permanently denied');
        await openAppSettings();
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Capture image from camera
  static Future<File?> captureImageFromCamera() async {
    try {
      // Request permission first
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        throw Exception('Camera permission denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        debugPrint('📸 Image captured: ${image.path}');
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error capturing image: $e');
      throw Exception('Failed to capture image: $e');
    }
  }

  /// Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        debugPrint('🖼️ Image selected from gallery: ${image.path}');
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Show bottom sheet to choose between camera and gallery
  static Future<File?> showImageSourceDialog(BuildContext context, {File? currentImageFile, String? currentImageUrl}) async {
    return await showModalBottomSheet<File?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        try {
                          final image = await captureImageFromCamera();
                          if (context.mounted) {
                            Navigator.pop(context, image);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to capture image: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.blue,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Camera',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Optional View button when there is an existing image
                  if (currentImageFile != null || (currentImageUrl != null && currentImageUrl.isNotEmpty)) ...[
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          // Show full-screen viewer dialog without closing the bottom sheet
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: EdgeInsets.zero,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: Colors.black,
                                    child: Center(
                                      child: InteractiveViewer(
                                        minScale: 0.5,
                                        maxScale: 5.0,
                                        child: currentImageFile != null
                                            ? Image.file(currentImageFile, fit: BoxFit.contain)
                                            : Image.network(currentImageUrl!, fit: BoxFit.contain),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.remove_red_eye,
                                size: 40,
                                color: Colors.purple,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        try {
                          final image = await pickImageFromGallery();
                          if (context.mounted) {
                            Navigator.pop(context, image);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick image: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 40,
                              color: Colors.green,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Upload image to Supabase Storage
  static Future<String?> uploadImageToSupabase(File imageFile, String fileName) async {
    try {
      debugPrint('📤 Uploading image to Supabase: $fileName');
      
      // Create a unique filename
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      // Check if bucket exists first
      try {
        final buckets = await _supabase.storage.listBuckets();
        final bucketExists = buckets.any((bucket) => bucket.name == 'products-images');
        
        if (!bucketExists) {
          debugPrint('📦 Creating products-images bucket...');
          await _supabase.storage.createBucket(
            'products-images',
            const BucketOptions(public: true),
          );
        }
      } catch (bucketError) {
        debugPrint('⚠️ Could not check/create bucket: $bucketError');
        // Continue anyway - bucket might exist but we can't list it
      }
      
      // Upload the file to Supabase Storage
      await _supabase.storage
          .from('products-images')
          .upload(uniqueFileName, imageFile);

      // Get the public URL
      final imageUrl = _supabase.storage
          .from('products-images')
          .getPublicUrl(uniqueFileName);

      debugPrint('✅ Image uploaded successfully: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete image from Supabase Storage
  static Future<void> deleteImageFromSupabase(String imageUrl) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final filename = uri.pathSegments.last;
      
      debugPrint('🗑️ Deleting image from Supabase: $filename');
      
      await _supabase.storage
          .from('products-images')
          .remove([filename]);

      debugPrint('✅ Image deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      // Don't throw here as it's not critical if image deletion fails
    }
  }

  /// Save image to local cache
  static Future<String> saveImageToCache(File imageFile, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/products-images');
      
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cachedFile = File('${cacheDir.path}/$fileName');
      await imageFile.copy(cachedFile.path);
      
      debugPrint('💾 Image saved to cache: ${cachedFile.path}');
      return cachedFile.path;
    } catch (e) {
      debugPrint('❌ Error saving image to cache: $e');
      throw Exception('Failed to save image to cache: $e');
    }
  }

  /// Get cached image
  static Future<File?> getCachedImage(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cachedFile = File('${directory.path}/products-images/$fileName');
      
      if (await cachedFile.exists()) {
        return cachedFile;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached image: $e');
      return null;
    }
  }
}
