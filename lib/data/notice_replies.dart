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
    await ref.set({
      'noticeId': reply.noticeId,
      'uid': reply.uid,
      'email': _clip(reply.email, 119),
      'name': _clip(reply.name, 79),
      'shopName': _clip(reply.shopName, 39),
      'answers': [
        for (final answer in reply.answers)
          {
            'id': _clip(answer.id, 40),
            'label': _clip(answer.label, 40),
            'type': answer.type.name,
            'value': _clip(answer.value, 300),
          },
      ],
      'createdAt': created ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
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
  );
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
