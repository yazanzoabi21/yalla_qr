import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/navbar.dart';
import '../../widgets/qr_code_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../widgets/theme_selector.dart';
import 'notification.dart';
import 'delivery_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? categoryName;

  const SettingsScreen({super.key, this.categoryName});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _accountProfile;
  Map<String, dynamic>? _categoryInfo;
  bool _isLoading = true;
  bool _isEditing = false;

  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  String? _userRole;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        debugPrint('⚙️ [Settings] Loading profile for user: ${user.email}');

        // First get category info if categoryName is provided
        if (widget.categoryName != null) {
          final categoryResponse = await Supabase.instance.client
              .from('categories')
              .select('*')
              .ilike('name', widget.categoryName!)
              .single();

          setState(() {
            _categoryInfo = categoryResponse;
          });

          debugPrint('   📂 Category context: ${_categoryInfo!['name']}');
        }

        // Get account profile from the accounts table based on user and category
        dynamic response;

        // If no category is specified (home screen), prefer ORG account
        if (_categoryInfo == null) {
          debugPrint(
            '   🏠 No category specified - loading ORG account (home screen context)',
          );
          final orgAccounts = await Supabase.instance.client
              .from('accounts')
              .select('*')
              .eq('owner_id', user.id)
              .eq('role', 'ORG')
              .limit(1);

          if (orgAccounts.isNotEmpty) {
            response = orgAccounts.first;
            debugPrint('   ✅ Found ORG account: ${response['name']}');
          } else {
            // Fallback to any account
            debugPrint('   ⚠️ No ORG account found, loading any account');
            final anyAccount = await Supabase.instance.client
                .from('accounts')
                .select('*')
                .eq('owner_id', user.id)
                .limit(1);
            response = anyAccount.isNotEmpty ? anyAccount.first : null;
          }
        } else {
          // If we have a specific category, filter by it
          debugPrint('   🔍 Filtering by category_id: ${_categoryInfo!['id']}');
          var query = Supabase.instance.client
              .from('accounts')
              .select('*')
              .eq('owner_id', user.id)
              .eq('category_id', _categoryInfo!['id']);

          // Try to get single account, but handle multiple accounts gracefully
          try {
            response = await query.maybeSingle();
          } catch (e) {
            // If multiple accounts exist, prefer USER role (for CLIENT pages)
            debugPrint('   ⚠️ Multiple accounts found, filtering by USER role');
            final multipleAccounts = await Supabase.instance.client
                .from('accounts')
                .select('*')
                .eq('owner_id', user.id)
                .eq('role', 'USER')
                .limit(1);

            if (multipleAccounts.isNotEmpty) {
              response = multipleAccounts.first;
            } else {
              // Fallback to any account
              final anyAccount = await Supabase.instance.client
                  .from('accounts')
                  .select('*')
                  .eq('owner_id', user.id)
                  .limit(1);
              response = anyAccount.isNotEmpty ? anyAccount.first : null;
            }
          }
        }

        if (response != null) {
          debugPrint('   ✅ Account found:');
          debugPrint('      - Name: ${response['name']}');
          debugPrint('      - Email: ${user.email}');
          debugPrint('      - Role: ${response['role']}');
          debugPrint('      - Category ID: ${response['category_id']}');
        } else {
          debugPrint(
            '   ⚠️ No account found for this user/category combination',
          );
        }

        setState(() {
          _accountProfile = response;
          _userRole = response?['role'] as String?;
          _populateControllers();
          _isLoading = false;
        });

        debugPrint('⚙️ [Settings] User role: $_userRole');
      } else {
        debugPrint('⚠️ [Settings] No user logged in');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [Settings] Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  void _populateControllers() {
    if (_accountProfile != null) {
      _nameController.text = _accountProfile!['name'] ?? '';
      _phoneController.text = _accountProfile!['phone'] ?? '';
      _descriptionController.text = _accountProfile!['description'] ?? '';
      _locationController.text = _accountProfile!['location_address'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        await _uploadProfileImage();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_selectedImage == null || _accountProfile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Validate file size (max 5MB)
      final fileSize = await _selectedImage!.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image size must be less than 5MB');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final accountId = _accountProfile!['id'].toString().replaceAll('-', '_');
      final fileName = 'profile_${accountId}_$timestamp.jpg';

      debugPrint('📤 Uploading profile image: $fileName');

      // Delete old image if exists
      final oldLogoUrl = _accountProfile!['logo_url'];
      if (oldLogoUrl != null && oldLogoUrl.isNotEmpty) {
        await _deleteImageFromStorage(oldLogoUrl);
      }

      // Upload the new image
      await supabase.storage
          .from('profile-images')
          .upload(
            fileName,
            _selectedImage!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get the public URL
      final imageUrl = supabase.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      // Update account with new logo URL
      await supabase
          .from('accounts')
          .update({
            'logo_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _accountProfile!['id']);

      debugPrint('✅ Profile image uploaded successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload profile
      await _loadUserProfile();
    } catch (e) {
      debugPrint('❌ Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploadingImage = false;
        _selectedImage = null;
      });
    }
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final filename = uri.pathSegments.last;

      await Supabase.instance.client.storage.from('profile-images').remove([
        filename,
      ]);

      debugPrint('🗑️ Deleted old profile image: $filename');
    } catch (e) {
      debugPrint('⚠️ Error deleting old image: $e');
    }
  }

  Future<void> _deleteProfileImage() async {
    if (_accountProfile?['logo_url'] == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile Image'),
        content: const Text(
          'Are you sure you want to delete your profile image?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Delete from storage
      await _deleteImageFromStorage(_accountProfile!['logo_url']);

      // Update account to remove logo URL
      await Supabase.instance.client
          .from('accounts')
          .update({
            'logo_url': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _accountProfile!['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload profile
      await _loadUserProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  void _viewProfileImage() {
    if (_accountProfile?['logo_url'] == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _accountProfile!['logo_url'],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && _accountProfile != null) {
        await Supabase.instance.client
            .from('accounts')
            .update({
              'name': _nameController.text,
              'phone': _phoneController.text,
              'description': _descriptionController.text,
              'location_address': _locationController.text,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _accountProfile!['id']);

        setState(() {
          _isEditing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reload the profile to get updated data
        await _loadUserProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to get color based on category
  Color _getCategoryColor() {
    if (_categoryInfo == null) return Colors.blue;

    switch (_categoryInfo!['name'].toString().toLowerCase()) {
      case 'meals':
        return Colors.orange;
      case 'gym':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  // Helper method to get category-specific profile title
  String _getProfileTitle() {
    if (_categoryInfo == null) return 'Admin Profile';
    return '${_categoryInfo!['name']} Profile';
  }

  // Helper method to get category-specific icon
  IconData _getCategoryIcon() {
    if (_categoryInfo == null) return Icons.admin_panel_settings;

    switch (_categoryInfo!['name'].toString().toLowerCase()) {
      case 'meals':
        return Icons.restaurant;
      case 'gym':
        return Icons.fitness_center;
      default:
        return Icons.admin_panel_settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // appBar: const Navbar(showLoginButton: false),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Settings'),
            const SizedBox(width: 10),
            // Role Badge
            if (_userRole != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _userRole == 'ORG'
                      ? Colors.purple.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _userRole == 'ORG' ? Colors.purple : Colors.green,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _userRole == 'ORG' ? Icons.business : Icons.person,
                      size: 14,
                      color: _userRole == 'ORG' ? Colors.purple : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _userRole!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _userRole == 'ORG'
                            ? Colors.purple
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with category context
                  if (_categoryInfo != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor().withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getCategoryColor()),
                          ),
                          child: Text(
                            _categoryInfo!['name'].toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_categoryInfo != null) const SizedBox(height: 20),
                  // Admin Profile Section
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getProfileTitle(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isEditing ? Icons.check_circle : Icons.edit,
                                  color: _isEditing
                                      ? _getCategoryColor()
                                      : null,
                                ),
                                onPressed: _isEditing
                                    ? _saveProfile
                                    : () {
                                        setState(() {
                                          _isEditing = true;
                                        });
                                      },
                              ),
                            ],
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Editing mode',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Profile Image with edit functionality
                          Center(
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: _accountProfile?['logo_url'] != null
                                      ? _viewProfileImage
                                      : null,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _getCategoryColor(),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: _isUploadingImage
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _accountProfile?['logo_url'] != null
                                        ? ClipOval(
                                            child: Image.network(
                                              _accountProfile!['logo_url'],
                                              fit: BoxFit.cover,
                                              width: 120,
                                              height: 120,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      color: _getCategoryColor()
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      child: Icon(
                                                        _getCategoryIcon(),
                                                        size: 60,
                                                        color:
                                                            _getCategoryColor(),
                                                      ),
                                                    );
                                                  },
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _getCategoryColor()
                                                  .withValues(alpha: 0.2),
                                            ),
                                            child: Icon(
                                              _getCategoryIcon(),
                                              size: 60,
                                              color: _getCategoryColor(),
                                            ),
                                          ),
                                  ),
                                ),
                                // Edit button (pen icon)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                // Delete button (only show if image exists)
                                if (_accountProfile?['logo_url'] != null)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _deleteProfileImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email (non-editable)
                          _buildProfileField(
                            'Email',
                            Supabase.instance.client.auth.currentUser?.email ??
                                'N/A',
                            Icons.email,
                            isEditable: false,
                          ),

                          // Name
                          _buildProfileField(
                            'Name',
                            _nameController.text,
                            Icons.person,
                            controller: _nameController,
                            isEditable: _isEditing,
                          ),

                          // Phone
                          _buildProfileField(
                            'Phone',
                            _phoneController.text,
                            Icons.phone,
                            controller: _phoneController,
                            isEditable: _isEditing,
                          ),

                          // Description
                          _buildProfileField(
                            'Description',
                            _descriptionController.text,
                            Icons.description,
                            controller: _descriptionController,
                            isEditable: _isEditing,
                            maxLines: 3,
                          ),

                          // Location
                          _buildProfileField(
                            'Location',
                            _locationController.text,
                            Icons.location_on,
                            controller: _locationController,
                            isEditable: _isEditing,
                          ),

                          if (_isEditing) ...[
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _populateControllers(); // Reset to original values
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    foregroundColor: Colors.black, // Text color
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _saveProfile,
                                  icon: const Icon(Icons.save, size: 20),
                                  label: const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getCategoryColor(),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    elevation: 4,
                                    shadowColor: _getCategoryColor()
                                        .withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // QR Code Section (only for ORG accounts)
                  if (_accountProfile != null && _userRole == 'ORG') ...[
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My QR Code',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share this QR code with customers to promote your business',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            QRCodeGenerator(accountId: _accountProfile!['id']),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Additional Settings Sections
                  _buildSettingsSection('General Settings', [
                    _buildSettingsTile(
                      'Notifications',
                      Icons.notifications,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    if (_userRole == 'ORG')
                      _buildSettingsTile(
                        'Delivery Settings',
                        Icons.local_shipping,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeliverySettingsScreen(
                                accountId: _accountProfile?['id'],
                              ),
                            ),
                          );
                        },
                      ),
                    // _buildSettingsTile('Privacy', Icons.privacy_tip, () {
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //     const SnackBar(
                    //       content: Text('Privacy settings coming soon'),
                    //     ),
                    //   );
                    // }),
                    // _buildSettingsTile('Security', Icons.security, () {
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //     const SnackBar(
                    //       content: Text('Security settings coming soon'),
                    //     ),
                    //   );
                    // }),
                  ]),

                  const SizedBox(height: 20),

                  _buildSettingsSection('App Settings', [
                    _buildSettingsTile('Theme', Icons.palette, () async {
                      await showThemeSelector(context);
                    }),
                    _buildSettingsTile('Language', Icons.language, () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Language settings coming soon'),
                        ),
                      );
                    }),
                  ]),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileField(
    String label,
    String value,
    IconData icon, {
    TextEditingController? controller,
    bool isEditable = false,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isEditable
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
                width: isEditable ? 1.6 : 1,
              ),
              color: isEditable
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surfaceVariant,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isEditable
                      ? theme.colorScheme.primary
                      : theme.iconTheme.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isEditable && controller != null
                      ? TextField(
                          controller: controller,
                          maxLines: maxLines,
                          cursorColor: theme.colorScheme.primary,
                          style: theme.textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        )
                      : Text(
                          value.isEmpty ? 'Not set' : value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: value.isEmpty
                                ? theme.textTheme.bodySmall?.color
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
