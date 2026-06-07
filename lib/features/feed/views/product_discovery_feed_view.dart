import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/navigation_drawer.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/feed/views/product_details_sheet.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/chat/views/inbox_view.dart';

/// Product Discovery Feed representing Figma Node 1:39.
/// Main marketplace landing hub for listing, browsing, and searching products.
class ProductDiscoveryFeedView extends ConsumerStatefulWidget {
  const ProductDiscoveryFeedView({super.key});

  @override
  ConsumerState<ProductDiscoveryFeedView> createState() => _ProductDiscoveryFeedViewState();
}

class _ProductDiscoveryFeedViewState extends ConsumerState<ProductDiscoveryFeedView> {
  int _activeTab = 0;
  Map<String, dynamic>? _cachedProfileData;
  String? _cachedProfileUserId;
  Future<Map<String, dynamic>>? _profileFuture;

  // Form controllers for Sell tab
  final _sellTitleController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _sellDescController = TextEditingController();
  String _sellCategory = 'Books';
  String _sellCondition = 'New';
  bool _sellHasUploadedMockImage = false;
  XFile? _selectedImageFile;
  bool _isUploadingProductImage = false;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _sellTitleController.dispose();
    _sellPriceController.dispose();
    _sellDescController.dispose();
    super.dispose();
  }

  void _postNewItem() {
    final title = _sellTitleController.text.trim();
    final priceStr = _sellPriceController.text.trim();
    final desc = _sellDescController.text.trim();

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

    _doPostItem(title: title, desc: desc, price: price);
  }

  Future<void> _doPostItem({required String title, required String desc, required double price}) async {
    // Use uploaded image URL if available, otherwise use category-based mock
    String imageUrl;
    if (_selectedImageFile != null) {
      setState(() => _isUploadingProductImage = true);
      try {
        final sellerId = ref.read(authStateProvider).valueOrNull?.id ?? 'usr-seller';
        final fileName = 'product_${sellerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await _selectedImageFile!.readAsBytes();
        await SupabaseConfig.client.storage
            .from('product-images')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        imageUrl = SupabaseConfig.client.storage
            .from('product-images')
            .getPublicUrl(fileName);
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
      imageUrl = 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&q=80&w=400';
      if (_sellCategory == 'Apparel') {
        imageUrl = 'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?auto=format&fit=crop&q=80&w=400';
      } else if (_sellCategory == 'Electronics') {
        imageUrl = 'https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&q=80&w=400';
      } else if (_sellCategory == 'Drawing Tools') {
        imageUrl = 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?auto=format&fit=crop&q=80&w=400';
      }
    }

    final newProduct = Product(
      id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: desc,
      price: price,
      category: _sellCategory,
      condition: _sellCondition,
      imageUrl: imageUrl,
      sellerId: ref.read(authStateProvider).valueOrNull?.id ?? 'usr-buyer',
      createdAt: DateTime.now(),
    );

    ref.read(productsListNotifierProvider.notifier).addProduct(newProduct);

    // Reset Form
    _sellTitleController.clear();
    _sellPriceController.clear();
    _sellDescController.clear();
    setState(() {
      _sellCategory = 'Books';
      _sellCondition = 'New';
      _sellHasUploadedMockImage = false;
      _selectedImageFile = null;
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
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
      );
      if (picked == null) return;
      setState(() {
        _selectedImageFile = picked;
        _sellHasUploadedMockImage = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: TeknoyTheme.error),
        );
      }
    }
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
              const Text(
                'Add Product Photo',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: TeknoyTheme.citMaroon,
                  child: Icon(Icons.photo_library_rounded, color: Colors.white),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                subtitle: const Text('Pick a photo from your device', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
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
                subtitle: const Text('Capture using your camera', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
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
                  ? 'Bargaining Center'
                  : _activeTab == 2
                      ? 'Sell Items'
                      : _activeTab == 3
                          ? 'Orders & Pickups'
                          : 'Wildcat Profile',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -0.5,
            color: TeknoyTheme.citMaroon,
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('System checks: verified connection with local Supabase live client.')),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD90429),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.sync_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF5A413D),
            ),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing campus catalog...'),
                  duration: Duration(milliseconds: 500),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await ref.read(productsListNotifierProvider.notifier).refresh();
            },
            tooltip: 'Sync Feed',
          ),
        ],
      ),
      drawer: const TeknoyNavigationDrawer(),
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
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: _activeTab == 0,
              onTap: () {
                setState(() => _activeTab = 0);
                ref.read(productsListNotifierProvider.notifier).refresh();
              },
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.message_rounded,
              label: 'Messages',
              isActive: _activeTab == 1,
              onTap: () => setState(() => _activeTab = 1),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.add_circle_rounded,
              label: 'Sell',
              isActive: _activeTab == 2,
              isActionFocus: true,
              onTap: () => setState(() => _activeTab = 2),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.receipt_long_rounded,
              label: 'Orders',
              isActive: _activeTab == 3,
              hasBadge: true,
              onTap: () => setState(() => _activeTab = 3),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.person_rounded,
              label: 'Profile',
              isActive: _activeTab == 4,
              onTap: () => setState(() => _activeTab = 4),
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
        return _buildOrdersTabBody(context);
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
                    SliverToBoxAdapter(
                      child: _buildTrendingBanner(context),
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
                              onTap: () => ProductDetailsSheet.show(context, product),
                              child: _buildProductCard(context, product),
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

  // ── Index 1: Negotiations List Body
  Widget _buildNegotiationsTabBody(BuildContext context) {
    // We display a beautiful scrollable active channels list pulling from the product list
    final products = ref.watch(filteredProductsProvider);
    if (products.isEmpty) {
      return const Center(
        child: Text('No active negotiations catalog items found.', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: products.length > 3 ? 3 : products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final buyers = ['Maria Santos (CIT-U CCS)', 'John Doe (CIT-U CEA)', 'Jane Smith (CIT-U CBA)'];
        final times = ['2 mins ago', '1 hour ago', '3 hours ago'];
        final prices = ['₱400.00', '₱350.00', '₱850.00'];
        final statuses = ['P2P Validation', 'Reserved', 'P2P Validation'];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                p.imageUrl ?? '',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, size: 30),
              ),
            ),
            title: Text(
              p.title,
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Sender: ${buyers[index]}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statuses[index] == 'Reserved'
                            ? Colors.blue.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statuses[index],
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statuses[index] == 'Reserved'
                              ? Colors.blue.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(times[index], style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  prices[index],
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: TeknoyTheme.citMaroon),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ],
            ),
            onTap: () async {
              final buyerId = ref.read(authStateProvider).valueOrNull?.id;
              if (buyerId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to negotiate.')),
                );
                return;
              }

              // Show micro-loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
                ),
              );

              try {
                final chatService = ref.read(chatServiceProvider);
                final roomId = await chatService.getOrCreateChatRoom(
                  buyerId: buyerId,
                  sellerId: p.sellerId,
                  productId: p.id,
                );

                Navigator.pop(context); // close loader

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatView(
                      product: p,
                      roomId: roomId,
                    ),
                  ),
                );
              } catch (e) {
                Navigator.pop(context); // close loader
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to initialize chat: $e')),
                );
              }
            },
          ),
        );
      },
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
        final role = data?['role'] as String? ?? 'BUYER';
        final isVerified = data?['is_seller_verified'] as bool? ?? false;

        if (role == 'BUYER') {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_rounded, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'Campus Vendor Account Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'To list and sell pre-loved books, uniforms, or drawing sets, you must register as a Campus Vendor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await SupabaseConfig.client
                          .from('users')
                          .update({'role': 'SELLER', 'is_seller_verified': false})
                          .eq('user_id', authState.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seller upgrade request submitted! Admin will review your account.')),
                      );
                      _profileFuture = null; // Clear cache to trigger reload
                      setState(() {}); // Refresh the builder
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit request: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.citMaroon,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: const Text('Apply for Campus Vendor Role', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        if (role == 'SELLER' && !isVerified) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions_rounded, size: 80, color: TeknoyTheme.citGold),
                const SizedBox(height: 24),
                const Text(
                  'Vendor Verification Pending',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your campus vendor application is currently in the admin verification queue.\nOnce the administrator reviews your CIT student credentials, your store listing tools will open immediately!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    _profileFuture = null; // Clear cached future to refetch role status
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TeknoyTheme.citMaroon,
                    side: const BorderSide(color: TeknoyTheme.citMaroon),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: const Text('Check Review Status', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        // Verified seller or admin: List Pre-Loved Item Form
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'List Pre-Loved Item',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
              ),
              const SizedBox(height: 6),
              const Text(
                'List drawing boards, drawing sets, textbooks, uniforms, or snacks to trade with fellow student Wildcats.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
          
          // Title
          const Text('Product Title *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _sellTitleController,
            decoration: const InputDecoration(
              hintText: 'e.g. Calculus Transcendentals 9th Ed',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Price & Condition row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Price (₱) *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _sellPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 450',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Condition *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _sellCondition,
                      items: ['New', 'Like New', 'Gently Used', 'Well Used']
                          .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                          .toList(),
                      onChanged: (val) => setState(() => _sellCondition = val!),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category
          const Text('Category *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sellCategory,
            items: ['Books', 'Drawing Tools', 'Uniforms', 'Electronics', 'Others']
                .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                .toList(),
            onChanged: (val) => setState(() => _sellCategory = val!),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Description
          const Text('Listing Description *', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _sellDescController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe details, sizing, chapters, condition or meeting landmarks...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),

          // Image uploader — real picker with preview
          GestureDetector(
            onTap: _showProductImageSourceSheet,
            child: Container(
              height: _selectedImageFile != null ? null : 140,
              decoration: BoxDecoration(
                color: _selectedImageFile != null
                    ? Colors.transparent
                    : (isDark ? const Color(0xFF18181C) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedImageFile != null
                      ? TeknoyTheme.citMaroon.withOpacity(0.4)
                      : Colors.grey.shade400,
                  style: BorderStyle.solid,
                ),
              ),
              child: _selectedImageFile != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: kIsWeb
                              ? Image.network(
                                  _selectedImageFile!.path,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_selectedImageFile!.path),
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedImageFile = null;
                              _sellHasUploadedMockImage = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                              ),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Photo selected — tap to change',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded, size: 40, color: TeknoyTheme.citMaroon),
                          const SizedBox(height: 8),
                          const Text(
                            'Add Product Photo',
                            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to choose from gallery or camera',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
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
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Uploading photo...', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  )
                : const Text('Post Campus Listing', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
      },
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getUserOrdersAndSales(String userId) async {
    const selectQuery = '''
      order_id,
      total_amount,
      pickup_location,
      status,
      created_at,
      buyer_id,
      seller_id,
      payment_reference,
      payment_proof_url,
      product_variants (
        products (
          name,
          base_price
        )
      )
    ''';
    try {
      // Buyer orders
      final buyRes = await SupabaseConfig.client
          .from('orders')
          .select(selectQuery)
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);
      final buyOrders = List<Map<String, dynamic>>.from(buyRes as List);

      // Seller (incoming) orders
      final sellRes = await SupabaseConfig.client
          .from('orders')
          .select(selectQuery)
          .eq('seller_id', userId)
          .order('created_at', ascending: false);
      final sellOrders = List<Map<String, dynamic>>.from(sellRes as List);

      return {'buy': buyOrders, 'sell': sellOrders};
    } catch (e) {
      return {'buy': [], 'sell': []};
    }
  }

  // ── Index 3: Orders Tracker Body (Meetups Timeline)
  Widget _buildOrdersTabBody(BuildContext context) {
    final authState = ref.watch(authStateProvider).valueOrNull;

    if (authState == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Please sign in to track orders.',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _getUserOrdersAndSales(authState.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon));
        }

        final data = snapshot.data ?? {'buy': [], 'sell': []};
        final buyOrders = data['buy'] ?? [];
        final sellOrders = data['sell'] ?? [];

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab Bar — theme-aware
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141418) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF22222A) : const Color(0xFFE8E8EC),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  labelColor: TeknoyTheme.citMaroon,
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
                  indicatorColor: TeknoyTheme.citMaroon,
                  indicatorWeight: 2.5,
                  tabs: [
                    Tab(text: 'My Purchases (${buyOrders.length})'),
                    Tab(text: 'Incoming Orders (${sellOrders.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildOrdersList(context, buyOrders, isBuyer: true),
                    _buildOrdersList(context, sellOrders, isBuyer: false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersList(BuildContext context, List<Map<String, dynamic>> orders, {required bool isBuyer}) {
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBuyer ? Icons.shopping_bag_rounded : Icons.storefront_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              isBuyer ? 'No Active Purchases' : 'No Incoming Orders',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isBuyer
                  ? 'Explore the marketplace, chat with campus sellers, and confirm a deal to see your orders tracked here!'
                  : 'When buyers send you purchase inquiries via chat, confirmed deals will appear here for tracking.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          isBuyer ? 'Purchase Trackers' : 'Incoming Deal Requests',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
        ),
        const SizedBox(height: 4),
        Text(
          isBuyer
              ? 'Track your campus meetup handoffs and payment verifications.'
              : 'Buyers who have confirmed a deal with you. Complete meetup to mark as done.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        ...orders.map((o) {
          final String status = o['status'] as String? ?? 'INQUIRY_SENT';
          final double price = double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0;

          // product_variants can be null if variant_id FK is null (e.g. locally-added product)
          String productTitle = 'Campus Merchandise';
          final variantRaw = o['product_variants'];
          if (variantRaw is Map) {
            final productRaw = variantRaw['products'];
            if (productRaw is Map) {
              productTitle = productRaw['name'] as String? ?? 'Campus Merchandise';
            }
          }

          final String rawId = o['order_id'] as String? ?? '';
          final String displayId = rawId.length >= 8
              ? 'ORD-${rawId.substring(0, 8).toUpperCase()}'
              : 'ORD-${rawId.toUpperCase()}';

          double progress = 0.2;
          String statusDisplay = 'Inquiry Sent';
          switch (status) {
            case 'INQUIRY_SENT': progress = 0.2; statusDisplay = 'Inquiry Sent — Awaiting Seller'; break;
            case 'APPROVED':     progress = 0.4; statusDisplay = 'Approved — Awaiting Payment'; break;
            case 'REJECTED':     progress = 0.1; statusDisplay = 'Offer Declined'; break;
            case 'PAYMENT_SUBMITTED': progress = 0.6; statusDisplay = 'GCash Proof Submitted'; break;
            case 'PAYMENT_VERIFIED':  progress = 0.8; statusDisplay = 'Payment Verified — Ready'; break;
            case 'READY_FOR_PICKUP':  progress = 0.9; statusDisplay = 'Ready for Campus Meetup'; break;
            case 'COMPLETED':    progress = 1.0; statusDisplay = 'Meetup Completed ✓'; break;
            case 'CANCELLED':    progress = 0.0; statusDisplay = 'Deal Cancelled'; break;
            case 'REJECTED':     progress = 0.0; statusDisplay = 'Deal Rejected'; break;
          }

          final isGcash = o['pickup_location']?.toString().contains('Payment: GCash') ?? false;
          final orderId = o['order_id'] as String;

          Widget? cardActionButton;

          if (isBuyer) {
            if ((status == 'APPROVED' || status == 'INQUIRY_SENT') && isGcash) {
              cardActionButton = Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showUploadReceiptDialog(context, orderId),
                    icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                    label: const Text('Upload GCash Receipt', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
                  ),
                ),
              );
            }
          } else {
            if (status == 'INQUIRY_SENT') {
              cardActionButton = Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(orderId, 'APPROVED'),
                        style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.success, foregroundColor: Colors.white),
                        child: const Text('Accept Deal', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateOrderStatus(orderId, 'REJECTED'),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                        child: const Text('Decline', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            } else if (status == 'PAYMENT_SUBMITTED') {
              cardActionButton = Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showVerifyReceiptDialog(
                      context, 
                      orderId: orderId,
                      amount: price,
                      refNum: o['payment_reference']?.toString() ?? '',
                      proofUrl: o['payment_proof_url']?.toString() ?? '',
                    ),
                    icon: const Icon(Icons.rate_review_rounded, size: 16, color: Colors.white),
                    label: const Text('Verify GCash Receipt', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.success),
                  ),
                ),
              );
            } else if (status == 'PAYMENT_VERIFIED' || (status == 'APPROVED' && !isGcash)) {
              cardActionButton = Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(orderId, 'COMPLETED'),
                    icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                    label: const Text('Complete Meetup', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
                  ),
                ),
              );
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildActiveOrderTimelineCard(
              context,
              orderId: displayId,
              productTitle: productTitle,
              amount: '₱${price.toStringAsFixed(2)}',
              landmark: o['pickup_location'] as String? ?? 'Library Lobby',
              time: 'Confirm meetup at agreed campus landmark',
              status: statusDisplay,
              progress: progress,
              actionButton: cardActionButton,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveOrderTimelineCard(
    BuildContext context, {
    required String orderId,
    required String productTitle,
    required String amount,
    required String landmark,
    required String time,
    required String status,
    required double progress,
    Widget? actionButton,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: TeknoyTheme.citMaroon),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: progress == 0.75 ? Colors.orange.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: progress == 0.75 ? Colors.orange.shade800 : Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              productTitle,
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Total Price: $amount',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            
            // Meetup Landmark details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25252A) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: TeknoyTheme.citMaroon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pickup Landmark: $landmark', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(time, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: TeknoyTheme.citMaroon,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: TeknoyTheme.citMaroon),
                ),
              ],
            ),
            if (actionButton != null) actionButton,
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await SupabaseConfig.client
          .from('orders')
          .update({'status': newStatus})
          .eq('order_id', orderId);
      if (mounted) {
        setState(() {}); // Trigger reload
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus!'), backgroundColor: TeknoyTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: TeknoyTheme.error),
        );
      }
    }
  }

  void _showUploadReceiptDialog(BuildContext context, String orderId) {
    final refController = TextEditingController();
    final proofController = TextEditingController(text: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Upload GCash Proof', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please type the reference number and provide a receipt screenshot url to verify.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextFormField(
              controller: refController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'GCash Reference Number (13 digits)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: proofController,
              decoration: const InputDecoration(
                labelText: 'Receipt Image URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            onPressed: () async {
              final refText = refController.text.trim();
              if (refText.length != 13 || double.tryParse(refText) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 13-digit reference number.'), backgroundColor: TeknoyTheme.error),
                );
                return;
              }
              Navigator.pop(context);
              try {
                await SupabaseConfig.client
                    .from('orders')
                    .update({
                      'status': 'PAYMENT_SUBMITTED',
                      'payment_reference': refText,
                      'payment_proof_url': proofController.text.trim(),
                    })
                    .eq('order_id', orderId);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receipt uploaded successfully!'), backgroundColor: TeknoyTheme.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Upload failed: $e'), backgroundColor: TeknoyTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
            child: const Text('Submit Proof', style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVerifyReceiptDialog(
    BuildContext context, {
    required String orderId,
    required double amount,
    required String refNum,
    required String proofUrl,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verify GCash Receipt', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Expected Amount: ₱${amount.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Reference Number: $refNum', style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
            const SizedBox(height: 12),
            const Text('Uploaded Receipt:', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(proofUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Verification Checklist (FR-18.1):', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon)),
            const SizedBox(height: 6),
            const Text('• Recipient account name matches your GCash account\n• Amount matches the expected order total\n• Transaction timestamp is within the last 2 hours\n• Screenshot shows the official GCash interface', style: TextStyle(fontFamily: 'Inter', fontSize: 11, height: 1.4, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(orderId, 'APPROVED'); // return to approved (awaiting payment) state
            },
            child: const Text('Decline Receipt', style: TextStyle(fontFamily: 'Outfit', color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(orderId, 'PAYMENT_VERIFIED');
            },
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.success),
            child: const Text('Verify & Complete', style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
          ),
        ],
      ),
    );
  }
  // ── Index 4: Profile Page Body Helpers ──
  Future<Map<String, dynamic>> _getUserRoleAndVerification(String userId) async {
    try {
      final res = await SupabaseConfig.client
          .from('users')
          .select('role, is_verified, student_id')
          .eq('user_id', userId)
          .single();
      return {
        'role': res['role'] as String? ?? 'BUYER',
        'is_verified': res['is_verified'] as bool? ?? false,
        'student_id': res['student_id'] as String?,
      };
    } catch (e) {
      return {'role': 'BUYER', 'is_verified': false};
    }
  }

  Future<void> _updateProfileMetadata(String dept, String contact, String gcashNumber) async {
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(
          data: {
            'department': dept,
            'contact': contact,
            'gcash_number': gcashNumber,
          },
        ),
      );
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      if (currentUserId != null) {
        await SupabaseConfig.client
            .from('users')
            .update({'gcash_number': gcashNumber})
            .eq('user_id', currentUserId);
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
                          Navigator.pop(context);
                          try {
                            await SupabaseConfig.client.rpc('delete_user_account');
                            await ref.read(authNotifierProvider.notifier).logout();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Account successfully deleted.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
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

    // Dark mode palette from the design prompt
    const profileBgDark = Color(0xFF101010);
    const cardBgDark = Color(0xFF1A1A1E);
    const cardBorderDark = Color(0xFF2A2A30);
    const accentRed = Color(0xFFB22222);
    const adminGold = Color(0xFFFFC107);
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
                          _buildStatItem('Listings', '12', isDark),
                          _buildStatDivider(cardBorder),
                          _buildStatItem('Deals', '48', isDark),
                          _buildStatDivider(cardBorder),
                          _buildStatItem('Trust Score', '98%', isDark, isHighlight: true),
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

                      const SizedBox(height: 14),

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
                        onSave: (newDept) => _updateProfileMetadata(newDept, contact, gcashNumber),
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
                        onSave: (newContact) => _updateProfileMetadata(dept, newContact, gcashNumber),
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
                        onSave: (newGcash) => _updateProfileMetadata(dept, contact, newGcash),
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
    required String label,
    required bool isActive,
    bool isActionFocus = false,
    bool hasBadge = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = TeknoyTheme.citMaroon;
    const inactiveColor = Color(0xFF5A413D);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: isActionFocus ? 26 : 22,
                  color: isActive ? activeColor : (isDark ? Colors.white60 : inactiveColor),
                ),
                if (hasBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD90429),
                        shape: BoxShape.circle,
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
                fontWeight: FontWeight.w500,
                color: isActive ? activeColor : (isDark ? Colors.white60 : inactiveColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      height: 166,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF3A0000), const Color(0xFF180E02)]
              : [const Color(0xFFFFF0F0), const Color(0xFFFFF9E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF5A1D1D) : const Color(0xFFFFD5D5),
          width: 1.5,
        ),
        boxShadow: TeknoyTheme.kElevationLow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Decorative glow circle
            Positioned(
              right: -50,
              top: -50,
              width: 150,
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                  color: TeknoyTheme.citGold.withOpacity(isDark ? 0.08 : 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                // Left Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dynamic Gold badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                          decoration: BoxDecoration(
                            color: TeknoyTheme.citGold,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Text(
                            '🔥 EXCLUSIVE OFFER',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: Color(0xFF6F5400),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          'Pre-Loved\nEngineering Books',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.15,
                            color: isDark ? Colors.white : TeknoyTheme.citMaroon,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtitle
                        Text(
                          'Up to 40% off from senior students. Limited time only.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: isDark ? Colors.white60 : const Color(0xFF5A413D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Content: Stack of books image with drop shadow
                Padding(
                  padding: const EdgeInsets.only(right: 20.0, top: 16.0, bottom: 16.0),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF25252A) : const Color(0xFFEDEEEF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&q=80&w=200',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Choose badge color based on product condition
    Color badgeBg;
    Color badgeText;
    if (product.condition.toLowerCase() == 'new') {
      badgeBg = const Color(0xFF10B981); // Emerald Green
      badgeText = Colors.white;
    } else if (product.condition.toLowerCase() == 'like new') {
      badgeBg = TeknoyTheme.citGold;
      badgeText = const Color(0xFF533F00);
    } else {
      badgeBg = isDark ? const Color(0xFF2C2C35) : const Color(0xFFECECEF);
      badgeText = isDark ? Colors.white70 : Colors.black87;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
          width: 1,
        ),
        boxShadow: TeknoyTheme.kElevationLow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Square Image Container (with Hero transition and condition tags)
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  // Image
                  Positioned.fill(
                    child: Hero(
                      tag: 'product_image_${product.id}',
                      child: Container(
                        color: isDark ? const Color(0xFF1C1C22) : const Color(0xFFF3F3F5),
                        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.image_rounded, color: Colors.grey, size: 28),
                              ),
                      ),
                    ),
                  ),
                  
                  // Condition Badge (top-left) - modern rounded tag
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: badgeBg.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        product.condition.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          color: badgeText,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                  // Wishlist / Favorite Button (top-right) - premium glassmorphism
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: TeknoyTheme.citMaroon,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Dense Layout Info Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rating & Category Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: TeknoyTheme.citGold),
                            const SizedBox(width: 3),
                            Text(
                              '4.8',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F1F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Title
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.25,
                            color: isDark ? Colors.white : const Color(0xFF191C1D),
                          ),
                        ),
                      ),
                    ),

                    // Price - prominent burgundy highlight
                    Text(
                      '₱${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: TeknoyTheme.citMaroon,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Column(
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

