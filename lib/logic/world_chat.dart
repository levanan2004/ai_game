import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/world_chat_rules.dart';
import '../save/progress_store.dart';
import 'shop_session.dart';

/// Tin thế giới (spec 5): the newest messages, sending through the server,
/// report, block, mute. functions/world_chat.js writes every message; this
/// side only shows what the server allows and explains a refusal.

/// One message of `world_chat/{id}`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.uid,
    required this.name,
    required this.text,
    required this.seq,
    this.avatar = '',
    this.frame = '',
    this.createdAt,
    this.official = false,
  });

  final String id;
  final String uid;
  final String name;
  final String avatar;

  /// The avatar frame the server stamped when it was sent ('' none).
  final String frame;
  final String text;
  final int seq;
  final DateTime? createdAt;

  /// Sent by an admin: wears the "Tiệm" badge, cannot be blocked.
  final bool official;
}

/// Why a message is reported. Labels: Nhất, worldchat.report.reason.*.
/// The ids are the ones functions/world_chat.js accepts.
enum ChatReportReason {
  profane('Chửi bậy'),
  harassment('Quấy rối'),
  scam('Lừa đảo/mua bán'),
  adult('Nội dung người lớn'),
  spam('Spam'),
  other('Khác');

  const ChatReportReason(this.label);

  final String label;

  static ChatReportReason? byName(Object? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// A chat_mutes/{uid} doc: the level an admin set and when. The end is
/// worked out from economy.json (like the server does).
class ChatMute {
  const ChatMute({required this.level, required this.at});

  final String level;
  final DateTime at;

  /// Null = not in force. A ban gives [ChatMuteState.banned].
  ChatMuteState? stateAt(DateTime now, WorldChatRules rules) {
    final l = rules.level(level);
    if (l == null) return null;
    if (l.forever) return const ChatMuteState(null);
    final m = l.minutes ?? 0;
    if (m <= 0) return null;
    final until = at.add(Duration(minutes: m));
    return until.isAfter(now) ? ChatMuteState(until) : null;
  }
}

class ChatMuteState {
  const ChatMuteState(this.until);

  /// Null = banned for good.
  final DateTime? until;
  bool get banned => until == null;
}

/// What the server said to one send.
class ChatSendResult {
  const ChatSendResult.ok({this.text = '', this.masked = false})
    : code = null,
      seconds = null,
      until = null;
  const ChatSendResult.refused(this.code, {this.seconds, this.until})
    : text = '',
      masked = false;

  /// null = sent. Otherwise the server's code (functions/world_chat.js):
  /// disabled, empty, too_long, blocked, blocked_link, no_save, locked_day,
  /// muted, banned, cooldown, duplicate; or network / server.
  final String? code;
  final String text;
  final bool masked;
  final int? seconds;
  final DateTime? until;
  bool get sent => code == null;
}

enum ChatReportSend { sent, already, failed }

/// Where the chat lives (Firestore + the callables; a memory one in tests).
abstract class WorldChatSource {
  /// The newest [limit] messages, oldest first. Errors when it cannot load.
  Stream<List<ChatMessage>> messages(int limit);

  /// config/worldChat.enabled; false while the doc is missing.
  Stream<bool> enabled();

  /// chat_mutes/{uid}, or null.
  Future<ChatMute?> mute(String uid);

  Future<ChatSendResult> send(String text, {required String avatar});

  Future<ChatReportSend> report(
    String messageId,
    ChatReportReason reason,
    String note,
  );
}

/// A message the player typed that the server has not taken yet.
class PendingChat {
  PendingChat(this.localId, this.text);

  final int localId;
  final String text;

  /// Failed: the red ! with "Chạm để thử lại".
  bool failed = false;
}

/// What replaces the input row (spec 5.4).
enum ChatLock { none, disabled, guest, lockedDay, muted, banned }

enum ChatLoad { idle, loading, ready, error }

/// Characters as the server counts them (an accented letter is 1).
int chatCharCount(String s) => s.trim().runes.length;

class WorldChatController extends ChangeNotifier {
  WorldChatController(this._s, {this.source, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ShopSession _s;
  final WorldChatSource? source;
  final DateTime Function() _now;

  WorldChatRules? get rules => _s.e.worldChat;

  /// The menu entry exists online with a `worldChat` block in economy.json.
  bool get offered => source != null && rules != null;

  bool open = false;
  bool rulesOpen = false;
  bool blockedListOpen = false;

  /// First open on this device: the 3-line rules popup (noi_quy, bản ngắn).
  bool rulesAccepted = false;

  ChatLoad load = ChatLoad.idle;
  bool enabled = false;
  List<ChatMessage> messages = const [];
  final List<PendingChat> pending = [];
  var _nextLocal = 1;

  ChatMute? _mute;
  DateTime? cooldownUntil;

  /// The last refusal to show under the input (filter, length, duplicate).
  String? inputError;

  /// Set when the last message went out with words masked (toast once).
  bool maskedNotice = false;

  StreamSubscription<List<ChatMessage>>? _msgSub;
  StreamSubscription<bool>? _onSub;

  void openChat() {
    if (!offered) return;
    open = true;
    _start();
    unawaited(refreshMute());
    notifyListeners();
  }

  void close() {
    if (!open) return;
    open = false;
    rulesOpen = false;
    blockedListOpen = false;
    notifyListeners();
  }

  void openRules() {
    rulesOpen = true;
    notifyListeners();
  }

  void closeRules() {
    rulesOpen = false;
    notifyListeners();
  }

  bool _blockedFromSettings = false;

  /// Settings > Người đã chặn opens the list over the game; back closes it.
  void openBlockedList() {
    if (!offered) return;
    _blockedFromSettings = !open;
    open = true;
    blockedListOpen = true;
    notifyListeners();
  }

  void closeBlockedList() {
    blockedListOpen = false;
    if (_blockedFromSettings) open = false;
    _blockedFromSettings = false;
    notifyListeners();
  }

  ProgressStore? _store;

  /// Reads whether the rules popup was accepted (main.dart; tests too).
  Future<void> useStore(ProgressStore store) async {
    _store = store;
    try {
      rulesAccepted = await store.loadChatRulesAccepted();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> acceptRules() async {
    rulesAccepted = true;
    notifyListeners();
    try {
      await _store?.saveChatRulesAccepted();
    } catch (_) {}
  }

  void _start() {
    final src = source;
    final r = rules;
    if (src == null || r == null) return;
    _onSub ??= src.enabled().listen(
      (on) {
        enabled = on;
        notifyListeners();
      },
      onError: (_) {
        enabled = false;
        notifyListeners();
      },
    );
    if (_msgSub != null && load != ChatLoad.error) return;
    unawaited(_msgSub?.cancel());
    load = ChatLoad.loading;
    _msgSub = src
        .messages(r.keepLatest)
        .listen(
          (list) {
            messages = list;
            load = ChatLoad.ready;
            notifyListeners();
          },
          onError: (_) {
            load = ChatLoad.error;
            notifyListeners();
          },
        );
  }

  /// "Thử lại" after a load error.
  void retryLoad() {
    load = ChatLoad.error;
    _start();
    notifyListeners();
  }

  Future<void> refreshMute() async {
    final uid = _s.accountUid;
    final src = source;
    if (uid == null || src == null) {
      _mute = null;
      return;
    }
    try {
      _mute = await src.mute(uid);
    } catch (_) {}
    notifyListeners();
  }

  /// Messages of blocked players are dropped (own and official ones never).
  List<ChatMessage> get visible => [
    for (final m in messages)
      if (m.official || !_s.board.isHidden(m.uid)) m,
  ];

  bool get someBlocked => visible.length < messages.length;

  int get daysLeft {
    final r = rules;
    if (r == null) return 0;
    final left = r.unlockDay - _s.state.day;
    return left > 0 ? left : 0;
  }

  ChatMuteState? get muteState {
    final r = rules;
    final m = _mute;
    if (r == null || m == null) return null;
    return m.stateAt(_now(), r);
  }

  ChatLock get lock {
    if (!enabled) return ChatLock.disabled;
    if (!_s.signedIn) return ChatLock.guest;
    if (daysLeft > 0) return ChatLock.lockedDay;
    final m = muteState;
    if (m != null) return m.banned ? ChatLock.banned : ChatLock.muted;
    return ChatLock.none;
  }

  /// Whole seconds left before the next send, 0 when free.
  int get cooldownLeft {
    final until = cooldownUntil;
    if (until == null) return 0;
    final ms = until.difference(_now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool isOwn(ChatMessage m) => m.uid == _s.accountUid;

  /// Sends [raw]. True when the input should be cleared (sent, or kept as a
  /// failed bubble to retry); false keeps the text so the player can fix it.
  Future<bool> send(String raw) async {
    final r = rules;
    final src = source;
    if (r == null || src == null || lock != ChatLock.none) return false;
    final text = raw.trim();
    if (text.isEmpty) {
      inputError = 'empty';
      notifyListeners();
      return false;
    }
    if (chatCharCount(text) > r.maxChars) {
      inputError = 'too_long';
      notifyListeners();
      return false;
    }
    if (cooldownLeft > 0) return false;
    inputError = null;
    final p = PendingChat(_nextLocal++, text);
    pending.add(p);
    notifyListeners();
    return _deliver(p, src, r);
  }

  /// Taps on a failed bubble.
  Future<void> retry(PendingChat p) async {
    final r = rules;
    final src = source;
    if (r == null || src == null || !p.failed || cooldownLeft > 0) return;
    p.failed = false;
    notifyListeners();
    await _deliver(p, src, r);
  }

  Future<bool> _deliver(
    PendingChat p,
    WorldChatSource src,
    WorldChatRules r,
  ) async {
    final ChatSendResult res;
    try {
      res = await src.send(p.text, avatar: _s.publishedAvatar);
    } catch (_) {
      p.failed = true;
      notifyListeners();
      return true;
    }
    if (res.sent) {
      pending.remove(p);
      cooldownUntil = _now().add(Duration(seconds: r.cooldownSeconds));
      maskedNotice = res.masked;
      notifyListeners();
      return true;
    }
    switch (res.code) {
      case 'network' || 'server':
        p.failed = true;
        notifyListeners();
        return true;
      case 'cooldown':
        cooldownUntil = _now().add(Duration(seconds: res.seconds ?? 1));
      case 'muted' || 'banned':
        final uid = _s.accountUid;
        if (uid != null) await refreshMute();
      case 'disabled':
        enabled = false;
      default:
        inputError = res.code;
    }
    pending.remove(p);
    notifyListeners();
    return false;
  }

  /// Reports [m] (never one's own).
  Future<ChatReportSend> report(
    ChatMessage m,
    ChatReportReason reason,
    String note,
  ) async {
    final src = source;
    final r = rules;
    if (src == null || r == null || isOwn(m) || !_s.signedIn) {
      return ChatReportSend.failed;
    }
    var n = note.trim();
    if (n.runes.length > r.reportNoteMax) {
      n = String.fromCharCodes(n.runes.take(r.reportNoteMax));
    }
    try {
      return await src.report(m.id, reason, n);
    } catch (_) {
      return ChatReportSend.failed;
    }
  }

  /// "Chặn": the same device list as "Ẩn người chơi này" on the Mị lực
  /// board (220a83b). False for one's own and the Tiệm's messages.
  Future<bool> block(ChatMessage m) async {
    if (isOwn(m) || m.official) return false;
    final ok = await _s.board.hidePlayer(m.uid, m.name);
    notifyListeners();
    return ok;
  }

  Future<void> unblock(String uid) async {
    await _s.board.unhide(uid);
    notifyListeners();
  }

  Map<String, String> get blockedPlayers => _s.board.hidden;

  @override
  void dispose() {
    unawaited(_msgSub?.cancel());
    unawaited(_onSub?.cancel());
    super.dispose();
  }
}

/// Keeps the chat in memory with the server's rules (tests, previews).
class MemoryWorldChat implements WorldChatSource {
  MemoryWorldChat({this.on = true, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  bool on;
  final DateTime Function() _now;
  final _list = <ChatMessage>[];
  final mutes = <String, ChatMute>{};
  final reports = <String, ChatReportReason>{};
  final _ctl = StreamController<List<ChatMessage>>.broadcast();
  final _onCtl = StreamController<bool>.broadcast();

  /// The next send gets this answer instead (tests).
  ChatSendResult? nextResult;
  int _seq = 0;
  String uid = 'me';
  String name = 'Tiệm của tôi';

  List<ChatMessage> get all => List.unmodifiable(_list);

  void add(ChatMessage m) {
    _list.add(m);
    _seq = m.seq > _seq ? m.seq : _seq;
    _ctl.add(List.of(_list));
  }

  void remove(String id) {
    _list.removeWhere((m) => m.id == id);
    _ctl.add(List.of(_list));
  }

  void setOn(bool v) {
    on = v;
    _onCtl.add(v);
  }

  @override
  Stream<List<ChatMessage>> messages(int limit) async* {
    yield _list.length > limit
        ? _list.sublist(_list.length - limit)
        : List.of(_list);
    yield* _ctl.stream;
  }

  @override
  Stream<bool> enabled() async* {
    yield on;
    yield* _onCtl.stream;
  }

  @override
  Future<ChatMute?> mute(String uid) async => mutes[uid];

  @override
  Future<ChatSendResult> send(String text, {required String avatar}) async {
    final forced = nextResult;
    if (forced != null) {
      nextResult = null;
      if (!forced.sent) return forced;
    }
    _seq++;
    add(
      ChatMessage(
        id: 'm${_seq.toString().padLeft(10, '0')}',
        uid: uid,
        name: name,
        avatar: avatar,
        text: forced?.text.isNotEmpty == true ? forced!.text : text,
        seq: _seq,
        createdAt: _now(),
      ),
    );
    return forced ?? const ChatSendResult.ok();
  }

  @override
  Future<ChatReportSend> report(
    String messageId,
    ChatReportReason reason,
    String note,
  ) async {
    final key = '${uid}_$messageId';
    if (reports.containsKey(key)) return ChatReportSend.already;
    reports[key] = reason;
    return ChatReportSend.sent;
  }
}
