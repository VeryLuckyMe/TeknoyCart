import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/chat/services/chat_service.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/chat/services/presence_service.dart';

/// Real-Time Chat Inbox listing active negotiations.
/// Enables seamless account-to-account conversations for both buyers and sellers.
class InboxView extends ConsumerStatefulWidget {
  final bool embedded;
  const InboxView({super.key, this.embedded = false});

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

      // 2. Batch fetch participant details in a single query instead of N serial queries
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
            .select('content, sent_at')
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

        // Parse Product
        final images = productData['product_images'] as List<dynamic>?;
        final imageUrl = (images != null && images.isNotEmpty)
            ? images[0]['image_url'] as String?
            : 'https://picsum.photos/seed/others/300/300';

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
          'other_user_id': otherUserId,
          'other_user_name': otherUserName,
          'other_user_role': currentUser.id == buyerId ? 'Seller' : 'Buyer',
          'last_message': lastMessage,
          'product': product,
        });
      }

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

  Widget _buildInboxBody(BuildContext context) {
    return _isLoading
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
              : _chatRooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No active chats yet.',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Chats will appear here once you message a seller.',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _chatRooms.length,
                      itemBuilder: (context, index) {
                        final room = _chatRooms[index];
                        final Product product = room['product'];
                        final String lastMsg = room['last_message'];
                        final isGcashProof = lastMsg.contains('[GCASH_RECEIPT_PROOF]');
                        final isDark = Theme.of(context).brightness == Brightness.dark;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatView(
                                      product: product,
                                      roomId: room['chat_id'] as String,
                                    ),
                                  ),
                                ).then((_) => _loadChatRooms());
                              },
                              onLongPress: () {
                                _showDeleteChatDialog(context, room['chat_id'] as String, room['other_user_name'] as String);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Leading avatar with online indicator overlay (glowing green dot)
                                    FutureBuilder<bool>(
                                      future: PresenceService.isUserOnline(room['other_user_id'] as String),
                                      builder: (context, snapshot) {
                                        final bool isUserOnline = snapshot.data ?? false;

                                        return Stack(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.2),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                backgroundImage: NetworkImage(product.imageUrl ?? ''),
                                                radius: 26,
                                                backgroundColor: isDark ? const Color(0xFF1C1C22) : const Color(0xFFEDEEEF),
                                              ),
                                            ),
                                            if (isUserOnline)
                                              Positioned(
                                                bottom: 2,
                                                right: 2,
                                                child: Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark ? const Color(0xFF141418) : Colors.white,
                                                      width: 2.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.green.withValues(alpha: 0.4),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    // Title & Subtitle Info Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  room['other_user_name'] as String,
                                                  style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: room['other_user_role'] == 'Seller'
                                                      ? TeknoyTheme.citMaroon.withValues(alpha: 0.12)
                                                      : TeknoyTheme.citGold.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: room['other_user_role'] == 'Seller'
                                                        ? TeknoyTheme.citMaroon.withValues(alpha: 0.3)
                                                        : TeknoyTheme.citGold.withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  (room['other_user_role'] as String).toUpperCase(),
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: room['other_user_role'] == 'Seller'
                                                        ? TeknoyTheme.citMaroon
                                                        : const Color(0xFF6F5400),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F1F5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Item: ${product.title}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white60 : Colors.black54,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Builder(
                                            builder: (context) {
                                              final isOffer = lastMsg.startsWith('Can we agree on ₱') || lastMsg.contains('? Deal?');
                                              final isAccepted = lastMsg == 'Offer Accepted!' || lastMsg.contains('Deal! 🤝') || lastMsg.contains('Deal!');

                                              Color iconColor = isDark ? Colors.white30 : Colors.grey;
                                              IconData iconData = Icons.chat_bubble_outline_rounded;
                                              Color textColor = isDark ? Colors.white70 : Colors.grey.shade800;
                                              FontWeight fontWeight = FontWeight.normal;
                                              String displayText = lastMsg;

                                              if (isGcashProof) {
                                                iconColor = Colors.blue;
                                                iconData = Icons.receipt_long_rounded;
                                                textColor = Colors.blue;
                                                fontWeight = FontWeight.bold;
                                                displayText = 'GCash Receipt Attached';
                                              } else if (isAccepted) {
                                                iconColor = TeknoyTheme.success;
                                                iconData = Icons.handshake_rounded;
                                                textColor = TeknoyTheme.success;
                                                fontWeight = FontWeight.bold;
                                                displayText = '🤝 Deal Accepted! Ready for Checkout';
                                              } else if (isOffer) {
                                                iconColor = const Color(0xFFC48200);
                                                iconData = Icons.local_offer_rounded;
                                                textColor = const Color(0xFFC48200);
                                                fontWeight = FontWeight.bold;
                                                displayText = '🏷️ Tawad Offer: $lastMsg';
                                              }

                                              return Row(
                                                children: [
                                                  Icon(iconData, size: 14, color: iconColor),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      displayText,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 13,
                                                        color: textColor,
                                                        fontWeight: fontWeight,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Trailing chevron
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
              setState(() {
                _isLoading = true;
              });
              try {
                final chatService = ChatService();
                await chatService.softDeleteChatRoom(chatId);
                await _loadChatRooms();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete chat: $e')),
                );
                setState(() {
                  _isLoading = false;
                });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadChatRooms,
          ),
        ],
        elevation: 1,
      ),
      body: _buildInboxBody(context),
    );
  }
}
