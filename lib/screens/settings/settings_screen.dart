import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/navbar.dart';

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
        }

        // Get account profile from the accounts table based on user and category
        final query = Supabase.instance.client
            .from('accounts')
            .select('*, categories(*)')
            .eq('owner_id', user.id);
        
        // If we have a specific category, filter by it
        if (_categoryInfo != null) {
          query.eq('category_id', _categoryInfo!['id']);
        }
        
        final response = await query.maybeSingle();
        
        setState(() {
          _accountProfile = response;
          _populateControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
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
    return Scaffold(
      appBar: const Navbar(showLoginButton: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with category context
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_categoryInfo != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    ],
                  ),
                  const SizedBox(height: 20),

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
                                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                                onPressed: _isEditing ? _saveProfile : () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Profile Avatar with category-specific styling
                          Center(
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: _getCategoryColor().withValues(alpha: 0.2),
                              child: Icon(
                                _getCategoryIcon(),
                                size: 60,
                                color: _getCategoryColor(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email (non-editable)
                          _buildProfileField(
                            'Email',
                            Supabase.instance.client.auth.currentUser?.email ?? 'N/A',
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
                                  ),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getCategoryColor(),
                                  ),
                                  child: const Text('Save Changes'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Additional Settings Sections
                  _buildSettingsSection(
                    'General Settings',
                    [
                      _buildSettingsTile(
                        'Notifications',
                        Icons.notifications,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notifications settings coming soon')),
                          );
                        },
                      ),
                      _buildSettingsTile(
                        'Privacy',
                        Icons.privacy_tip,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Privacy settings coming soon')),
                          );
                        },
                      ),
                      _buildSettingsTile(
                        'Security',
                        Icons.security,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Security settings coming soon')),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSettingsSection(
                    'App Settings',
                    [
                      _buildSettingsTile(
                        'Theme',
                        Icons.palette,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Theme settings coming soon')),
                          );
                        },
                      ),
                      _buildSettingsTile(
                        'Language',
                        Icons.language,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Language settings coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: isEditable ? Colors.white : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: isEditable && controller != null
                      ? TextField(
                          controller: controller,
                          maxLines: maxLines,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                      : Text(
                          value.isEmpty ? 'Not set' : value,
                          style: TextStyle(
                            fontSize: 16,
                            color: value.isEmpty ? Colors.grey : Colors.black87,
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
