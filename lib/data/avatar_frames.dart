/// Khung avatar (spec 3): which frames exist and how each one opens, from
/// economy.json `avatarFrames`; the VIP level of a VIP frame from
/// `vip.tiers[].frame` (the lowest level that lists it). Nothing here is a
/// number of its own. The server (functions/avatar_frames.js) reads the same
/// two blocks and is the one that decides what a player may wear.
library;

import 'pot_rules.dart' show VipConfig;

/// How a frame opens.
enum FrameOrigin {
  /// Every signed-in player has it ("Khung mặc định khi đăng nhập").
  standard('default'),

  /// Opens at a VIP level (VIP: task 6, so locked for everyone for now).
  vip('vip'),

  /// Granted by the server for an event (wallets/{uid}.frames).
  event('event'),

  /// Granted by the server for a season top rank (wallets/{uid}.frames).
  seasonTop('seasonTop'),

  /// Bought with Pha lê (no prices yet).
  buy('buy');

  const FrameOrigin(this.key);
  final String key;

  static FrameOrigin fromKey(Object? key) => values.firstWhere(
    (s) => s.key == key,
    orElse: () => FrameOrigin.event,
  );
}

class AvatarFrameDef {
  const AvatarFrameDef({
    required this.id,
    required this.source,
    this.vipLevel,
    this.event = '',
    this.maxRank,
  });

  /// Also the sprite name: `assets/images/avatar_frames/{id}_lon|_nho.webp`.
  final String id;
  final FrameOrigin source;

  /// VIP frames: the lowest VIP level that opens it (null: no tier lists it).
  final int? vipLevel;

  /// Event frames: the event's name ("Tết").
  final String event;

  /// Season frames: the last rank that wins it.
  final int? maxRank;
}

class AvatarFramesConfig {
  const AvatarFramesConfig(this.frames);

  static const none = AvatarFramesConfig([]);

  /// In economy.json order (the picker grid order).
  final List<AvatarFrameDef> frames;

  AvatarFrameDef? byId(String id) {
    for (final f in frames) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// What a player with [vipLevel] and the server-granted [granted] frames
  /// may wear (signed in). Same rule as functions/avatar_frames.js.
  Set<String> ownedBy({int vipLevel = 0, Set<String> granted = const {}}) => {
    for (final f in frames)
      if (f.source == FrameOrigin.standard ||
          (f.source == FrameOrigin.vip &&
              f.vipLevel != null &&
              vipLevel >= f.vipLevel!) ||
          granted.contains(f.id))
        f.id,
  };

  static final _id = RegExp(r'^[a-z0-9_]{1,40}$');

  factory AvatarFramesConfig.fromJson(Object? json, VipConfig vip) {
    if (json is! Map || json['frames'] is! List) return none;
    final vipAt = <String, int>{};
    for (final t in vip.tiers) {
      if (t.frame.isEmpty || t.level <= 0) continue;
      final at = vipAt[t.frame];
      if (at == null || t.level < at) vipAt[t.frame] = t.level;
    }
    return AvatarFramesConfig([
      for (final f in json['frames'] as List)
        if (f is Map && f['id'] is String && _id.hasMatch(f['id'] as String))
          AvatarFrameDef(
            id: f['id'] as String,
            source: FrameOrigin.fromKey(f['source']),
            vipLevel: FrameOrigin.fromKey(f['source']) ==
                    FrameOrigin.vip
                ? vipAt[f['id']]
                : null,
            event: f['event'] is String ? f['event'] as String : '',
            maxRank: f['maxRank'] is num ? (f['maxRank'] as num).toInt() : null,
          ),
    ]);
  }
}
