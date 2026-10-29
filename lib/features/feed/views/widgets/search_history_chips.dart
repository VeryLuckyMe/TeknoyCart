import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/services/search_history_service.dart';

/// Interactive, horizontal chip deck displaying the student's recent search keywords.
/// Supports tapping to re-run queries, individual item removal, and "Clear All".
class SearchHistoryChips extends ConsumerWidget {
  final void Function(String query)? onSelectQuery;
  final EdgeInsetsGeometry padding;
  final bool showHeader;

  const SearchHistoryChips({
    super.key,
    this.onSelectQuery,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                ),
                const SizedBox(width: 6),
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => ref.read(searchHistoryProvider.notifier).clearAll(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final query = history[index];
                return _buildSearchChip(context, ref, query, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchChip(BuildContext context, WidgetRef ref, String query, bool isDark) {
    final chipBg = isDark
        ? const Color(0xFF26191C)
        : TeknoyTheme.citMaroon.withValues(alpha: 0.06);
    final borderColor = isDark
        ? TeknoyTheme.citMaroon.withValues(alpha: 0.35)
        : TeknoyTheme.citMaroon.withValues(alpha: 0.18);

    return Container(
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => onSelectQuery?.call(query),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 13,
                  color: isDark ? TeknoyTheme.citGold.withValues(alpha: 0.8) : TeknoyTheme.citMaroon,
                ),
                const SizedBox(width: 5),
                Text(
                  query,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  key: ValueKey('delete_chip_$query'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(searchHistoryProvider.notifier).removeQuery(query),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
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

