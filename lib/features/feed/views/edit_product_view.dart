import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';

class EditProductView extends ConsumerStatefulWidget {
  final Map<String, dynamic> productItem;

  const EditProductView({super.key, required this.productItem});

  @override
  ConsumerState<EditProductView> createState() => _EditProductViewState();
}

class _VariantEditItem {
  final String? variantId; // null if newly generated
  final String variantValue; // e.g. "S / Pink" or "M"
  final String variantName; // "Variation" or "Size"
  int stock;
  final int reserved;
  final bool isExisting;

  _VariantEditItem({
    this.variantId,
    required this.variantValue,
    required this.variantName,
    required this.stock,
    this.reserved = 0,
    this.isExisting = false,
  });
}

class _PhotoEditItem {
  final String? imageUrl;
  final XFile? localFile;
  final Uint8List? localBytes;
  bool isPrimary;

  _PhotoEditItem({
    this.imageUrl,
    this.localFile,
    this.localBytes,
    this.isPrimary = false,
  });

  bool get isLocal => localFile != null;
}

class _EditProductViewState extends ConsumerState<EditProductView> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;
  late final TextEditingController _batchStockController;

  late String _status;
  late bool _isPreorder;
  late String _categoryName;
  late int _categoryId;

  // Photos
  final List<_PhotoEditItem> _photos = [];

  // Specifications
  final Map<String, TextEditingController> _attrTextControllers = {};
  final Map<String, String> _attrSelectValues = {};
  final Map<String, Set<String>> _attrMultiSelectValues = {};
  final Map<String, TextEditingController> _customAttrControllers = {};
  final Map<String, List<String>> _customAttributeOptions = {};
  bool _isDetailsAccordionExpanded = false;

  // Variants & Matrix
  final Map<String, _VariantEditItem> _variantMatrix = {};
  int _singleStockQuantity = 1;

  bool _isSaving = false;
  bool _isLoadingInitial = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.productItem['name']?.toString() ?? '');
    
    final rawPrice = widget.productItem['base_price'];
    final priceStr = (rawPrice is num)
        ? rawPrice.toStringAsFixed(2)
        : (rawPrice?.toString() ?? '0.00');
    _priceController = TextEditingController(text: priceStr);

    _descController = TextEditingController(text: widget.productItem['description']?.toString() ?? '');
    _batchStockController = TextEditingController(text: '5');
    _status = widget.productItem['status']?.toString() ?? 'ACTIVE';
    _isPreorder = widget.productItem['is_preorder_enabled'] == true;

    _categoryId = (widget.productItem['category_id'] as num?)?.toInt() ?? 9;
    _categoryName = ref.read(categoryNameToIdProvider).entries
        .firstWhere((e) => e.value == _categoryId, orElse: () => const MapEntry('Clothes', 9))
        .key;

    _initPhotos();
    _initSpecificationsAndVariants();
  }

  void _initPhotos() {
    final images = widget.productItem['product_images'] as List<dynamic>? ?? [];
    if (images.isNotEmpty) {
      for (final img in images) {
        if (img is Map) {
          final url = img['image_url']?.toString() ?? '';
          if (url.isNotEmpty) {
            _photos.add(_PhotoEditItem(
              imageUrl: url,
              isPrimary: img['is_primary'] == true,
            ));
          }
        }
      }
    }
    // Ensure exactly one photo is marked primary if list is non-empty
    if (_photos.isNotEmpty && !_photos.any((p) => p.isPrimary)) {
      _photos.first.isPrimary = true;
    }
  }

  void _initSpecificationsAndVariants() {
    // 1. Existing variants from productItem
    final existingVariants = widget.productItem['product_variants'] as List<dynamic>? ?? [];
    for (final v in existingVariants) {
      if (v is Map<String, dynamic>) {
        final vId = v['variant_id']?.toString();
        final vVal = v['variant_value']?.toString() ?? v['variant_name']?.toString() ?? 'Default';
        final vName = v['variant_name']?.toString() ?? 'Variation';
        
        int stock = 0;
        int reserved = 0;
        final inv = v['inventory'];
        if (inv is List && inv.isNotEmpty && inv[0] is Map) {
          stock = (inv[0]['stock_qty'] as num?)?.toInt() ?? 0;
          reserved = (inv[0]['reserved_qty'] as num?)?.toInt() ?? 0;
        } else if (inv is Map) {
          stock = (inv['stock_qty'] as num?)?.toInt() ?? 0;
          reserved = (inv['reserved_qty'] as num?)?.toInt() ?? 0;
        }

        _variantMatrix[vVal] = _VariantEditItem(
          variantId: vId,
          variantValue: vVal,
          variantName: vName,
          stock: stock,
          reserved: reserved,
          isExisting: true,
        );
      }
    }

    // 2. Parse category attributes from productItem
    final rawAttrs = widget.productItem['category_attributes'];
    List<dynamic> attrList = [];
    if (rawAttrs is String) {
      try {
        attrList = jsonDecode(rawAttrs) as List<dynamic>;
      } catch (_) {}
    } else if (rawAttrs is List) {
      attrList = rawAttrs;
    }

    for (final a in attrList) {
      if (a is Map) {
        final name = a['name']?.toString() ?? '';
        final value = a['value']?.toString() ?? '';
        if (name.isEmpty || value.isEmpty) continue;

        if (name.toLowerCase() == 'size' || name.toLowerCase() == 'color') {
          final delimiter = value.contains(',') ? ',' : (value.contains('·') ? '·' : (value.contains('/') ? '/' : ','));
          final parts = value.split(delimiter).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
          _attrMultiSelectValues[name] = parts;
        } else {
          _attrSelectValues[name] = value;
          _attrTextControllers[name] = TextEditingController(text: value);
        }
      }
    }

    // Rebuild variant matrix combinations if multi-select attributes are present
    _rebuildVariantMatrix();
    _isLoadingInitial = false;
  }

  void _rebuildVariantMatrix() {
    final sizes = (_attrMultiSelectValues['Size'] ?? {}).toList();
    final colors = (_attrMultiSelectValues['Color'] ?? {}).toList();

    // Canonical sorting of sizes
    sizes.sort((a, b) => ProductAttribute.sizeRank(a).compareTo(ProductAttribute.sizeRank(b)));

    final Set<String> expectedCombos = {};

    if (sizes.isNotEmpty && colors.isNotEmpty) {
      for (final s in sizes) {
        for (final c in colors) {
          expectedCombos.add('$s / $c');
        }
      }
    } else if (sizes.isNotEmpty) {
      for (final s in sizes) {
        expectedCombos.add(s);
      }
    } else if (colors.isNotEmpty) {
      for (final c in colors) {
        expectedCombos.add(c);
      }
    }

    if (expectedCombos.isNotEmpty) {
      // Add missing combinations
      for (final combo in expectedCombos) {
        if (!_variantMatrix.containsKey(combo)) {
          // Check if there is an existing equivalent (e.g. S · Pink vs S / Pink)
          final altKey = _variantMatrix.keys.firstWhere(
            (k) => k.replaceAll(' · ', ' / ') == combo || k.replaceAll(' / ', ' · ') == combo,
            orElse: () => '',
          );
          if (altKey.isNotEmpty) {
            final oldItem = _variantMatrix.remove(altKey)!;
            _variantMatrix[combo] = _VariantEditItem(
              variantId: oldItem.variantId,
              variantValue: combo,
              variantName: combo.contains(' / ') ? 'Variation' : 'Size',
              stock: oldItem.stock,
              reserved: oldItem.reserved,
              isExisting: oldItem.isExisting,
            );
          } else {
            _variantMatrix[combo] = _VariantEditItem(
              variantValue: combo,
              variantName: combo.contains(' / ') ? 'Variation' : 'Size',
              stock: 5,
              reserved: 0,
              isExisting: false,
            );
          }
        }
      }

      // Remove combinations that were unselected (unless they have active reservations)
      final keysToRemove = <String>[];
      for (final entry in _variantMatrix.entries) {
        if (!expectedCombos.contains(entry.key) && entry.value.reserved == 0) {
          keysToRemove.add(entry.key);
        }
      }
      for (final k in keysToRemove) {
        _variantMatrix.remove(k);
      }
    } else {
      // Single stock item
      if (_variantMatrix.isNotEmpty) {
        _singleStockQuantity = _variantMatrix.values.first.stock;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _batchStockController.dispose();
    for (final c in _attrTextControllers.values) {
      c.dispose();
    }
    for (final c in _customAttrControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── PHOTO ACTIONS ──
  Future<void> _pickPhotos(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedList = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1080,
        );
        for (final file in pickedList) {
          if (_photos.length >= 8) break;
          final bytes = await file.readAsBytes();
          setState(() {
            _photos.add(_PhotoEditItem(
              localFile: file,
              localBytes: bytes,
              isPrimary: _photos.isEmpty,
            ));
          });
        }
      } else {
        if (_photos.length >= 8) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 8 photos reached.')),
          );
          return;
        }
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1080,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          setState(() {
            _photos.add(_PhotoEditItem(
              localFile: picked,
              localBytes: bytes,
              isPrimary: _photos.isEmpty,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _addPhotoByUrl() async {
    final urlCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Image URL', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
            onPressed: () {
              final val = urlCtrl.text.trim();
              if (val.isNotEmpty && (val.startsWith('http://') || val.startsWith('https://'))) {
                setState(() {
                  _photos.add(_PhotoEditItem(
                    imageUrl: val,
                    isPrimary: _photos.isEmpty,
                  ));
                });
                Navigator.pop(dCtx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: TeknoyTheme.citMaroon),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(bCtx);
                _pickPhotos(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: TeknoyTheme.citMaroon),
              title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(bCtx);
                _pickPhotos(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: TeknoyTheme.citMaroon),
              title: const Text('Add via Image URL', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(bCtx);
                _addPhotoByUrl();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setPrimaryPhoto(int index) {
    setState(() {
      for (int i = 0; i < _photos.length; i++) {
        _photos[i].isPrimary = (i == index);
      }
    });
  }

  void _removePhoto(int index) {
    setState(() {
      final removed = _photos.removeAt(index);
      if (removed.isPrimary && _photos.isNotEmpty) {
        _photos.first.isPrimary = true;
      }
    });
  }

  // ── BATCH STOCK ACTIONS ──
  void _applyBatchStock() {
    final val = int.tryParse(_batchStockController.text.trim());
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid stock quantity (0 or more)')),
      );
      return;
    }
    setState(() {
      for (final item in _variantMatrix.values) {
        if (val >= item.reserved) {
          item.stock = val;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated all variant stocks to $val units!'),
        backgroundColor: TeknoyTheme.citMaroon,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── SAVING LOGIC ──
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least 1 product photo.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price greater than 0.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final productId = widget.productItem['product_id']?.toString() ?? '';
      final user = ref.read(authStateProvider).valueOrNull;
      final sellerId = user?.id ?? 'usr-seller';

      // 1. Upload any newly added local photos to Supabase Storage
      final List<Map<String, dynamic>> finalImageList = [];
      for (int i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (p.isLocal && p.localBytes != null) {
          final fileName = 'product_${sellerId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await SupabaseConfig.client.storage
              .from('product-images')
              .uploadBinary(
                fileName,
                p.localBytes!,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
          final publicUrl = SupabaseConfig.client.storage
              .from('product-images')
              .getPublicUrl(fileName);
          finalImageList.add({
            'url': publicUrl,
            'is_primary': p.isPrimary,
          });
        } else if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
          finalImageList.add({
            'url': p.imageUrl!,
            'is_primary': p.isPrimary,
          });
        }
      }

      // Ensure at least one is marked primary
      if (finalImageList.isNotEmpty && !finalImageList.any((img) => img['is_primary'] == true)) {
        finalImageList.first['is_primary'] = true;
      }

      // 2. Assemble category attributes JSON
      final List<Map<String, String>> categoryAttributes = [];
      for (final entry in _attrTextControllers.entries) {
        final val = entry.value.text.trim();
        if (val.isNotEmpty) {
          categoryAttributes.add({'name': entry.key, 'value': val});
        }
      }
      for (final entry in _attrSelectValues.entries) {
        if (entry.value.isNotEmpty && !entry.key.toLowerCase().contains('custom')) {
          categoryAttributes.add({'name': entry.key, 'value': entry.value});
        }
      }
      for (final entry in _attrMultiSelectValues.entries) {
        if (entry.value.isNotEmpty) {
          final list = entry.value.toList();
          if (entry.key.toLowerCase() == 'size') {
            list.sort((a, b) => ProductAttribute.sizeRank(a).compareTo(ProductAttribute.sizeRank(b)));
          }
          categoryAttributes.add({'name': entry.key, 'value': list.join(', ')});
        }
      }

      // 3. Update the `products` table
      await SupabaseConfig.client.from('products').update({
        'name': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'base_price': price,
        'status': _status,
        'is_preorder_enabled': _isPreorder,
        'category_attributes': categoryAttributes,
      }).eq('product_id', productId);

      // 4. Synchronize `product_images` table
      try {
        await SupabaseConfig.client
            .from('product_images')
            .delete()
            .eq('product_id', productId);

        for (final img in finalImageList) {
          await SupabaseConfig.client.from('product_images').insert({
            'product_id': productId,
            'image_url': img['url'],
            'is_primary': img['is_primary'],
          });
        }
      } catch (imgErr) {
        debugPrint('Image sync error: $imgErr');
      }

      // 5. Synchronize variants & inventories
      // 5a. Clean up removed variants from DB
      final existingDbVars = (widget.productItem['product_variants'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final currentActiveVariantIds = _variantMatrix.values
          .map((v) => v.variantId)
          .whereType<String>()
          .toSet();

      for (final oldVar in existingDbVars) {
        final oldVarId = oldVar['variant_id']?.toString();
        if (oldVarId != null && !currentActiveVariantIds.contains(oldVarId)) {
          int reserved = 0;
          final inv = oldVar['inventory'];
          if (inv is List && inv.isNotEmpty && inv[0] is Map) {
            reserved = (inv[0]['reserved_qty'] as num?)?.toInt() ?? 0;
          } else if (inv is Map) {
            reserved = (inv['reserved_qty'] as num?)?.toInt() ?? 0;
          }

          if (reserved > 0) {
            // Keep reserved units intact, set physical stock to reserved
            try {
              await SupabaseConfig.client
                  .from('inventory')
                  .update({'stock_qty': reserved, 'last_updated': DateTime.now().toIso8601String()})
                  .eq('variant_id', oldVarId);
            } catch (_) {}
          } else {
            // Safely delete inventory and variant rows
            try {
              await SupabaseConfig.client.from('inventory').delete().eq('variant_id', oldVarId);
              await SupabaseConfig.client.from('product_variants').delete().eq('variant_id', oldVarId);
            } catch (delErr) {
              debugPrint('Failed to delete removed variant $oldVarId: $delErr');
            }
          }
        }
      }

      // 5b. Update or insert active variants
      if (_variantMatrix.isNotEmpty) {
        for (final entry in _variantMatrix.entries) {
          final combo = entry.key;
          final item = entry.value;

          if (item.variantId != null && item.variantId!.isNotEmpty) {
            // Existing variant -> Update inventory
            await SupabaseConfig.client
                .from('inventory')
                .update({
                  'stock_qty': item.stock,
                  'last_updated': DateTime.now().toIso8601String(),
                })
                .eq('variant_id', item.variantId!);
          } else {
            // Newly created variant -> Insert into product_variants + inventory
            final cleanCombo = combo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
            final safeProd = productId.length >= 6 ? productId.substring(0, 6) : productId;
            final sku = 'SKU-${safeProd.toUpperCase()}-$cleanCombo-${DateTime.now().millisecondsSinceEpoch % 10000}';

            final inserted = await SupabaseConfig.client
                .from('product_variants')
                .insert({
                  'product_id': productId,
                  'variant_name': combo.contains(' / ') ? 'Variation' : 'Size',
                  'variant_value': combo,
                  'additional_price': 0,
                  'sku': sku,
                })
                .select()
                .maybeSingle();

            if (inserted != null && inserted['variant_id'] != null) {
              final newVarId = inserted['variant_id'].toString();
              await SupabaseConfig.client.from('inventory').insert({
                'variant_id': newVarId,
                'stock_qty': item.stock >= 0 ? item.stock : 0,
                'reserved_qty': 0,
                'low_stock_threshold': 1,
              });
            }
          }
        }
      } else {
        // Single default variant update
        final existingVars = widget.productItem['product_variants'] as List<dynamic>? ?? [];
        if (existingVars.isNotEmpty && existingVars.first is Map) {
          final firstVarId = existingVars.first['variant_id']?.toString();
          if (firstVarId != null && firstVarId.isNotEmpty) {
            await SupabaseConfig.client
                .from('inventory')
                .update({
                  'stock_qty': _singleStockQuantity,
                  'last_updated': DateTime.now().toIso8601String(),
                })
                .eq('variant_id', firstVarId);
          }
        }
      }

      // 6. Refresh feeds and notify
      await ref.read(productsListNotifierProvider.notifier).refresh();

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully!'),
            backgroundColor: TeknoyTheme.citMaroon,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update product: $e'),
            backgroundColor: TeknoyTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesAsync = ref.watch(categoryAttributeTemplatesProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0A0A) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Edit Product',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF141418) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveProduct,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: TeknoyTheme.citMaroon),
                    )
                  : const Icon(Icons.check_rounded, color: TeknoyTheme.citMaroon),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: TeknoyTheme.citMaroon,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // 1. Photos Section
                  _buildSectionCard(
                    isDark: isDark,
                    title: 'Product Photos (${_photos.length}/8)',
                    subtitle: 'Tap a photo to set as Cover Photo. Cover photo is shown in the feed.',
                    icon: Icons.photo_library_outlined,
                    child: _buildPhotosGrid(isDark),
                  ),
                  const SizedBox(height: 16),

                  // 2. Basic Information
                  _buildSectionCard(
                    isDark: isDark,
                    title: 'Basic Information',
                    subtitle: 'Product title, category & price',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Product Title *'),
                        TextFormField(
                          controller: _titleController,
                          maxLength: 80,
                          decoration: _inputDecoration(
                            hintText: 'e.g. Boxy Oversized Shirt',
                            isDark: isDark,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a product title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Category'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFEEEEF2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.category_outlined, size: 16, color: TeknoyTheme.citMaroon),
                                        const SizedBox(width: 8),
                                        Text(
                                          _categoryName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Base Price (₱) *'),
                                  TextFormField(
                                    controller: _priceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _inputDecoration(
                                      prefixText: '₱ ',
                                      hintText: '0.00',
                                      isDark: isDark,
                                    ),
                                    validator: (val) {
                                      final p = double.tryParse(val?.trim() ?? '');
                                      if (p == null || p <= 0) return 'Valid price required';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Description'),
                        TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            hintText: 'Describe details, fit, condition, material, campus meetup notes...',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Category Specifications
                  templatesAsync.when(
                    data: (templatesMap) {
                      final templates = templatesMap[_categoryName] ?? [];
                      if (templates.isEmpty) return const SizedBox.shrink();

                      // Non-variant attributes only (single select or text)
                      final specTemplates = templates.where((t) => !t.isMultiSelect).toList();
                      if (specTemplates.isEmpty) return const SizedBox.shrink();

                      // Split into primary (1-tap pill chips / top suggestions) & secondary (collapsible accordion)
                      final primaryConfig = primaryCategoryAttributeNames[_categoryName] ?? [];
                      final effectivePrimary = specTemplates
                          .where((t) => primaryConfig.contains(t.name))
                          .toList();
                      final effectiveSecondary = specTemplates
                          .where((t) => !primaryConfig.contains(t.name))
                          .toList();

                      // Count how many secondary attributes are filled
                      int filledSecondaryCount = 0;
                      for (final sec in effectiveSecondary) {
                        final val = sec.type == 'select'
                            ? _attrSelectValues[sec.name]
                            : _attrTextControllers[sec.name]?.text.trim();
                        if (val != null && val.isNotEmpty) {
                          filledSecondaryCount++;
                        }
                      }

                      return _buildSectionCard(
                        isDark: isDark,
                        title: '$_categoryName Specifications',
                        subtitle: 'Tap quick options below to speed up buyer discovery',
                        icon: Icons.list_alt_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Primary Attributes (1-Tap Chips)
                            ...effectivePrimary.map((t) => _buildAttributeField(t, isDark, isPrimary: true)),

                            // 2. Secondary Attributes (Collapsible Accordion)
                            if (effectiveSecondary.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF16161D) : const Color(0xFFF8F8FA),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _isDetailsAccordionExpanded
                                        ? TeknoyTheme.citMaroon.withValues(alpha: 0.35)
                                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
                                    width: _isDetailsAccordionExpanded ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => setState(() => _isDetailsAccordionExpanded = !_isDetailsAccordionExpanded),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isDetailsAccordionExpanded ? Icons.tune_rounded : Icons.add_circle_outline_rounded,
                                              size: 18,
                                              color: TeknoyTheme.citMaroon,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'More $_categoryName Details (Optional)',
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (filledSecondaryCount > 0)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '$filledSecondaryCount added',
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: TeknoyTheme.citMaroon,
                                                  ),
                                                ),
                                              ),
                                            AnimatedRotation(
                                              turns: _isDetailsAccordionExpanded ? 0.5 : 0.0,
                                              duration: const Duration(milliseconds: 200),
                                              child: Icon(
                                                Icons.keyboard_arrow_down_rounded,
                                                size: 20,
                                                color: isDark ? Colors.white54 : Colors.black45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    AnimatedCrossFade(
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06), height: 1),
                                            const SizedBox(height: 14),
                                            ...effectiveSecondary.map((t) => _buildAttributeField(t, isDark, isPrimary: false)),
                                          ],
                                        ),
                                      ),
                                      crossFadeState: _isDetailsAccordionExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 220),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // 4. Two-Tier Variant Matrix & Inventory (Shopee/Lazada Pro Max)
                  templatesAsync.when(
                    data: (templatesMap) {
                      final templates = templatesMap[_categoryName] ?? [];
                      final multiSelectTemplates = templates.where((t) => t.isMultiSelect).toList();

                      if (multiSelectTemplates.isEmpty) {
                        // Single stock quantity for non-variant products
                        return _buildSectionCard(
                          isDark: isDark,
                          title: 'Inventory Stock',
                          subtitle: 'Available quantity in stock',
                          icon: Icons.inventory_2_outlined,
                          child: Row(
                            children: [
                              const Text('Available Stock:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              _buildQuantityStepper(
                                value: _singleStockQuantity,
                                isDark: isDark,
                                onDecrement: _singleStockQuantity > 0
                                    ? () => setState(() => _singleStockQuantity--)
                                    : null,
                                onIncrement: () => setState(() => _singleStockQuantity++),
                              ),
                            ],
                          ),
                        );
                      }

                      return _buildSectionCard(
                        isDark: isDark,
                        title: 'Variants & Stock Matrix',
                        subtitle: 'Select all available sizes & colors. Adjust stock per variation.',
                        icon: Icons.tune_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 4a. Chips for each multi-select attribute (Size, Color)
                            ...multiSelectTemplates.map((t) => _buildMultiSelectPicker(t, isDark)),
                            const SizedBox(height: 16),

                            // 4b. Batch Set Stock Bar (Shopee / Lazada Feature)
                            if (_variantMatrix.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: TeknoyTheme.citMaroon.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 20, color: TeknoyTheme.citMaroon),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Batch Stock for All Variants:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(
                                        controller: _batchStockController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: TeknoyTheme.citMaroon,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: _applyBatchStock,
                                      child: const Text('Apply All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 4c. Individual Variant List
                            if (_variantMatrix.isNotEmpty) ...[
                              const Text(
                                'Individual Variant Quantities:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              ..._variantMatrix.entries.map((entry) => _buildVariantRow(entry.value, isDark)),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.center,
                                child: Text(
                                  'Select at least one Size or Color above to create variants.',
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // 5. Listing Status & Settings
                  _buildSectionCard(
                    isDark: isDark,
                    title: 'Listing Settings',
                    subtitle: 'Control listing visibility and pre-orders',
                    icon: Icons.settings_outlined,
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Listing is Active', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            _status == 'ACTIVE' ? 'Visible to campus buyers in feed' : 'Hidden from feed and search',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                          value: _status == 'ACTIVE',
                          activeThumbColor: TeknoyTheme.citMaroon,
                          onChanged: (val) {
                            setState(() => _status = val ? 'ACTIVE' : 'INACTIVE');
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pre-Orders Enabled', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            _isPreorder ? 'Accept orders ahead of batch arrival' : 'Only in-stock physical orders',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                          value: _isPreorder,
                          activeThumbColor: Colors.deepPurple,
                          onChanged: (val) {
                            setState(() => _isPreorder = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141418) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isSaving ? null : _saveProduct,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── WIDGET HELPERS ──
  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: TeknoyTheme.citMaroon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPhotosGrid(bool isDark) {
    return Column(
      children: [
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + (_photos.length < 8 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == _photos.length) {
                // Add Photo Button
                return InkWell(
                  onTap: _showAddPhotoOptions,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 95,
                    height: 105,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, color: TeknoyTheme.citMaroon, size: 28),
                        SizedBox(height: 6),
                        Text(
                          '+ Add Photo',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final photo = _photos[index];
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => _setPrimaryPhoto(index),
                    child: Container(
                      width: 95,
                      height: 105,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: photo.isPrimary ? TeknoyTheme.citMaroon : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: photo.isLocal && photo.localBytes != null
                            ? Image.memory(photo.localBytes!, fit: BoxFit.cover)
                            : (photo.imageUrl != null
                                ? Image.network(photo.imageUrl!, fit: BoxFit.cover)
                                : Container(color: Colors.grey)),
                      ),
                    ),
                  ),
                  // Cover Photo Badge
                  if (photo.isPrimary)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: TeknoyTheme.citMaroon,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Cover Photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  // Delete Button
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectPicker(CategoryAttributeTemplate template, bool isDark) {
    final attrName = template.name;
    final isSize = attrName.toLowerCase() == 'size';
    final isColor = attrName.toLowerCase() == 'color';

    final options = isSize
        ? (List<String>.from(template.options)..sort((a, b) => ProductAttribute.sizeRank(a).compareTo(ProductAttribute.sizeRank(b))))
        : (isColor ? template.options.where((o) => o.toLowerCase() != 'other').toList() : template.options);

    final selectedSet = _attrMultiSelectValues[attrName] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('$attrName Variations (${selectedSet.length} selected)'),
            if (isSize)
              TextButton(
                onPressed: () => _showAddCustomOptionDialog('Size'),
                child: const Text('+ Custom Size', style: TextStyle(fontSize: 12, color: TeknoyTheme.citMaroon, fontWeight: FontWeight.bold)),
              )
            else if (isColor)
              TextButton(
                onPressed: () => _showAddCustomOptionDialog('Color'),
                child: const Text('+ Custom Color', style: TextStyle(fontSize: 12, color: TeknoyTheme.citMaroon, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selectedSet.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              selectedColor: TeknoyTheme.citMaroon,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              backgroundColor: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF3F3F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    selectedSet.add(opt);
                  } else {
                    selectedSet.remove(opt);
                  }
                  _attrMultiSelectValues[attrName] = selectedSet;
                  _rebuildVariantMatrix();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showAddCustomOptionDialog(String attrType) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Add Custom $attrType', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'e.g. $attrType name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  final set = _attrMultiSelectValues[attrType] ?? {};
                  set.add(val);
                  _attrMultiSelectValues[attrType] = set;
                  _rebuildVariantMatrix();
                });
                Navigator.pop(dCtx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCustomSpecificationDialog(String templateName) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Add Custom $templateName', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'e.g. $templateName name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  final list = _customAttributeOptions.putIfAbsent(templateName, () => <String>[]);
                  if (!list.contains(val)) list.add(val);
                  _attrSelectValues[templateName] = val;
                });
                Navigator.pop(dCtx);
              }
            },
            child: const Text('Add & Select', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantRow(_VariantEditItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.variantValue,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter'),
                ),
                if (item.reserved > 0)
                  Text(
                    '${item.reserved} held in active reservations (min: ${item.reserved})',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          _buildQuantityStepper(
            value: item.stock,
            isDark: isDark,
            onDecrement: item.stock > item.reserved
                ? () {
                    setState(() => item.stock--);
                  }
                : null,
            onIncrement: () {
              setState(() => item.stock++);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStepper({
    required int value,
    required bool isDark,
    required VoidCallback? onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onDecrement,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.remove, size: 16, color: onDecrement != null ? TeknoyTheme.citMaroon : Colors.grey),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          InkWell(
            onTap: onIncrement,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.add, size: 16, color: TeknoyTheme.citMaroon),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeField(CategoryAttributeTemplate t, bool isDark, {required bool isPrimary}) {
    if (t.type == 'select') {
      final currentValue = _attrSelectValues[t.name];
      final customOptions = _customAttributeOptions.putIfAbsent(t.name, () => <String>[]);
      if (currentValue != null && currentValue.isNotEmpty && !t.options.contains(currentValue) && !customOptions.contains(currentValue)) {
        customOptions.add(currentValue);
      }
      final allOptions = [...t.options, ...customOptions];

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLabel(t.name),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Optional',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
                if (currentValue != null && currentValue.isNotEmpty) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _attrSelectValues.remove(t.name)),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...allOptions.map((opt) {
                  final isSelected = currentValue == opt;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _attrSelectValues.remove(t.name);
                        } else {
                          _attrSelectValues[t.name] = opt;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TeknoyTheme.citMaroon
                            : (isDark ? const Color(0xFF14141A) : const Color(0xFFFAFAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? TeknoyTheme.citMaroon
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            opt,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showAddCustomSpecificationDialog(t.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                    decoration: BoxDecoration(
                      color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.12 : 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: TeknoyTheme.citMaroon),
                        SizedBox(width: 4),
                        Text(
                          '+ Other',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: TeknoyTheme.citMaroon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      final ctrl = _attrTextControllers.putIfAbsent(
        t.name,
        () => TextEditingController(text: _attrSelectValues[t.name] ?? ''),
      );
      final suggestions = primaryAttributeQuickSuggestions[_categoryName]?[t.name] ?? [];

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLabel(t.name),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Optional',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
                if (suggestions.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    'Quick options',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: suggestions.map((sug) {
                  final isMatch = ctrl.text.trim().toLowerCase() == sug.toLowerCase();
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        if (isMatch) {
                          ctrl.clear();
                        } else {
                          ctrl.text = sug;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMatch
                            ? TeknoyTheme.citMaroon
                            : (isDark ? const Color(0xFF191922) : const Color(0xFFF1F1F5)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isMatch
                              ? TeknoyTheme.citMaroon
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: isMatch ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMatch) ...[
                            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            sug,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: isMatch ? FontWeight.bold : FontWeight.w500,
                              color: isMatch ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            TextFormField(
              controller: ctrl,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hintText: t.placeholder,
                isDark: isDark,
              ).copyWith(
                suffixIcon: ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => setState(() => ctrl.clear()),
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter'),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    String? prefixText,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF7F7F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TeknoyTheme.citMaroon, width: 1.5),
      ),
    );
  }
}
