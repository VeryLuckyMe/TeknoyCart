import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/auth/views/widgets/seller_kyc_verification_view.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/manage_listings_view.dart';

/// Modular Sell Tab for ProductDiscoveryFeedView (HIGH-04).
class SellTab extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const SellTab({super.key, this.onNavigateTab});

  @override
  ConsumerState<SellTab> createState() => _SellTabState();
}

class _SellTabState extends ConsumerState<SellTab> {
  int _sellSubTab = 0; // 0: List New Item, 1: My Listings

  final ScrollController _categoryScrollController = ScrollController();


  // Form controllers for Sell tab
  final _sellTitleController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _sellDescController = TextEditingController();
  final _sellStockController = TextEditingController(text: '1');
  String _sellCategory = 'Books';
  String _sellCondition = 'New';
  final List<XFile> _selectedImageFiles = [];
  bool _isUploadingProductImage = false;
  final _imagePicker = ImagePicker();

  // Category-specific attribute controllers (dynamic per category)
  final Map<String, TextEditingController> _attributeTextControllers = {};
  final Map<String, String> _attributeSelectValues = {};
  final Map<String, Set<String>> _attributeMultiSelectValues = {};
  final Map<String, List<String>> _customAttributeOptions = {};
  final Map<String, TextEditingController> _variantStockControllers = {};
  final TextEditingController _batchStockController = TextEditingController(text: '5');
  bool _isDetailsAccordionExpanded = false;

  bool get _hasActiveVariants {
    return _attributeMultiSelectValues.values.any((set) => set.isNotEmpty);
  }

  List<String> get _variationCombinations {
    final activeEntries = _attributeMultiSelectValues.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (activeEntries.isEmpty) return const [];

    List<String> getSortedOptions(MapEntry<String, Set<String>> entry) {
      final list = entry.value.toList();
      if (entry.key.trim().toLowerCase() == 'size') {
        list.sort((a, b) => ProductAttribute.sizeRank(a).compareTo(ProductAttribute.sizeRank(b)));
      }
      return list;
    }

    if (activeEntries.length == 1) {
      return getSortedOptions(activeEntries.first);
    }

    // Generate cartesian product across all active variation dimensions (e.g. Size x Color)
    List<String> combinations = getSortedOptions(activeEntries.first);
    for (int i = 1; i < activeEntries.length; i++) {
      final nextOptions = getSortedOptions(activeEntries[i]);
      final List<String> nextCombos = [];
      for (final prefix in combinations) {
        for (final opt in nextOptions) {
          nextCombos.add('$prefix · $opt');
        }
      }
      combinations = nextCombos;
    }
    return combinations;
  }

  int get _calculatedTotalVariantStock {
    final combos = _variationCombinations;
    if (combos.isEmpty) {
      return int.tryParse(_sellStockController.text.trim()) ?? 1;
    }
    int total = 0;
    for (final combo in combos) {
      final ctrl = _variantStockControllers[combo];
      total += int.tryParse(ctrl?.text.trim() ?? '') ?? 5;
    }
    return total;
  }

  static const List<String> _foodConditionOptions = [
    'Freshly Prepared / Daily Cooked',
    'Packaged & Sealed (Brand New)',
    'Made to Order',
    'Frozen / Chilled',
  ];

  static const List<String> _generalConditionOptions = [
    'New',
    'Like New',
    'Gently Used',
    'Well Used',
  ];

  static const Map<String, List<String>> _quickTitleStarters = {
    'Books': [
      'Calculus Early Transcendentals',
      'University Physics',
      'Engineering Mechanics',
      'Differential Equations',
    ],
    'Uniforms': [
      'CIT-U Official PE Shirt',
      'CIT-U School Uniform Polo',
      'Department Organization Shirt',
      'CEA White Lab Gown',
    ],
    'Clothes': [
      'Oversized Graphic T-Shirt',
      'Vintage Baggy Denim Jorts',
      'Campus Fleece Hoodie',
      'Relaxed Fit Cargo Shorts',
    ],
    'Electronics': [
      'Casio Scientific Calculator',
      'Wireless Ergonomic Mouse',
      'Laptop Type-C Power Adapter',
      'USB-C Multiport Dongle',
    ],
    'Drawing Tools': [
      'Staedtler Technical Pen Set',
      'Drafting T-Square 24-inch',
      'Rotring Precision Compass',
      'Engineering Triangle Set 30/60',
    ],
    'Food & Beverages': [
      'Freshly Cooked Silog Meal',
      'Chilled Cold Brew Coffee',
      'Homemade Fudgy Brownies',
      'Sweet Pastillas Pack',
    ],
    'School Supplies': [
      'Yellow Intermediate Pad Paper',
      'Pilot G-Tech 0.3 Black Pens',
      'A4 Clear Book Display Binder',
      'Complete Student Stationery Kit',
    ],
    'Services': [
      'Peer Tutoring (Math / CS)',
      'High-Speed Document Printing',
      'Hardbound Thesis Binding',
      'Graphic Design & Poster Making',
    ],
    'Others': [
      'Student Dorm Essential',
      'Campus Umbrella',
      'Water Tumbler 1L',
    ],
  };

  static const Map<String, List<String>> _quickDescStarters = {
    'Books': [
      'Complete pages, no markings',
      'Used for 1 term, pristine condition',
      'Meetup at CIT-U Library lobby',
    ],
    'Uniforms': [
      'Clean & sanitized, no stains',
      'Official CIT-U embroidery intact',
      'Meetup at CIT-U Main Gate / Quad',
    ],
    'Clothes': [
      'Washed and ready to wear',
      'Boxy/oversized fit, pre-loved',
      'Meetup at campus canteen',
    ],
    'Electronics': [
      '100% working, test upon meetup',
      'Includes original charging cable',
      'Essential for engineering math',
    ],
    'Food & Beverages': [
      'Freshly prepared daily, clean prep',
      'Pre-order 1 day ahead for batch meetup',
      'Free campus delivery at Main Gate',
    ],
    'Drawing Tools': [
      'All drafting pieces complete with case',
      'Used for CEA graphics class',
      'Good condition, no cracks',
    ],
    'School Supplies': [
      'Brand new / sealed packaging',
      'Surplus student stock from last term',
    ],
    'Services': [
      'Available Mon-Fri 3PM to 6PM',
      'Fast turnaround time, student rate',
    ],
    'Others': [
      'Used for 1 term, still in great shape',
      'Campus meetup available today',
    ],
  };


  @override
  void dispose() {
    _categoryScrollController.dispose();
    _sellTitleController.dispose();
    _sellPriceController.dispose();
    _sellDescController.dispose();
    _sellStockController.dispose();
    _batchStockController.dispose();
    for (final ctrl in _variantStockControllers.values) {
      ctrl.dispose();
    }
    _variantStockControllers.clear();
    for (final ctrl in _attributeTextControllers.values) {
      ctrl.dispose();
    }
    _attributeTextControllers.clear();
    _attributeMultiSelectValues.clear();
    _customAttributeOptions.clear();
    super.dispose();
  }

  void _postNewItem() {
    final title = _sellTitleController.text.trim();
    final priceStr = _sellPriceController.text.trim();
    final desc = _sellDescController.text.trim();
    final stockStr = _sellStockController.text.trim();

    if (title.isEmpty || priceStr.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields marked with *'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    final price = double.tryParse(priceStr);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price greater than zero.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    final stock = int.tryParse(stockStr) ?? 1;
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid stock quantity of at least 1.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    _doPostItem(title: title, desc: desc, price: price, stock: stock);
  }

  Future<void> _doPostItem({
    required String title,
    required String desc,
    required double price,
    required int stock,
  }) async {
    // Upload all selected images to Supabase Storage
    List<String> imageUrls = [];
    if (_selectedImageFiles.isNotEmpty) {
      setState(() => _isUploadingProductImage = true);
      try {
        final sellerId = ref.read(authStateProvider).valueOrNull?.id ?? 'usr-seller';
        for (int i = 0; i < _selectedImageFiles.length; i++) {
          final file = _selectedImageFiles[i];
          final fileName = 'product_${sellerId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final bytes = await file.readAsBytes();
          await SupabaseConfig.client.storage
              .from('product-images')
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
          final publicUrl = SupabaseConfig.client.storage
              .from('product-images')
              .getPublicUrl(fileName);
          imageUrls.add(publicUrl);
        }
      } catch (e) {
        setState(() => _isUploadingProductImage = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e'), backgroundColor: TeknoyTheme.error),
          );
        }
        return;
      }
      setState(() => _isUploadingProductImage = false);
    } else {
      // Dynamic mock visual based on category
      const categoryImages = {
        'Books': 'https://picsum.photos/seed/books-cs/400/300',
        'Uniforms': 'https://picsum.photos/seed/uniforms/400/300',
        'Clothes': 'https://picsum.photos/seed/clothes-apparel/400/300',
        'Electronics': 'https://picsum.photos/seed/electronics/400/300',
        'Drawing Tools': 'https://picsum.photos/seed/drawing-tools/400/300',
        'Food & Beverages': 'https://picsum.photos/seed/food-snacks/400/300',
        'School Supplies': 'https://picsum.photos/seed/school-supplies/400/300',
        'Services': 'https://picsum.photos/seed/services/400/300',
      };
      final fallbackUrl = categoryImages[_sellCategory] ?? 'https://picsum.photos/seed/others/400/300';
      imageUrls = [fallbackUrl];
    }

    // Collect category-specific attributes from form controllers
    final List<ProductAttribute> categoryAttributes = [];
    for (final entry in _attributeTextControllers.entries) {
      final val = entry.value.text.trim();
      if (val.isNotEmpty) {
        categoryAttributes.add(ProductAttribute(name: entry.key, value: val));
      }
    }
    for (final entry in _attributeSelectValues.entries) {
      if (entry.value.isNotEmpty) {
        categoryAttributes.add(ProductAttribute(name: entry.key, value: entry.value));
      }
    }
    for (final entry in _attributeMultiSelectValues.entries) {
      if (entry.value.isNotEmpty) {
        final list = entry.value.toList();
        if (entry.key.trim().toLowerCase() == 'size') {
          list.sort((a, b) => ProductAttribute.sizeRank(a).compareTo(ProductAttribute.sizeRank(b)));
        }
        categoryAttributes.add(ProductAttribute(name: entry.key, value: list.join(', ')));
      }
    }

    final newProduct = Product(
      id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: desc,
      price: price,
      category: _sellCategory,
      condition: _sellCondition,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      imageUrls: imageUrls,
      sellerId: ref.read(authStateProvider).valueOrNull?.id ?? 'usr-buyer',
      createdAt: DateTime.now(),
      categoryAttributes: categoryAttributes,
    );

    // Collect individual variant stock levels (combination matrix)
    final Map<String, int> variantStocks = {};
    if (_hasActiveVariants) {
      for (final combo in _variationCombinations) {
        final ctrl = _variantStockControllers[combo];
        final val = int.tryParse(ctrl?.text.trim() ?? '') ?? 5;
        // Standardize delimiter to ' / ' for backend storage & checkout resolution
        final standardizedKey = combo.replaceAll(' · ', ' / ');
        variantStocks[standardizedKey] = val >= 0 ? val : 0;
      }
    }

    final int effectiveTotalStock = _hasActiveVariants ? _calculatedTotalVariantStock : stock;

    ref.read(productsListNotifierProvider.notifier).addProduct(
      newProduct,
      variantStocks: variantStocks.isNotEmpty ? variantStocks : null,
      totalStock: effectiveTotalStock,
    );

    // Reset Form
    _sellTitleController.clear();
    _sellPriceController.clear();
    _sellDescController.clear();
    _sellStockController.text = '1';
    _batchStockController.text = '5';
    for (final ctrl in _variantStockControllers.values) {
      ctrl.dispose();
    }
    _variantStockControllers.clear();
    for (final ctrl in _attributeTextControllers.values) {
      ctrl.dispose();
    }
    _attributeTextControllers.clear();
    _attributeSelectValues.clear();
    _attributeMultiSelectValues.clear();
    _customAttributeOptions.clear();
    setState(() {
      _sellCategory = 'Books';
      _sellCondition = 'New';
      _selectedImageFiles.clear();
      widget.onNavigateTab?.call(0);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listed "$title" to CIT-U catalog successfully!'),
          backgroundColor: TeknoyTheme.success,
        ),
      );
    }
  }

  Future<void> _pickProductImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedList = await _imagePicker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1080,
        );
        if (pickedList.isNotEmpty) {
          setState(() {
            for (final file in pickedList) {
              if (_selectedImageFiles.length < 8) {
                _selectedImageFiles.add(file);
              }
            }
          });
        }
      } else {
        if (_selectedImageFiles.length >= 8) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maximum of 8 photos reached.'),
                backgroundColor: TeknoyTheme.citMaroon,
              ),
            );
          }
          return;
        }
        final picked = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1080,
        );
        if (picked != null) {
          setState(() {
            _selectedImageFiles.add(picked);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: TeknoyTheme.error),
        );
      }
    }
  }

  /// Builds dynamic form fields based on the selected category's attribute templates.
  /// Each category has its own set of attributes (e.g., Size/Color for Uniforms,
  /// Brand/Model for Electronics). Templates are fetched from Supabase with
  /// a hardcoded fallback for offline resilience.
  /// Builds dynamic category attribute fields based on the selected category.
  /// Uses a hybrid model: Primary attributes are displayed as fast 1-tap pill chips,
  /// while secondary optional specifications are placed inside an elegant collapsible accordion.
  Widget _buildCategoryAttributeFields(bool isDark) {
    final templatesAsync = ref.watch(categoryAttributeTemplatesProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: templatesAsync.when(
        loading: () => const SizedBox.shrink(key: ValueKey('attr_loading')),
        error: (_, __) => const SizedBox.shrink(key: ValueKey('attr_error')),
        data: (templatesMap) {
          final templates = templatesMap[_sellCategory];
          if (templates == null || templates.isEmpty) {
            return const SizedBox.shrink(key: ValueKey('attr_empty'));
          }

        final primaryNames = primaryCategoryAttributeNames[_sellCategory] ?? [];
        final primaryTemplates = templates.where((t) => primaryNames.contains(t.name)).toList();
        final effectivePrimary = primaryTemplates.isNotEmpty ? primaryTemplates : templates.take(2).toList();
        final effectiveSecondary = templates.where((t) => !effectivePrimary.contains(t)).toList();

        // Calculate count of filled secondary attributes for the accordion badge
        int filledSecondaryCount = 0;
        for (final t in effectiveSecondary) {
          if (t.isMultiSelect) {
            if ((_attributeMultiSelectValues[t.name]?.isNotEmpty ?? false)) {
              filledSecondaryCount++;
            }
          } else if (t.type == 'select') {
            if ((_attributeSelectValues[t.name]?.isNotEmpty ?? false)) {
              filledSecondaryCount++;
            }
          } else {
            if ((_attributeTextControllers[t.name]?.text.trim().isNotEmpty ?? false)) {
              filledSecondaryCount++;
            }
          }
        }

        return Column(
          key: ValueKey<String>('attr_fields_$_sellCategory'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.12 : 0.06),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(_sellCategory),
                    size: 18,
                    color: TeknoyTheme.citMaroon,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_sellCategory Details',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: TeknoyTheme.citMaroon,
                          ),
                        ),
                        Text(
                          'Tap quick options below to speed up buyer discovery',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 1. Primary Attributes (1-Tap Pill Chips)
            ...effectivePrimary.map((template) => _buildSingleAttributeWidget(template, isDark, isPrimary: true)),

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
                                'More $_sellCategory Details (Optional)',
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
                            ...effectiveSecondary.map((template) => _buildSingleAttributeWidget(template, isDark, isPrimary: false)),
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
              const SizedBox(height: 14),
            ],
            // ── Consolidated Shopee / Lazada Variation Stock Matrix ──
            if (_hasActiveVariants) ...[
              const SizedBox(height: 12),
              _buildShopeeVariationMatrixDeck(isDark),
            ],
          ],
        );
      },
    ),
  );
}

  /// Builds an individual category attribute field:
  /// - Multi-select attributes render as a 1-tap multi-selection chip deck with checkmarks
  /// - Single-select options render as responsive 1-tap pill chips with custom options
  /// - Text attributes with quick suggestions render 1-tap suggestion pills + clean input
  /// - Standard text attributes render as clean compact text inputs
  Widget _buildSingleAttributeWidget(
    CategoryAttributeTemplate template,
    bool isDark, {
    required bool isPrimary,
  }) {
    if (template.type == 'select' && template.options.isNotEmpty) {
      if (template.isMultiSelect) {
        // Multi-select chip selector for sizes or colors
        final selectedSet = _attributeMultiSelectValues.putIfAbsent(template.name, () => <String>{});
        final customOptions = _customAttributeOptions.putIfAbsent(template.name, () => <String>[]);
        final allOptions = [...template.options, ...customOptions];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
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
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      selectedSet.isEmpty
                          ? 'Tap in-stock options'
                          : '${selectedSet.length} selected',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: TeknoyTheme.citMaroon,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...allOptions.map((opt) {
                    final isSelected = selectedSet.contains(opt);
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedSet.remove(opt);
                          } else {
                            selectedSet.add(opt);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                fontSize: 13,
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
                  // + Custom Option chip
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showAddCustomOptionDialog(template.name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.12 : 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: TeknoyTheme.citMaroon.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 15, color: TeknoyTheme.citMaroon),
                          const SizedBox(width: 4),
                          Text(
                            '+ Custom ${template.name}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
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
      }

      // Single-select: 1-Tap Pill Chips
      final currentValue = _attributeSelectValues[template.name];
      final customOptions = _customAttributeOptions.putIfAbsent(template.name, () => <String>[]);
      final allOptions = [...template.options, ...customOptions];

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
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
                    onTap: () => setState(() => _attributeSelectValues.remove(template.name)),
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
            const SizedBox(height: 8),
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
                          _attributeSelectValues.remove(template.name);
                        } else {
                          _attributeSelectValues[template.name] = opt;
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
                // + Custom Option chip for single-select
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showAddCustomOptionDialog(template.name),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 14, color: TeknoyTheme.citMaroon),
                        const SizedBox(width: 4),
                        Text(
                          '+ Other',
                          style: const TextStyle(
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
      // Text input field — with optional 1-tap quick suggestion chips!
      if (!_attributeTextControllers.containsKey(template.name)) {
        _attributeTextControllers[template.name] = TextEditingController();
      }
      final ctrl = _attributeTextControllers[template.name]!;
      final suggestions = primaryAttributeQuickSuggestions[_sellCategory]?[template.name] ?? [];

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
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
              const SizedBox(height: 8),
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
            TextField(
              controller: ctrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: template.placeholder,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF14141A) : const Color(0xFFFAFAFC),
                suffixIcon: ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => setState(() => ctrl.clear()),
                      )
                    : null,
              ),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
          ],
        ),
      );
    }
  }

  /// Interactive Shopee / Lazada style Variation Stock Matrix deck
  Widget _buildShopeeVariationMatrixDeck(bool isDark) {
    final combos = _variationCombinations;
    if (combos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191922) : const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TeknoyTheme.citMaroon.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart_outlined, size: 18, color: TeknoyTheme.citMaroon),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock per Variation Combination',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: TeknoyTheme.citMaroon,
                      ),
                    ),
                    Text(
                      'Set exact inventory for each size & color pair',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: TeknoyTheme.citGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${combos.length} variations',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B6B00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Quick Fill / Batch Tool (Shopee/Lazada style) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: TeknoyTheme.citGold),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Quick Fill All:',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 55,
                  height: 34,
                  child: TextField(
                    controller: _batchStockController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final batchVal = _batchStockController.text.trim();
                    if (batchVal.isEmpty) return;
                    setState(() {
                      for (final combo in combos) {
                        _variantStockControllers.putIfAbsent(combo, () => TextEditingController()).text = batchVal;
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Applied $batchVal units to all ${combos.length} variations!'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.citMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(60, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Apply All',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Combination Rows ──
          ...combos.map((combo) {
            final ctrl = _variantStockControllers.putIfAbsent(
              combo,
              () => TextEditingController(text: '5'),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        combo,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: TeknoyTheme.citMaroon,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                      color: TeknoyTheme.citMaroon,
                      onPressed: () {
                        final cur = int.tryParse(ctrl.text.trim()) ?? 0;
                        if (cur > 0) {
                          setState(() {
                            ctrl.text = '${cur - 1}';
                          });
                        }
                      },
                    ),
                    SizedBox(
                      width: 48,
                      height: 32,
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      color: TeknoyTheme.citMaroon,
                      onPressed: () {
                        final cur = int.tryParse(ctrl.text.trim()) ?? 0;
                        setState(() {
                          ctrl.text = '${cur + 1}';
                        });
                      },
                    ),
                    const Text(
                      'units',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }


  /// Opens an intuitive dialog allowing the seller to add a custom size (e.g. 33, 34, US 9.5) or custom variant
  void _showAddCustomOptionDialog(String templateName) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSize = templateName.toLowerCase() == 'size';
    final isColor = templateName.toLowerCase() == 'color';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_circle_outline_rounded, color: TeknoyTheme.citMaroon, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add Custom $templateName',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSize
                  ? 'Enter numeric waist size (e.g. 33, 34, 35) or custom dimension:'
                  : isColor
                      ? 'Enter custom color name (e.g. Olive Green, Beige):'
                      : 'Enter custom $templateName:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                hintText: isSize ? 'e.g. 33, 34, 32x30, US 9.5' : isColor ? 'e.g. Olive Green' : 'e.g. Custom',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: TeknoyTheme.citMaroon, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (val) {
                _addCustomOption(templateName, val);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TeknoyTheme.citMaroon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _addCustomOption(templateName, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Add & Select', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addCustomOption(String templateName, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final customList = _customAttributeOptions.putIfAbsent(templateName, () => <String>[]);
      if (!customList.contains(trimmed)) {
        customList.add(trimmed);
      }
      final selectedSet = _attributeMultiSelectValues.putIfAbsent(templateName, () => <String>{});
      selectedSet.add(trimmed);
    });
  }

  /// Returns an appropriate icon for each product category
  static IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Books':
        return Icons.menu_book_rounded;
      case 'Drawing Tools':
        return Icons.architecture_rounded;
      case 'Uniforms':
        return Icons.badge_rounded;
      case 'Clothes':
        return Icons.checkroom_rounded;
      case 'Electronics':
        return Icons.devices_rounded;
      case 'Food & Beverages':
        return Icons.restaurant_rounded;
      case 'School Supplies':
        return Icons.edit_rounded;
      case 'Services':
        return Icons.handyman_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _onCategorySelected(String val) {
    if (val == _sellCategory) return;
    // Defer disposal of old controllers so animating exit transitions don't query disposed controllers
    final oldTextControllers = List<TextEditingController>.from(_attributeTextControllers.values);
    final oldVariantControllers = List<TextEditingController>.from(_variantStockControllers.values);
    _attributeTextControllers.clear();
    _attributeSelectValues.clear();
    _attributeMultiSelectValues.clear();
    _customAttributeOptions.clear();
    _variantStockControllers.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        for (final ctrl in oldTextControllers) {
          ctrl.dispose();
        }
        for (final ctrl in oldVariantControllers) {
          ctrl.dispose();
        }
      });
    });

    setState(() {
      _sellCategory = val;
      if (val == 'Food & Beverages') {
        _sellCondition = _foodConditionOptions.first;
      } else if (!_generalConditionOptions.contains(_sellCondition)) {
        _sellCondition = _generalConditionOptions.first;
      }
    });
  }

  void _scrollToCategory(int index) {
    if (!_categoryScrollController.hasClients) return;
    final targetOffset = (index * 104.0) - 40.0;
    final maxScroll = _categoryScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);
    _categoryScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    final categories = ref.watch(sellCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Category *',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: Text(
                  _sellCategory,
                  key: ValueKey<String>(_sellCategory),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: TeknoyTheme.citMaroon,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            controller: _categoryScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat == _sellCategory;
              final icon = _getCategoryIcon(cat);

              return GestureDetector(
                onTap: () {
                  _onCategorySelected(cat);
                  _scrollToCategory(index);
                },
                child: AnimatedScale(
                  scale: isSelected ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 96,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TeknoyTheme.citMaroon
                          : (isDark ? const Color(0xFF191922) : const Color(0xFFF3F3F7)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? TeknoyTheme.citMaroon
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                        width: isSelected ? 1.6 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: TeknoyTheme.citMaroon.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            icon,
                            key: ValueKey<String>('${cat}_$isSelected'),
                            size: 20,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConditionChips(bool isDark) {
    final isFood = _sellCategory == 'Food & Beverages';
    final options = isFood ? _foodConditionOptions : _generalConditionOptions;

    // Structured metadata for high-craft marketplace condition grading
    ({String title, String subtitle, IconData icon}) getConditionMeta(String raw) {
      switch (raw) {
        case 'Freshly Prepared / Daily Cooked':
          return (
            title: 'Freshly Prepared',
            subtitle: 'Cooked fresh today',
            icon: Icons.restaurant_rounded,
          );
        case 'Packaged & Sealed (Brand New)':
          return (
            title: 'Sealed Pack',
            subtitle: 'Original sealed pack',
            icon: Icons.inventory_2_outlined,
          );
        case 'Made to Order':
          return (
            title: 'Made to Order',
            subtitle: 'Prepared on demand',
            icon: Icons.outdoor_grill_outlined,
          );
        case 'Frozen / Chilled':
          return (
            title: 'Frozen / Chilled',
            subtitle: 'Preserved cold storage',
            icon: Icons.ac_unit_rounded,
          );
        case 'New':
          return (
            title: 'Brand New',
            subtitle: 'Unopened or never used',
            icon: Icons.verified_outlined,
          );
        case 'Like New':
          return (
            title: 'Like New',
            subtitle: 'Flawless, barely used',
            icon: Icons.diamond_outlined,
          );
        case 'Gently Used':
          return (
            title: 'Gently Used',
            subtitle: 'Minor wear, fully works',
            icon: Icons.thumb_up_alt_outlined,
          );
        case 'Well Used':
          return (
            title: 'Well Used',
            subtitle: 'Visible wear, discounted',
            icon: Icons.archive_outlined,
          );
        default:
          return (
            title: raw,
            subtitle: 'Standard condition',
            icon: Icons.check_circle_outline_rounded,
          );
      }
    }

    final rows = <Widget>[];
    for (int i = 0; i < options.length; i += 2) {
      final opt1 = options[i];
      final opt2 = (i + 1 < options.length) ? options[i + 1] : null;

      rows.add(
        Row(
          children: [
            Expanded(child: _buildConditionCard(opt1, getConditionMeta(opt1), isDark)),
            const SizedBox(width: 10),
            if (opt2 != null)
              Expanded(child: _buildConditionCard(opt2, getConditionMeta(opt2), isDark))
            else
              const Spacer(),
          ],
        ),
      );
      if (i + 2 < options.length) {
        rows.add(const SizedBox(height: 10));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Text(
                isFood ? 'Freshness & Preparation *' : 'Item Condition *',
                key: ValueKey<bool>(isFood),
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Text(
              'Required',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
          child: Column(
            key: ValueKey<bool>(isFood),
            children: rows,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionCard(
    String opt,
    ({String title, String subtitle, IconData icon}) meta,
    bool isDark,
  ) {
    final isSelected = _sellCondition == opt;
    final primaryColor = TeknoyTheme.citMaroon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _sellCondition = opt);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? primaryColor.withValues(alpha: 0.18) : const Color(0xFFFDF2F2))
                : (isDark ? const Color(0xFF16161F) : const Color(0xFFFAFAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? const Color(0xFF282834) : const Color(0xFFE5E5EB)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF22222E) : const Color(0xFFF0F0F5)),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      meta.icon,
                      size: 15,
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white70 : const Color(0xFF555562)),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? primaryColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? primaryColor
                            : (isDark ? Colors.white24 : const Color(0xFFD1D1D8)),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                meta.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : primaryColor)
                      : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.normal,
                  color: isSelected
                      ? (isDark ? Colors.white70 : primaryColor.withValues(alpha: 0.8))
                      : (isDark ? Colors.white38 : const Color(0xFF8E8E93)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceAndStockSection(bool isDark) {
    final currentStock = int.tryParse(_sellStockController.text.trim()) ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price Input with prefix
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price (₱) *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sellPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g. 450',
                      prefixText: '₱ ',
                      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon, fontSize: 15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stock Stepper / Variant Indicator
            Expanded(
              flex: 5,
              child: _hasActiveVariants
                  ? Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF7F7FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TeknoyTheme.citMaroon.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calculate_outlined, size: 14, color: TeknoyTheme.citMaroon),
                              SizedBox(width: 4),
                              Text('Stock (Variants)', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_calculatedTotalVariantStock total units',
                            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13, color: TeknoyTheme.citMaroon),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Stock *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF191922) : const Color(0xFFFAFAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 18),
                                color: currentStock > 1 ? TeknoyTheme.citMaroon : Colors.grey,
                                onPressed: currentStock > 1
                                    ? () {
                                        setState(() {
                                          _sellStockController.text = '${currentStock - 1}';
                                        });
                                      }
                                    : null,
                              ),
                              Text(
                                '$currentStock unit${currentStock > 1 ? 's' : ''}',
                                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                color: TeknoyTheme.citMaroon,
                                onPressed: () {
                                  setState(() {
                                    _sellStockController.text = '${currentStock + 1}';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 1-Tap Quick Price Benchmark chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Presets:',
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black45),
              ),
              const SizedBox(width: 6),
              ...[50, 100, 150, 250, 350, 500].map((pVal) {
                final isCurrent = _sellPriceController.text.trim() == '$pVal';
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _sellPriceController.text = '$pVal';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isDark ? TeknoyTheme.citMaroon.withValues(alpha: 0.22) : const Color(0xFFFDF2F2))
                            : (isDark ? const Color(0xFF1E1E26) : const Color(0xFFF1F1F5)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent ? TeknoyTheme.citMaroon : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '₱$pVal',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent
                              ? (isDark ? Colors.white : TeknoyTheme.citMaroon)
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // +₱50 bump button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final cur = double.tryParse(_sellPriceController.text.trim()) ?? 0;
                  setState(() {
                    _sellPriceController.text = '${(cur + 50).toInt()}';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '+₱50',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showProductImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                _selectedImageFiles.isEmpty
                    ? 'Add Product Photos (Up to 8)'
                    : 'Add More Photos (${_selectedImageFiles.length}/8)',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: TeknoyTheme.citMaroon,
                  child: Icon(Icons.photo_library_rounded, color: Colors.white),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                subtitle: const Text('Pick one or multiple photos from device', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProductImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: TeknoyTheme.citGold,
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white),
                ),
                title: const Text('Take a Photo', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture item or variant close-up', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProductImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider).valueOrNull;

    if (authState == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Please sign in to list items.',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (!authState.isSeller) {
      return SellerKYCVerificationView(
        userId: authState.id,
        initialSellerType: 'STUDENT',
        onVerificationSubmitted: () => setState(() {}),
        onRefreshStatus: () async {
          await ref.read(authNotifierProvider.notifier).refreshProfile();
          if (mounted) setState(() {});
        },
      );
    }

    // Verified seller or admin: Tab selector between List New Item and My Listings
    return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF0F0F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sellSubTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _sellSubTab == 0 ? TeknoyTheme.citMaroon : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _sellSubTab == 0
                                ? [
                                    BoxShadow(
                                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                                color: _sellSubTab == 0 ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'List New Item',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _sellSubTab == 0 ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sellSubTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _sellSubTab == 1 ? TeknoyTheme.citMaroon : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _sellSubTab == 1
                                ? [
                                    BoxShadow(
                                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: _sellSubTab == 1 ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'My Listings',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _sellSubTab == 1 ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _sellSubTab == 0
                    ? SingleChildScrollView(
                        key: const ValueKey('sell_subtab_list_item'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'List an Item',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
              ),
              const SizedBox(height: 6),
              const Text(
                'List textbooks, uniforms, electronics, or snacks to trade with fellow student Wildcats.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
          
          // ── 1. Category Selection ──
          _buildCategorySelector(isDark),
          const SizedBox(height: 20),

          // ── 2. Product Title (with 1-Tap Starters) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Product Title *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
              if (_sellTitleController.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _sellTitleController.clear()),
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
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sellTitleController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. Calculus Transcendentals 9th Ed',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: (_quickTitleStarters[_sellCategory] ?? []).isNotEmpty
                ? Padding(
                    key: ValueKey<String>('title_starters_$_sellCategory'),
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Text(
                            'Suggestions:',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...(_quickTitleStarters[_sellCategory] ?? []).map((starter) {
                            final isCurrent = _sellTitleController.text.trim() == starter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    _sellTitleController.text = starter;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? (isDark ? TeknoyTheme.citMaroon.withValues(alpha: 0.22) : const Color(0xFFFDF2F2))
                                        : (isDark ? const Color(0xFF1E1E26) : const Color(0xFFF1F1F5)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isCurrent ? TeknoyTheme.citMaroon : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    starter,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                      color: isCurrent
                                          ? (isDark ? Colors.white : TeknoyTheme.citMaroon)
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('title_starters_none')),
          ),
          const SizedBox(height: 20),

          // ── 3. Price & Available Stock Section ──
          _buildPriceAndStockSection(isDark),
          const SizedBox(height: 20),

          // ── 4. Item Condition / Freshness 1-Tap Chips ──
          _buildConditionChips(isDark),
          const SizedBox(height: 20),

          // ── Dynamic Category Attributes Section ──
          _buildCategoryAttributeFields(isDark),
          const SizedBox(height: 20),

          // Description
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Listing Description *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
              if (_sellDescController.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _sellDescController.clear()),
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
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sellDescController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Describe details, sizing, condition or meeting landmarks...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: (_quickDescStarters[_sellCategory] ?? []).isNotEmpty
                ? Padding(
                    key: ValueKey<String>('desc_starters_$_sellCategory'),
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Text(
                            'Quick Notes:',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...(_quickDescStarters[_sellCategory] ?? []).map((note) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    if (_sellDescController.text.trim().isEmpty) {
                                      _sellDescController.text = note;
                                    } else {
                                      _sellDescController.text = '${_sellDescController.text.trim()} • $note';
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF1F1F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+ $note',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('desc_starters_none')),
          ),
          const SizedBox(height: 24),

          // Image uploader — Multi-photo gallery deck (up to 8 photos)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Product Photos',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _selectedImageFiles.isNotEmpty
                          ? TeknoyTheme.citMaroon.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selectedImageFiles.length}/8',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: _selectedImageFiles.isNotEmpty ? TeknoyTheme.citMaroon : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedImageFiles.isNotEmpty && _selectedImageFiles.length < 8)
                GestureDetector(
                  onTap: _showProductImageSourceSheet,
                  child: const Text(
                    '+ Add Photo',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Upload front, back, close-ups, and variant angles. 1st photo is Cover.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 10),

          if (_selectedImageFiles.isEmpty)
            GestureDetector(
              onTap: _showProductImageSourceSheet,
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181C) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded, size: 30, color: TeknoyTheme.citMaroon),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add Product Photos (Up to 8)',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap to choose multiple images from gallery or take a photo',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImageFiles.length + (_selectedImageFiles.length < 8 ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  // Add more card at the end
                  if (index == _selectedImageFiles.length) {
                    return GestureDetector(
                      onTap: _showProductImageSourceSheet,
                      child: Container(
                        width: 105,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181C) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: TeknoyTheme.citMaroon.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 26, color: TeknoyTheme.citMaroon.withValues(alpha: 0.8)),
                            const SizedBox(height: 6),
                            const Text(
                              'Add Photo',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: TeknoyTheme.citMaroon,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final file = _selectedImageFiles[index];
                  final isCover = index == 0;

                  return Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCover ? TeknoyTheme.citMaroon : Colors.grey.withValues(alpha: 0.3),
                            width: isCover ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb
                              ? Image.network(
                                  file.path,
                                  width: 110,
                                  height: 140,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(file.path),
                                  width: 110,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      // Cover Badge
                      if (isCover)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.citMaroon,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_rounded, size: 11, color: TeknoyTheme.citGold),
                                SizedBox(width: 3),
                                Text(
                                  'Cover',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Remove Button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImageFiles.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 32),

          // Submit Post
          ElevatedButton(
            onPressed: _isUploadingProductImage ? null : _postNewItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: TeknoyTheme.citMaroon,
              disabledBackgroundColor: TeknoyTheme.citMaroon.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUploadingProductImage
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text('Uploading photos (${_selectedImageFiles.length})...', style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  )
                : const Text('Post Campus Listing', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    )
                  : const ManageListingsView(
                      key: ValueKey('sell_subtab_my_listings'),
                      embedded: true,
                    ),
              ),
            ),
          ],
        );
  }


}
