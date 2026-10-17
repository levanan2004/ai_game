import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/cloud_merge.dart';
import '../logic/pet.dart';
import '../logic/player_account.dart';
import '../logic/xu_grant.dart';

/// Joins `profiles` (name, email) with `users` (save, first login, grant).
class FirestoreAccountAdmin implements AccountAdmin {
  FirestoreAccountAdmin({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<PlayerAccount>> loadProfiles() async {
    final profiles = await _db.collection('profiles').get();
    return [
      for (final doc in profiles.docs)
        PlayerAccount(
          uid: doc.id,
          name: _text(doc.data()['name']),
          email: _text(doc.data()['email']),
          shopName: _text(doc.data()['shopName']),
        ),
    ];
  }

  @override
  Future<List<PlayerAccount>> loadSaves(List<String> uids) async {
    final ids = [
      for (final uid in uids)
        if (uid.isNotEmpty) uid,
    ];
    if (ids.isEmpty) return const [];
    final accounts = <PlayerAccount>[];
    for (var i = 0; i < ids.length; i += accountSaveBatch) {
      final end = i + accountSaveBatch > ids.length
          ? ids.length
          : i + accountSaveBatch;
      final refs = [
        for (final uid in ids.sublist(i, end)) _db.collection('users').doc(uid),
      ];
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: refs)
          .get();
      accounts.addAll([
        for (final doc in snap.docs) _fromUser(doc.id, doc.data()),
      ]);
    }
    return accounts;
  }

  @override
  Future<List<PlayerAccount>> findByEmail(String email) async {
    final typed = email.trim();
    if (typed.length < 2) return const [];
    final found = <String, PlayerAccount>{};
    for (final q in {typed, typed.toLowerCase()}) {
      final snap = await _db
          .collection('profiles')
          .orderBy('email')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(8)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        found[doc.id] = PlayerAccount(
          uid: doc.id,
          name: _text(data['name']),
          email: _text(data['email']),
          shopName: _text(data['shopName']),
        );
      }
    }
    if (found.isEmpty) return const [];
    final saves = await loadSaves(found.keys.toList());
    return mergeAccountSaves(found.values.toList(), saves);
  }

  @override
  Future<List<String>> markEstablished(List<PlayerAccount> rows) async {
    final marked = <String>[];
    for (final row in rows) {
      final day = row.day;
      if (row.joinedAt != null || day == null || day < establishedAccountDay) {
        continue;
      }
      final when = row.updatedAt ?? DateTime.now();
      try {
        await _db.collection('users').doc(row.uid).update({
          'joinedAt': Timestamp.fromDate(when),
        });
        marked.add(row.uid);
      } catch (_) {}
    }
    return marked;
  }

  @override
  Future<void> grant({
    required String uid,
    required int money,
    int? day,
    required String note,
  }) async {
    final clean = note.trim();
    if (uid.isEmpty ||
        money < 0 ||
        money > maxGrantMoney ||
        (day != null && (day < 1 || day > maxGrantDay)) ||
        (money == 0 && day == null) ||
        clean.length > 200) {
      throw ArgumentError('grant');
    }
    await _db.collection('users').doc(uid).set({
      'grant': {
        'id': _db.collection('users').doc().id,
        'money': money,
        'note': clean,
        'day': ?day,
      },
    }, SetOptions(merge: true));
  }

  @override
  Future<PetGiftBox> sendGift({
    required String uid,
    required Map<String, int> items,
    required String note,
  }) async {
    final clean = note.trim();
    final sending = sanitizeGiftItems(items);
    if (uid.isEmpty || sending.isEmpty || clean.length > 200) {
      throw ArgumentError('gift');
    }
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final waiting = giftFromMap(data['gift']);
    final progress = data['progress'];
    final applied = progress is Map && progress['appliedGiftId'] is String
        ? progress['appliedGiftId'] as String
        : '';
    final base = waiting != null && waiting.id != applied
        ? waiting.items
        : const <String, int>{};
    final merged = combineGiftItems(base, sending);
    final box = PetGiftBox(
      id: _db.collection('users').doc().id,
      items: merged,
      note: clean,
    );
    await ref.set({
      'gift': {'id': box.id, 'note': box.note, 'items': box.items},
    }, SetOptions(merge: true));
    return box;
  }
}

PlayerAccount _fromUser(String uid, Map<String, dynamic> data) {
  final progress = data['progress'];
  final map = progress is Map ? progress : null;
  final shop = _text(map?['shopName']);
  final applied = _text(map?['appliedGrantId']);
  return PlayerAccount(
    uid: uid,
    shopName: shop,
    money: _int(map?['money']),
    day: _int(map?['day']),
    bouquets: _int(map?['lifetimeBouquetsSold']) ?? 0,
    joinedAt: _time(data['joinedAt']),
    updatedAt: _time(data['updatedAt']),
    grant: grantFromMap(data['grant']),
    appliedGrantId: applied.isEmpty ? null : applied,
    gift: giftFromMap(data['gift']),
    appliedGiftId: _text(map?['appliedGiftId']).isEmpty
        ? null
        : _text(map?['appliedGiftId']),
    pocket: PetPocket.fromProgress(map),
  );
}

String _text(Object? value) => value is String ? value : '';

int? _int(Object? value) => value is num ? value.toInt() : null;

DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;
