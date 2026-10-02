import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teknoycart/core/theme.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final XFile? pendingImageFile;
  final bool isUploadingImage;
  final bool isOtherPartyDeleted;
  final VoidCallback onClearImage;
  final VoidCallback onShowImageSource;
  final VoidCallback onSendMessage;

  static const List<String> quickInquiryPresets = [
    'Is this still available?',
    'Can we meet at Canteen benches?',
    'Can we meet at CEA lobby?',
    'Is the price negotiable?',
    'Can I inspect the condition first?',
  ];

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.pendingImageFile,
    required this.isUploadingImage,
    required this.isOtherPartyDeleted,
    required this.onClearImage,
    required this.onShowImageSource,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pending image preview banner
        if (pendingImageFile != null || isUploadingImage)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: TeknoyTheme.citMaroon.withValues(alpha: 0.06),
            child: Row(
              children: [
                if (pendingImageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            pendingImageFile!.path,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(pendingImageFile!.path),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: isUploadingImage
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: TeknoyTheme.citMaroon,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Uploading image...',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Image ready to send',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onClearImage();
                  },
                ),
              ],
            ),
          ),

        // Quick Campus Inquiry Preset Chips
        if (!isOtherPartyDeleted)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.trim().isNotEmpty) return const SizedBox.shrink();
              return Container(
                height: 38,
                margin: const EdgeInsets.only(top: 6, bottom: 2),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: quickInquiryPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = quickInquiryPresets[index];
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        controller.text = preset;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF3F3F6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white12 : const Color(0xFFE2E2E8),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            preset,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white.withValues(alpha: 0.85) : TeknoyTheme.citMaroon,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

        // Input Send Deck
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: isOtherPartyDeleted
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.block_rounded, color: TeknoyTheme.citMaroon, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You cannot reply to this conversation because the other party has cleared the chat.',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: TeknoyTheme.citMaroon.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      // Attachment Icon — real image picker
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: TeknoyTheme.citMaroon,
                          size: 26,
                        ),
                        onPressed: isUploadingImage
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                onShowImageSource();
                              },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            HapticFeedback.lightImpact();
                            onSendMessage();
                          },
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: TeknoyTheme.citMaroon,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: TeknoyTheme.citMaroon,
                        radius: 22,
                        child: IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onSendMessage();
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
