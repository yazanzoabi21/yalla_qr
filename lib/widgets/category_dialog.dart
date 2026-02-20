import 'dart:math';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';

/// Reusable dialog widget for adding or editing categories
/// Supports icon and color selection with customization options
class CategoryDialog extends StatefulWidget {
  final Category? category; // null for add, non-null for edit
  final String parentCategoryId;
  final String title; // e.g., "Add New Category" or "Edit Category"
  final String actionButtonText; // e.g., "Add Category" or "Save Changes"
  final List<Color> defaultColors;
  final List<IconData> defaultIcons;
  final VoidCallback onSuccess;

  const CategoryDialog({
    super.key,
    this.category,
    required this.parentCategoryId,
    required this.title,
    required this.actionButtonText,
    required this.defaultColors,
    required this.defaultIcons,
    required this.onSuccess,
  });

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late Color selectedColor;
  late IconData selectedIcon;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.category?.name ?? '');
    descriptionController = TextEditingController(text: widget.category?.description ?? '');
    selectedColor = widget.category?.color ?? _generateRandomColor();
    selectedIcon = widget.category?.icon ?? Icons.category;
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Color _generateRandomColor() {
    final random = Random();
    final hue = random.nextDouble() * 360;
    final saturation = 0.6 + random.nextDouble() * 0.4;
    final value = 0.7 + random.nextDouble() * 0.3;
    return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
  }

  // Return a truncated list of icons to display in the main dialog.
  List<IconData> _visibleIcons(List<IconData> icons, int maxVisible) {
    if (icons.length <= maxVisible) return icons;
    return icons.sublist(0, maxVisible);
  }

  Future<void> _handleSubmit() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (widget.category == null) {
        // Create new category
        await CategoryService.createCategoryForAccount(
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
          parentId: widget.parentCategoryId,
          iconCode: selectedIcon.codePoint,
          colorValue: '0x${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        );
      } else {
        // Update existing category
        await CategoryService.updateCategory(
          id: widget.category!.id,
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
          iconCode: selectedIcon.codePoint,
          colorValue: '0x${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleDelete() async {
    if (widget.category == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${widget.category!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      await CategoryService.deleteCategory(widget.category!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose Color:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...widget.defaultColors.map((color) => _ColorOption(
                    color: color,
                    isSelected: selectedColor == color,
                    onTap: () => setState(() => selectedColor = color),
                  )),
                  _CustomColorButton(
                    currentColor: selectedColor,
                    onColorSelected: (color) => setState(() => selectedColor = color),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose Icon:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Show a compact set of icons in the main dialog and
                  // expose the rest via the "More" button. Keeps UI consistent
                  // with the SuperMarket module where a small palette is shown.
                  ..._visibleIcons(widget.defaultIcons, 8).map((icon) => _IconOption(
                    icon: icon,
                    color: selectedColor,
                    isSelected: selectedIcon == icon,
                    onTap: () => setState(() => selectedIcon = icon),
                  )),
                  _CustomIconButton(
                    currentIcon: selectedIcon,
                    color: selectedColor,
                    onIconSelected: (icon) => setState(() => selectedIcon = icon),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.category != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _handleDelete,
                          icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                          label: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                  if (widget.category != null) const SizedBox(width: 10),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SizedBox(
                      height: 36,
                      child: TextButton(
                        onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(widget.actionButtonText, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
              : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final Color currentColor;
  final Function(Color) onColorSelected;

  const _CustomColorButton({
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400, width: 2),
        ),
        child: const Icon(Icons.palette, size: 20),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    Color selectedColor = currentColor;
    double hue = HSVColor.fromColor(currentColor).hue;
    double saturation = HSVColor.fromColor(currentColor).saturation;
    double value = HSVColor.fromColor(currentColor).value;

    final result = await showDialog<Color>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();

            return AlertDialog(
              title: const Text('Choose Custom Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ColorSlider(
                      label: 'Hue',
                      value: hue,
                      max: 360,
                      onChanged: (val) => setState(() => hue = val),
                    ),
                    _ColorSlider(
                      label: 'Saturation',
                      value: saturation,
                      max: 1.0,
                      onChanged: (val) => setState(() => saturation = val),
                    ),
                    _ColorSlider(
                      label: 'Brightness',
                      value: value,
                      max: 1.0,
                      onChanged: (val) => setState(() => value = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selectedColor),
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      onColorSelected(result);
    }
  }
}

class _ColorSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Function(double) onChanged;

  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(0)}'),
        Slider(
          value: value,
          min: 0,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _IconOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconOption({
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Icon(icon, color: isSelected ? color : Colors.grey.shade700),
      ),
    );
  }
}

class _CustomIconButton extends StatelessWidget {
  final IconData currentIcon;
  final Color color;
  final Function(IconData) onIconSelected;

  const _CustomIconButton({
    required this.currentIcon,
    required this.color,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showIconPicker(context),
      child: Container(
        width: 80,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.more_horiz, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text('More', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Future<void> _showIconPicker(BuildContext context) async {
    final allIcons = _getDefaultIcons();
    IconData selectedIcon = currentIcon;

    final result = await showDialog<IconData>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Choose Icon'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: allIcons.length,
                  itemBuilder: (context, index) {
                    final icon = allIcons[index];
                    final isSelected = selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = icon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: color, width: 2) : null,
                        ),
                        child: Icon(icon, color: isSelected ? color : Colors.grey.shade700),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selectedIcon),
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      onIconSelected(result);
    }
  }

  List<IconData> _getDefaultIcons() {
    return [
      Icons.shopping_cart, Icons.shopping_bag, Icons.store,
      Icons.storefront, Icons.local_grocery_store, Icons.shopping_basket,
      Icons.kitchen, Icons.restaurant, Icons.local_cafe,
      Icons.bakery_dining, Icons.local_pizza, Icons.wine_bar,
      Icons.local_bar, Icons.cake, Icons.icecream,
      Icons.fastfood, Icons.lunch_dining, Icons.local_dining,
      Icons.food_bank, Icons.egg_alt, Icons.breakfast_dining,
      Icons.ramen_dining, Icons.apple, Icons.water_drop,
      Icons.cleaning_services, Icons.shower, Icons.soap,
      Icons.sanitizer, Icons.local_pharmacy, Icons.medication,
      Icons.vaccines, Icons.checkroom, Icons.dry_cleaning,
      Icons.print, Icons.toys, Icons.sports_basketball,
      Icons.fitness_center, Icons.pets, Icons.emoji_nature,
      Icons.yard, Icons.local_florist, Icons.brightness_5,
      Icons.lightbulb, Icons.power, Icons.electrical_services,
      Icons.plumbing, Icons.hardware, Icons.build,
      Icons.handyman, Icons.carpenter, Icons.home_repair_service,
      Icons.construction, Icons.settings, Icons.phone_android,
      Icons.computer, Icons.headphones, Icons.watch,
      Icons.camera_alt, Icons.videogame_asset, Icons.sports_esports,
      Icons.book, Icons.menu_book, Icons.library_books,
      Icons.school, Icons.brush, Icons.palette,
      Icons.dinner_dining, Icons.set_meal, Icons.restaurant_menu,
      Icons.rice_bowl, Icons.soup_kitchen, Icons.tapas,
      Icons.emoji_food_beverage, Icons.outdoor_grill, Icons.microwave,
      Icons.blender, Icons.dining, Icons.brunch_dining,
      Icons.nightlife, Icons.bento, Icons.cookie, Icons.flatware,
      Icons.liquor, Icons.sports_bar, Icons.takeout_dining, Icons.kebab_dining,
    ];
  }
}
