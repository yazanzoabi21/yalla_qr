import 'dart:io';

import 'package:flutter/material.dart';

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
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
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
