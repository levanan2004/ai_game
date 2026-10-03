import 'game_notice.dart';

/// One filled ô, with the label copied at send time so a later edit of
/// the notice does not rename an answer already stored.
class NoticeAnswer {
  const NoticeAnswer({
    required this.id,
    required this.label,
    required this.type,
    required this.value,
  });

  final String id;
  final String label;
  final NoticeInputType type;
  final String value;
}

/// One player's answer to a góp ý notice. The document id is
/// [noticeReplyId]. Each account sends one answer per notice.
class NoticeReply {
  const NoticeReply({
    required this.noticeId,
    required this.uid,
    required this.email,
    required this.name,
    required this.shopName,
    required this.answers,
    this.createdAt,
    this.updatedAt,
    this.approved = false,
    this.imageUrl,
  });

  final String noticeId;
  final String uid;
  final String email;
  final String name;
  final String shopName;
  final List<NoticeAnswer> answers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Admin mark on the stored form. Missing on older replies means chưa duyệt.
  final bool approved;

  /// Optional picture the player attached (Storage download URL).
  final String? imageUrl;

  NoticeReply copyWith({bool? approved}) {
    return NoticeReply(
      noticeId: noticeId,
      uid: uid,
      email: email,
      name: name,
      shopName: shopName,
      answers: answers,
      createdAt: createdAt,
      updatedAt: updatedAt,
      approved: approved ?? this.approved,
      imageUrl: imageUrl,
    );
  }
}

/// Reads and writes the signed-in player's own reply.
abstract class NoticeReplies {
  Future<NoticeReply?> mine(String noticeId, String uid);

  Future<void> submit(NoticeReply reply);
}

class UnavailableNoticeReplies implements NoticeReplies {
  const UnavailableNoticeReplies();

  @override
  Future<NoticeReply?> mine(String noticeId, String uid) async => null;

  @override
  Future<void> submit(NoticeReply reply) async {}
}

/// Admin list of every reply. Filtered in the page by notice.
abstract class NoticeReplyAdmin {
  Future<List<NoticeReply>> loadAll();

  /// Writes only the duyệt mark. The answers stay as the player sent them.
  Future<void> setApproved({
    required String noticeId,
    required String uid,
    required bool approved,
  });
}

String noticeReplyId(String noticeId, String uid) => '${noticeId}_$uid';

/// Digits only, so "100.000" is stored as "100000".
String noticeDigits(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

/// `100000` and `100.000` both display as `100.000`.
String noticeGroupedNumber(String raw) {
  final digits = noticeDigits(raw).replaceFirst(RegExp(r'^0+'), '');
  if (digits.isEmpty) return raw.trim().isEmpty ? '' : '0';
  final body = digits.length > 9 ? digits.substring(0, 9) : digits;
  final out = StringBuffer();
  for (var i = 0; i < body.length; i++) {
    if (i > 0 && (body.length - i) % 3 == 0) out.write('.');
    out.write(body[i]);
  }
  return out.toString();
}

String noticeStoredValue(NoticeInputType type, String raw) {
  final text = raw.trim();
  if (type == NoticeInputType.number) return noticeDigits(text);
  return text;
}

/// Null when [values] can be stored for [fields]. Keys are field ids.
String? noticeAnswersError({
  required List<NoticeField> fields,
  required Map<String, String> values,
}) {
  final defined = noticeFieldsError(fields);
  if (defined != null) return 'Thông báo này chưa có ô để điền.';
  for (final field in fields) {
    final value = noticeStoredValue(field.type, values[field.id] ?? '');
    if (field.required && value.isEmpty) return 'Điền "${field.label}".';
    if (value.isEmpty) continue;
    switch (field.type) {
      case NoticeInputType.number:
        final number = int.tryParse(value);
        if (number == null || number < 0 || number > maxNoticeNumber) {
          return '"${field.label}" cần là số từ 0 đến 100.000.000.';
        }
      case NoticeInputType.text:
        if (value.length > maxNoticeTextChars) {
          return '"${field.label}" tối đa $maxNoticeTextChars ký tự.';
        }
      case NoticeInputType.note:
        if (value.length > maxNoticeNoteChars) {
          return '"${field.label}" tối đa $maxNoticeNoteChars ký tự.';
        }
    }
  }
  return null;
}

/// Giá dùng khi duyệt tự động form quà đền bù.
const compensationFlowerXu = 150000;
const compensationPotXu = 1800000;
const compensationOtherXu = 150000;

/// Trên mức này thì không duyệt tự động. Admin sửa được trên trang form.
const compensationAutoSkipXu = 80000000;

/// True for the compensation notice, so other góp ý forms stay manual.
bool noticeIsCompensation(String title) => title.toLowerCase().contains('đền');

/// Xu, flowers, pots and other items read from the labels on the form.
class CompensationAmount {
  const CompensationAmount({
    required this.xu,
    required this.flowers,
    required this.pots,
    required this.other,
  });

  final int xu;
  final int flowers;
  final int pots;
  final int other;

  int get total =>
      xu +
      flowers * compensationFlowerXu +
      pots * compensationPotXu +
      other * compensationOtherXu;
}

CompensationAmount compensationAmount(NoticeReply reply) {
  return CompensationAmount(
    xu: _replyNumber(reply, RegExp('xu', caseSensitive: false)),
    flowers: _replyNumber(reply, RegExp('hoa', caseSensitive: false)),
    pots: _replyNumber(reply, RegExp('chậu|chau', caseSensitive: false)),
    other: _replyNumber(
      reply,
      RegExp('vật phẩm|vat pham', caseSensitive: false),
    ),
  );
}

/// Pending replies at or under [skipAbove] can be marked đã duyệt.
/// A total above [skipAbove] stays for a person to check.
bool compensationAutoApproves(NoticeReply reply, {required int skipAbove}) {
  if (reply.approved || skipAbove < 0) return false;
  return compensationAmount(reply).total <= skipAbove;
}

int _replyNumber(NoticeReply reply, RegExp label) {
  for (final answer in reply.answers) {
    if (!label.hasMatch(answer.label)) continue;
    final digits = noticeDigits(answer.value);
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }
  return 0;
}

/// Case-insensitive match on who sent the form and what they typed.
bool replyMatches(NoticeReply reply, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final answers = [
    for (final answer in reply.answers) '${answer.label} ${answer.value}',
  ].join(' ');
  return [
    reply.uid,
    reply.email,
    reply.name,
    reply.shopName,
    answers,
  ].any((part) => part.toLowerCase().contains(q));
}

/// Newest first when [ascending] is false. A missing time stays last.
List<NoticeReply> sortReplies(
  List<NoticeReply> rows, {
  bool ascending = false,
}) {
  final copy = [...rows];
  copy.sort((a, b) {
    final at = a.updatedAt ?? a.createdAt;
    final bt = b.updatedAt ?? b.createdAt;
    final c = _replyTime(at, bt, ascending: ascending);
    if (c != 0) return c;
    return a.uid.compareTo(b.uid);
  });
  return copy;
}

int _replyTime(DateTime? a, DateTime? b, {required bool ascending}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return ascending ? cmp : -cmp;
}

/// The answers a player sends, in the notice's field order.
List<NoticeAnswer> noticeAnswersFor({
  required List<NoticeField> fields,
  required Map<String, String> values,
}) {
  return [
    for (final field in fields)
      NoticeAnswer(
        id: field.id,
        label: field.label.trim(),
        type: field.type,
        value: noticeStoredValue(field.type, values[field.id] ?? ''),
      ),
  ];
}
