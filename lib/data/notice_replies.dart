import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/game_notice.dart';
import '../logic/notice_reply.dart';

/// The signed-in player's reply on `notice_replies/{noticeId}_{uid}`.
class FirestoreNoticeReplies implements NoticeReplies {
  FirestoreNoticeReplies({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _replies =>
      _db.collection('notice_replies');

  @override
  Future<NoticeReply?> mine(String noticeId, String uid) async {
    if (noticeId.isEmpty || uid.isEmpty) return null;
    final snap = await _replies.doc(noticeReplyId(noticeId, uid)).get();
    final data = snap.data();
    if (data == null) return null;
    return _read(data);
  }

  @override
  Future<void> submit(NoticeReply reply) async {
    final ref = _replies.doc(noticeReplyId(reply.noticeId, reply.uid));
    // A first reply has no document yet. Reading it is denied, and that
    // must not block the write.
    Timestamp? created;
    try {
      final existing = await ref.get();
      final raw = existing.data()?['createdAt'];
      if (raw is Timestamp) created = raw;
    } catch (_) {}
    try {
      await ref.set(replyDocument(reply, created: created));
    } on FirebaseException catch (e) {
      // Rules from before the Góp ý form do not know type / message /
      // progress. Until they are deployed, send the note as an answer row
      // (cut to 300) so the reply still arrives.
      if (e.code != 'permission-denied' || !_hasFeedbackFields(reply)) rethrow;
      await ref.set(replyDocument(reply, created: created, legacy: true));
    }
  }
}

bool _hasFeedbackFields(NoticeReply reply) =>
    reply.feedbackType != null || reply.message != null;

/// The `notice_replies` document for [reply]. [legacy] leaves out the Góp ý
/// fields and carries the note in the answers instead.
Map<String, Object?> replyDocument(
  NoticeReply reply, {
  Timestamp? created,
  bool legacy = false,
}) {
  final answers = [
    for (final answer in reply.answers)
      {
        'id': _clip(answer.id, 40),
        'label': _clip(answer.label, 40),
        'type': answer.type.name,
        'value': _clip(
          answer.value,
          answer.type == NoticeInputType.text ? 80 : 300,
        ),
      },
    if (legacy && (reply.message ?? '').trim().isNotEmpty)
      {
        'id': 'loi_nhan',
        'label': 'Lời nhắn',
        'type': NoticeInputType.note.name,
        'value': _clip(reply.message!, 300),
      },
  ];
  final progress = reply.progress;
  return {
    'noticeId': reply.noticeId,
    'uid': reply.uid,
    'email': _clip(reply.email, 119),
    'name': _clip(reply.name, 79),
    'shopName': _clip(reply.shopName, 39),
    'answers': answers.length > 8 ? answers.sublist(0, 8) : answers,
    'createdAt': created ?? FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'imageUrl': ?_photo(reply.imageUrl),
    if (!legacy && reply.feedbackType != null) 'type': reply.feedbackType,
    if (!legacy && reply.message != null)
      'message': _clip(reply.message!, maxFeedbackChars),
    if (!legacy && progress != null) 'progress': progress,
  };
}

/// Every reply, for the admin page. The page groups them by notice.
class FirestoreNoticeReplyAdmin implements NoticeReplyAdmin {
  FirestoreNoticeReplyAdmin({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<NoticeReply>> loadAll() async {
    final replies = <NoticeReply>[];
    var query = _db.collection('notice_replies').limit(300);
    while (true) {
      final snap = await query.get();
      replies.addAll([for (final doc in snap.docs) ?_read(doc.data())]);
      if (snap.docs.length < 300) return replies;
      query = _db
          .collection('notice_replies')
          .limit(300)
          .startAfterDocument(snap.docs.last);
    }
  }

  @override
  Future<void> setApproved({
    required String noticeId,
    required String uid,
    required bool approved,
  }) async {
    if (noticeId.isEmpty || uid.isEmpty) return;
    await _db
        .collection('notice_replies')
        .doc(noticeReplyId(noticeId, uid))
        .update({'approved': approved});
  }
}

/// A Storage download URL. Anything else is not stored.
String? _photo(String? url) {
  final text = url?.trim() ?? '';
  if (text.isEmpty || text.length >= 1000) return null;
  return text.startsWith('https://') ? text : null;
}

String _clip(String value, int max) {
  final text = value.trim();
  return text.length <= max ? text : text.substring(0, max);
}

NoticeReply? _read(Map<String, dynamic> data) {
  final noticeId = data['noticeId'];
  final uid = data['uid'];
  if (noticeId is! String || uid is! String) return null;
  if (noticeId.isEmpty || uid.isEmpty) return null;
  final created = data['createdAt'];
  final updated = data['updatedAt'];
  return NoticeReply(
    noticeId: noticeId,
    uid: uid,
    email: data['email'] is String ? data['email'] as String : '',
    name: data['name'] is String ? data['name'] as String : '',
    shopName: data['shopName'] is String ? data['shopName'] as String : '',
    answers: _answers(data['answers']),
    createdAt: created is Timestamp ? created.toDate() : null,
    updatedAt: updated is Timestamp ? updated.toDate() : null,
    approved: data['approved'] == true,
    imageUrl: _photo(
      data['imageUrl'] is String ? data['imageUrl'] as String : null,
    ),
    feedbackType: data['type'] is String ? data['type'] as String : null,
    message: data['message'] is String ? data['message'] as String : null,
    progress: _progress(data['progress']),
  );
}

Map<String, int?>? _progress(Object? raw) {
  if (raw is! Map) return null;
  return {
    for (final f in feedbackProgressFields)
      f.key: raw[f.key] is num ? (raw[f.key] as num).toInt() : null,
  };
}

List<NoticeAnswer> _answers(Object? raw) {
  if (raw is! List) return const [];
  final answers = <NoticeAnswer>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = item['id'];
    final label = item['label'];
    if (id is! String || label is! String || id.isEmpty) continue;
    answers.add(
      NoticeAnswer(
        id: id,
        label: label,
        type: noticeInputTypeOf(item['type']),
        value: item['value'] is String ? item['value'] as String : '',
      ),
    );
  }
  return answers;
}
