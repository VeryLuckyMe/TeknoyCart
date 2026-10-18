import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';

/// Shared filter + sort bottom sheet used by both the Browse tab and the
/// search results screen, so the two surfaces stay consistent.
///
/// Edits are staged locally and committed only when "Apply Filters" is
/// tapped — "Reset" clears the staged values (it does not commit).
Future<void> showProductFilterSheet(BuildContext context, WidgetRef ref) {
  final currentCondition = ref.read(selectedConditionProvider);
  final currentMin = ref.read(minPriceProvider);
  final currentMax = ref.read(maxPriceProvider);
  final currentSort = ref.read(sortOptionProvider);

  final minController = TextEditingController(text: currentMin?.toString() ?? '');
  final maxController = TextEditingController(text: currentMax?.toString() ?? '');
  String tempCondition = currentCondition;
  ProductSortOption tempSort = currentSort;

  return showModalBottomSheet(
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
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                        color: Colors.grey.withValues(alpha: 0.3),
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
                          setModalState(() {
                            tempCondition = 'All';
                            tempSort = ProductSortOption.recommended;
                          });
                        },
                        child: const Text(
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

                  // ── Sort By ──
                  const Text(
                    'Sort By',
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
                    children: ProductSortOption.values.map((option) {
                      final isSelected = tempSort == option;
                      return ChoiceChip(
                        label: Text(
                          option.label,
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
                            setModalState(() => tempSort = option);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Condition ──
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

                  // ── Price Range ──
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
                        ref.read(sortOptionProvider.notifier).state = tempSort;
                        Navigator.pop(context);
                        minController.dispose();
                        maxController.dispose();
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
            ),
          );
        },
      );
    },
  );
}
