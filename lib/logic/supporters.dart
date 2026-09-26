import 'dart:typed_data';

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
  });

  final String id;
  final String name;
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
}) {
  return Supporter(
    id: id,
    name: name is String ? name : '',
    message: message is String ? message : '',
    date: date,
    visible: visible != false,
    avatar: avatar is String ? avatar : '',
    amount: amount is num ? amount.toInt() : null,
  );
}

/// Client-side order from firebase_backend.md.
///
/// Do not `orderBy('amount')`: Firestore drops documents missing the field.
/// People with an amount come first, highest first. The same amount puts the
/// newer [Supporter.date] above. No amount (null or 0) sits at the bottom,
/// newest first. `visible == false` is left out.
List<Supporter> sortSupporters(List<Supporter> all) {
  final shown = all.where((s) => s.visible).toList();
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

const supportPageSize = 50;

const storageBucket = 'tiem-hoa-som-mai.firebasestorage.app';

/// Public download URL for a Storage path. Preset codes (no "/") return null.
String? storageAvatarUrl(String avatar) {
  if (!avatar.contains('/')) return null;
  final encoded = Uri.encodeComponent(avatar);
  return 'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encoded?alt=media';
}
