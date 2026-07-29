import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_details_sheet.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerStorefrontView extends ConsumerStatefulWidget {
  final String sellerId;
  final String sellerName;

  const SellerStorefrontView({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  ConsumerState<SellerStorefrontView> createState() => _SellerStorefrontViewState();
}

class _AuthProfile {
  final String fullName;
  final String? storeName;
  _AuthProfile({required this.fullName, this.storeName});
}

class _SellerStorefrontViewState extends ConsumerState<SellerStorefrontView> {
  String _searchQuery = '';
  String? _fetchedStoreName;
  bool _isLoadingStore = true;

  @override
  void initState() {
    super.initState();
    _loadStoreProfile();
  }

  Future<void> _loadStoreProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final profile = await supabase
          .from('store_profiles')
          .select('store_name')
          .eq('seller_id', widget.sellerId)
          .maybeSingle();
      
      if (profile != null && mounted) {
        setState(() {
          _fetchedStoreName = profile['store_name'] as String?;
          _isLoadingStore = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingStore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = _fetchedStoreName ?? widget.sellerName;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF6F6F9),
      body: CustomScrollView(
        slivers: [
          // 1. Beautiful Header Banner Bar
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: TeknoyTheme.citMaroon,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.3),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TeknoyTheme.citMaroon,
                          TeknoyTheme.citMaroonLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          radius: 28,
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black38, offset: Offset(0, 1.5), blurRadius: 4),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.verified_user_rounded, color: TeknoyTheme.citGold, size: 12),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'CIT-U Campus Vendor',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: Colors.white70,
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
                ],
              ),
            ),
          ),

          // 2. Search Box within Store
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141418) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
                  ),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                    hintText: 'Search within storefront...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // 3. Products List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: const Text(
                'Store Catalog',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 4. Products Grid
          productsAsync.when(
            data: (products) {
              final sellerProducts = products.where((p) {
                final belongsToSeller = p.sellerId == widget.sellerId;
                final matchesSearch = _searchQuery.isEmpty ||
                    p.title.toLowerCase().contains(_searchQuery) ||
                    p.description.toLowerCase().contains(_searchQuery);
                return belongsToSeller && matchesSearch;
              }).toList();

              if (sellerProducts.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text(
                        'No products found listed under this store.',
                        style: TextStyle(color: Colors.grey, fontFamily: 'Inter'),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = sellerProducts[index];
                      return GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ProductDetailsSheet(product: product),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141418) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
                            ),
                          ),
                          child: _buildProductCard(product, isDark),
                        ),
                      );
                    },
                    childCount: sellerProducts.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error loading products: $err'),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                : Container(
                    color: TeknoyTheme.citMaroon.withOpacity(0.05),
                    child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.title,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '₱${product.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : TeknoyTheme.citMaroon,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
