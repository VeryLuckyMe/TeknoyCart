import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/chat/services/chat_service.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/chat/services/presence_service.dart';

/// Real-Time Chat Inbox listing active negotiations.
/// Refactored to eliminate container bloat with a clean, borderless, airy layout
/// inspired by modern mobile messaging standards and CIT-U brand aesthetics.
class InboxView extends ConsumerStatefulWidget {
  final bool embedded;
  final void Function(int tabIndex)? onNavigateTab;

  const InboxView({
    super.key,
    this.embedded = false,
    this.onNavigateTab,
  });

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> {
  static List<Map<String, dynamic>>? _cachedChatRooms;
  static String? _cachedChatUserId;

  bool _isLoading = true;
  List<Map<String, dynamic>> _chatRooms = [];
  String? _errorMessage;
  Timer? _presenceRefreshTimer;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadChatRooms();

    // Auto-trigger immediate heartbeat for current user when inbox view is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(authStateProvider).valueOrNull;
      if (currentUser != null) {
        PresenceService.instance.startHeartbeat(currentUser.id);
      }
    });

    // Refresh presence indicators every 15 seconds so online/offline updates live
    _presenceRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _presenceRefreshTimer?.cancel();
    super.dispose();
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.month}/${dt.day}';
    }
  }

  Future<void> _loadChatRooms({bool forceRefresh = false}) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please log in to view active chats.";
      });
      return;
    }

    // Instant zero-latency render from memory cache
    if (!forceRefresh && _cachedChatRooms != null && _cachedChatUserId == currentUser.id) {
      setState(() {
        _chatRooms = _cachedChatRooms!;
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = _chatRooms.isEmpty;
      _errorMessage = null;
    });

    try {
      final client = SupabaseConfig.client;

      // Query active chat rooms where the user is either the buyer or the seller
      final response = await client
          .from('chats')
          .select('''
            chat_id,
            buyer_id,
            seller_id,
            deleted_by_buyer,
            deleted_by_seller,
            inquiries (
              inquiry_id,
              product_id,
              products (
                product_id,
                name,
                base_price,
                description,
                status,
                seller_id,
                product_images (
                  image_url
                )
              )
            )
          ''')
          .or('buyer_id.eq.${currentUser.id},seller_id.eq.${currentUser.id}');

      final chatData = response as List<dynamic>;

      // 1. Filter valid rooms first (skipping deleted rooms & rooms with missing product data)
      final validRooms = <Map<String, dynamic>>[];
      for (final raw in chatData) {
        final rawRoom = raw as Map<String, dynamic>;
        final String buyerId = rawRoom['buyer_id'] as String;
        final String sellerId = rawRoom['seller_id'] as String;
        final bool deletedByBuyer = rawRoom['deleted_by_buyer'] as bool? ?? false;
        final bool deletedBySeller = rawRoom['deleted_by_seller'] as bool? ?? false;

        // Skip chat rooms soft-deleted by current user
        if (currentUser.id == buyerId && deletedByBuyer) continue;
        if (currentUser.id == sellerId && deletedBySeller) continue;

        final inquiry = rawRoom['inquiries'];
        if (inquiry == null) continue;

        final productData = inquiry['products'];
        if (productData == null) continue;

        validRooms.add(rawRoom);
      }

      // 2. Batch fetch participant details in a single query
      final otherUserIds = validRooms.map((r) {
        final buyerId = r['buyer_id'] as String;
        final sellerId = r['seller_id'] as String;
        return currentUser.id == buyerId ? sellerId : buyerId;
      }).toSet().toList();

      final Map<String, String> userNames = {};
      if (otherUserIds.isNotEmpty) {
        try {
          final usersRes = await client
              .from('users')
              .select('user_id, full_name')
              .filter('user_id', 'in', otherUserIds);
          for (final u in (usersRes as List)) {
            userNames[u['user_id'].toString()] = u['full_name'] as String? ?? 'Wildcat Student';
          }
        } catch (_) {}
      }

      // 3. Fetch latest messages concurrently in parallel
      final messageFutures = validRooms.map((r) {
        final chatId = r['chat_id'] as String;
        return client
            .from('messages')
            .select('content, sent_at, sender_id, is_read')
            .eq('chat_id', chatId)
            .order('sent_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .catchError((_) => null);
      }).toList();

      final messageResults = await Future.wait(messageFutures);

      final List<Map<String, dynamic>> rooms = [];
      for (int i = 0; i < validRooms.length; i++) {
        final rawRoom = validRooms[i];
        final String chatId = rawRoom['chat_id'] as String;
        final String buyerId = rawRoom['buyer_id'] as String;
        final String sellerId = rawRoom['seller_id'] as String;
        final productData = rawRoom['inquiries']['products'];

        final otherUserId = currentUser.id == buyerId ? sellerId : buyerId;
        final otherUserName = userNames[otherUserId] ?? 'Wildcat Student';

        final lastMsgRes = messageResults[i];
        final String lastMessage = lastMsgRes != null
            ? (lastMsgRes['content'] as String? ?? 'No messages yet')
            : 'No messages yet';

        final String? sentAtStr = lastMsgRes != null ? lastMsgRes['sent_at'] as String? : null;
        final DateTime? lastMessageTime = sentAtStr != null ? DateTime.tryParse(sentAtStr) : null;
        final String? msgSenderId = lastMsgRes != null ? lastMsgRes['sender_id'] as String? : null;
        final bool isRead = lastMsgRes != null ? (lastMsgRes['is_read'] as bool? ?? true) : true;
        final bool isUnread = !isRead && msgSenderId != null && msgSenderId != currentUser.id;

        // Parse Product
        final images = productData['product_images'] as List<dynamic>?;
        final imageUrl = (images != null && images.isNotEmpty)
            ? images[0]['image_url'] as String?
            : 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=300&auto=format&fit=crop';

        final product = Product(
          id: productData['product_id'] as String,
          title: productData['name'] as String? ?? 'Campus Product',
          price: (productData['base_price'] is num)
              ? (productData['base_price'] as num).toDouble()
              : double.tryParse(productData['base_price'].toString()) ?? 0.0,
          category: 'Campus Gear',
          condition: 'Like New',
          imageUrl: imageUrl,
          sellerId: sellerId,
          description: productData['description'] as String? ?? '',
          createdAt: DateTime.now(),
        );

        rooms.add({
          'chat_id': chatId,
          'buyer_id': buyerId,
          'seller_id': sellerId,
          'other_user_id': otherUserId,
          'other_user_name': otherUserName,
          'other_user_role': currentUser.id == buyerId ? 'Seller' : 'Buyer',
          'last_message': lastMessage,
          'last_message_time': lastMessageTime,
          'is_unread': isUnread,
          'product': product,
        });
      }

      // Sort chats by most recent message first
      rooms.sort((a, b) {
        final timeA = a['last_message_time'] as DateTime?;
        final timeB = b['last_message_time'] as DateTime?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        _cachedChatRooms = rooms;
        _cachedChatUserId = currentUser.id;
        setState(() {
          _chatRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load chats: $e";
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    switch (_selectedFilter) {
      case 'Unread':
        return _chatRooms.where((r) => r['is_unread'] == true).toList();
      case 'Deals':
        return _chatRooms.where((r) {
          final msg = (r['last_message'] as String? ?? '').toLowerCase();
          return msg.contains('deal') || msg.contains('offer') || msg.contains('₱');
        }).toList();
      case 'Buying':
        return _chatRooms.where((r) => r['other_user_role'] == 'Seller').toList();
      case 'Selling':
        return _chatRooms.where((r) => r['other_user_role'] == 'Buyer').toList();
      case 'All':
      default:
        return _chatRooms;
    }
  }

  Widget _buildFilterBar(bool isDark) {
    final filters = ['All', 'Unread', 'Deals', 'Buying', 'Selling'];
    return Padding(
      padding: const EdgeInsets.only(top: 2.0, bottom: 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = filter);
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TeknoyTheme.citMaroon
                        : (isDark ? TeknoyTheme.darkSurfaceRaised : Colors.white),
                    borderRadius: BorderRadius.circular(24),
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
                    filter,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minimal 3D Speech Bubbles Illustration
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TeknoyTheme.citGold.withValues(alpha: isDark ? 0.2 : 0.15),
                    TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.05 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 18,
                    left: 18,
                    child: Container(
                      width: 44,
                      height: 38,
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citMaroon,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    right: 18,
                    child: Container(
                      width: 38,
                      height: 32,
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citGold,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TeknoyTheme.citGold.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: Color(0xFF4A3800),
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _selectedFilter == 'Unread'
                  ? 'No unread messages'
                  : _selectedFilter == 'Deals'
                      ? 'No active deal offers'
                      : 'No conversations yet',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All'
                  ? 'Ask about textbooks, drawing tools, or uniforms directly with CIT-U student peers.'
                  : 'Chats matching this filter will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark ? Colors.white54 : TeknoyTheme.lightTextSecondary,
                height: 1.4,
              ),
            ),
            if (_selectedFilter == 'All') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onNavigateTab?.call(0);
                },
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text('Explore Campus Listings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.citMaroon,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> room, bool isDark) {
    final Product product = room['product'];
    final String lastMsg = room['last_message'] as String? ?? '';
    final DateTime? lastMsgTime = room['last_message_time'] as DateTime?;
    final bool isUnread = room['is_unread'] == true;
    final otherUserId = room['other_user_id'] as String;
    final otherUserName = room['other_user_name'] as String;
    final otherUserRole = room['other_user_role'] as String;

    final isGcashProof = lastMsg.contains('[GCASH_RECEIPT_PROOF]');
    final isAccepted = lastMsg == 'Offer Accepted!' ||
        lastMsg.contains('Deal! 🤝') ||
        lastMsg.contains('Deal Accepted');
    final isOffer = lastMsg.startsWith('Can we agree on ₱') || lastMsg.contains('? Deal?');

    // Muted preview styles
    Color previewColor = isDark ? Colors.white60 : TeknoyTheme.lightTextSecondary;
    FontWeight previewWeight = FontWeight.normal;
    String displayText = lastMsg;

    if (isGcashProof) {
      previewColor = Colors.blue;
      previewWeight = FontWeight.w600;
      displayText = 'GCash Receipt Attached';
    } else if (isAccepted) {
      previewColor = TeknoyTheme.success;
      previewWeight = FontWeight.w600;
      displayText = 'Deal Accepted! Ready for Checkout';
    } else if (isOffer) {
      previewColor = TeknoyTheme.warningDark;
      previewWeight = FontWeight.w600;
      displayText = 'Tawad Offer: $lastMsg';
    }

    // Soft warm tint for unread chats (matching reference mockup)
    final rowBgColor = isUnread
        ? (isDark ? const Color(0xFF1E1215) : Colors.white.withValues(alpha: 0.85))
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: rowBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          hoverColor: isDark
              ? TeknoyTheme.darkHover
              : Colors.white,
          highlightColor: isDark
              ? const Color(0xFF262632)
              : Colors.white,
          splashColor: isDark
              ? TeknoyTheme.citMaroon.withValues(alpha: 0.15)
              : TeknoyTheme.citMaroon.withValues(alpha: 0.04),
          onTap: () {
            HapticFeedback.lightImpact();

            // 1. Optimistically clear unread badge in memory immediately
            setState(() {
              room['is_unread'] = false;
            });
            if (_cachedChatRooms != null) {
              for (final r in _cachedChatRooms!) {
                if (r['chat_id'] == room['chat_id']) {
                  r['is_unread'] = false;
                }
              }
            }

            // 2. Mark messages as read in Supabase
            final currentUserId = ref.read(authStateProvider).valueOrNull?.id ?? SupabaseConfig.client.auth.currentUser?.id;
            if (currentUserId != null) {
              ChatService().markMessagesAsRead(
                roomId: room['chat_id'] as String,
                currentUserId: currentUserId,
              );
            }

            // 3. Navigate to chat and force refresh when popping back
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatView(
                  product: product,
                  roomId: room['chat_id'] as String,
                ),
              ),
            ).then((_) => _loadChatRooms(forceRefresh: true));
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showDeleteChatDialog(context, room['chat_id'] as String, otherUserName);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Clean Avatar with Presence Dot
                FutureBuilder<bool>(
                  future: PresenceService.isUserOnline(otherUserId),
                  builder: (context, snapshot) {
                    final bool isUserOnline = snapshot.data ?? false;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(product.imageUrl ?? ''),
                          backgroundColor: isDark
                              ? TeknoyTheme.darkCardBorder
                              : const Color(0xFFEDEEEF),
                        ),
                        if (isUserOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: TeknoyTheme.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isUnread
                                      ? (isDark
                                          ? const Color(0xFF1E1215)
                                          : const Color(0xFFFFF7F0))
                                      : (isDark
                                          ? TeknoyTheme.darkBg
                                          : Colors.white),
                                  width: 2.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 14),

                // Name, Product Context & Last Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Name + Optional Role Pill
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    otherUserName,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.5,
                                      color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (otherUserRole == 'Seller') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.25 : 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Seller',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: TeknoyTheme.citMaroon,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(lastMsgTime),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              color: isUnread
                                  ? (isDark ? const Color(0xFFFF8585) : const Color(0xFFEA580C))
                                  : (isDark ? Colors.white38 : TeknoyTheme.lightTextMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Item name subtle text
                      Text(
                        'Item: ${product.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : TeknoyTheme.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Bottom Row: Message Preview + Unread Counter Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: isUnread ? (isDark ? Colors.white : const Color(0xFF1E293B)) : previewColor,
                                fontWeight: isUnread ? FontWeight.w600 : previewWeight,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEA580C), // Warm Wildcat orange
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '1',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
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
  }

  Widget _buildInboxBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredRooms;

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          // Minimalist, borderless category filter bar
          _buildFilterBar(isDark),

          // Main Conversation Stream
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Inter', color: Colors.grey),
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? _buildEmptyState(isDark)
                        : RefreshIndicator(
                            onRefresh: () => _loadChatRooms(forceRefresh: true),
                            color: TeknoyTheme.citMaroon,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildChatItem(filtered[index], isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog(BuildContext context, String chatId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Conversation?',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete your conversation with $userName? This action only clears it for you.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final chatService = ChatService();
                await chatService.softDeleteChatRoom(chatId);
                await _loadChatRooms(forceRefresh: true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete chat: $e')),
                  );
                }
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TeknoyTheme.citMaroon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildInboxBody(context);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBgAlt,
      appBar: AppBar(
        toolbarHeight: 46.0,
        title: const Text(
          'Chats',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadChatRooms(forceRefresh: true),
            tooltip: 'Refresh',
          ),
        ],
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
            padding: const EdgeInsets.only(top: 46.0),
            child: _buildInboxBody(context),
          ),
        ),
      ),
    );
  }
}
