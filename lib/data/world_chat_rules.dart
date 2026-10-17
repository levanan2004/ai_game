/// Tin thế giới numbers, from `assets/data/economy.json` `worldChat`
/// (Phú's spec 5.1, Nhất's chu_tin_the_gioi.md; Hà Phương confirmed them for An
/// on 17/10).
/// functions/world_chat.js reads the same keys and is the one that enforces
/// them: the app only shows them (counter, cooldown ring, locked card).
library;

/// One step of the penalty ladder (noi_quy_tin_the_gioi.md điều 9).
class ChatMuteLevel {
  const ChatMuteLevel(this.id, this.minutes);

  /// warning, mute_1h, mute_24h, mute_7d, ban.
  final String id;

  /// 0 = only a warning; null = for good (ban).
  final int? minutes;

  bool get forever => minutes == null;
}

class WorldChatRules {
  const WorldChatRules({
    required this.unlockDay,
    required this.maxChars,
    required this.cooldownSeconds,
    required this.duplicateWindowSeconds,
    required this.keepLatest,
    required this.reportNoteMax,
    required this.muteLevels,
  });

  /// Sending opens on this game day (reading is open to everyone).
  final int unlockDay;
  final int maxChars;
  final int cooldownSeconds;
  final int duplicateWindowSeconds;

  /// The server keeps this many newest messages; the app reads as many.
  final int keepLatest;
  final int reportNoteMax;
  final List<ChatMuteLevel> muteLevels;

  ChatMuteLevel? level(String id) {
    for (final l in muteLevels) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Null when economy.json has no `worldChat` block: the chat stays hidden.
  /// A block with a missing or bad number throws, like PhaLeRules.
  static WorldChatRules? fromJson(Object? j) {
    if (j == null) return null;
    if (j is! Map) throw const FormatException('economy.json worldChat');
    int n(String key) {
      final v = j[key];
      if (v is! num || v <= 0 || v != v.toInt()) {
        throw FormatException('economy.json worldChat.$key');
      }
      return v.toInt();
    }

    final levels = <ChatMuteLevel>[];
    final raw = j['muteLevels'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('economy.json worldChat.muteLevels');
    }
    for (final l in raw) {
      if (l is! Map || l['id'] is! String) {
        throw const FormatException('economy.json worldChat.muteLevels');
      }
      final m = l['minutes'];
      levels.add(ChatMuteLevel(l['id'] as String, m is num ? m.toInt() : null));
    }
    return WorldChatRules(
      unlockDay: n('unlockDay'),
      maxChars: n('maxChars'),
      cooldownSeconds: n('cooldownSeconds'),
      duplicateWindowSeconds: n('duplicateWindowSeconds'),
      keepLatest: n('keepLatest'),
      reportNoteMax: n('reportNoteMax'),
      muteLevels: List.unmodifiable(levels),
    );
  }
}
