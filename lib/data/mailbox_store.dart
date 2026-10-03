import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/mailbox.dart';

DateTime? _date(Object? raw) => raw is Timestamp ? raw.toDate() : null;

GameMail? _read(String id, Map<String, dynamic> data) =>
    mailFromMap(id, data, date: _date);

/// Player side: `mails/{id}` sent to the player or to everyone, and the
/// player's own marks on `users/{uid}/mailState/{mailId}`.
class FirestoreMailbox implements MailService {
  FirestoreMailbox({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _mails =>
      _db.collection('mails');

  CollectionReference<Map<String, dynamic>> _marks(String uid) =>
      _db.collection('users').doc(uid).collection('mailState');

  @override
  Future<List<GameMail>> inbox(String uid) async {
    // Two equality queries (no composite index). The rules allow each one
    // because every row they return is addressed to this player.
    final results = await Future.wait([
      _mails.where('target', isEqualTo: mailToAll).limit(mailInboxLimit).get(),
      _mails.where('target', isEqualTo: uid).limit(mailInboxLimit).get(),
    ]);
    return [
      for (final snap in results)
        for (final doc in snap.docs) ?_read(doc.id, doc.data()),
    ];
  }

  @override
  Future<Map<String, MailState>> states(String uid) async {
    final snap = await _marks(uid).limit(500).get();
    return {
      for (final doc in snap.docs)
        doc.id: MailState(
          read: doc.data()['read'] == true,
          claimed: doc.data()['claimed'] == true,
        ),
    };
  }

  @override
  Future<void> markRead(String uid, String mailId) async {
    final ref = _marks(uid).doc(mailId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data?['read'] == true || data?['claimed'] == true) return;
      tx.set(ref, {
        'read': true,
        'claimed': false,
        'readAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<MailClaimResult> claim(String uid, String mailId) async {
    final ref = _marks(uid).doc(mailId);
    try {
      return await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.data()?['claimed'] == true) return MailClaimResult.already;
        tx.set(ref, {
          'read': true,
          'claimed': true,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        return MailClaimResult.claimed;
      });
    } on FirebaseException catch (e) {
      // A rejected write after another tab claimed reads as already.
      if (e.code == 'permission-denied') {
        try {
          final snap = await ref.get();
          if (snap.data()?['claimed'] == true) return MailClaimResult.already;
        } catch (_) {}
      }
      return MailClaimResult.failed;
    }
  }
}

/// Admin side of `mails/{id}`.
class FirestoreMailAdmin implements MailAdmin {
  FirestoreMailAdmin({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _mails =>
      _db.collection('mails');

  @override
  String newId() => _mails.doc().id;

  @override
  Future<List<GameMail>> loadAll() async {
    final snap = await _mails.limit(200).get();
    return sortMails([for (final doc in snap.docs) ?_read(doc.id, doc.data())]);
  }

  @override
  Future<void> send(GameMail mail) async {
    final map = mailToMap(mail);
    await _mails.doc(mail.id).set({
      for (final e in map.entries)
        e.key: switch (e.value) {
          final DateTime d => Timestamp.fromDate(d),
          null => FieldValue.serverTimestamp(),
          final other => other,
        },
    });
  }

  @override
  Future<void> delete(String id) => _mails.doc(id).delete();
}
