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
