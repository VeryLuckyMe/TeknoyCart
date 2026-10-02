import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/chat/views/widgets/chat_input_bar.dart';

void main() {
  group('ChatInputBar Quick Inquiry Chips & Interaction Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('Renders quick inquiry preset chips when input is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              pendingImageFile: null,
              isUploadingImage: false,
              isOtherPartyDeleted: false,
              onClearImage: () {},
              onShowImageSource: () {},
              onSendMessage: () {},
            ),
          ),
        ),
      );

      // Verify preset chips are rendered
      expect(find.text('Is this still available?'), findsOneWidget);
      expect(find.text('Can we meet at Canteen benches?'), findsOneWidget);
      expect(find.text('Can we meet at CEA lobby?'), findsOneWidget);
    });

    testWidgets('Tapping a preset chip fills the text controller and hides chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              pendingImageFile: null,
              isUploadingImage: false,
              isOtherPartyDeleted: false,
              onClearImage: () {},
              onShowImageSource: () {},
              onSendMessage: () {},
            ),
          ),
        ),
      );

      // Tap the first preset
      await tester.tap(find.text('Is this still available?'));
      await tester.pump();

      // Controller should now contain the preset text
      expect(controller.text, 'Is this still available?');

      // Preset chips should now be hidden because controller text is non-empty
      expect(find.text('Can we meet at Canteen benches?'), findsNothing);
    });

    testWidgets('Chips are hidden when isOtherPartyDeleted is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              pendingImageFile: null,
              isUploadingImage: false,
              isOtherPartyDeleted: true,
              onClearImage: () {},
              onShowImageSource: () {},
              onSendMessage: () {},
            ),
          ),
        ),
      );

      expect(find.text('Is this still available?'), findsNothing);
      expect(find.textContaining('You cannot reply to this conversation'), findsOneWidget);
    });
  });
}
