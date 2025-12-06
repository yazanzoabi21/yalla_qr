import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/navbar.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/scan_prompt_overlay.dart';
import '../../services/qr_scanner_service.dart';
import '../../services/qr_code_service.dart';
import '../../models/organization_visitor.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../auth/login_screen.dart';
import 'organization_products_screen.dart';

class ClientCategoriesScreen extends StatefulWidget {
  const ClientCategoriesScreen({super.key});

  @override
  State<ClientCategoriesScreen> createState() => _ClientCategoriesScreenState();
}

class _ClientCategoriesScreenState extends State<ClientCategoriesScreen> {
  bool _showScanPrompt = true;
  List<OrganizationVisitor> _scanHistory = [];
  Map<String, Account> _orgAccounts = {}; // Cache for organization accounts
  Map<String, List<Category>> _accountCategories = {}; // Cache for account categories (account_id -> list of categories)
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if user logged in from different context
    final prefs = await SharedPreferences.getInstance();
    final loginContext = prefs.getString('login_context'); // 'ORG' or 'CLIENT'
    final existingUser = Supabase.instance.client.auth.currentUser;
    
    if (existingUser != null) {
      debugPrint('🔄 [ClientPage] Found existing session: ${existingUser.email}');
      debugPrint('🔄 [ClientPage] Login context: $loginContext');
      
      // If user logged in from ORG context, sign them out
      if (loginContext == 'ORG') {
        debugPrint('🔄 [ClientPage] User logged in from ORG context - signing out');
        await Supabase.instance.client.auth.signOut();
        await prefs.remove('login_context');
        await prefs.remove('last_scanned_qr');
        
        if (mounted) {
          setState(() {
            _scanHistory = [];
            _showScanPrompt = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login with a CLIENT account to scan QR codes'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // User is in correct context (CLIENT or null - first login), load their data
        debugPrint('🔄 [ClientPage] Loading user data...');
        _loadSavedScan();
        _loadScanHistory();
      }
    } else {
      debugPrint('🔄 [ClientPage] No user logged in');
    }
  }

  /// Check if current user is ORG - if so, sign them out for CLIENT page
  Future<void> _checkUserRoleAndAuth() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        debugPrint('🔍 [ClientPage] Checking user role...');
        debugPrint('   📧 Current auth user: ${user.email}');
        
        // Check user's role in accounts table - need to handle multiple accounts
        final accountsResponse = await Supabase.instance.client
            .from('accounts')
            .select('role')
            .eq('owner_id', user.id);
        
        if (accountsResponse.isNotEmpty) {
          // Check if ANY account is ORG role
          final hasOrgAccount = accountsResponse.any((acc) => acc['role'] == 'ORG');
          final hasUserAccount = accountsResponse.any((acc) => acc['role'] == 'USER');
          
          debugPrint('   👤 Found ${accountsResponse.length} account(s)');
          debugPrint('   👤 Has ORG account: $hasOrgAccount');
          debugPrint('   👤 Has USER account: $hasUserAccount');
          
          // If user has ONLY ORG accounts (no USER), sign them out
          if (hasOrgAccount && !hasUserAccount) {
            debugPrint('   ⚠️ ORG-only user detected on CLIENT page - signing out');
            await Supabase.instance.client.auth.signOut();
            
            // Clear any saved scan data
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('last_scanned_qr');
            
            if (mounted) {
              setState(() {
                _scanHistory = [];
                _showScanPrompt = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please login with a CLIENT account to scan QR codes'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            debugPrint('   ✅ CLIENT user confirmed');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking user role: $e');
    }
  }

  Future<void> _loadSavedScan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScan = prefs.getString('last_scanned_qr');
      if (savedScan != null && savedScan.isNotEmpty) {
        setState(() {
          _showScanPrompt = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved scan: $e');
    }
  }

  /// Load scan history from database
  Future<void> _loadScanHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('📊 [ClientPage] No user logged in, skipping history load');
        return;
      }

      setState(() {
        _isLoadingHistory = true;
      });

      debugPrint('📊 [ClientPage] Loading scan history for user: ${user.email}');
      
      // Get user's account ID
      final accountResponse = await Supabase.instance.client
          .from('accounts')
          .select('id, role')
          .eq('owner_id', user.id)
          .eq('role', 'USER')  // Filter for USER role only
          .maybeSingle();
      
      if (accountResponse == null) {
        debugPrint('⚠️ [ClientPage] No USER account found for user ${user.email}');
        setState(() {
          _isLoadingHistory = false;
        });
        return;
      }

      final accountId = accountResponse['id'] as String;
      debugPrint('   👤 Account ID: $accountId');
      debugPrint('   🔍 Querying organization_visitors where user_id = $accountId');
      
      // Get visitor records for this user (organizations they've visited)
      final visitHistory = await Supabase.instance.client
          .from('organization_visitors')
          .select()
          .eq('user_id', accountId)
          .order('last_scanned_at', ascending: false)
          .limit(20);

      debugPrint('   📋 Raw query result: $visitHistory');

      final history = (visitHistory as List)
          .map((json) => OrganizationVisitor.fromJson(json))
          .toList();

      debugPrint('✅ [ClientPage] Loaded ${history.length} scan records');
      
      if (history.isNotEmpty) {
        debugPrint('   📝 First record:');
        debugPrint('      - Organization ID: ${history[0].orgId}');
        debugPrint('      - User ID: ${history[0].userId}');
        debugPrint('      - Last scanned: ${history[0].lastScannedAt}');
      }

      // Fetch organization details for each scan
      final orgAccounts = <String, Account>{};
      final accountCategories = <String, List<Category>>{};
      
      for (var visit in history) {
        try {
          // Fetch account details
          final accountData = await Supabase.instance.client
              .from('accounts')
              .select()
              .eq('id', visit.orgId)
              .single();
          
          final account = Account.fromJson(accountData);
          orgAccounts[visit.orgId] = account;
          
          // Fetch categories for this account via account_categories junction table
          try {
            final categoryRelations = await Supabase.instance.client
                .from('account_categories')
                .select('category_id')
                .eq('account_id', visit.orgId)
                .eq('is_hidden', false);
            
            final categoryIds = (categoryRelations as List)
                .map((item) => item['category_id'] as String)
                .toList();
            
            // Fetch the actual category details
            final categoriesList = <Category>[];
            for (var categoryId in categoryIds) {
              final category = await CategoryService.getCategoryById(categoryId);
              if (category != null) {
                categoriesList.add(category);
              }
            }
            
            if (categoriesList.isNotEmpty) {
              accountCategories[visit.orgId] = categoriesList;
            }
          } catch (e) {
            debugPrint('Failed to fetch categories for account ${visit.orgId}: $e');
          }
        } catch (e) {
          debugPrint('Failed to fetch account for ${visit.orgId}: $e');
        }
      }

      setState(() {
        _scanHistory = history;
        _orgAccounts = orgAccounts;
        _accountCategories = accountCategories;
        _isLoadingHistory = false;
        if (history.isNotEmpty) {
          _showScanPrompt = false;
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ [ClientPage] Error loading scan history: $e');
      debugPrint('   Stack trace: $stackTrace');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _saveScan(String qrCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_scanned_qr', qrCode);
    } catch (e) {
      debugPrint('Error saving scan: $e');
    }
  }

  Future<void> _handleScan() async {
    // Check if user is logged in
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      // User is not logged in, show login screen for CLIENT registration
      if (!mounted) return;
      
      debugPrint('👤 Opening login for CLIENT registration (registerAsClient: true)');
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(
            registerAsClient: true, // Register as USER/CLIENT
          ),
        ),
      );
      
      // After login, check if user is now logged in
      final newUser = Supabase.instance.client.auth.currentUser;
      if (newUser == null) {
        // User cancelled login or login failed
        return;
      }
      
      // User is now logged in, continue with scan
      if (!mounted) return;
    }
    
    // User is logged in, proceed with scan
    final result = await QRScannerService.scanQRCode(context);
    if (result != null) {
      setState(() {
        _showScanPrompt = false;
      });
      
      // Save the scanned result
      await _saveScan(result);
      
      // Log the scan to scan_logs table
      debugPrint('\n════════════════════════════════════════════════════════════');
      debugPrint('🎯 [ClientCategories] Starting scan logging process');
      debugPrint('   📋 Scanned QR Code: $result');
      
      try {
        final qrCodeService = QRCodeService(Supabase.instance.client);
        debugPrint('   🔍 [ClientCategories] Looking up QR code in database...');
        
        final qrCode = await qrCodeService.getQRCodeByCode(result);
        
        if (qrCode != null) {
          debugPrint('   ✅ [ClientCategories] QR code found!');
          debugPrint('      - QR Code ID: ${qrCode.id}');
          debugPrint('      - Account ID: ${qrCode.accountId}');
          debugPrint('      - Code: ${qrCode.code}');
          
          // Check if user already has this organization in their scan history
          final orgId = qrCode.accountId;
          final alreadyScanned = _scanHistory.any((visit) => visit.orgId == orgId);
          
          if (alreadyScanned) {
            debugPrint('   ℹ️ [ClientCategories] Organization already in scan history');
            
            // Show toast that they already have this scan
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'You\'ve already scanned this organization before!',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
          
          debugPrint('   📝 [ClientCategories] Logging scan...');
          
          await qrCodeService.logScan(
            qrCodeId: qrCode.id,
          );
          
          debugPrint('   ✅ [ClientCategories] Scan logged successfully');
          debugPrint('   📊 This scan should trigger visitor tracking in QRCodeService.logScan()');
          
          // Show success message only for new scans
          if (mounted && !alreadyScanned) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New organization added to your scan history!',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } else {
          debugPrint('   ⚠️ [ClientCategories] QR code not found in database: $result');
        }
      } catch (e, stackTrace) {
        debugPrint('   ❌ [ClientCategories] Failed to log scan!');
        debugPrint('      Error: $e');
        debugPrint('      Stack: $stackTrace');
      }
      
      debugPrint('   ✅ [ClientCategories] Scan process completed');
      debugPrint('════════════════════════════════════════════════════════════\n');
      
      // Reload scan history after successful scan
      await _loadScanHistory();
    }
  }

  void _handleSkip() {
    setState(() {
      _showScanPrompt = false;
    });
  }

  Future<void> _viewOrganizationProducts(String organizationId) async {
    try {
      // Fetch account details for this organization
      final accountData = await Supabase.instance.client
          .from('accounts')
          .select()
          .eq('id', organizationId)
          .single();

      final account = Account.fromJson(accountData);

      if (!mounted) return;

      // Navigate to organization products screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrganizationProductsScreen(
            account: account,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load organization: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unenrollFromOrganization(String organizationId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get user's account ID
      final accountResponse = await Supabase.instance.client
          .from('accounts')
          .select('id')
          .eq('owner_id', user.id)
          .eq('role', 'USER')
          .maybeSingle();
      
      if (accountResponse == null) return;

      final accountId = accountResponse['id'] as String;

      // Delete the organization_visitors record
      await Supabase.instance.client
          .from('organization_visitors')
          .delete()
          .eq('user_id', accountId)
          .eq('org_id', organizationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Successfully unenrolled'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Reload scan history
        await _loadScanHistory();
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unenroll: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUnenrollMenu(BuildContext context, OrganizationVisitor visit, Color categoryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.exit_to_app,
                      color: Colors.red,
                    ),
                  ),
                  title: const Text(
                    'Unenroll',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Remove this organization from your list',
                    style: TextStyle(fontSize: 13),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Confirm Unenroll'),
                          content: const Text(
                            'Are you sure you want to unenroll from this organization? You\'ll need to scan their QR code again to re-enroll.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Unenroll'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      await _unenrollFromOrganization(visit.orgId);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      appBar: Navbar(
        showScanButton: true,
        onScanPressed: _handleScan,
      ),
      body: Stack(
        children: [
          // Main content - Show scan history
          _isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _scanHistory.isEmpty
                  ? EmptyStateWidget(
                      message: 'No Scans Yet',
                      icon: Icons.qr_code_2,
                      subtitle: 'Scan a QR code to get started',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadScanHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _scanHistory.length,
                        itemBuilder: (context, index) {
                          final visit = _scanHistory[index];
                          return _buildScanHistoryCard(visit);
                        },
                      ),
                    ),
          
          // Scan prompt overlay - only show when there's no scan history
          if (_scanHistory.isEmpty && !_isLoadingHistory)
            ScanPromptOverlay(
              onScan: _handleScan,
              onSkip: _handleSkip,
            ),
        ],
      ),
    );
  }

  Widget _buildScanHistoryCard(OrganizationVisitor visit) {
    final now = DateTime.now();
    final lastScanned = visit.lastScannedAt;
    final difference = now.difference(lastScanned);
    
    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (difference.inHours < 1) {
      timeAgo = '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      timeAgo = '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      timeAgo = '${difference.inDays}d ago';
    } else {
      timeAgo = '${lastScanned.day}/${lastScanned.month}/${lastScanned.year}';
    }

    // Get organization account and categories
    final account = _orgAccounts[visit.orgId];
    final categories = _accountCategories[visit.orgId] ?? [];
    final category = categories.isNotEmpty ? categories.first : null; // Use first category as primary
    
    // Get category-specific color and icon
    final categoryColor = category?.color ?? Colors.blue;
    final categoryIcon = category?.icon ?? Icons.business;
    final categoryName = category?.name ?? 'Business';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: categoryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _viewOrganizationProducts(visit.orgId),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                categoryColor.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Category Icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            categoryColor.withValues(alpha: 0.2),
                            categoryColor.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: categoryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category as large title
                          Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: 0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Organization name as a smaller subtitle (if available)
                          if (account?.name != null && account!.name!.isNotEmpty) ...[
                            Text(
                              account.name!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Time Badge
                    // Container(
                    //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    //   decoration: BoxDecoration(
                    //     color: categoryColor.withValues(alpha: 0.1),
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   child: Column(
                    //     children: [
                    //       Icon(
                    //         Icons.schedule,
                    //         size: 16,
                    //         color: categoryColor,
                    //       ),
                    //       const SizedBox(height: 4),
                    //       Text(
                    //         timeAgo,
                    //         style: TextStyle(
                    //           fontSize: 11,
                    //           color: categoryColor,
                    //           fontWeight: FontWeight.w700,
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    // const SizedBox(width: 8),
                    // Three dots menu button
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      child: IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: categoryColor,
                          size: 24,
                        ),
                        onPressed: () => _showUnenrollMenu(context, visit, categoryColor),
                        tooltip: 'Options',
                        style: IconButton.styleFrom(
                          backgroundColor: categoryColor.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Description if available
                if (account?.description != null && account!.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    account.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Stats Row
                // Container(
                //   padding: const EdgeInsets.all(12),
                //   decoration: BoxDecoration(
                //     color: categoryColor.withValues(alpha: 0.05),
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(
                //       color: categoryColor.withValues(alpha: 0.15),
                //       width: 1,
                //     ),
                //   ),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceAround,
                //     children: [
                //       _buildStatItem(
                //         Icons.access_time,
                //         'First Scan',
                //         '${visit.firstScannedAt.day}/${visit.firstScannedAt.month}/${visit.firstScannedAt.year}',
                //         categoryColor,
                //       ),
                //       Container(
                //         width: 1,
                //         height: 40,
                //         color: categoryColor.withValues(alpha: 0.2),
                //       ),
                //       _buildStatItem(
                //         Icons.update,
                //         'Last Scan',
                //         timeAgo,
                //         categoryColor,
                //       ),
                //     ],
                //   ),
                // ),
                
                // const SizedBox(height: 12),
                
                // Tap to view indicator
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tap to view products',
                        style: TextStyle(
                          fontSize: 13,
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: categoryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
