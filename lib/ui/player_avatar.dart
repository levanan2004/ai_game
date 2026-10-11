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
/// placeholder (the shop's initial) when there is none to show.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.avatar,
    required this.name,
    required this.radius,
  });

  final String avatar;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Avatar(name: name, avatarId: '', radius: radius);
    if (avatarKindOf(avatar) == AvatarKind.none) return placeholder;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
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
  }
}
