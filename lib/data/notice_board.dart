import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/game_notice.dart';

/// `notices/{id}` for players (visible rows) and for the admin page.
class FirestoreNoticeBoard implements NoticeBoard {
  FirestoreNoticeBoard({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notices =>
      _db.collection('notices');

  @override
  Future<List<GameNotice>> published() async {
    final snap = await _notices
        .where('visible', isEqualTo: true)
        .limit(40)
        .get();
    final list = [
      for (final doc in snap.docs) ?_read(doc.id, doc.data(), players: true),
    ];
    list.sort(compareNotices);
    return list;
  }
}

class FirestoreNoticeAdmin implements NoticeAdmin {
  FirestoreNoticeAdmin({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notices =>
      _db.collection('notices');

  @override
  String newId() => _notices.doc().id;

  @override
  Future<List<GameNotice>> loadAll() async {
    final snap = await _notices.get();
    final list = [
      for (final doc in snap.docs) ?_read(doc.id, doc.data(), players: false),
    ];
    list.sort(compareNotices);
    return list;
  }

  @override
  Future<void> save(GameNotice notice) async {
    final link = normalizeNoticeLink(notice.link ?? '');
    final label = notice.linkLabel?.trim() ?? '';
    final labelOrNull = link != null && label.isNotEmpty ? label : null;
    await _notices.doc(notice.id).set({
      'title': notice.title.trim(),
      'body': notice.body.trim(),
      'visible': notice.visible,
      'kind': notice.kind.name,
      if (notice.kind == NoticeKind.form)
        'fields': [for (final field in notice.fields) field.toJson()],
      'createdAt': notice.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(notice.createdAt!),
      'link': ?link,
      'linkLabel': ?labelOrNull,
      'imageUrl': ?normalizeImageUrl(notice.imageUrl),
    });
  }

  @override
  Future<void> delete(String id) => _notices.doc(id).delete();
}

GameNotice? _read(
  String id,
  Map<String, dynamic> data, {
  required bool players,
}) {
  final title = data['title'];
  final body = data['body'];
  if (title is! String || body is! String) return null;
  if (title.trim().isEmpty || body.trim().isEmpty) return null;
  final visible = data['visible'] == true;
  if (players && !visible) return null;
  final rawLink = data['link'];
  final link = rawLink is String ? normalizeNoticeLink(rawLink) : null;
  final rawLabel = data['linkLabel'];
  final created = data['createdAt'];
  return GameNotice(
    id: id,
    title: title.trim(),
    body: body.trim(),
    link: link,
    linkLabel: rawLabel is String ? rawLabel.trim() : null,
    createdAt: created is Timestamp ? created.toDate() : null,
    visible: visible,
    kind: switch (data['kind']) {
      'form' => NoticeKind.form,
      'feedback' => NoticeKind.feedback,
      _ => NoticeKind.read,
    },
    fields: data['kind'] == 'form'
        ? noticeFieldsFrom(data['fields'])
        : const [],
    imageUrl: normalizeImageUrl(
      data['imageUrl'] is String ? data['imageUrl'] as String : null,
    ),
  );
}
