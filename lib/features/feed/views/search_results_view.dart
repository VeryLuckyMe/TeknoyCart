import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_detail_view.dart';
import 'package:teknoycart/features/feed/views/seller_storefront_view.dart';
import 'package:teknoycart/features/feed/views/widgets/product_filter_sheet.dart';
import 'package:teknoycart/core/services/search_history_service.dart';
import 'package:teknoycart/features/feed/views/widgets/search_history_chips.dart';

class SearchResultsView extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchResultsView({
    super.key,
    required this.initialQuery,
  });

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  late TextEditingController _searchController;
  late String _activeQuery;

  @override
  void initState() {
    super.initState();
    _activeQuery = widget.initialQuery;
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(searchHistoryProvider.notifier).addQuery(widget.initialQuery);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
    }
    setState(() {
      _activeQuery = trimmed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsAsync = ref.watch(productsListProvider);
    final storesAsync = ref.watch(matchingStoresProvider(_activeQuery));
    final selectedCondition = ref.watch(selectedConditionProvider);
    final minPrice = ref.watch(minPriceProvider);
    final maxPrice = ref.watch(maxPriceProvider);
    final sort = ref.watch(sortOptionProvider);
    final hasAdvancedFilters =
        selectedCondition != 'All' || minPrice != null || maxPrice != null;

    const bgColorDark = TeknoyTheme.darkBg;
    const cardBgDark = TeknoyTheme.darkSurfaceHigh;
    const cardBorderDark = Color(0xFF262634);

    final bgColor = isDark ? bgColorDark : TeknoyTheme.lightBgAlt;
    final cardBg = isDark ? cardBgDark : Colors.white;
    final cardBorder = isDark ? cardBorderDark : const Color(0xFFE8E8F0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 50.0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181C) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? TeknoyTheme.darkDivider : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _submitSearch,
              onSubmitted: _submitSearch,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search products or stores...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: isDark ? Colors.white38 : TeknoyTheme.lightTextMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: TeknoyTheme.citMaroon),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _submitSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.22, 1.0],
            colors: isDark
                ? [
                    const Color(0xFF221115),
                    const Color(0xFF140D10),
                    TeknoyTheme.darkBg,
                  ]
                : [
                    const Color(0xFFFFEDE1),
                    const Color(0xFFFFF7F2),
                    TeknoyTheme.lightBgAlt,
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
                  sliver: SliverList.list(
                    children: [
                      // ── Section 0: Recent Search History Chips (visible when query is empty)
                      if (_activeQuery.isEmpty)
                        SearchHistoryChips(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          onSelectQuery: (selected) {
                            _searchController.text = selected;
                            _submitSearch(selected);
                          },
                        ),

                      // ── Section 1: Stores Container
                      Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront_rounded, size: 18, color: TeknoyTheme.citMaroon),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Matching Stores',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  storesAsync.when(
                    data: (stores) {
                      if (stores.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? TeknoyTheme.darkBorder : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  size: 26,
                                  color: isDark ? Colors.white30 : TeknoyTheme.lightTextMuted,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _activeQuery.isEmpty
                                      ? 'Type a keyword above to find campus stores.'
                                      : 'No matching campus stores found for "$_activeQuery".',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: isDark ? Colors.white60 : TeknoyTheme.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: stores.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final store = stores[index];
                            return Container(
                              width: 220,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                                        child: const Icon(Icons.store_rounded, color: TeknoyTheme.citMaroon, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              store.storeName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Owner: ${store.ownerName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11,
                                                color: isDark ? Colors.white60 : TeknoyTheme.lightTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SellerStorefrontView(
                                              sellerId: store.sellerId,
                                              sellerName: store.ownerName,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: TeknoyTheme.citMaroon,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                      label: const Text(
                                        'Visit Store',
                                        style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon)),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  // ── Section 2: Products Container
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.grid_view_rounded, size: 18, color: TeknoyTheme.citMaroon),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Matching Products',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Filters',
                        onPressed: () => showProductFilterSheet(context, ref),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.tune_rounded, size: 20, color: TeknoyTheme.citMaroon),
                            if (hasAdvancedFilters)
                              Positioned(
                                top: -1,
                                right: -2,
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
                      PopupMenuButton<ProductSortOption>(
                        tooltip: 'Sort products',
                        onSelected: (val) =>
                            ref.read(sortOptionProvider.notifier).state = val,
                        itemBuilder: (context) => ProductSortOption.values
                            .map((option) => PopupMenuItem(
                                  value: option,
                                  child: Text(
                                    option.label,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C22) : const Color(0xFFEFEFF3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sort == ProductSortOption.recommended ? 'Sort' : sort.label,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 32.0),
                  sliver: productsAsync.when(
                    data: (allProducts) {
                      final matchingProducts = applyProductFilters(
                        allProducts,
                        search: _activeQuery,
                        category: 'All', // Search spans every category
                        condition: selectedCondition,
                        minPrice: minPrice,
                        maxPrice: maxPrice,
                        sort: sort,
                      );

                      if (matchingProducts.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? TeknoyTheme.darkBorder : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: isDark ? Colors.white30 : TeknoyTheme.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _activeQuery.isEmpty
                                    ? 'No products available'
                                    : 'No products match "$_activeQuery"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try searching for uniforms, calculus books, or engineering tools.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : TeknoyTheme.lightTextSecondary,
                                ),
                              ),
                              if (_activeQuery.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    _submitSearch('');
                                  },
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  label: const Text(
                                    'Clear Search',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: TeknoyTheme.citMaroon,
                                    side: const BorderSide(color: TeknoyTheme.citMaroon),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ],
                              SearchHistoryChips(
                                padding: const EdgeInsets.only(top: 18.0),
                                onSelectQuery: (selected) {
                                  _searchController.text = selected;
                                  _submitSearch(selected);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                      }

                      return SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: matchingProducts.length,
                        itemBuilder: (context, index) {
                          final product = matchingProducts[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailView(product: product),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Image.network(
                                            product.imageUrl ?? '',
                                            semanticLabel: 'Photo of ${product.title}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: isDark ? const Color(0xFF222228) : const Color(0xFFF1F5F9),
                                              child: Icon(Icons.image_not_supported_rounded, color: isDark ? Colors.white24 : Colors.grey.shade400),
                                            ),
                                          ),
                                        ),
                                        if (product.sellerStoreName != null && product.sellerStoreName!.trim().isNotEmpty)
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.storefront_rounded, size: 10, color: TeknoyTheme.citGold),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    product.sellerStoreName!,
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                                                ),
                                              ),
                                              if (product.categoryAttributes.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Wrap(
                                                    spacing: 4,
                                                    runSpacing: 2,
                                                    children: product.categoryAttributes
                                                        .take(2)
                                                        .map((attr) => Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                              decoration: BoxDecoration(
                                                                color: isDark
                                                                    ? Colors.white.withValues(alpha: 0.08)
                                                                    : const Color(0xFFF1F5F9),
                                                                borderRadius: BorderRadius.circular(5),
                                                                border: Border.all(
                                                                  color: isDark
                                                                      ? Colors.white.withValues(alpha: 0.1)
                                                                      : const Color(0xFFE2E8F0),
                                                                  width: 0.5,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                '${attr.name}: ${attr.value}',
                                                                style: TextStyle(
                                                                  fontFamily: 'Inter',
                                                                  fontSize: 8.5,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                                ),
                                                              ),
                                                            ))
                                                        .toList(),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            '₱${product.price.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: TeknoyTheme.citMaroon,
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
                        },
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon)),
                      ),
                    ),
                    error: (err, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text('Error loading products: $err')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
