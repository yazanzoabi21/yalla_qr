import 'dart:io';

import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/camera_service.dart';
import '../services/currency_service.dart';
import '../services/product_service.dart';
import '../models/product.dart';

class AddProductForm extends StatefulWidget {
  final String categoryId;
  final Product? initialProduct;
  final void Function(Product)? onSaved;

  const AddProductForm({
    Key? key,
    required this.categoryId,
    this.initialProduct,
    this.onSaved,
  }) : super(key: key);

  @override
  State<AddProductForm> createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceLbpCtrl = TextEditingController();
  final _priceUsdCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  double _usdRate = 0;

  File? _imageFile;
  String? _existingImageUrl;
  bool _isSaving = false;
  bool _isGenerating = false;
  String _aiLanguage = 'en';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceLbpCtrl.dispose();
    _priceUsdCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUsdRate();
    // Rebuild when name changes so the AI button enables/disables correctly
    _nameCtrl.addListener(() => setState(() {}));
    // populate if editing
    final ip = widget.initialProduct;
    if (ip != null) {
      _nameCtrl.text = ip.name ?? '';
      _descCtrl.text = ip.description ?? '';
      _priceLbpCtrl.text = ip.priceLbp != null
          ? ip.priceLbp!.toStringAsFixed(0)
          : '';
      _priceUsdCtrl.text = ip.priceUsd != null
          ? ip.priceUsd!.toStringAsFixed(2)
          : '';
      _quantityCtrl.text = ip.quantity?.toString() ?? '1';
      _existingImageUrl = ip.imageUrl;
    }
  }

  Future<void> _generateDescription() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isGenerating = true);
    try {
      final description = await AiService.generateProductDescription(
        productName: name,
        priceLbp: double.tryParse(_priceLbpCtrl.text.replaceAll(',', '')),
        priceUsd: double.tryParse(_priceUsdCtrl.text.replaceAll(',', '')),
        language: _aiLanguage,
      );
      if (!mounted) return;
      setState(() => _descCtrl.text = description);
    } catch (e) {
      debugPrint('❌ [AddProductForm] AI generation failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI error: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _loadUsdRate() async {
    try {
      _usdRate = await CurrencyService.getUsdRate();
    } catch (_) {
      _usdRate = 0;
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await CameraService.showImageSourceDialog(
        context,
        currentImageFile: _imageFile,
        currentImageUrl: _existingImageUrl,
      );
      if (file != null) {
        setState(() => _imageFile = file);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image error: $e')));
    }
  }

  void _onLbpChanged(String v) {
    if (v.isEmpty) {
      _priceUsdCtrl.text = '';
      return;
    }
    final lbp = double.tryParse(v.replaceAll(',', ''));
    if (lbp == null) return;
    if (_usdRate > 0) {
      final usd = lbp / _usdRate;
      _priceUsdCtrl.text = usd.toStringAsFixed(2);
    }
  }

  void _onUsdChanged(String v) {
    if (v.isEmpty) {
      _priceLbpCtrl.text = '';
      return;
    }
    final usd = double.tryParse(v.replaceAll(',', ''));
    if (usd == null) return;
    if (_usdRate > 0) {
      final lbp = usd * _usdRate;
      _priceLbpCtrl.text = lbp.toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        final filename = _nameCtrl.text.trim().replaceAll(' ', '_') + '.jpg';
        imageUrl = await CameraService.uploadImageToSupabase(
          _imageFile!,
          filename,
        );
      }

      final priceLbp = double.tryParse(_priceLbpCtrl.text.replaceAll(',', ''));
      final priceUsd = double.tryParse(_priceUsdCtrl.text.replaceAll(',', ''));

      if (widget.initialProduct == null) {
        // create
        final product = await ProductService.createProduct(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          priceLbp: priceLbp,
          priceUsd: priceUsd,
          imageUrl: imageUrl,
          inStock: (int.tryParse(_quantityCtrl.text) ?? 1) > 0,
          categoryId: widget.categoryId,
        );

        widget.onSaved?.call(product);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        // update
        final prodId = widget.initialProduct!.id;
        final updated = await ProductService.updateProduct(
          productId: prodId!,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          priceLbp: priceLbp,
          priceUsd: priceUsd,
          imageUrl: imageUrl ?? _existingImageUrl,
          quantity:
              int.tryParse(_quantityCtrl.text) ??
              widget.initialProduct!.quantity,
        );

        widget.onSaved?.call(updated);
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create product: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imageFile == null
                    ? (_existingImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _existingImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 160,
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.camera_alt, size: 36),
                                  SizedBox(height: 8),
                                  Text('Tap to take photo'),
                                ],
                              ),
                            ))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 160,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a name' : null,
                  ),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      suffixIcon: Tooltip(
                        message: _nameCtrl.text.trim().isEmpty
                            ? 'Enter a product name first'
                            : 'Generate description with AI',
                        child: _isGenerating
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.auto_awesome),
                                color: Colors.amber,
                                onPressed: _nameCtrl.text.trim().isEmpty
                                    ? null
                                    : _generateDescription,
                              ),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  // Language selector for AI description
                  Row(
                    children: [
                      const Text('AI Language:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 8),
                      for (final entry in const [
                        ('en', 'EN'),
                        ('ar', 'AR'),
                        ('fr', 'FR'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(entry.$2, style: const TextStyle(fontSize: 12)),
                            selected: _aiLanguage == entry.$1,
                            onSelected: (_) => setState(() => _aiLanguage = entry.$1),
                            selectedColor: const Color.fromARGB(255, 85, 68, 17),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceLbpCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Price (LBP)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: _onLbpChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _priceUsdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Price (USD)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: _onUsdChanged,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _quantityCtrl,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
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
}
