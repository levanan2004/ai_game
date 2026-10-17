import 'package:flutter/material.dart';

import '../logic/supporters.dart' show storageAvatarUrl;
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart' show Avatar;

/// How one avatar pointer is drawn. The pointer is the single kind of value
/// every public place keeps (`player_avatars/{uid}.path`, the leaderboard's
/// `charm_board.avatar`, a supporter's `avatar`, the session's
/// `ShopSession.publishedAvatar`):
///  - `http(s)://...`: a photo (an uploaded one with its revision, or the
///    Google photo);
///  - `users/{uid}/avatar.jpg`: an uploaded photo as a Storage path, turned
///    into its public URL;
///  - a preset id (`minh_anh`, ...): the portrait from the avatar picker
///    (`assets/images/customers/<id>`);
///  - empty or `google` (no photo known): nothing to draw, the caller's
///    placeholder shows.
enum AvatarKind { photo, preset, none }

/// The one resolver: what [avatar] points at.
AvatarKind avatarKindOf(String avatar) {
  if (avatarPhotoUrl(avatar) != null) return AvatarKind.photo;
  if (avatar.isEmpty || avatar == 'google') return AvatarKind.none;
  return AvatarKind.preset;
}

/// The picture's URL for a photo pointer, null for presets and empties.
String? avatarPhotoUrl(String avatar) {
  if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
    return avatar;
  }
  return storageAvatarUrl(avatar);
}

/// The portrait filling its parent (clip it round yourself): the photo, the
/// preset art, or [fallback] for no avatar, while a photo loads, and when a
/// file fails. Every place that shows a player's avatar draws it with this
/// (directly or through [PlayerAvatar]); `avatar_audit_test` guards that.
class PlayerAvatarFace extends StatelessWidget {
  const PlayerAvatarFace({
    super.key,
    required this.avatar,
    required this.fallback,
  });

  final String avatar;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final url = avatarPhotoUrl(avatar);
    if (url != null) {
      return Image.network(
        url,
        key: const Key('player-avatar-photo'),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) {
          if (progress != null) return fallback;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.base,
            builder: (_, v, c) => Opacity(opacity: v, child: c!),
            child: child,
          );
        },
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (avatarKindOf(avatar) == AvatarKind.none) return fallback;
    return Image.asset(
      Art.customer(avatar),
      key: const Key('player-avatar-preset'),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// A player's portrait in a round slot of [radius], with the round
/// placeholder (the shop's initial) when there is none to show, and the
/// avatar frame [frameId] around it (spec 3.1: the one avatar widget, every
/// place that shows a player goes through it).
///
/// The frame sprite's round hole is 72% of its side, so it is drawn
/// 2·radius / 0.72 wide, centred on the slot and spilling past it: the
/// widget itself stays 2·radius, so no layout moves when a frame is worn.
/// Up to [smallFrameMax] dp the simple `_nho` sprite is used (28 dp chat).
/// No frame: the thin `surface.borderStrong` ring as before.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.avatar,
    required this.name,
    required this.radius,
    this.frameId = '',
  });

  final String avatar;
  final String name;
  final double radius;

  /// Frame id (economy.json avatarFrames, as the server stored it); ''
  /// none.
  final String frameId;

  /// The frame's round hole: 72% of the sprite's side (Phú).
  static const frameHole = 0.72;

  /// Avatars up to this diameter use the simple `_nho` frame.
  static const smallFrameMax = 32.0;

  /// The frame sprite's side for an avatar of [radius].
  static double frameSide(double radius) => radius * 2 / frameHole;

  @override
  Widget build(BuildContext context) {
    final placeholder = Avatar(name: name, avatarId: '', radius: radius);
    final framed = frameId.isNotEmpty;
    final Widget face = avatarKindOf(avatar) == AvatarKind.none
        ? placeholder
        : Container(
            width: radius * 2,
            height: radius * 2,
            decoration: framed
                ? const BoxDecoration(shape: BoxShape.circle)
                : BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surfaceBorderStrong,
                      width: AppBorder.thin,
                    ),
                  ),
            child: ClipOval(
              child: PlayerAvatarFace(avatar: avatar, fallback: placeholder),
            ),
          );
    if (!framed) return face;
    final side = frameSide(radius);
    final spill = (side - radius * 2) / 2;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: face),
          Positioned(
            left: -spill,
            top: -spill,
            width: side,
            height: side,
            child: IgnorePointer(
              child: Image.asset(
                Art.avatarFrame(frameId, small: radius * 2 <= smallFrameMax),
                key: Key('player-avatar-frame-$frameId'),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
