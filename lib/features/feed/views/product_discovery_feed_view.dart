import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/widgets/navigation_drawer.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/features/feed/views/product_detail_view.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/feed/views/search_results_view.dart';
import 'package:teknoycart/features/chat/views/inbox_view.dart';
import 'package:teknoycart/features/checkout/views/order_history_view.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/views/cart_view.dart';
import 'package:teknoycart/features/feed/views/widgets/feed_product_card.dart';
import 'package:teknoycart/features/feed/views/widgets/feed_trending_banner.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/buyer_reviews_sheet.dart';
import 'package:teknoycart/features/feed/views/manage_listings_view.dart';
import 'package:teknoycart/features/auth/views/widgets/seller_kyc_verification_view.dart';


/// Provider to dynamically count completed orders/deals for a given user ID
final userCompletedDealsCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  if (userId.isEmpty) return 0;
  try {
    final client = SupabaseConfig.client;
    final res = await client
        .from('orders')
        .select('order_id')
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .eq('status', 'completed');
    return (res as List).length;
  } catch (_) {
    return 0;
  }
});

/// Product Discovery Feed representing Figma Node 1:39.
/// Main marketplace landing hub for listing, browsing, and searching products.
class ProductDiscoveryFeedView extends ConsumerStatefulWidget {
  final int initialTab;
  const ProductDiscoveryFeedView({super.key, this.initialTab = 0});

  @override
  ConsumerState<ProductDiscoveryFeedView> createState() => _ProductDiscoveryFeedViewState();
}

class _ProductDiscoveryFeedViewState extends ConsumerState<ProductDiscoveryFeedView> {
  int _activeTab = 0;
  int _sellSubTab = 0; // 0: List New Item, 1: My Listings
  Map<String, dynamic>? _cachedProfileData;
  String? _cachedProfileUserId;
  Future<Map<String, dynamic>>? _profileFuture;


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

  StreamSubscription<AuthState>? _recoverySub;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _recoverySub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showSetNewPasswordSheet(context);
          }
        });
      }
    });
  }

  void _showSetNewPasswordSheet(BuildContext context) {
    final passCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Set New Password',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please enter your new password below.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final newPass = passCtrl.text.trim();
                    if (newPass.length < 6) return;
                    Navigator.pop(ctx);
                    try {
                      await SupabaseConfig.client.auth.updateUser(UserAttributes(password: newPass));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password updated successfully!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF800000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Update Password', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
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
      _activeTab = 0;
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

    return templatesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (templatesMap) {
        final templates = templatesMap[_sellCategory];
        if (templates == null || templates.isEmpty) {
          return const SizedBox.shrink();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TeknoyTheme.citMaroon.withOpacity(isDark ? 0.12 : 0.06),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TeknoyTheme.citMaroon.withOpacity(0.15),
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
                        ? TeknoyTheme.citMaroon.withOpacity(0.35)
                        : (isDark ? Colors.white10 : Colors.black.withOpacity(0.08)),
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
                                  color: TeknoyTheme.citMaroon.withOpacity(0.12),
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
                            Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06), height: 1),
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
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
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
                      color: TeknoyTheme.citMaroon.withOpacity(0.08),
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
                        color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.12 : 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: TeknoyTheme.citMaroon.withOpacity(0.4),
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
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
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
                        color: TeknoyTheme.citMaroon.withOpacity(0.8),
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
                      color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.12 : 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: TeknoyTheme.citMaroon.withOpacity(0.4),
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
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
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
                      color: TeknoyTheme.citMaroon.withOpacity(0.8),
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
          color: TeknoyTheme.citMaroon.withOpacity(0.25),
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
                  color: TeknoyTheme.citMaroon.withOpacity(0.1),
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
                  color: TeknoyTheme.citGold.withOpacity(0.2),
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
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.2 : 0.08),
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
                color: TeknoyTheme.citMaroon.withOpacity(0.12),
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
    for (final ctrl in _attributeTextControllers.values) {
      ctrl.dispose();
    }
    _attributeTextControllers.clear();
    _attributeSelectValues.clear();
    _attributeMultiSelectValues.clear();
    _customAttributeOptions.clear();
    for (final ctrl in _variantStockControllers.values) {
      ctrl.dispose();
    }
    _variantStockControllers.clear();
    setState(() {
      _sellCategory = val;
      if (val == 'Food & Beverages') {
        _sellCondition = _foodConditionOptions.first;
      } else if (!_generalConditionOptions.contains(_sellCondition)) {
        _sellCondition = _generalConditionOptions.first;
      }
    });
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
                color: TeknoyTheme.citMaroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _sellCategory,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: TeknoyTheme.citMaroon,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat == _sellCategory;
              final icon = _getCategoryIcon(cat);

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _onCategorySelected(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 92,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TeknoyTheme.citMaroon
                        : (isDark ? const Color(0xFF191922) : const Color(0xFFF3F3F7)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? TeknoyTheme.citMaroon
                          : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: TeknoyTheme.citMaroon.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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
            Text(
              isFood ? 'Freshness & Preparation *' : 'Item Condition *',
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
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
        ...rows,
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
                ? (isDark ? primaryColor.withOpacity(0.18) : const Color(0xFFFDF2F2))
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
                      color: primaryColor.withOpacity(0.08),
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
                          ? primaryColor.withOpacity(0.12)
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
                      ? (isDark ? Colors.white70 : primaryColor.withOpacity(0.8))
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
                        border: Border.all(color: TeknoyTheme.citMaroon.withOpacity(0.2)),
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
                            ? (isDark ? TeknoyTheme.citMaroon.withOpacity(0.22) : const Color(0xFFFDF2F2))
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
                    color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.15 : 0.08),
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
                  color: Colors.grey.withOpacity(0.3),
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

  void _showFilterSheet(BuildContext context) {
    final currentCondition = ref.read(selectedConditionProvider);
    final currentMin = ref.read(minPriceProvider);
    final currentMax = ref.read(maxPriceProvider);

    final minController = TextEditingController(text: currentMin?.toString() ?? '');
    final maxController = TextEditingController(text: currentMax?.toString() ?? '');
    String tempCondition = currentCondition;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141418) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Catalog',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          minController.clear();
                          maxController.clear();
                          setModalState(() => tempCondition = 'All');
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: TeknoyTheme.citMaroon,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Condition',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'New', 'Like New', 'Gently Used', 'Well Worn'].map((cond) {
                      final isSelected = tempCondition == cond;
                      return ChoiceChip(
                        label: Text(
                          cond,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: TeknoyTheme.citMaroon,
                        backgroundColor: isDark ? const Color(0xFF202026) : const Color(0xFFF0F1F2),
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => tempCondition = cond);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Price Range (₱)',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Min',
                            hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF202026) : const Color(0xFFF0F1F2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('to', style: TextStyle(fontFamily: 'Inter')),
                      ),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Max',
                            hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF202026) : const Color(0xFFF0F1F2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final minVal = double.tryParse(minController.text);
                        final maxVal = double.tryParse(maxController.text);
                        ref.read(selectedConditionProvider.notifier).state = tempCondition;
                        ref.read(minPriceProvider.notifier).state = minVal;
                        ref.read(maxPriceProvider.notifier).state = maxVal;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TeknoyTheme.citMaroon,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F12) : Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: TeknoyTheme.citMaroon),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Navigation Drawer',
            );
          },
        ),
        title: Text(
          _activeTab == 0
              ? 'TeknoyCart'
              : _activeTab == 1
                  ? 'Messages'
                  : _activeTab == 2
                      ? 'Sell Items'
                      : _activeTab == 3
                          ? 'My Orders'
                          : 'Wildcat Profile',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontSize: 21,
            letterSpacing: -0.5,
            color: TeknoyTheme.citMaroon,
          ),
        ),
        centerTitle: true,
        actions: [
          // ── 1. Shopping Cart Action ──
          Consumer(
            builder: (context, ref, child) {
              final cart = ref.watch(cartProvider);
              final itemCount = cart.fold<int>(0, (sum, item) => sum + item.quantity);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shopping_cart_outlined,
                      color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                      size: 22,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CartView(),
                        ),
                      );
                    },
                    tooltip: 'Shopping Cart',
                  ),
                  if (itemCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD90429),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$itemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // ── 2. Notification Action ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                  size: 22,
                ),
                onPressed: () => _showNotificationsSheet(context),
                tooltip: 'Notifications',
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD90429),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: TeknoyNavigationDrawer(
        onSelectTab: (index) {
          setState(() => _activeTab = index);
        },
      ),
      body: _buildActiveTabBody(context),
      bottomNavigationBar: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F12) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF282830) : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
              context,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              isActive: _activeTab == 0,
              onTap: () {
                setState(() => _activeTab = 0);
                ref.read(productsListNotifierProvider.notifier).refresh();
              },
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum_rounded,
              label: 'Messages',
              isActive: _activeTab == 1,
              hasBadge: false,
              onTap: () => setState(() => _activeTab = 1),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.add_circle_outline_rounded,
              activeIcon: Icons.add_circle_rounded,
              label: 'Sell',
              isActive: _activeTab == 2,
              isActionFocus: true,
              onTap: () => setState(() => _activeTab = 2),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Orders',
              isActive: _activeTab == 3,
              hasBadge: false,
              onTap: () => setState(() => _activeTab = 3),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              isActive: _activeTab == 4,
              onTap: () => setState(() => _activeTab = 4),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: TeknoyTheme.kElevationHigh,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: TeknoyTheme.citMaroon, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Campus Deal Notifications',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.handshake_rounded, color: TeknoyTheme.success),
              ),
              title: const Text('Tawad & Offer Alerts', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Live negotiation offers and accepted deals are synced to your Chat Inbox in real time.', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF8E1),
                child: Icon(Icons.security_rounded, color: Color(0xFF8B6B00)),
              ),
              title: const Text('TeknoyCart Student Guarantee', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('All approved meetup deals require OTP & QR confirmation before funds release.', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InboxView()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('View All Deals in Chat Inbox', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabBody(BuildContext context) {
    switch (_activeTab) {
      case 0:
        return _buildHomeTabBody(context);
      case 1:
        return const InboxView(embedded: true);
      case 2:
        return _buildSellTabBody(context);
      case 3:
        return const OrderHistoryView(embedded: true);
      case 4:
        return _buildProfileTabBody(context);
      default:
        return _buildHomeTabBody(context);
    }
  }

  // ── Index 0: Home Feed Body
  Widget _buildHomeTabBody(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final filteredProducts = ref.watch(filteredProductsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input Deck with Filter Tune Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181C) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF282830) : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchResultsView(initialQuery: val.trim()),
                          ),
                        );
                      }
                    },
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF191C1D),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search textbooks, uniforms, snacks...',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? Colors.white38 : const Color(0xFF5A413D).withOpacity(0.7),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5A413D)),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFF5A413D)),
                              onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showFilterSheet(context),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181C) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF282830) : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: TeknoyTheme.citMaroon,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Wildcat Campus Spotlight Banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TeknoyTheme.citMaroon,
                    TeknoyTheme.citMaroonLight.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: TeknoyTheme.citMaroon.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Opacity(
                      opacity: 0.15,
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 160,
                        color: TeknoyTheme.citGold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: TeknoyTheme.citGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'CAMPUS SPOTLIGHT',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: TeknoyTheme.citMaroon,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Save 50% on Engineering Drawing Boards',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verified listings from CEA graduates • Limited availability',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal Category Pills
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).state = cat;
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TeknoyTheme.citMaroon
                        : (isDark ? const Color(0xFF18181C) : const Color(0xFFF3F4F5)),
                    borderRadius: BorderRadius.circular(9999),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark ? const Color(0xFF282830) : const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF191C1D)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Products list view / Canvas
        Expanded(
          child: productsAsync.when(
            data: (_) {
              if (filteredProducts.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No items match your search.',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: TeknoyTheme.citMaroon,
                onRefresh: () => ref.read(productsListNotifierProvider.notifier).refresh(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Trending Banner
                    const SliverToBoxAdapter(
                      child: FeedTrendingBanner(),
                    ),
                    // Product Grid
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.54,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = filteredProducts[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailView(product: product),
                                ),
                              ),
                              child: FeedProductCard(product: product),
                            );
                          },
                          childCount: filteredProducts.length,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 64, color: TeknoyTheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Offline: ${err.toString()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter', color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _getUserRoleAndStatus(String userId) async {
    try {
      final res = await SupabaseConfig.client
          .from('users')
          .select('role, is_seller_verified, student_id')
          .eq('user_id', userId)
          .single();
      return res;
    } catch (e) {
      return null;
    }
  }

  // ── Index 2: Sell Form Body (Fully Usable Post form)
  Widget _buildSellTabBody(BuildContext context) {
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

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserRoleAndStatus(authState.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon));
        }

        final data = snapshot.data;
        final role = data?['role'] as String? ?? authState.role;
        final isVerified = data?['is_seller_verified'] as bool? ?? authState.isSellerVerified;

        if (role == 'BUYER' || (role == 'SELLER' && !isVerified)) {
          return SellerKYCVerificationView(
            userId: authState.id,
            initialSellerType: (data?['seller_type'] as String?) ?? 'STUDENT',
            onVerificationSubmitted: () {
              _profileFuture = null;
              setState(() {});
            },
            onRefreshStatus: () async {
              _profileFuture = null;
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
                                      color: TeknoyTheme.citMaroon.withOpacity(0.3),
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
                                      color: TeknoyTheme.citMaroon.withOpacity(0.3),
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
              child: _sellSubTab == 0
                  ? SingleChildScrollView(
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
                      color: TeknoyTheme.citMaroon.withOpacity(0.8),
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
          if ((_quickTitleStarters[_sellCategory] ?? []).isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                                ? (isDark ? TeknoyTheme.citMaroon.withOpacity(0.22) : const Color(0xFFFDF2F2))
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
          ],
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
                      color: TeknoyTheme.citMaroon.withOpacity(0.8),
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
          if ((_quickDescStarters[_sellCategory] ?? []).isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
          ],
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
                          ? TeknoyTheme.citMaroon.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.12),
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
                    color: TeknoyTheme.citMaroon.withOpacity(0.3),
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
                          color: TeknoyTheme.citMaroon.withOpacity(0.1),
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
                            color: TeknoyTheme.citMaroon.withOpacity(0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 26, color: TeknoyTheme.citMaroon.withOpacity(0.8)),
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
                            color: isCover ? TeknoyTheme.citMaroon : Colors.grey.withOpacity(0.3),
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
                              color: Colors.black.withOpacity(0.65),
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
              disabledBackgroundColor: TeknoyTheme.citMaroon.withOpacity(0.6),
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
                  : const ManageListingsView(embedded: true),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateProfileMetadata(String dept, String contact, String gcashNumber, {String? storeName}) async {
    try {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      final updateData = <String, dynamic>{
        'department': dept,
        'contact': contact,
        'gcash_number': gcashNumber,
      };
      if (storeName != null) {
        updateData['store_name'] = storeName;
      }

      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(data: updateData),
      );

      if (currentUserId != null) {
        await SupabaseConfig.client
            .from('users')
            .update({
              'gcash_number': gcashNumber,
              'contact': contact,
            })
            .eq('user_id', currentUserId);

        if (storeName != null && storeName.trim().isNotEmpty) {
          await SupabaseConfig.client.from('store_profiles').upsert({
            'seller_id': currentUserId,
            'store_name': storeName.trim(),
          });
        }
      }
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile details updated live in Supabase!'),
          backgroundColor: TeknoyTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
    }
  }

  void _showEditProfileRowDialog(BuildContext context, {required String label, required String currentValue, required Function(String) onSave}) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $label', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onSave(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = math.Random();
    final randomCode = List.generate(5, (index) => chars[rand.nextInt(chars.length)]).join();

    final controller = TextEditingController();
    bool isValid = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Delete Account',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is permanent and cannot be undone. All your listings, deals, and messages will be permanently deleted.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type this code to delete the account: $randomCode',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        isValid = val.trim() == randomCode;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          try {
                            await SupabaseConfig.client.rpc('delete_user_account');
                            await ref.read(authNotifierProvider.notifier).logout();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✅ Account successfully deleted.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete account: $e'),
                                backgroundColor: TeknoyTheme.error,
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withOpacity(0.4),
                  ),
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Index 4: Profile Page Body — High-Fidelity Dark Mode Design
  Widget _buildProfileTabBody(BuildContext context) {
    final authStateAsync = ref.watch(authStateProvider);
    final user = authStateAsync.valueOrNull;
    final name = user?.username ?? 'Wildcat Student';
    final email = user?.email ?? 'Pending verification';
    final rawId = user?.id ?? '';
    final dept = user?.department ?? 'College of Computer Studies';
    final contact = user?.contact ?? '0912 345 6789';
    final gcashNumber = user?.gcashNumber ?? 'Not Configured';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final productsAsync = ref.watch(productsListProvider);
    final userListingsCount = productsAsync.valueOrNull
            ?.where((p) => p.sellerId == rawId)
            .length ??
        0;
    final dealsAsync = ref.watch(userCompletedDealsCountProvider(rawId));
    final dealsCount = dealsAsync.valueOrNull ?? 0;

    // Dark mode palette from the design prompt
    const profileBgDark = Color(0xFF101010);
    const cardBgDark = Color(0xFF1A1A1E);
    const cardBorderDark = Color(0xFF2A2A30);
    const accentRed = Color(0xFFB22222);
    const labelColorDark = Color(0xFF8A8A94);
    const valueColorDark = Color(0xFFE8E8EC);

    // Light mode fallbacks
    final bgColor = isDark ? profileBgDark : const Color(0xFFF5F5F8);
    final cardBg = isDark ? cardBgDark : Colors.white;
    final cardBorder = isDark ? cardBorderDark : const Color(0xFFE0E0E4);
    final labelColor = isDark ? labelColorDark : const Color(0xFF6B6B75);
    final valueColor = isDark ? valueColorDark : const Color(0xFF1A1A1E);
    final nameColor = isDark ? Colors.white : Colors.black;

    // Cache the future so it doesn't re-run on every tab switch
    if (rawId.isNotEmpty && _cachedProfileUserId != rawId) {
       _cachedProfileUserId = rawId;
       _profileFuture = _getUserRoleAndStatus(rawId)
           .then((v) => v ?? {'role': 'BUYER', 'is_seller_verified': false});
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture ?? Future.value({'role': 'BUYER', 'is_seller_verified': false}),
      builder: (context, snapshot) {
        // Use cached data if available to avoid re-showing loading state
        if (snapshot.hasData) {
          _cachedProfileData = snapshot.data;
        }
        final roleInfo = _cachedProfileData ?? {'role': 'BUYER', 'is_seller_verified': false};
        final String role = roleInfo['role'] as String;
        final bool isVerified = roleInfo['is_seller_verified'] as bool;
        final isSeller = role == 'SELLER';
        // Resolve student ID instantly: session cache first, then DB data, then Pending
        final String studentId = user?.studentId 
            ?? (roleInfo['student_id'] as String?)
            ?? 'Pending';

        final badgeText = isSeller
            ? (isVerified ? 'VERIFIED CAMPUS VENDOR' : 'PENDING SELLER')
            : 'STUDENT BUYER';
        final badgeColor = isVerified ? const Color(0xFF22C55E) : const Color(0xFF10B981);
        final badgeIcon = isVerified ? Icons.verified_user_rounded : Icons.shield_rounded;

        final String rawStoreName = (SupabaseConfig.client.auth.currentUser?.userMetadata?['store_name'] as String?)
            ?? (roleInfo['store_name'] as String? ?? '');
        final String storeName = rawStoreName.trim().isNotEmpty ? rawStoreName.trim() : 'Not Configured';

        return Container(
          color: bgColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ── Top Profile Header Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                    boxShadow: isDark ? [
                      BoxShadow(
                        color: accentRed.withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar with glowing ring
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accentRed.withOpacity(0.8),
                              accentRed.withOpacity(0.3),
                              accentRed.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(isDark ? 0.25 : 0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: cardBg,
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: isDark ? const Color(0xFF222228) : const Color(0xFFF0F0F4),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'W',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: accentRed,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // User Name
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: nameColor,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Verification Badge — refined pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: badgeColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, color: badgeColor, size: 13),
                            const SizedBox(width: 6),
                            Text(
                              badgeText,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: cardBorder, height: 1),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            'Listings',
                            '$userListingsCount',
                            isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ManageListingsView()),
                              );
                            },
                          ),
                          _buildStatDivider(cardBorder),
                          _buildStatItem(
                            'Deals',
                            '$dealsCount',
                            isDark,
                            onTap: () {
                              setState(() => _activeTab = 3);
                            },
                          ),
                          _buildStatDivider(cardBorder),
                          Consumer(
                            builder: (context, ref, _) {
                              final targetSellerId = rawId.isNotEmpty ? rawId : 'usr-seller';
                              final summary = ref.watch(sellerRatingSummaryProvider(targetSellerId));
                              final hasReviews = summary.total > 0;
                              final ratingScore = hasReviews ? summary.average.toStringAsFixed(1) : '5.0';
                              final ratingLabel = hasReviews
                                  ? '${summary.total} ${summary.total == 1 ? 'Review' : 'Reviews'}'
                                  : 'Buyer Reviews';

                              return Tooltip(
                                message: 'View Buyer Reviews',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => BuyerReviewsSheet(
                                        sellerId: targetSellerId,
                                        sellerName: name,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ratingScore,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFB22222),
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: Color(0xFFF59E0B),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ratingLabel,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 12,
                                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Information Container
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accentRed,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Student ID
                      _buildProfileInfoField(
                        context,
                        label: 'Student ID',
                        value: studentId,
                        icon: Icons.badge_outlined,
                        isEditable: false,
                        labelColor: labelColor,
                        valueColor: valueColor,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        isDark: isDark,
                        onSave: (_) {},
                      ),

                      const SizedBox(height: 14),

                      // CIT-U Email
                      _buildProfileInfoField(
                        context,
                        label: 'CIT-U Email',
                        value: email,
                        icon: Icons.email_outlined,
                        isEditable: false,
                        labelColor: labelColor,
                        valueColor: valueColor,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        isDark: isDark,
                        onSave: (_) {},
                      ),

                      if (isSeller) ...[
                        // Store Display Name
                        _buildProfileInfoField(
                          context,
                          label: 'Store Display Name',
                          value: storeName,
                          icon: Icons.storefront_outlined,
                          isEditable: true,
                          labelColor: labelColor,
                          valueColor: valueColor,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          isDark: isDark,
                          onSave: (newStore) => _updateProfileMetadata(dept, contact, gcashNumber, storeName: newStore),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Department
                      _buildProfileInfoField(
                        context,
                        label: 'Department',
                        value: dept,
                        icon: Icons.school_outlined,
                        isEditable: true,
                        labelColor: labelColor,
                        valueColor: valueColor,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        isDark: isDark,
                        onSave: (newDept) => _updateProfileMetadata(newDept, contact, gcashNumber, storeName: storeName == 'Not Configured' ? null : storeName),
                      ),

                      const SizedBox(height: 14),

                      // Contact Number
                      _buildProfileInfoField(
                        context,
                        label: 'Contact Number',
                        value: contact,
                        icon: Icons.phone_outlined,
                        isEditable: true,
                        labelColor: labelColor,
                        valueColor: valueColor,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        isDark: isDark,
                        onSave: (newContact) => _updateProfileMetadata(dept, newContact, gcashNumber, storeName: storeName == 'Not Configured' ? null : storeName),
                      ),

                      const SizedBox(height: 14),

                      // GCash Number
                      _buildProfileInfoField(
                        context,
                        label: 'GCash Number',
                        value: gcashNumber,
                        icon: Icons.account_balance_wallet_outlined,
                        isEditable: true,
                        labelColor: labelColor,
                        valueColor: valueColor,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        isDark: isDark,
                        onSave: (newGcash) => _updateProfileMetadata(dept, contact, newGcash, storeName: storeName == 'Not Configured' ? null : storeName),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Sign Out Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ref.read(authNotifierProvider.notifier).logout();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logout failed: $e')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB22222),
                        side: const BorderSide(color: Color(0xFFB22222), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Sign Out Account',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Delete Account Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDeleteAccountDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD90429),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text(
                        'Delete Account',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),
                
                // Footer
                Text(
                  'TeknoyCart CIT-U v1.4.0',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cebu Institute of Technology - University',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: labelColor.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Elevated profile info field with optional edit icon.
  Widget _buildProfileInfoField(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required bool isEditable,
    required Color labelColor,
    required Color valueColor,
    required Color cardBg,
    required Color cardBorder,
    required bool isDark,
    required Function(String) onSave,
  }) {
    const accentRed = Color(0xFFB22222);

    return InkWell(
      onTap: isEditable
          ? () => _showEditProfileRowDialog(context, label: label, currentValue: value, onSave: onSave)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141418) : const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF252530) : const Color(0xFFE8E8EC),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Leading icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentRed.withOpacity(isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accentRed),
            ),
            const SizedBox(width: 14),

            // Label + Value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Edit icon
            if (isEditable)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accentRed.withOpacity(isDark ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, size: 14, color: accentRed),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildBottomNavItem(
    BuildContext context, {
    required IconData icon,
    IconData? activeIcon,
    required String label,
    required bool isActive,
    bool isActionFocus = false,
    bool hasBadge = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = TeknoyTheme.citMaroon;
    final inactiveColor = isDark ? Colors.white54 : const Color(0xFF757575);

    if (isActionFocus) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 28,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [TeknoyTheme.citMaroon, Color(0xFF8B0000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF202026), const Color(0xFF141418)]
                              : [const Color(0xFF2E2628), const Color(0xFF1A1416)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? TeknoyTheme.citMaroon.withOpacity(0.4)
                          : Colors.black.withOpacity(isDark ? 0.35 : 0.22),
                      blurRadius: isActive ? 8 : 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? activeColor
                      : (isDark ? Colors.white70 : const Color(0xFF2E2628)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentIcon = (isActive && activeIcon != null) ? activeIcon : icon;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  currentIcon,
                  size: 23,
                  color: isActive ? activeColor : inactiveColor,
                ),
                if (hasBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD90429),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark, {bool isHighlight = false, VoidCallback? onTap}) {
    final itemWidget = Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isHighlight 
                ? const Color(0xFFB22222) 
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return Tooltip(
        message: 'View $label',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: itemWidget,
          ),
        ),
      );
    }
    return itemWidget;
  }

  Widget _buildStatDivider(Color borderColor) {
    return Container(
      height: 24,
      width: 1,
      color: borderColor,
    );
  }
}

class TextStyles {
  static TextStyle badgeStyle(Color textColor) => TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
        fontSize: 10,
        color: textColor,
        letterSpacing: 0.5,
      );
}

