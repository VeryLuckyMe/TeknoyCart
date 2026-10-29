import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme.dart';
import '../../providers/product_provider.dart';
import '../product_detail_view.dart';
import '../search_results_view.dart';
import '../widgets/feed_product_card.dart';
import '../widgets/product_card_skeleton.dart';
import '../widgets/product_filter_sheet.dart';

/// Modular Browse Tab for ProductDiscoveryFeedView (HIGH-04).
class BrowseTab extends ConsumerStatefulWidget {
  const BrowseTab({super.key});

  @override
  ConsumerState<BrowseTab> createState() => _BrowseTabState();
}

class _SpotlightSlideData {
  final String badge;
  final IconData badgeIcon;
  final String title;
  final String defaultSubtitle;
  final String activeSubtitle;
  final String category;
  final IconData watermarkIcon;
  final List<Color> gradientColors;

  const _SpotlightSlideData({
    required this.badge,
    required this.badgeIcon,
    required this.title,
    required this.defaultSubtitle,
    required this.activeSubtitle,
    required this.category,
    required this.watermarkIcon,
    required this.gradientColors,
  });
}

class _BrowseTabState extends ConsumerState<BrowseTab> {
  final PageController _spotlightController = PageController();
  int _activeSpotlightPage = 0;

  static const List<_SpotlightSlideData> _spotlightSlides = [
    _SpotlightSlideData(
      badge: 'CAMPUS SPOTLIGHT',
      badgeIcon: Icons.bolt_rounded,
      title: 'Save 50% on Engineering Drawing Boards',
      defaultSubtitle: 'Verified student listings from CEA graduates • Tap to filter',
      activeSubtitle: 'Showing verified Drawing Tools • Tap to view all',
      category: 'Drawing Tools',
      watermarkIcon: Icons.architecture_rounded,
      gradientColors: [
        TeknoyTheme.citMaroon,
        Color(0xFFA01A26),
      ],
    ),
    _SpotlightSlideData(
      badge: 'TEXTBOOK DEALS',
      badgeIcon: Icons.local_fire_department_rounded,
      title: 'Up to 40% Off Senior Engineering Books',
      defaultSubtitle: 'Pre-loved textbooks from CIT-U upperclassmen • Tap to filter',
      activeSubtitle: 'Showing verified Books • Tap to view all',
      category: 'Books',
      watermarkIcon: Icons.menu_book_rounded,
      gradientColors: [
        Color(0xFF5C0A14),
        Color(0xFF8C1D2C),
      ],
    ),
    _SpotlightSlideData(
      badge: 'WILDCAT ESSENTIALS',
      badgeIcon: Icons.verified_rounded,
      title: 'Official CIT-U Uniforms & Lanyards',
      defaultSubtitle: 'PE shirts, department polos & campus gear • Tap to filter',
      activeSubtitle: 'Showing verified Uniforms • Tap to view all',
      category: 'Uniforms',
      watermarkIcon: Icons.checkroom_rounded,
      gradientColors: [
        Color(0xFF4A0E17),
        Color(0xFF7A1624),
      ],
    ),
  ];

  @override
  void dispose() {
    _spotlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final filteredProducts = ref.watch(filteredProductsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedCondition = ref.watch(selectedConditionProvider);
    final minPrice = ref.watch(minPriceProvider);
    final maxPrice = ref.watch(maxPriceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAdvancedFilters =
        selectedCondition != 'All' || minPrice != null || maxPrice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input Deck with Filter Tune Button (Compact Headroom)
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 2.0, 16.0, 6.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181C) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? TeknoyTheme.darkDivider : const Color(0xFFE0E0E0),
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
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF191C1D),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search textbooks, uniforms, snacks...',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        color: isDark ? Colors.white38 : TeknoyTheme.citMaroonMuted.withValues(alpha: 0.7),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: TeknoyTheme.citMaroonMuted),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear_rounded, size: 18, color: TeknoyTheme.citMaroonMuted),
                              onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: hasAdvancedFilters ? 'Filters, active' : 'Filters',
                child: GestureDetector(
                  onTap: () => showProductFilterSheet(context, ref),
                  child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181C) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? TeknoyTheme.darkDivider : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: TeknoyTheme.citMaroon,
                        ),
                      ),
                      // Gold dot: signals condition/price filters are active
                      if (hasAdvancedFilters)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: TeknoyTheme.citGold,
                              shape: BoxShape.circle,
                            ),
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

        // Wildcat Campus Spotlight Carousel (Compact 86px Anti-Forehead Carousel with Search Auto-Collapse)
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: searchQuery.trim().isNotEmpty
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 86,
                      child: PageView.builder(
                        key: const Key('browse_spotlight_pageview'),
                        controller: _spotlightController,
                        itemCount: _spotlightSlides.length,
                        onPageChanged: (index) {
                          setState(() => _activeSpotlightPage = index);
                        },
                        itemBuilder: (context, index) {
                          final slide = _spotlightSlides[index];
                          final isSpotlightActive = selectedCategory == slide.category;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(selectedCategoryProvider.notifier).state =
                                      isSpotlightActive ? 'All' : slide.category;
                                },
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: slide.gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.22),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        right: -10,
                                        bottom: -14,
                                        child: Opacity(
                                          opacity: 0.14,
                                          child: Icon(
                                            slide.watermarkIcon,
                                            size: 110,
                                            color: TeknoyTheme.citGold,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: TeknoyTheme.citGold,
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        slide.badgeIcon,
                                                        size: 10,
                                                        color: TeknoyTheme.citMaroon,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        slide.badge,
                                                        style: const TextStyle(
                                                          fontFamily: 'Outfit',
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.w900,
                                                          color: TeknoyTheme.citMaroon,
                                                          letterSpacing: 0.6,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.22),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        isSpotlightActive ? 'Filtering' : 'View Deals',
                                                        style: const TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      const Icon(
                                                        Icons.arrow_forward_ios_rounded,
                                                        size: 8,
                                                        color: TeknoyTheme.citGold,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              slide.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isSpotlightActive
                                                  ? slide.activeSubtitle
                                                  : slide.defaultSubtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 10.5,
                                                color: Colors.white.withValues(alpha: 0.82),
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
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_spotlightSlides.length, (i) {
                        final isActive = i == _activeSpotlightPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          height: 4,
                          width: isActive ? 14 : 5,
                          decoration: BoxDecoration(
                            color: isActive
                                ? TeknoyTheme.citGold
                                : (isDark ? Colors.white24 : TeknoyTheme.citMaroon.withValues(alpha: 0.25)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
        ),

        // Horizontal Category Pills (Compact 34px)
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedCategoryProvider.notifier).state = cat;
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TeknoyTheme.citMaroon
                        : (isDark ? TeknoyTheme.darkSurfaceRaised : Colors.white),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: isSelected
                          ? TeknoyTheme.citMaroon
                          : (isDark ? const Color(0xFF2C2C3A) : const Color(0xFFE2E8F0)),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: TeknoyTheme.citMaroon.withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),

        // Products list view / Canvas
        Expanded(
          child: productsAsync.when(
            data: (_) {
              if (filteredProducts.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isDark ? TeknoyTheme.darkCardBorder : TeknoyTheme.lightSurfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.search_off_rounded,
                            size: 36,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items match your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF191C1D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try clearing your search terms or selecting another category.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                            ref.read(selectedCategoryProvider.notifier).state = 'All';
                            ref.read(selectedConditionProvider.notifier).state = 'All';
                            ref.read(minPriceProvider.notifier).state = null;
                            ref.read(maxPriceProvider.notifier).state = null;
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'Reset All Filters',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TeknoyTheme.citMaroon,
                            side: const BorderSide(color: TeknoyTheme.citMaroon, width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: TeknoyTheme.citMaroon,
                onRefresh: () => ref.read(productsListNotifierProvider.notifier).refresh(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
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
            loading: () => const ProductGridSkeleton(),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: TeknoyTheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_off_rounded, size: 36, color: TeknoyTheme.error),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Interrupted',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF191C1D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unable to load campus listings right now. Please check your network connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => ref.read(productsListNotifierProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Retry Connection',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TeknoyTheme.citMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

}
