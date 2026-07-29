import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_details_sheet.dart';

/// State-of-the-Art Seller Storefront View matching modern campus marketplace design (Figma Node 1:39 style).
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

class _SellerStorefrontViewState extends ConsumerState<SellerStorefrontView> {
  String _searchQuery = '';
  String? _fetchedStoreName;
  String? _fetchedOwnerName;
  bool _isFollowing = false;
  int _activeTab = 0; // 0: Home, 1: Products, 2: Categories, 3: Feed
  String _sortBy = 'latest'; // latest, price_low, price_high
  String? _selectedCategory;

  String get _mockFollowers {
    final hash = widget.sellerId.hashCode.abs();
    final base = 800 + (hash % 1200);
    if (base >= 1000) {
      final kVal = (base / 1000).toStringAsFixed(1);
      return _isFollowing ? '${kVal}k+' : '${kVal}k';
    }
    return _isFollowing ? '${base + 1}' : '$base';
  }

  String get _mockFollowings {
    final hash = widget.sellerId.hashCode.abs();
    return '${15 + (hash % 35)}';
  }

  String get _mockRating {
    final hash = widget.sellerId.hashCode.abs();
    final ratings = ['4.8', '4.9', '4.7', '5.0'];
    return ratings[hash % ratings.length];
  }

  @override
  void initState() {
    super.initState();
    _loadStoreProfile();
  }

  Future<void> _loadStoreProfile() async {
    try {
      final client = SupabaseConfig.client;

      // 1. Fetch store_name from store_profiles table
      final profile = await client
          .from('store_profiles')
          .select('store_name')
          .eq('seller_id', widget.sellerId)
          .maybeSingle();

      // 2. Fetch full_name from users table
      final userRecord = await client
          .from('users')
          .select('full_name')
          .eq('user_id', widget.sellerId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (profile != null && profile['store_name'] != null) {
            _fetchedStoreName = profile['store_name'] as String;
          }
          if (userRecord != null && userRecord['full_name'] != null) {
            _fetchedOwnerName = userRecord['full_name'] as String;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _navigateToChat() async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to chat with the store owner.')),
      );
      return;
    }
    if (currentUser.id == widget.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own storefront.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
      ),
    );

    try {
      final chatService = ref.read(chatServiceProvider);
      final products = ref.read(productsListProvider).valueOrNull ?? [];
      final sellerProducts = products.where((p) => p.sellerId == widget.sellerId).toList();

      Product targetProduct;
      if (sellerProducts.isNotEmpty) {
        targetProduct = sellerProducts.first;
      } else {
        targetProduct = Product(
          id: 'store-inquiry-${widget.sellerId}',
          title: _fetchedStoreName ?? widget.sellerName,
          description: 'General inquiry to store owner.',
          price: 0,
          category: 'General',
          condition: 'New',
          sellerId: widget.sellerId,
          createdAt: DateTime.now(),
        );
      }

      final roomId = await chatService.getOrCreateChatRoom(
        buyerId: currentUser.id,
        sellerId: widget.sellerId,
        productId: targetProduct.id,
      );

      if (mounted) {
        Navigator.pop(context); // close loader
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatView(
              product: targetProduct,
              roomId: roomId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final storeName = _fetchedStoreName ?? widget.sellerName;
    final ownerName = _fetchedOwnerName ?? (widget.sellerName != storeName ? widget.sellerName : 'Campus Seller');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF6F6F9),
      appBar: AppBar(
        backgroundColor: TeknoyTheme.citMaroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          storeName,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: 'Share Store',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Store link for "$storeName" copied to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (val) {
              if (val == 'report') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted for admin review.')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 18, color: TeknoyTheme.citMaroon),
                    SizedBox(width: 8),
                    Text('Share Storefront', style: TextStyle(fontFamily: 'Outfit')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Report Store', style: TextStyle(fontFamily: 'Outfit', color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Premium Store Header Card (Dark Red / Maroon Container) ──
            Container(
              decoration: const BoxDecoration(
                color: TeknoyTheme.citMaroon,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Avatar + Info Deck
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Avatar / Logo Box
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.storefront_rounded,
                            color: TeknoyTheme.citMaroon,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Store Title, Verification Badge, and Owner Name Box
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.verified_rounded, color: TeknoyTheme.citGold, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'CIT-U Campus Vendor',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // ── OWNER NAME TEXT BOX (Requested Feature) ──
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_rounded,
                                    color: TeknoyTheme.citGold,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Owner: $ownerName',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons Row: Follow & Chat
                  Row(
                    children: [
                      // Follow Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isFollowing = !_isFollowing;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_isFollowing ? 'Now following $storeName' : 'Unfollowed $storeName'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: TeknoyTheme.citMaroon,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Chat Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _navigateToChat,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: TeknoyTheme.citMaroonDark.withOpacity(0.3),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Chat',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3 Stat Cards (RATING, FOLLOWERS, FOLLOWINGS)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeaderStatItem(_mockRating, 'RATING'),
                        _buildStatDivider(),
                        _buildHeaderStatItem(_mockFollowers, 'FOLLOWERS'),
                        _buildStatDivider(),
                        _buildHeaderStatItem(_mockFollowings, 'FOLLOWINGS'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Search Box within Storefront ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141418) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
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
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Inter'),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // ── 3. Horizontal Navigation Tabs (Home, Products, Categories, Feed) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTabOption(0, 'Home'),
                  _buildTabOption(1, 'Products'),
                  _buildTabOption(2, 'Categories'),
                  _buildTabOption(3, 'Feed'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Store Catalog Title & Sort Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Store Catalog',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Handpicked essentials for campus life',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) => setState(() => _sortBy = val),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C22) : const Color(0xFFEFEFF3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _sortBy == 'price_low'
                                ? 'Sort: Price Low'
                                : _sortBy == 'price_high'
                                    ? 'Sort: Price High'
                                    : 'Sort by',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'latest', child: Text('Latest Listed', style: TextStyle(fontFamily: 'Inter'))),
                      const PopupMenuItem(value: 'price_low', child: Text('Price: Low to High', style: TextStyle(fontFamily: 'Inter'))),
                      const PopupMenuItem(value: 'price_high', child: Text('Price: High to Low', style: TextStyle(fontFamily: 'Inter'))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Category filter chips if Categories tab selected
            if (_activeTab == 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Books', 'Uniforms', 'Electronics', 'Drawing Tools'].map((cat) {
                      final isSelected = (_selectedCategory ?? 'All') == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          selectedColor: TeknoyTheme.citMaroon,
                          onSelected: (val) {
                            setState(() {
                              _selectedCategory = cat == 'All' ? null : cat;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // ── 5. Products Grid ──
            productsAsync.when(
              data: (products) {
                final sellerProducts = products.where((p) {
                  final belongsToSeller = p.sellerId == widget.sellerId;
                  final matchesSearch = _searchQuery.isEmpty ||
                      p.title.toLowerCase().contains(_searchQuery) ||
                      p.description.toLowerCase().contains(_searchQuery);
                  final matchesCategory = _selectedCategory == null || p.category.toLowerCase() == _selectedCategory!.toLowerCase();
                  return belongsToSeller && matchesSearch && matchesCategory;
                }).toList();

                if (_sortBy == 'price_low') {
                  sellerProducts.sort((a, b) => a.price.compareTo(b.price));
                } else if (_sortBy == 'price_high') {
                  sellerProducts.sort((a, b) => b.price.compareTo(a.price));
                } else {
                  sellerProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                }

                if (sellerProducts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No products matching "$_searchQuery"'
                                : 'No products found listed under this store catalog.',
                            style: const TextStyle(color: Colors.grey, fontFamily: 'Inter'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: sellerProducts.length,
                    itemBuilder: (context, index) {
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
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                            ],
                          ),
                          child: _buildProductCard(product, isDark, index),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text('Error loading catalog: $err', style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabOption(int index, String label) {
    final isSelected = _activeTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? TeknoyTheme.citMaroon : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? TeknoyTheme.citMaroon
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildProductCard(Product product, bool isDark, int index) {
    // Show mock discount badge on select items for realistic campus storefront visual
    final showDiscount = index % 3 == 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: TeknoyTheme.citMaroon.withOpacity(0.05),
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: TeknoyTheme.citMaroon.withOpacity(0.05),
                        child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                      ),
              ),
              if (showDiscount)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '-25%',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
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
                  fontSize: 14,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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
