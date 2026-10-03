import 'package:flutter/foundation.dart';

import 'game_notice.dart';
import 'rewards.dart';

/// Target of a mail sent to every player.
const mailToAll = 'all';

const maxMailTitleChars = 80;
const maxMailBodyChars = 2000;

/// Most mails one inbox query reads (per target).
const mailInboxLimit = 50;

/// One letter in the Hộp thư (`mails/{id}`), written by an admin.
///
/// [target] is [mailToAll] or one player's uid. [rewards] uses the shared
/// [RewardBundle] JSON, so the mailbox, login rewards and giftcodes read
/// the same items.
@immutable
class GameMail {
  GameMail({
    required this.id,
    required this.title,
    required this.body,
    required this.target,
    RewardBundle? rewards,
    this.imageUrl,
    this.createdAt,
    this.expiresAt,
  }) : rewards = rewards ?? RewardBundle.empty;

  final String id;
  final String title;
  final String body;
  final String target;
  final RewardBundle rewards;

  /// `https://…` only. Null when the mail has no picture.
  final String? imageUrl;
  final DateTime? createdAt;

  /// After this the mail is hidden and cannot be claimed. Null: never.
  final DateTime? expiresAt;

  bool get hasGift => rewards.isNotEmpty;
  bool get toAll => target == mailToAll;

  bool expired(DateTime now) => expiresAt != null && !expiresAt!.isAfter(now);
}

/// Per player, per mail (`users/{uid}/mailState/{mailId}`).
@immutable
class MailState {
  const MailState({this.read = false, this.claimed = false});

  static const fresh = MailState();

  final bool read;

  /// The gift was added to this account. Never goes back to false.
  final bool claimed;

  MailState copyWith({bool? read, bool? claimed}) =>
      MailState(read: read ?? this.read, claimed: claimed ?? this.claimed);
}

/// Firestore map of a mail. Dates stay [DateTime]; the store converts
/// them. [createdAt] null means "server time".
Map<String, Object?> mailToMap(GameMail mail) => {
  'title': mail.title.trim(),
  'body': mail.body.trim(),
  'target': mail.target,
  'rewards': mail.rewards.toJson(),
  'imageUrl': ?normalizeImageUrl(mail.imageUrl),
  'createdAt': mail.createdAt,
  'expiresAt': ?mail.expiresAt,
};

/// Reads a mail document. Broken ones return null; unknown reward kinds
/// are skipped by [RewardBundle.fromJson].
GameMail? mailFromMap(
  String id,
  Map<String, Object?> data, {
  DateTime? Function(Object? raw)? date,
}) {
  final title = data['title'];
  final body = data['body'];
  final target = data['target'];
  if (title is! String || title.trim().isEmpty) return null;
  if (target is! String || target.isEmpty) return null;
  final readDate = date ?? (raw) => raw is DateTime ? raw : null;
  return GameMail(
    id: id,
    title: title.trim(),
    body: body is String ? body.trim() : '',
    target: target,
    rewards: RewardBundle.fromJson(data['rewards']),
    imageUrl: normalizeImageUrl(
      data['imageUrl'] is String ? data['imageUrl'] as String : null,
    ),
    createdAt: readDate(data['createdAt']),
    expiresAt: readDate(data['expiresAt']),
  );
}

/// Null when an admin may send this mail.
String? mailFormError(GameMail mail, {required String rawImageUrl}) {
  final title = mail.title.trim();
  if (title.isEmpty || title.length > maxMailTitleChars) {
    return 'Tiêu đề cần từ 1 đến $maxMailTitleChars ký tự.';
  }
  if (mail.body.trim().length > maxMailBodyChars) {
    return 'Nội dung tối đa $maxMailBodyChars ký tự.';
  }
  if (mail.target.isEmpty) return 'Chọn người nhận.';
  if (rawImageUrl.trim().isNotEmpty && normalizeImageUrl(rawImageUrl) == null) {
    return 'Link ảnh cần bắt đầu bằng https://';
  }
  return null;
}

/// Newest first; a mail without a date stays last.
List<GameMail> sortMails(Iterable<GameMail> mails) {
  final list = [...mails];
  list.sort((a, b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    final c = bt.compareTo(at);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}

/// "Đến 31/10" for an expiry, empty when there is none.
String mailExpiryLabel(DateTime? expiresAt) {
  if (expiresAt == null) return '';
  final local = expiresAt.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return 'Đến $d/$m/${local.year}';
}

enum MailClaimResult {
  /// The gift was added just now.
  claimed,

  /// Already claimed here, in another tab, or on another device.
  already,

  /// A claim for this mail is still running (double tap).
  busy,

  /// Expired, missing, without a gift, or nobody signed in.
  refused,

  /// The network or the rules refused. Nothing was added; try again.
  failed,
}

/// The signed-in player's side of the mailbox.
abstract class MailService {
  /// Mails sent to [uid] or to everyone, any order, expired included.
  Future<List<GameMail>> inbox(String uid);

  /// Read/claimed marks of [uid], by mail id.
  Future<Map<String, MailState>> states(String uid);

  /// Marks one mail read. Never touches the claimed mark.
  Future<void> markRead(String uid, String mailId);

  /// Atomically flips the claimed mark. Returns [MailClaimResult.claimed]
  /// only for the one call that flipped it; every later call, from any
  /// tab or device, gets [MailClaimResult.already].
  Future<MailClaimResult> claim(String uid, String mailId);
}

/// Admin side (`/quan-tri`). The rules reject everyone else.
abstract class MailAdmin {
  String newId();
  Future<List<GameMail>> loadAll();
  Future<void> send(GameMail mail);
  Future<void> delete(String id);
}

/// What the Hộp thư shows. Requires sign-in: a guest sees no mails.
class MailboxFeed extends ChangeNotifier {
  MailboxFeed({this.service, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MailService? service;
  final DateTime Function() _now;

  String? uid;
  List<GameMail> _mails = const [];
  Map<String, MailState> _states = {};
  final _claiming = <String>{};
  var open = false;
  String? detailId;
  var loading = false;
  String? error;
  var _gone = false;

  /// Not expired, newest first.
  List<GameMail> get mails {
    final now = _now();
    return sortMails(_mails.where((m) => !m.expired(now)));
  }

  MailState stateOf(String id) => _states[id] ?? MailState.fresh;

  bool claiming(String id) => _claiming.contains(id);

  /// A mail with a gift stays unread until it is claimed.
  int get unread =>
      uid == null ? 0 : mails.where((m) => !stateOf(m.id).read).length;

  GameMail? get detail {
    final id = detailId;
    if (id == null) return null;
    for (final mail in mails) {
      if (mail.id == id) return mail;
    }
    return null;
  }

  /// Switches the inbox to another account (null: signed out).
  Future<void> bindUser(String? next) async {
    if (next == uid) return;
    uid = next;
    _mails = const [];
    _states = {};
    detailId = null;
    error = null;
    _notify();
    if (next != null) await refresh();
  }

  Future<void> refresh() async {
    final who = uid;
    final store = service;
    if (who == null || store == null) return;
    loading = true;
    _notify();
    try {
      final list = await store.inbox(who);
      final marks = await store.states(who);
      if (_gone || who != uid) return;
      _mails = list;
      // A claim finished while the list loaded keeps its mark.
      _states = {
        ...marks,
        for (final e in _states.entries)
          if (e.value.claimed) e.key: e.value,
      };
      error = null;
    } catch (_) {
      if (_gone || who != uid) return;
      error = 'Chưa tải được hộp thư.';
    } finally {
      if (!_gone && who == uid) {
        loading = false;
        _notify();
      }
    }
  }

  void toggle() {
    open = !open;
    detailId = null;
    _notify();
    if (open) refresh();
  }

  void close() {
    open = false;
    detailId = null;
    _notify();
  }

  void showList() {
    detailId = null;
    _notify();
  }

  /// Opens a mail. One without a gift is marked read now; a gift stays
  /// unread until "Nhận quà".
  Future<void> openMail(String id) async {
    detailId = id;
    _notify();
    final mail = detail;
    final who = uid;
    if (mail == null || who == null || mail.hasGift) return;
    if (stateOf(id).read) return;
    _states[id] = stateOf(id).copyWith(read: true);
    _notify();
    try {
      await service?.markRead(who, id);
    } catch (_) {}
  }

  /// Claims the gift of mail [id] once per account.
  ///
  /// The claimed mark is flipped on the server first (a transaction), and
  /// only the call that flipped it runs [grant]. A double tap, a second tab
  /// or another device gets [MailClaimResult.already] and adds nothing.
  /// [allowed] is false when this tab may not write the account now.
  Future<MailClaimResult> claim(
    String id, {
    required bool allowed,
    required RewardBundle Function(GameMail mail) grant,
  }) async {
    if (_claiming.contains(id)) return MailClaimResult.busy;
    final mail = detail?.id == id ? detail : _find(id);
    final who = uid;
    final store = service;
    if (stateOf(id).claimed) return MailClaimResult.already;
    if (mail == null ||
        who == null ||
        store == null ||
        !allowed ||
        !mail.hasGift ||
        mail.expired(_now())) {
      return MailClaimResult.refused;
    }
    _claiming.add(id);
    _notify();
    try {
      final result = await store.claim(who, id);
      if (_gone || who != uid) return MailClaimResult.failed;
      if (result == MailClaimResult.claimed) grant(mail);
      if (result == MailClaimResult.claimed ||
          result == MailClaimResult.already) {
        _states[id] = const MailState(read: true, claimed: true);
      }
      return result;
    } catch (_) {
      return MailClaimResult.failed;
    } finally {
      _claiming.remove(id);
      _notify();
    }
  }

  GameMail? _find(String id) {
    for (final mail in mails) {
      if (mail.id == id) return mail;
    }
    return null;
  }

  void _notify() {
    if (!_gone) notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}
