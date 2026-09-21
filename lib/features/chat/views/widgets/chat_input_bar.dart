import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pending image preview banner
        if (pendingImageFile != null || isUploadingImage)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: TeknoyTheme.citMaroon.withOpacity(0.06),
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
                  onPressed: onClearImage,
                ),
              ],
            ),
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
                      color: TeknoyTheme.citMaroon.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: TeknoyTheme.citMaroon.withOpacity(0.15),
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
                              color: TeknoyTheme.citMaroon.withOpacity(0.8),
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
                        onPressed: isUploadingImage ? null : onShowImageSource,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSendMessage(),
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
                                color: Theme.of(context).dividerColor.withOpacity(0.1),
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
                          onPressed: onSendMessage,
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
