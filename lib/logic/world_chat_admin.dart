import 'world_chat.dart';

/// One chat_reports doc, as /quan-tri shows it.
class ChatReport {
  const ChatReport({
    required this.id,
    required this.reporterUid,
    required this.targetUid,
    required this.targetName,
    required this.messageId,
    required this.text,
    required this.reason,
    this.note = '',
    this.context = const [],
    this.done = false,
    this.createdAt,
  });

  final String id;
  final String reporterUid;
  final String targetUid;
  final String targetName;
  final String messageId;

  /// The server's copy of the message (it may already have scrolled away).
  final String text;
  final ChatReportReason reason;
  final String note;

  /// Up to 5 messages on each side, oldest first, the reported one inside.
  final List<ChatMessage> context;
  final bool done;
  final DateTime? createdAt;
}

/// The admin's side of Tin thế giới (/quan-tri). Rules let only admins do
/// any of it.
abstract class WorldChatAdmin {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool on);

  /// Newest first.
  Future<List<ChatMessage>> latest({int limit = 100});
  Future<void> deleteMessage(String id);

  /// Sets the penalty level of [uid] from now (rules: at = request.time).
  Future<void> setMute(
    String uid,
    String level, {
    String reason = '',
    String messageId = '',
  });
  Future<void> clearMute(String uid);
  Future<ChatMute?> mute(String uid);

  /// Newest first.
  Future<List<ChatReport>> reports({int limit = 100});
  Future<void> markDone(String reportId);
}

/// Memory admin for tests.
class MemoryWorldChatAdmin implements WorldChatAdmin {
  MemoryWorldChatAdmin(this.chat, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MemoryWorldChat chat;
  final DateTime Function() _now;
  final reportList = <ChatReport>[];
  final done = <String>{};

  @override
  Future<bool> isEnabled() async => chat.on;

  @override
  Future<void> setEnabled(bool on) async => chat.setOn(on);

  @override
  Future<List<ChatMessage>> latest({int limit = 100}) async =>
      chat.all.reversed.take(limit).toList();

  @override
  Future<void> deleteMessage(String id) async => chat.remove(id);

  @override
  Future<void> setMute(
    String uid,
    String level, {
    String reason = '',
    String messageId = '',
  }) async {
    chat.mutes[uid] = ChatMute(level: level, at: _now());
  }

  @override
  Future<void> clearMute(String uid) async => chat.mutes.remove(uid);

  @override
  Future<ChatMute?> mute(String uid) async => chat.mutes[uid];

  @override
  Future<List<ChatReport>> reports({int limit = 100}) async => [
    for (final r in reportList.reversed.take(limit))
      ChatReport(
        id: r.id,
        reporterUid: r.reporterUid,
        targetUid: r.targetUid,
        targetName: r.targetName,
        messageId: r.messageId,
        text: r.text,
        reason: r.reason,
        note: r.note,
        context: r.context,
        done: done.contains(r.id),
        createdAt: r.createdAt,
      ),
  ];

  @override
  Future<void> markDone(String reportId) async => done.add(reportId);
}
