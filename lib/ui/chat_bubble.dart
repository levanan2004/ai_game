import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/chat_frames.dart';
import '../theme/tokens.dart';

/// Phú's khung tin nhắn: the frame art nine-sliced (centerSlice) at scale
/// 0.25, text 13 sp #2E5E3D with 12 dp side padding, always below the top
/// decoration; own messages flip the art (tail on the right), not the text.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.frameId,
    required this.text,
    this.own = false,
  });

  /// A chatBubbleFrames id; unknown or '' = the default (thường).
  final String frameId;
  final String text;
  final bool own;

  static const textColor = Color(0xFF2E5E3D);
  static const fallback = 'chat_thuong';

  @override
  Widget build(BuildContext context) {
    final id = chatFrameArtOf(frameId) != null ? frameId : fallback;
    final art = chatFrameArtOf(id)!;
    const s = ChatFrameArt.scale;
    return ConstrainedBox(
      key: Key('chat-bubble-$id'),
      constraints: BoxConstraints(
        minWidth: ChatFrameArt.side * 2 * s + 4,
        minHeight: (art.top + ChatFrameArt.bottom) * s + 4,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Transform.flip(
              flipX: own,
              child: Image.asset(
                art.asset,
                scale: 1 / s,
                centerSlice: art.slice,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              math.max(8, art.top * s),
              12,
              math.max(8, ChatFrameArt.bottom * s),
            ),
            child: Text(
              text,
              style: AppText.make(AppFonts.body, 13, 600, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
