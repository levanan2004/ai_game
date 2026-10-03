/// `read` is a normal announcement. `form` asks the player to fill
/// the inputs the admin defined on that notice. `feedback` (stored as
/// `feedback`) opens the fixed Góp ý popup (SPEC_gop_y.md) and has no
/// inputs of its own.
enum NoticeKind { read, form, feedback }

/// Form and Góp ý notices take one reply per account.
bool noticeTakesReplies(NoticeKind kind) => kind != NoticeKind.read;

/// What the player types into one ô.
enum NoticeInputType { number, text, note }

/// A number ô accepts digits from 0 up to this, nine digits at most.
const maxNoticeNumber = 100000000;

/// A short-text ô.
const maxNoticeTextChars = 80;

/// A paragraph ô.
const maxNoticeNoteChars = 300;

/// One ô on a góp ý notice. [id] stays put when the label is edited,
/// so an answer already sent still lines up.
class NoticeField {
  const NoticeField({
    required this.id,
    required this.label,
    required this.type,
    this.required = true,
  });

  final String id;
  final String label;
  final NoticeInputType type;
  final bool required;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label.trim(),
    'type': type.name,
    'required': required,
  };
}

const maxNoticeFields = 8;

String noticeInputLabel(NoticeInputType type) => switch (type) {
  NoticeInputType.number => 'Số',
  NoticeInputType.text => 'Chữ ngắn',
  NoticeInputType.note => 'Đoạn chữ',
};

/// What the player may type into an ô of [type]. Shown next to the
/// admin's type picker.
String noticeInputLimit(NoticeInputType type) => switch (type) {
  NoticeInputType.number => 'User nhập số từ 0 đến 100.000.000',
  NoticeInputType.text => 'User nhập tối đa $maxNoticeTextChars ký tự',
  NoticeInputType.note => 'User nhập tối đa $maxNoticeNoteChars ký tự',
};

/// Null when a form notice may store [fields].
String? noticeFieldsError(List<NoticeField> fields) {
  if (fields.isEmpty) return 'Thêm ít nhất một ô.';
  if (fields.length > maxNoticeFields) return 'Tối đa $maxNoticeFields ô.';
  final ids = <String>{};
  for (final field in fields) {
    final label = field.label.trim();
    if (label.isEmpty || label.length > 40) {
      return 'Nhãn mỗi ô từ 1 đến 40 ký tự.';
    }
    if (field.id.length < 4 || field.id.length > 40 || !ids.add(field.id)) {
      return 'Ô không hợp lệ.';
    }
  }
  return null;
}

NoticeInputType noticeInputTypeOf(Object? raw) => switch (raw) {
  'text' => NoticeInputType.text,
  'note' => NoticeInputType.note,
  _ => NoticeInputType.number,
};

/// Drops a broken ô. An empty list means the notice has nothing to fill.
List<NoticeField> noticeFieldsFrom(Object? raw) {
  if (raw is! List) return const [];
  final fields = <NoticeField>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = item['id'];
    final label = item['label'];
    if (id is! String || label is! String) continue;
    final cleanId = id.trim();
    final cleanLabel = label.trim();
    if (cleanId.length < 4 || cleanLabel.isEmpty) continue;
    fields.add(
      NoticeField(
        id: cleanId,
        label: cleanLabel,
        type: noticeInputTypeOf(item['type']),
        required: item['required'] != false,
      ),
    );
    if (fields.length == maxNoticeFields) break;
  }
  return fields;
}

/// One in-game announcement (`notices/{id}`).
class GameNotice {
  const GameNotice({
    required this.id,
    required this.title,
    required this.body,
    this.link,
    this.linkLabel,
    this.createdAt,
    this.visible = true,
    this.kind = NoticeKind.read,
    this.fields = const [],
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;

  final NoticeKind kind;

  /// Empty unless [kind] is [NoticeKind.form].
  final List<NoticeField> fields;

  /// `https://…`, `http://…`, or a site path such as `/about`.
  final String? link;

  /// Button text. Empty means "Mở liên kết".
  final String? linkLabel;
  final DateTime? createdAt;
  final bool visible;

  /// Optional picture (`https://…`) shown above the body.
  final String? imageUrl;

  String get buttonLabel {
    final label = linkLabel?.trim() ?? '';
    return label.isEmpty ? 'Mở liên kết' : label;
  }
}

/// Public list of notices that are turned on.
abstract class NoticeBoard {
  Future<List<GameNotice>> published();
}

class EmptyNoticeBoard implements NoticeBoard {
  const EmptyNoticeBoard();

  @override
  Future<List<GameNotice>> published() async => const [];
}

/// Admin create, edit, and delete. The rules still reject non-admins.
abstract class NoticeAdmin {
  String newId();
  Future<List<GameNotice>> loadAll();
  Future<void> save(GameNotice notice);
  Future<void> delete(String id);
}

/// `https://…`, `http://…`, or a same-site path. Anything else is refused
/// so a notice cannot open `javascript:` or a protocol the game does not use.
String? normalizeNoticeLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (text.startsWith('/') && !text.startsWith('//') && !text.contains(' ')) {
    return text;
  }
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri.toString();
}

/// Only https pictures, under 500 characters. Anything else is dropped.
/// Used by notices and mails.
String? normalizeImageUrl(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty || text.length >= 500) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return text;
}

enum NoticeListSort { created, title }

/// Case-insensitive match on the title or the body.
bool noticeMatches(GameNotice notice, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return notice.title.toLowerCase().contains(q) ||
      notice.body.toLowerCase().contains(q);
}

/// Missing dates and empty titles stay last. [ascending] false puts a
/// newer notice, or a title later in the alphabet, first.
List<GameNotice> sortNotices(
  List<GameNotice> rows,
  NoticeListSort sort, {
  bool ascending = false,
}) {
  final copy = [...rows];
  copy.sort((a, b) {
    final c = switch (sort) {
      NoticeListSort.created => _noticeTime(
        a.createdAt,
        b.createdAt,
        ascending: ascending,
      ),
      NoticeListSort.title => _noticeText(
        a.title,
        b.title,
        ascending: ascending,
      ),
    };
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });
  return copy;
}

int _noticeTime(DateTime? a, DateTime? b, {required bool ascending}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return ascending ? cmp : -cmp;
}

int _noticeText(String a, String b, {required bool ascending}) {
  if (a.trim().isEmpty && b.trim().isEmpty) return 0;
  if (a.trim().isEmpty) return 1;
  if (b.trim().isEmpty) return -1;
  final cmp = a.toLowerCase().compareTo(b.toLowerCase());
  return ascending ? cmp : -cmp;
}

String noticeDateLabel(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month';
}

int compareNotices(GameNotice a, GameNotice b) {
  final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bd.compareTo(ad);
}
