import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/providers/seller_type_provider.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/utils/order_ui_helper.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';
import 'package:teknoycart/features/checkout/views/cart_view.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/feed/views/seller_storefront_view.dart';
import 'package:teknoycart/features/feed/views/widgets/product_reviews_section.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/core/services/wishlist_service.dart';
import 'package:teknoycart/features/feed/views/widgets/product_image_lightbox.dart';
import 'package:teknoycart/features/feed/views/widgets/product_campus_meetup_card.dart';
import 'package:teknoycart/features/feed/views/widgets/product_seller_card.dart';
import 'package:teknoycart/features/feed/views/widgets/product_purchase_bar.dart';

/// Immersive TeknoyCart Wildcat Product Details Page (PDP).
/// Features high-resolution media gallery, student trust badges, verified seller
/// credentials, direct campus meetup scheduling, and responsive action bar.
class ProductDetailView extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailView({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends ConsumerState<ProductDetailView> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  final Map<String, String> _selectedVariantsByAttr = {};
  int _availableStock = 1;
  bool _isLoadingInventory = false;
  String? _selectedVariant;
  int _quantity = 1;
  bool _isInitializingChat = false;

  List<String> _productImages = [];
  List<Map<String, dynamic>> _fetchedVariants = [];

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    _productImages = List.from(widget.product.imageUrls);
    final variantAttrs = widget.product.categoryAttributes
        .where((a) => a.options.length > 1 || a.name.toLowerCase() == 'size' || a.name.toLowerCase() == 'color')
        .toList();
    _availableStock = variantAttrs.isEmpty ? 1 : 0;
    for (final attr in variantAttrs) {
      final isSize = attr.name.toLowerCase() == 'size';
      final options = isSize
          ? (List<String>.from(attr.options)..sort((a, b) => ProductAttribute.sizeRank(a).compareTo(ProductAttribute.sizeRank(b))))
          : attr.options;
      if (options.isNotEmpty) {
        _selectedVariantsByAttr[attr.name] = options.first;
      }
    }
    _selectedVariant = _getEffectiveVariantName();
    _fetchInventoryForCurrentVariant();
    _fetchProductImages();
  }

  Future<void> _fetchProductImages() async {
    try {
      final rows = await SupabaseConfig.client
          .from('product_images')
          .select('image_url, is_primary')
          .eq('product_id', product.id)
          .order('is_primary', ascending: false);
      if (rows.isNotEmpty && mounted) {
        final urls = rows
            .map((r) => r['image_url'] as String? ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
        if (urls.isNotEmpty) {
          setState(() {
            _productImages = urls;
          });
        }
      }
    } catch (e) {
      debugPrint('PRODUCT_DETAIL_FETCH_IMAGES_FAILED: $e');
    }
  }

  String _getEffectiveVariantName() {
    final variantAttrs = widget.product.categoryAttributes
        .where((a) =>
            a.options.isNotEmpty &&
            (a.options.length > 1 ||
                a.name.toLowerCase() == 'size' ||
                a.name.toLowerCase() == 'color'))
        .toList();

    if (variantAttrs.isEmpty) {
      if (_selectedVariantsByAttr.isNotEmpty) {
        return _selectedVariantsByAttr.values.join(' / ');
      }
      return _selectedVariant ?? '';
    }

    final selectedValues = variantAttrs
        .map((a) => _selectedVariantsByAttr[a.name] ?? (a.options.isNotEmpty ? a.options.first : ''))
        .where((v) => v.isNotEmpty)
        .toList();

    return selectedValues.join(' / ');
  }

  Future<void> _fetchInventoryForCurrentVariant() async {
    setState(() => _isLoadingInventory = true);
    try {
      final client = SupabaseConfig.client;
      final effVariant = _getEffectiveVariantName();

      // Fetch all variants and their inventory for this product
      final variants = await client
          .from('product_variants')
          .select('variant_id, variant_name, variant_value, inventory(stock_qty, reserved_qty)')
          .eq('product_id', product.id);

      if (mounted) {
        _fetchedVariants = List<Map<String, dynamic>>.from(
            variants.whereType<Map<String, dynamic>>());
      }

      if (variants.isNotEmpty && mounted) {
        Map<String, dynamic>? matchedVariant;

        // 1. Exact or normalized delimiter match
        if (effVariant.isNotEmpty) {
          final cleanEff = effVariant.trim().toLowerCase();
          for (final v in variants) {
            final val = (v['variant_value']?.toString() ?? '').trim().toLowerCase();
            if (val == cleanEff ||
                val.replaceAll(' · ', ' / ') == cleanEff ||
                val.replaceAll(' / ', ' · ') == cleanEff) {
              matchedVariant = v;
              break;
            }
          }
        }

        // 2. Token-based match: all selected active variant tokens exist in variant_value
        if (matchedVariant == null && _selectedVariantsByAttr.isNotEmpty) {
          final activeTokens = _selectedVariantsByAttr.entries
              .where((e) =>
                  e.key.toLowerCase() == 'size' ||
                  e.key.toLowerCase() == 'color' ||
                  widget.product.categoryAttributes.any((a) => a.name == e.key && a.options.length > 1))
              .map((e) => e.value.trim().toLowerCase())
              .where((t) => t.isNotEmpty)
              .toList();

          if (activeTokens.isNotEmpty) {
            for (final v in variants) {
              final val = (v['variant_value']?.toString() ?? '').trim().toLowerCase();
              final allMatch = activeTokens.every((token) => val.contains(token));
              if (allMatch) {
                matchedVariant = v;
                break;
              }
            }
          }
        }

        // 3. Fallback: single variant listing
        if (matchedVariant == null && variants.length == 1) {
          matchedVariant = variants.first;
        }

        if (matchedVariant != null) {
          final inv = matchedVariant['inventory'];
          int stock = inv == null ? 1 : 0;
          int reserved = 0;
          if (inv is List && inv.isNotEmpty && inv[0] is Map) {
            stock = (inv[0]['stock_qty'] as num?)?.toInt() ?? 0;
            reserved = (inv[0]['reserved_qty'] as num?)?.toInt() ?? 0;
          } else if (inv is Map) {
            stock = (inv['stock_qty'] as num?)?.toInt() ?? 0;
            reserved = (inv['reserved_qty'] as num?)?.toInt() ?? 0;
          }

          final calculatedAvailable = (stock - reserved) > 0 ? (stock - reserved) : 0;
          setState(() {
            _availableStock = calculatedAvailable;
            if (_quantity > _availableStock && _availableStock > 0) {
              _quantity = _availableStock;
            } else if (_availableStock == 0) {
              _quantity = 1;
            }
            _isLoadingInventory = false;
          });
          return;
        }
      }

      if (mounted) {
        final hasVariants = widget.product.categoryAttributes.any(
            (a) => a.options.length > 1 || a.name.toLowerCase() == 'size' || a.name.toLowerCase() == 'color');
        setState(() {
          _availableStock = hasVariants ? 0 : 1;
          _isLoadingInventory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final hasVariants = widget.product.categoryAttributes.any(
            (a) => a.options.length > 1 || a.name.toLowerCase() == 'size' || a.name.toLowerCase() == 'color');
        setState(() {
          _availableStock = hasVariants ? 0 : 1;
          _isLoadingInventory = false;
        });
      }
    }
  }

  /// Evaluates whether a specific variant option is out of stock in combination with other active selections.
  bool _isOptionOutOfStock(String attrName, String option) {
    if (_fetchedVariants.isEmpty) return false;
    final cleanOption = option.trim().toLowerCase();

    final candidateTokens = <String>[];
    for (final entry in _selectedVariantsByAttr.entries) {
      if (entry.key.toLowerCase() == attrName.toLowerCase()) {
        candidateTokens.add(cleanOption);
      } else {
        candidateTokens.add(entry.value.trim().toLowerCase());
      }
    }

    if (candidateTokens.isEmpty) {
      candidateTokens.add(cleanOption);
    }

    for (final v in _fetchedVariants) {
      final val = (v['variant_value']?.toString() ?? '').trim().toLowerCase();
      final allTokensMatch = candidateTokens.every((token) => val.contains(token));
      if (allTokensMatch) {
        final inv = v['inventory'];
        int stock = 0;
        int reserved = 0;
        if (inv is List && inv.isNotEmpty && inv[0] is Map) {
          stock = (inv[0]['stock_qty'] as num?)?.toInt() ?? 0;
          reserved = (inv[0]['reserved_qty'] as num?)?.toInt() ?? 0;
        } else if (inv is Map) {
          stock = (inv['stock_qty'] as num?)?.toInt() ?? 0;
          reserved = (inv['reserved_qty'] as num?)?.toInt() ?? 0;
        }
        if ((stock - reserved) > 0) {
          return false; // Found available stock!
        }
      }
    }

    return true; // No variant found or stock <= 0
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getProductImages() {
    if (_productImages.isNotEmpty) {
      return _productImages;
    }
    if (product.imageUrls.isNotEmpty) {
      return product.imageUrls;
    }
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return [product.imageUrl!];
    }
    return [];
  }

  void _showMakeAnOfferDialog(BuildContext context) {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to make an offer.'),
          backgroundColor: TeknoyTheme.citMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (currentUser.id == product.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot make an offer on your own listing.'),
          backgroundColor: TeknoyTheme.citMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_availableStock <= 0 && !product.isPreorderEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is out of stock, so offers are closed.'),
          backgroundColor: TeknoyTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final originalPrice = product.price;
    final offerController = TextEditingController(
      text: (originalPrice * 0.90).round().toString(), // Default 10% tawad discount
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final rawText = offerController.text.trim();
            final currentOfferVal = double.tryParse(rawText) ?? (originalPrice * 0.90);
            final savings = originalPrice - currentOfferVal;
            final discountPercent = originalPrice > 0 ? ((savings / originalPrice) * 100).round() : 0;
            final isValidOffer = currentOfferVal > 0 && currentOfferVal < originalPrice;
            final isLowball = currentOfferVal > 0 && currentOfferVal < (originalPrice * 0.40);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1B22) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: TeknoyTheme.kElevationHigh,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Handle Bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4.5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: TeknoyTheme.citGold.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.handshake_rounded,
                                color: Color(0xFFB48200),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Make an Offer (Tawad)',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Propose a fair campus deal to the seller',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              icon: const Icon(Icons.close_rounded, size: 22),
                              visualDensity: VisualDensity.compact,
                              onPressed: isSubmitting ? null : () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Product Summary Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? TeknoyTheme.darkSurface : const Color(0xFFF7F7FA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white10 : const Color(0xFFE8E8EE),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  color: isDark ? const Color(0xFF222228) : const Color(0xFFEAEAF0),
                                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          product.imageUrl!,
                                          semanticLabel: 'Photo of ${product.title}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                        )
                                      : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          'Original Asking Price: ',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          '₱${originalPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Quick Discount Chips (-5%, -10%, -15%, -20%)
                        Row(
                          children: [
                            _buildDiscountChip(
                              label: '-5%',
                              discountedPrice: (originalPrice * 0.95).roundToDouble(),
                              controller: offerController,
                              setModalState: setModalState,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildDiscountChip(
                              label: '-10%',
                              discountedPrice: (originalPrice * 0.90).roundToDouble(),
                              controller: offerController,
                              setModalState: setModalState,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildDiscountChip(
                              label: '-15%',
                              discountedPrice: (originalPrice * 0.85).roundToDouble(),
                              controller: offerController,
                              setModalState: setModalState,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildDiscountChip(
                              label: '-20%',
                              discountedPrice: (originalPrice * 0.80).roundToDouble(),
                              controller: offerController,
                              setModalState: setModalState,
                              isDark: isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Modern Focused Price Input Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? TeknoyTheme.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: currentOfferVal >= originalPrice && currentOfferVal > 0
                                  ? Colors.red.shade400
                                  : (isDark ? const Color(0xFF2C2C36) : const Color(0xFFD6D6E0)),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'YOUR OFFERED PRICE',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                  ),
                                  if (savings > 0 && discountPercent > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: TeknoyTheme.citGold.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$discountPercent% OFF',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8B6508),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    '₱',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: TeknoyTheme.citMaroon,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: offerController,
                                      enabled: !isSubmitting,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setModalState(() {}),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        border: InputBorder.none,
                                        hintText: '0',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Real-time Inline Validation / Savings Badge
                        if (currentOfferVal >= originalPrice)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Offer must be lower than asking price (₱${originalPrice.toStringAsFixed(0)})',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isLowball)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB48200)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Heads up: offers under 40% are rarely accepted by sellers.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: isDark ? Colors.amber.shade300 : const Color(0xFF8B6508),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (savings > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 16, color: TeknoyTheme.success),
                                const SizedBox(width: 8),
                                Text(
                                  'You save ₱${savings.toStringAsFixed(0)} ($discountPercent% OFF asking price)',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: TeknoyTheme.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Submit Action Button
                        ElevatedButton(
                          onPressed: (!isValidOffer || isSubmitting)
                              ? null
                              : () async {
                                  final offerVal = double.tryParse(offerController.text.trim()) ?? (originalPrice * 0.90);
                                  if (offerVal <= 0 || offerVal >= originalPrice) return;

                                  setModalState(() {
                                    isSubmitting = true;
                                  });

                                  try {
                                    final chatService = ref.read(chatServiceProvider);
                                    final roomId = await chatService.getOrCreateChatRoom(
                                      buyerId: currentUser.id,
                                      sellerId: product.sellerId,
                                      productId: product.id,
                                      productName: product.title,
                                      productPrice: product.price,
                                    );

                                    // Close bottom sheet safely
                                    if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
                                      Navigator.of(sheetContext).pop();
                                    }

                                    if (!context.mounted) return;

                                    // Push ChatView on parent view's context
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => ChatView(
                                          product: product,
                                          roomId: roomId,
                                          initialOfferPrice: offerVal,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (modalContext.mounted) {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to open chat: $e'),
                                          backgroundColor: TeknoyTheme.citMaroon,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TeknoyTheme.citMaroon,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDark ? Colors.white12 : const Color(0xFFE0E0E6),
                            disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: isValidOffer ? 2 : 0,
                          ),
                          child: isSubmitting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Connecting to Seller...',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send_rounded, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Send ₱${currentOfferVal.toStringAsFixed(0)} Offer & Open Chat',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
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
            );
          },
        );
      },
    );
  }

  Widget _buildDiscountChip({
    required String label,
    required double discountedPrice,
    required TextEditingController controller,
    required StateSetter setModalState,
    required bool isDark,
  }) {
    final formattedPrice = discountedPrice.toStringAsFixed(0);
    final isSelected = controller.text.trim() == formattedPrice;

    return Expanded(
      child: InkWell(
        onTap: () {
          setModalState(() {
            controller.text = formattedPrice;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? TeknoyTheme.citMaroon
                : (isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBg),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? TeknoyTheme.citMaroon
                  : (isDark ? Colors.white12 : const Color(0xFFE2E2EA)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₱$formattedPrice',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStandardChat(BuildContext context) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to chat with the seller.')),
      );
      return;
    }

    if (currentUser.id == product.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself on your own listing.')),
      );
      return;
    }

    setState(() => _isInitializingChat = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final roomId = await chatService.getOrCreateChatRoom(
        buyerId: currentUser.id,
        sellerId: product.sellerId,
        productId: product.id,
        productName: product.title,
        productPrice: product.price,
      );

      if (!context.mounted) return;
      setState(() => _isInitializingChat = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatView(
            product: product,
            roomId: roomId,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        setState(() => _isInitializingChat = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $e')),
        );
      }
    }
  }

  void _addToCart() {
    if (_availableStock <= 0 && !product.isPreorderEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This variant is currently out of stock.'),
          backgroundColor: TeknoyTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final effectiveVariant = _getEffectiveVariantName();
    ref.read(cartProvider.notifier).addToCart(
          product,
          quantity: _quantity,
          variantName: effectiveVariant.isNotEmpty ? effectiveVariant : null,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Added "${product.title}" to cart!')),
          ],
        ),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: TeknoyTheme.citGold,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartView()),
            );
          },
        ),
        backgroundColor: TeknoyTheme.citMaroon,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openImageLightbox(BuildContext context, List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => ProductImageLightbox(
          images: images,
          initialIndex: initialIndex,
          productTitle: product.title,
        ),
      ),
    );
  }

  void _buyNow() {
    final effectiveVariant = _getEffectiveVariantName();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutView(
          product: product,
          isDirectBuy: true,
          quantity: _quantity,
          variantName: effectiveVariant.isNotEmpty ? effectiveVariant : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final images = _getProductImages();

    return Scaffold(
      backgroundColor: isDark ? TeknoyTheme.darkBg : const Color(0xFFF7F7F9),
      body: Stack(
        children: [
          // Main Scrollable Content
          CustomScrollView(
            slivers: [
              // Edge-to-Edge Image Carousel App Bar
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: isDark ? TeknoyTheme.darkSurface : Colors.white,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Center(
                    child: CircleAvatar(
                      backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                      child: IconButton(
                        tooltip: 'Back',
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                actions: [
                  CircleAvatar(
                    backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final isFavorite = ref.watch(isProductFavoritedProvider(product.id));
                        return IconButton(
                          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                          icon: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: TeknoyTheme.citMaroon,
                            size: 20,
                          ),
                          onPressed: () async {
                            final isFav = await ref.read(wishlistProvider.notifier).toggle(product.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isFav ? 'Saved to favorites' : 'Removed from favorites'),
                              duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                    child: IconButton(
                      tooltip: 'Share product',
                      icon: Icon(
                        Icons.share_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 20,
                      ),
                      onPressed: () async {
                        final link = 'https://teknoycart.cit.edu/p/${product.id}';
                        await Clipboard.setData(ClipboardData(text: link));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Link copied: $link'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // Carousel Slider
                      images.isNotEmpty
                          ? PageView.builder(
                              controller: _pageController,
                              itemCount: images.length,
                              onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                              itemBuilder: (context, index) {
                                return Semantics(
                                  button: true,
                                  label: 'View photo ${index + 1}',
                                  child: GestureDetector(
                                    onTap: () => _openImageLightbox(context, images, index),
                                    child: Container(
                                      color: isDark ? TeknoyTheme.darkSurface : const Color(0xFFF7F7FA),
                                      child: Center(
                                        child: Hero(
                                          tag: index == 0 ? 'product_image_${product.id}' : 'product_image_${product.id}_$index',
                                          child: Image.network(
                                            images[index],
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                            height: double.infinity,
                                            excludeFromSemantics: true,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Icon(
                                                Icons.image_not_supported_rounded,
                                                size: 64,
                                                color: isDark ? Colors.white24 : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: isDark ? TeknoyTheme.darkCardBorder : const Color(0xFFEDE8F5),
                              child: Center(
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                                ),
                              ),
                            ),

                      // Image Gallery Index Pill
                      if (images.isNotEmpty)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${images.length}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Product Core Details
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary Price & Badges Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Price & Badges (Wrap to prevent overflow on long numbers or small screens)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '₱${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: TeknoyTheme.citMaroon,
                                  letterSpacing: -0.5,
                                ),
                              ),

                              // Category Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? TeknoyTheme.darkCardBorder : TeknoyTheme.lightSurfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  product.category,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : TeknoyTheme.citMaroonMuted,
                                  ),
                                ),
                              ),

                              // Condition Tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: TeknoyTheme.citGold.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: TeknoyTheme.citGold.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  OrderUiHelper.formatCondition(product.condition),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF8B6B00),
                                  ),
                                ),
                              ),

                              // Negotiable / Tawad Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.handshake_outlined,
                                      size: 11,
                                      color: TeknoyTheme.citMaroon,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'TAWAD OK',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: TeknoyTheme.citMaroon,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Product Title
                          Text(
                            product.title,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Social Proof & Trust Metrics Bar
                          Row(
                            children: [
                              Consumer(
                                builder: (context, ref, _) {
                                  final summary = ref.watch(productRatingSummaryProvider(product.id));
                                  return Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 16, color: TeknoyTheme.citGold),
                                      const SizedBox(width: 3),
                                      Text(
                                        summary.total > 0
                                            ? '${summary.average.toStringAsFixed(1)} (${summary.total} reviews)'
                                            : 'No reviews yet',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Container(width: 1, height: 12, color: Colors.grey.withValues(alpha: 0.3)),
                              const SizedBox(width: 12),
                              const Icon(Icons.verified_user_outlined, size: 14, color: TeknoyTheme.success),
                              const SizedBox(width: 4),
                              const Text(
                                'Campus Meetup',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: TeknoyTheme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🛡️ TeknoyCart Student Guarantee (Shopee Guarantee Style)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: TeknoyTheme.citGold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.citGold.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              color: Color(0xFF8B6B00),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TeknoyCart Student Guarantee',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF6B5100),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Funds held safely. Handoff is confirmed via 6-digit OTP & QR code during physical meetup.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: Color(0xFF6B5100),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Interactive Variant Selector
                    _buildVariantSection(isDark),

                    // Interactive Quantity Selector (Shopee / Lazada Style)
                    _buildQuantitySection(isDark),

                    // Product Specifications
                    _buildSpecificationsSection(isDark),

                    // Product Description
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            product.description.isNotEmpty
                                ? product.description
                                : 'No additional description provided for this listing.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5,
                              height: 1.5,
                              color: isDark ? Colors.white70 : const Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Campus Fulfillment & Meetup Zones (Answers PDP Question 6)
                    ProductCampusMeetupCard(isDark: isDark),
                    const SizedBox(height: 10),

                    // Seller Store Profile Card
                    ProductSellerCard(
                      isDark: isDark,
                      storeName: product.sellerStoreName ?? 'CIT-U Student Seller',
                      onVisitShop: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SellerStorefrontView(
                              sellerId: product.sellerId,
                              sellerName: product.sellerStoreName ?? 'CIT-U Student Seller',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Ratings & Reviews Section
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
                      ),
                      child: ProductReviewsSection(product: widget.product),
                    ),

                    // Bottom safe spacing for sticky bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // Loading overlay during chat room creation
          if (_isInitializingChat)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
              ),
            ),

          // Sticky Bottom Action Bar (Signature Shopee 4-Piece Action Layout)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ProductPurchaseBar(
              isDark: isDark,
              cartCount: ref.watch(cartProvider).length,
              isInitializingChat: _isInitializingChat,
              availableStock: _availableStock,
              isPreorderEnabled: product.isPreorderEnabled,
              isLoadingInventory: _isLoadingInventory,
              onChatPressed: () => _openStandardChat(context),
              onAddToCartPressed: _addToCart,
              onMakeOfferPressed: () => _showMakeAnOfferDialog(context),
              onBuyNowPressed: _buyNow,
              showMakeOffer: ref.watch(sellerAcceptsOffersProvider(product.sellerId)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSection(bool isDark) {
    final variantAttrs = widget.product.categoryAttributes
        .where((a) =>
            a.options.isNotEmpty &&
            (a.options.length > 1 ||
                a.name.toLowerCase() == 'size' ||
                a.name.toLowerCase() == 'color'))
        .toList();

    if (variantAttrs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: variantAttrs.map((attr) {
          final isSize = attr.name.toLowerCase() == 'size';
          final options = isSize
              ? (List<String>.from(attr.options)..sort((a, b) => ProductAttribute.sizeRank(a).compareTo(ProductAttribute.sizeRank(b))))
              : attr.options;
          final currentSelection = _selectedVariantsByAttr[attr.name] ?? (options.isNotEmpty ? options.first : '');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select ${attr.name}',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Chosen: $currentSelection',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = opt.trim().toLowerCase() == currentSelection.trim().toLowerCase();
                  final isOutOfStock = _isOptionOutOfStock(attr.name, opt);

                  return Opacity(
                    opacity: isOutOfStock && !isSelected ? 0.38 : 1.0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _selectedVariantsByAttr[attr.name] = opt;
                          _selectedVariant = _getEffectiveVariantName();
                        });
                        _fetchInventoryForCurrentVariant();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isOutOfStock ? TeknoyTheme.citMaroon.withValues(alpha: 0.7) : TeknoyTheme.citMaroon)
                              : (isDark ? const Color(0xFF1F1F26) : const Color(0xFFF3F3F5)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? TeknoyTheme.citMaroon
                                : (isOutOfStock ? (isDark ? Colors.white12 : Colors.black12) : Colors.transparent),
                          ),
                        ),
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: isOutOfStock && !isSelected ? TextDecoration.lineThrough : null,
                            decorationColor: isDark ? Colors.white38 : Colors.black38,
                            color: isSelected
                                ? Colors.white
                                : (isOutOfStock
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : (isDark ? Colors.white70 : Colors.black87)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Interactive Quantity Stepper section
  Widget _buildQuantitySection(bool isDark) {
    final maxAllowed = _availableStock > 0 ? _availableStock : 1;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quantity',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isLoadingInventory
                    ? 'Checking stock...'
                    : (_availableStock > 0
                        ? '$_availableStock units available in stock'
                        : 'Out of stock for this variant'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: _availableStock > 0
                      ? (isDark ? Colors.white60 : Colors.black54)
                      : TeknoyTheme.error,
                  fontWeight: _availableStock <= 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? const Color(0xFF2B2B36) : const Color(0xFFE2E2EA),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Decrease quantity',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  color: _quantity > 1 ? TeknoyTheme.citMaroon : Colors.grey,
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase quantity',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  color: (_quantity < maxAllowed && _availableStock > 0)
                      ? TeknoyTheme.citMaroon
                      : Colors.grey,
                  onPressed: (_quantity < maxAllowed && _availableStock > 0)
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationsSection(bool isDark) {
    if (product.categoryAttributes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Specifications',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(4.0),
            },
            children: product.categoryAttributes.map((attr) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text(
                      attr.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text(
                      attr.value,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
