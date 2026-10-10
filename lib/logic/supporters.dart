import 'dart:typed_data';

import 'shop_name.dart';

/// One name on the Đại thiện nhân board (Firestore `supporters/{id}`).
class Supporter {
  const Supporter({
    required this.id,
    required this.name,
    required this.message,
    required this.date,
    required this.visible,
    required this.avatar,
    required this.amount,
    this.uid = '',
  });

  final String id;
  final String name;

  /// Firebase uid of the player this row belongs to. Empty for anonymous gifts.
  final String uid;
  final String message;
  final DateTime? date;

  /// Hidden when false. A missing field counts as visible.
  final bool visible;

  /// Preset customer file name ("minh_anh") or a Storage path containing "/".
  final String avatar;

  /// Đồng. Null or 0 means no amount chip.
  final int? amount;

  bool get hasAmount => amount != null && amount! > 0;

  String get displayName {
    final n = name.trim();
    return n.isEmpty ? 'Một người ẩn danh' : n;
  }
}

/// Reads the public supporter list. Implementations must not throw into
/// the game loop; the screen shows an error row instead.
abstract class SupporterSource {
  Future<List<Supporter>> load();
}

/// Owner accounts that manage the board without an `admins/{uid}` document.
/// Must match `adminUids()` in firestore.rules and storage.rules.
///
/// `rFdE3O7LLBZIu0msxtvGktXmfJp1` is the Firebase uid of
/// cunuoc2016@gmail.com. The admin page and the đại thiện nhân board
/// both accept this uid (or an `admins/{uid}` document).
const supportAdminUids = {'rFdE3O7LLBZIu0msxtvGktXmfJp1'};

/// Board management for [supportAdminUids] and accounts listed in
/// Firestore `admins/{uid}`.
///
/// The phone number lives in `supporter_private/{id}`, which only admins can
/// read. `supporters` is public, so nothing private may be written there.
abstract class SupporterAdmin {
  /// False on any error, so a missing rule or network hides the tools.
  Future<bool> isAdmin();

  String newId();

  /// Every document, hidden ones included, unsorted.
  Future<List<Supporter>> loadAll();

  /// Empty when none was saved.
  Future<String> loadPhone(String id);

  /// Creates or replaces [s]. An empty [phone] removes the private record.
  Future<void> save(Supporter s, {required String phone});

  /// Also removes the private record and an uploaded avatar.
  Future<void> delete(Supporter s);

  /// Returns the Storage path to store in [Supporter.avatar]. Each upload
  /// gets a new file name so browsers do not show a cached old photo.
  Future<String> uploadAvatar(String id, Uint8List jpeg);

  /// Removes an uploaded `supporters/...` photo; preset codes are ignored.
  Future<void> deleteAvatar(String path);
}

class NoSupporterAdmin implements SupporterAdmin {
  const NoSupporterAdmin();

  @override
  Future<bool> isAdmin() async => false;

  @override
  String newId() => throw StateError('Không có quyền quản lý');

  @override
  Future<List<Supporter>> loadAll() => throw StateError('Không có quyền');

  @override
  Future<String> loadPhone(String id) => throw StateError('Không có quyền');

  @override
  Future<void> save(Supporter s, {required String phone}) =>
      throw StateError('Không có quyền');

  @override
  Future<void> delete(Supporter s) => throw StateError('Không có quyền');

  @override
  Future<String> uploadAvatar(String id, Uint8List jpeg) =>
      throw StateError('Không có quyền');

  @override
  Future<void> deleteAvatar(String path) async {}
}

/// Admin form amount: "200000", "200.000", "200k", "1,5tr". Empty is 0.
/// Null means the text is not an amount.
int? parseSupportAmount(String raw) {
  var t = raw.trim().toLowerCase().replaceAll(' ', '');
  if (t.isEmpty) return 0;
  var unit = 1;
  if (t.endsWith('tr')) {
    unit = 1000000;
    t = t.substring(0, t.length - 2);
  } else if (t.endsWith('k')) {
    unit = 1000;
    t = t.substring(0, t.length - 1);
  }
  if (unit == 1) {
    t = t.replaceAll('.', '').replaceAll(',', '');
    return RegExp(r'^\d+$').hasMatch(t) ? int.parse(t) : null;
  }
  t = t.replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
  return (double.parse(t) * unit).round();
}

/// "dd/mm/yyyy" (also "-" or "."). Null when it is not a real date.
DateTime? parseDayMonthYear(String raw) {
  final m = RegExp(
    r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$',
  ).firstMatch(raw.trim());
  if (m == null) return null;
  final d = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final y = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) return null;
  return date;
}

String formatDayMonthYear(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Keeps digits and a leading "+". Empty stays empty; null means invalid.
String? normalizePhone(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'[\s.\-]'), '');
  if (t.isEmpty) return '';
  return RegExp(r'^\+?\d{9,15}$').hasMatch(t) ? t : null;
}

/// Used when Firebase never started. The board shows the retry row.
class UnavailableSupporterSource implements SupporterSource {
  const UnavailableSupporterSource();

  @override
  Future<List<Supporter>> load() async {
    throw StateError('Firebase chưa khởi tạo');
  }
}

Supporter supporterFromFields({
  required String id,
  Object? name,
  Object? message,
  DateTime? date,
  Object? visible,
  Object? avatar,
  Object? amount,
  Object? uid,
}) {
  return Supporter(
    id: id,
    name: name is String ? name : '',
    message: message is String ? message : '',
    date: date,
    visible: visible != false,
    avatar: avatar is String ? avatar : '',
    amount: amount is num ? amount.toInt() : null,
    uid: uid is String ? uid : '',
  );
}

/// A signed-in player, written to `profiles/{uid}` so an admin can find them.
class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.shopName,
  });

  final String uid;
  final String name;
  final String email;
  final String shopName;

  /// Name for the board: Google name, otherwise the shop name, otherwise email.
  String get label {
    for (final raw in [name, shopName, email]) {
      final t = raw.trim();
      if (t.isNotEmpty) return t;
    }
    return uid;
  }
}

/// Profiles of players who have signed in, plus the owner's board switch.
abstract class PlayerDirectory {
  Future<void> sync({
    required String uid,
    required String name,
    required String email,
    required String shopName,
  });

  /// Newest first. Only accounts that have opened the game while signed in.
  Future<List<PlayerProfile>> recent({int limit = 10});

  Future<PlayerProfile?> byUid(String uid);

  /// Profiles whose user id starts with [prefix]. Empty when [prefix] is empty.
  Future<List<PlayerProfile>> byUidPrefix(String prefix, {int limit = 10});

  /// The signed-in player flips their own row. Rules reject anyone else.
  Future<void> setOwnVisible(String supporterId, bool visible);

  /// Public pointer to the player's portrait. [path] is a Storage path,
  /// a preset id, or an https URL for a Google photo.
  Future<void> publishAvatar({
    required String uid,
    required String path,
    required int rev,
  });

  /// Raw pointer for [uid], or null when they have not published one.
  Future<String?> publishedAvatar(String uid);

  /// uid -> image URL the board can show. Missing players are omitted.
  Future<Map<String, String>> avatarUrls(Iterable<String> uids);

  /// Reserves [shopName] for [uid]. [ShopNameClaim.taken] when another
  /// account already has that name, ignoring capitalization.
  /// A null [uid] only checks; it does not reserve the name.
  /// [previousName] is released when it belongs to [uid].
  Future<ShopNameClaim> claimShopName({
    String? uid,
    required String shopName,
    String? previousName,
  });
}

class NoPlayerDirectory implements PlayerDirectory {
  const NoPlayerDirectory();

  @override
  Future<void> sync({
    required String uid,
    required String name,
    required String email,
    required String shopName,
  }) async {}

  @override
  Future<List<PlayerProfile>> recent({int limit = 10}) async => const [];

  @override
  Future<PlayerProfile?> byUid(String uid) async => null;

  @override
  Future<List<PlayerProfile>> byUidPrefix(
    String prefix, {
    int limit = 10,
  }) async => const [];

  @override
  Future<void> setOwnVisible(String supporterId, bool visible) async {}

  @override
  Future<void> publishAvatar({
    required String uid,
    required String path,
    required int rev,
  }) async {}

  @override
  Future<String?> publishedAvatar(String uid) async => null;

  @override
  Future<Map<String, String>> avatarUrls(Iterable<String> uids) async =>
      const {};

  @override
  Future<ShopNameClaim> claimShopName({
    String? uid,
    required String shopName,
    String? previousName,
  }) async => ShopNameClaim.claimed;
}

/// Client-side order from firebase_backend.md.
///
/// Do not `orderBy('amount')`: Firestore drops documents missing the field.
/// People with an amount come first, highest first. The same amount puts the
/// newer [Supporter.date] above. No amount (null or 0) sits at the bottom,
/// newest first. `visible == false` is left out, except a row whose [keepUid]
/// matches, so that player can turn their own name back on.
List<Supporter> sortSupporters(List<Supporter> all, {String? keepUid}) {
  final mine = keepUid ?? '';
  final shown = all
      .where((s) => s.visible || (mine.isNotEmpty && s.uid == mine))
      .toList();
  shown.sort((a, b) {
    if (a.hasAmount != b.hasAmount) return a.hasAmount ? -1 : 1;
    if (a.hasAmount && b.hasAmount) {
      final byAmount = b.amount!.compareTo(a.amount!);
      if (byAmount != 0) return byAmount;
    }
    final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bd.compareTo(ad);
  });
  return shown;
}

enum SupporterAdminSort { date, name, amount }

/// Case-insensitive match on the name, message, or uid.
bool supporterAdminMatches(Supporter person, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [
    person.name,
    person.displayName,
    person.message,
    person.uid,
  ].any((part) => part.toLowerCase().contains(q));
}

/// Admin list order. Hidden rows stay in the list. Missing dates, names,
/// and amounts stay last. [ascending] false is giảm dần.
List<Supporter> sortSupporterAdmin(
  List<Supporter> rows,
  SupporterAdminSort sort, {
  bool ascending = false,
}) {
  final copy = [...rows];
  copy.sort((a, b) {
    final c = switch (sort) {
      SupporterAdminSort.date => _adminTime(
        a.date,
        b.date,
        ascending: ascending,
      ),
      SupporterAdminSort.name => _adminText(
        a.displayName,
        b.displayName,
        ascending: ascending,
      ),
      SupporterAdminSort.amount => _adminNum(
        a.hasAmount ? a.amount : null,
        b.hasAmount ? b.amount : null,
        ascending: ascending,
      ),
    };
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });
  return copy;
}

int _adminNum(int? a, int? b, {required bool ascending}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return ascending ? cmp : -cmp;
}

int _adminTime(DateTime? a, DateTime? b, {required bool ascending}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return ascending ? cmp : -cmp;
}

int _adminText(String a, String b, {required bool ascending}) {
  if (a.trim().isEmpty && b.trim().isEmpty) return 0;
  if (a.trim().isEmpty) return 1;
  if (b.trim().isEmpty) return -1;
  final cmp = a.toLowerCase().compareTo(b.toLowerCase());
  return ascending ? cmp : -cmp;
}

const supportPageSize = 50;

const storageBucket = 'tiem-hoa-som-mai.firebasestorage.app';

/// Public download URL for a Storage path. Preset codes (no "/") return null.
String? storageAvatarUrl(String avatar, {int? rev}) {
  if (!avatar.contains('/')) return null;
  final encoded = Uri.encodeComponent(avatar);
  final base =
      'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encoded?alt=media';
  return rev == null ? base : '$base&v=$rev';
}
