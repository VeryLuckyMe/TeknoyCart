import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/feed/models/product.dart';

/// Real-Time Chat Inbox listing active negotiations.
/// Enables seamless account-to-account conversations for both buyers and sellers.
class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chatRooms = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please log in to view active chats.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
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
      final List<Map<String, dynamic>> rooms = [];

      for (var rawRoom in chatData) {
        final String chatId = rawRoom['chat_id'] as String;
        final String buyerId = rawRoom['buyer_id'] as String;
        final String sellerId = rawRoom['seller_id'] as String;
        
        final inquiry = rawRoom['inquiries'];
        if (inquiry == null) continue;
        
        final productData = inquiry['products'];
        if (productData == null) continue;

        // Fetch other participant details
        final otherUserId = currentUser.id == buyerId ? sellerId : buyerId;
        final otherUserRes = await client
            .from('users')
            .select('full_name, email')
            .eq('user_id', otherUserId)
            .maybeSingle();

        final otherUserName = otherUserRes != null 
            ? otherUserRes['full_name'] as String? ?? 'Wildcat Student'
            : 'Wildcat Student';

        // Fetch last message content
        final lastMsgRes = await client
            .from('messages')
            .select('content, sent_at')
            .eq('chat_id', chatId)
            .order('sent_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final String lastMessage = lastMsgRes != null
            ? lastMsgRes['content'] as String? ?? 'No messages yet'
            : 'No messages yet';

        // Parse Product
        final images = productData['product_images'] as List<dynamic>?;
        final imageUrl = (images != null && images.isNotEmpty)
            ? images[0]['image_url'] as String?
            : 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&q=80&w=300';

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
          'other_user_name': otherUserName,
          'other_user_role': currentUser.id == buyerId ? 'Seller' : 'Buyer',
          'last_message': lastMessage,
          'product': product,
        });
      }

      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
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
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _chatRooms.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final room = _chatRooms[index];
                        final Product product = room['product'];
                        final String lastMsg = room['last_message'];
                        final isGcashProof = lastMsg.contains('[GCASH_RECEIPT_PROOF]');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(product.imageUrl ?? ''),
                            radius: 26,
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                room['other_user_name'] as String,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: room['other_user_role'] == 'Seller'
                                      ? TeknoyTheme.citMaroon.withOpacity(0.1)
                                      : TeknoyTheme.citGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  room['other_user_role'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: room['other_user_role'] == 'Seller'
                                        ? TeknoyTheme.citMaroon
                                        : TeknoyTheme.citGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Regarding: ${product.title}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isGcashProof ? '📷 GCash Proof of Payment' : lastMsg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isGcashProof ? Colors.blue : Colors.grey.shade700,
                                  fontWeight: isGcashProof ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
                        );
                      },
                    ),
    );
  }
}
