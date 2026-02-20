# Category Components Refactoring

This document describes the reusable category components that have been created to standardize category management across different modules (supermarket, meals, gym, etc.).

## Components Created

### 1. CategoryHeaderCard (`lib/widgets/category_header_card.dart`)
A reusable header card widget that displays a gradient card with icon, title, and description.

**Usage:**
```dart
CategoryHeaderCard(
  title: 'Super Market',
  description: 'Manage your grocery and retail products',
  icon: Icons.local_grocery_store,
  gradientColors: [
    Colors.green.shade600,
    Colors.green.shade400,
    Colors.green.shade300,
  ],
)
```

### 2. CategoryGridView (`lib/widgets/category_grid_view.dart`)
A reusable grid view widget for displaying child categories with icons, names, and product counts.

**Features:**
- Grid layout with 2 columns
- Category cards with gradient colors
- Product count badges
- Edit button on each card
- Optional background image
- Tap to navigate to category details

**Usage:**
```dart
CategoryGridView(
  categories: childCategories,
  productCounts: productCounts,
  onCategoryTap: _onChildCategoryTap,
  onEditCategory: _showEditCategoryDialog,
  backgroundImagePath: 'assets/images/SuperMarket.png',
  productLabel: 'product',
)
```

### 3. CategoryDialog (`lib/widgets/category_dialog.dart`)
A reusable dialog widget for adding or editing categories with icon and color selection.

**Features:**
- Add or edit mode (determined by passing null or existing category)
- Text fields for name and description
- Color picker with predefined and custom colors
- Icon picker with predefined and custom icons
- Delete functionality (edit mode only)
- Form validation
- Loading states

**Usage:**
```dart
// Add new category
showDialog(
  context: context,
  builder: (context) => CategoryDialog(
    parentCategoryId: parentCategory.id,
    title: 'Add New Category',
    actionButtonText: 'Add Category',
    defaultColors: [Colors.green, Colors.blue, ...],
    defaultIcons: [Icons.shopping_cart, Icons.store, ...],
    onSuccess: () {
      // Refresh categories
      _refreshChildCategories();
    },
  ),
);

// Edit existing category
showDialog(
  context: context,
  builder: (context) => CategoryDialog(
    category: existingCategory,
    parentCategoryId: parentCategory.id,
    title: 'Edit Category',
    actionButtonText: 'Save Changes',
    defaultColors: [Colors.green, Colors.blue, ...],
    defaultIcons: [Icons.shopping_cart, Icons.store, ...],
    onSuccess: () {
      // Refresh categories
      _refreshChildCategories();
    },
  ),
);
```

### 4. CategoryEmptyState (`lib/widgets/category_empty_state.dart`)
A reusable empty state widget for when no categories exist.

**Usage:**
```dart
CategoryEmptyState(
  icon: Icons.shopping_bag_outlined,
  title: 'No Categories Yet',
  subtitle: 'Create categories to get started',
)
```

## Refactored Screens

### SuperMarketScreen
- **Old:** `lib/screens/super_market/super_market_screen.dart` (~1440 lines)
- **New:** `lib/screens/super_market/super_market_screen_refactored.dart` (~344 lines)
- **Reduction:** ~75% less code

### MealsScreen
- **Old:** `lib/screens/meals/meals_screen.dart` (~1750 lines)
- **New:** `lib/screens/meals/meals_screen_refactored.dart` (~419 lines)
- **Reduction:** ~76% less code

## Benefits

1. **Code Reusability**: Same components can be used across supermarket, meals, gym, and other category-based modules
2. **Maintainability**: Changes to category UI/UX only need to be made in one place
3. **Consistency**: All category screens have the same look and feel
4. **Reduced Complexity**: Screens are much shorter and easier to understand
5. **Separation of Concerns**: UI components are separated from business logic

## How to Apply

To use the refactored screens, replace the old files with the new ones:

```bash
# Backup old files (optional)
mv lib/screens/super_market/super_market_screen.dart lib/screens/super_market/super_market_screen_old.dart
mv lib/screens/meals/meals_screen.dart lib/screens/meals/meals_screen_old.dart

# Rename refactored files
mv lib/screens/super_market/super_market_screen_refactored.dart lib/screens/super_market/super_market_screen.dart
mv lib/screens/meals/meals_screen_refactored.dart lib/screens/meals/meals_screen.dart
```

## Creating New Category-Based Modules

To create a new category-based module (e.g., Gym, Pharmacy), follow this pattern:

```dart
import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../widgets/category_header_card.dart';
import '../../widgets/category_grid_view.dart';
import '../../widgets/category_dialog.dart';
import '../../widgets/category_empty_state.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../models/category.dart';

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<Category> childCategories = [];
  Map<String, int> productCounts = {};
  Category? gymCategory;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load parent category (Gym)
    // Load child categories
    // Load product counts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(showMenuButton: false),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: CategoryHeaderCard(
              title: 'Gym',
              description: 'Manage your gym equipment and services',
              icon: Icons.fitness_center,
              gradientColors: [
                Colors.purple.shade600,
                Colors.purple.shade400,
                Colors.purple.shade300,
              ],
            ),
          ),
          // ... rest of the layout using CategoryGridView, etc.
        ],
      ),
    );
  }
}
```

## Component Customization

All components support theming and can be customized through parameters:

- **CategoryHeaderCard**: Custom gradients, icons, titles
- **CategoryGridView**: Custom background images, product labels
- **CategoryDialog**: Custom color palettes, icon sets
- **CategoryEmptyState**: Custom icons, titles, subtitles

## Dependencies

These components depend on:
- `../../models/category.dart`
- `../../services/category_service.dart`
- `../../services/product_service.dart`

Ensure these services and models are properly implemented in your project.
