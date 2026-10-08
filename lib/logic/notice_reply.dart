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
    this.imageUrls = const [],
    this.feedbackType,
    this.message,
    this.progress,
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

  /// Every picture on the reply. Empty replies that only stored [imageUrl]
  /// still count that one.
  final List<String> imageUrls;

  List<String> get photos {
    if (imageUrls.isNotEmpty) return imageUrls;
    final one = imageUrl;
    if (one == null || one.isEmpty) return const [];
    return [one];
  }

  /// Góp ý form (SPEC_gop_y.md): `bao_loi`, `y_tuong` or `khac`. Null on
  /// replies to older forms.
  final String? feedbackType;

  /// The player's note, up to [maxFeedbackChars]. Null on older replies.
  final String? message;

  /// Only with `bao_loi`: days, coins, flowersOpened, potsOpened,
  /// otherItems. A blank ô is null.
  final Map<String, int?>? progress;

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
      imageUrls: imageUrls,
      feedbackType: feedbackType,
      message: message,
      progress: progress,
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
    reply.message ?? '',
    feedbackTypeOf(reply.feedbackType)?.label ?? '',
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

// ---- Góp ý form (SPEC_gop_y.md) -------------------------------------------

/// The note may be longer while typing; sending needs at most this many.
const maxFeedbackChars = 1000;

/// The three chips. Copy by Nhất.
enum FeedbackType {
  baoLoi(
    'bao_loi',
    'Báo lỗi',
    'Kể giúp mình chuyện gì đã xảy ra, lúc bạn đang làm gì nhé.',
  ),
  yTuong('y_tuong', 'Ý tưởng', 'Bạn muốn tiệm có thêm gì nào?'),
  khac('khac', 'Khác', 'Gõ điều bạn muốn nói ở đây nhé.');

  const FeedbackType(this.code, this.label, this.hint);

  /// Stored as `type`.
  final String code;
  final String label;
  final String hint;
}

FeedbackType? feedbackTypeOf(String? code) {
  for (final t in FeedbackType.values) {
    if (t.code == code) return t;
  }
  return null;
}

const feedbackMessageLabel = 'Bạn muốn nhắn gì cho tiệm?';
const feedbackTooLong = 'Hơi dài rồi, bạn rút gọn dưới 1000 ký tự nhé.';
const feedbackProgressTitle = 'Tiến độ của bạn';
const feedbackProgressNote =
    'Không bắt buộc, nhưng giúp tụi mình tìm lỗi nhanh hơn.';
const feedbackPhotoLabel = 'Ảnh chụp màn hình (không bắt buộc)';
const feedbackSentToast = 'Đã gửi rồi! Cảm ơn bạn đã giúp tiệm tốt hơn.';
const feedbackFailedToast = 'Chưa gửi được, bạn thử lại sau chút nhé.';

/// One ô of the "Tiến độ của bạn" group. [key] is the `progress` field;
/// [id] and [label] are the answer row the admin page and the
/// compensation check already read ("Số xu", "Số hoa đã mở", …).
class FeedbackProgressField {
  const FeedbackProgressField(this.key, this.id, this.label, this.hint);

  final String key;
  final String id;
  final String label;
  final String hint;
}

const feedbackProgressFields = [
  FeedbackProgressField('days', 'so_ngay', 'Số ngày', 'Ví dụ: 30'),
  FeedbackProgressField('coins', 'so_xu', 'Số xu', 'Ví dụ: 50000'),
  FeedbackProgressField('flowersOpened', 'so_hoa', 'Số hoa đã mở', 'Ví dụ: 30'),
  FeedbackProgressField('potsOpened', 'so_chau', 'Số chậu đã mở', 'Ví dụ: 30'),
  FeedbackProgressField('otherItems', 'vat_pham', 'Vật phẩm khác', 'Ví dụ: 30'),
];

/// Characters as the counter shows them.
int feedbackLength(String message) => message.length;

/// `12/1000`, `1.043/1000`.
String feedbackCounter(int n) =>
    '${n >= 1000 ? noticeGroupedNumber('$n') : '$n'}/$maxFeedbackChars';

bool feedbackTooLongFor(String message) =>
    feedbackLength(message) > maxFeedbackChars;

/// Gửi is on only with a note that is not blank and not too long, and
/// while nothing is being sent.
bool feedbackCanSend(String message, {required bool busy}) =>
    !busy && message.trim().isNotEmpty && !feedbackTooLongFor(message);

/// The progress map for `bao_loi`, keyed by [FeedbackProgressField.key].
/// Blank or unreadable ô are null. Other kinds send none.
Map<String, int?>? feedbackProgress(
  FeedbackType type,
  Map<String, String> raw,
) {
  if (type != FeedbackType.baoLoi) return null;
  return {
    for (final f in feedbackProgressFields)
      f.key: _progressNumber(raw[f.key] ?? ''),
  };
}

int? _progressNumber(String raw) {
  final digits = noticeDigits(raw);
  if (digits.isEmpty) return null;
  final n = int.tryParse(digits.length > 9 ? digits.substring(0, 9) : digits);
  if (n == null || n > maxNoticeNumber) return null;
  return n;
}

/// Answer rows kept for the admin list and the compensation check: the
/// kind first (the reply rules need at least one row), then the filled
/// progress numbers.
List<NoticeAnswer> feedbackAnswers(
  FeedbackType type,
  Map<String, int?>? progress,
) {
  return [
    NoticeAnswer(
      id: 'loai',
      label: 'Kiểu',
      type: NoticeInputType.text,
      value: type.label,
    ),
    if (progress != null)
      for (final f in feedbackProgressFields)
        if (progress[f.key] != null)
          NoticeAnswer(
            id: f.id,
            label: f.label,
            type: NoticeInputType.number,
            value: '${progress[f.key]}',
          ),
  ];
}
