import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/account.dart';

class ClientFilterDialog extends StatefulWidget {
  final List<Account> organizations;
  final List<Category> allCategories;
  final Set<String> selectedOrganizationIds;
  final Set<String> selectedCategoryIds;
  final Function(Set<String> orgIds, Set<String> categoryIds) onApplyFilters;

  const ClientFilterDialog({
    super.key,
    required this.organizations,
    required this.allCategories,
    required this.selectedOrganizationIds,
    required this.selectedCategoryIds,
    required this.onApplyFilters,
  });

  @override
  State<ClientFilterDialog> createState() => _ClientFilterDialogState();
}

class _ClientFilterDialogState extends State<ClientFilterDialog> {
  late Set<String> _selectedOrgIds;
  late Set<String> _selectedCategoryIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedOrgIds = Set.from(widget.selectedOrganizationIds);
    _selectedCategoryIds = Set.from(widget.selectedCategoryIds);
  }

  List<Account> get _filteredOrganizations {
    if (_searchQuery.isEmpty) {
      return widget.organizations;
    }

    final query = _searchQuery.toLowerCase();
    return widget.organizations.where((org) {
      return org.name.toLowerCase().contains(query) ||
          (org.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedOrgIds.clear();
      _selectedCategoryIds.clear();
    });
  }

  void _selectAllOrganizations() {
    setState(() {
      _selectedOrgIds = widget.organizations.map((org) => org.id).toSet();
    });
  }

  void _selectAllCategories() {
    setState(() {
      _selectedCategoryIds = widget.allCategories.map((cat) => cat.id).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        _selectedOrgIds.isNotEmpty || _selectedCategoryIds.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.filter_list, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filter Organizations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasActiveFilters)
                    TextButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search organizations...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Filter content
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Colors.blue.shade700,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blue.shade700,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.business, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Organizations ${_selectedOrgIds.isNotEmpty ? "(${_selectedOrgIds.length})" : ""}',
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.category, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Categories ${_selectedCategoryIds.isNotEmpty ? "(${_selectedCategoryIds.length})" : ""}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Organizations Tab
                          _buildOrganizationsTab(),
                          // Categories Tab
                          _buildCategoriesTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApplyFilters(
                          _selectedOrgIds,
                          _selectedCategoryIds,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationsTab() {
    return Column(
      children: [
        // Select all button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredOrganizations.length} organizations',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: _selectAllOrganizations,
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Select All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),

        // Organizations list
        Expanded(
          child: _filteredOrganizations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No organizations found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredOrganizations.length,
                  itemBuilder: (context, index) {
                    final org = _filteredOrganizations[index];
                    final isSelected = _selectedOrgIds.contains(org.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.blue.shade300
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedOrgIds.add(org.id);
                            } else {
                              _selectedOrgIds.remove(org.id);
                            }
                          });
                        },
                        title: Text(
                          org.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle:
                            org.description != null &&
                                org.description!.isNotEmpty
                            ? Text(
                                org.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.business,
                            color: isSelected
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        activeColor: Colors.blue.shade700,
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        // Select all button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.allCategories.length} categories',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: _selectAllCategories,
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Select All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),

        // Categories list
        Expanded(
          child: widget.allCategories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No categories available',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.allCategories.length,
                  itemBuilder: (context, index) {
                    final category = widget.allCategories[index];
                    final isSelected = _selectedCategoryIds.contains(
                      category.id,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? category.color.withValues(alpha: 0.5)
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedCategoryIds.add(category.id);
                            } else {
                              _selectedCategoryIds.remove(category.id);
                            }
                          });
                        },
                        title: Text(
                          category.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle:
                            category.description != null &&
                                category.description!.isNotEmpty
                            ? Text(
                                category.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? category.color.withValues(alpha: 0.2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            category.icon,
                            color: isSelected
                                ? category.color
                                : Colors.grey.shade600,
                          ),
                        ),
                        activeColor: category.color,
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
