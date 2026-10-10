import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/giftcodes.dart';
import '../logic/login_rewards.dart';
import '../logic/welfare.dart';
import '../logic/welfare_slides.dart';

DateTime? _date(Object? raw) => raw is Timestamp ? raw.toDate() : null;

/// DateTime to Timestamp, everything else unchanged.
Map<String, Object?> _stamps(Map<String, Object?> map) => {
  for (final e in map.entries)
    e.key: switch (e.value) {
      final DateTime d => Timestamp.fromDate(d),
      final other => other,
    },
};

const _configPath = 'config/loginRewards';
const _slidesLimit = 30;

/// Player side of Phúc lợi:
/// `config/loginRewards`, `users/{uid}/welfare/login`,
/// `giftcodes/{CODE}` + `giftcodeBatches/{id}` + `users/{uid}/redeemed/{batchId}`,
/// and `slides/{id}`.
class FirestoreWelfare implements WelfareService {
  FirestoreWelfare({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _login(String uid) =>
      _db.collection('users').doc(uid).collection('welfare').doc('login');

  @override
  Future<LoginRewardConfig?> loginConfig() async {
    final snap = await _db.doc(_configPath).get();
    return LoginRewardConfig.fromMap(snap.data());
  }

  @override
  Future<LoginState> loginState(String uid) async =>
      LoginState.fromMap((await _login(uid).get()).data());

  @override
  Future<LoginClaimOutcome> claimLogin(
    String uid,
    LoginRewardConfig config,
    DateTime now,
  ) async {
    final ref = _login(uid);
    try {
      return await _db.runTransaction((tx) async {
        final state = LoginState.fromMap((await tx.get(ref)).data());
        final plan = planLogin(state, config, vnDayNumber(now));
        final next = plan.next;
        if (next == null) {
          return LoginClaimOutcome(
            plan.finished
                ? LoginClaimResult.finished
                : LoginClaimResult.already,
            state,
          );
        }
        tx.set(ref, {
          ...next.toMap(),
          'lastClaimDate': vnDateKey(now),
          'lastClaimAt': FieldValue.serverTimestamp(),
        });
        return LoginClaimOutcome(LoginClaimResult.claimed, next, day: plan.day);
      });
    } on FirebaseException catch (e) {
      // Refused by the rules: another tab won the day, or this device's
      // clock is on another day than the server.
      var state = LoginState.none;
      try {
        state = await loginState(uid);
      } catch (_) {}
      if (e.code == 'permission-denied' &&
          state.lastClaimDay == vnDayNumber(now)) {
        return LoginClaimOutcome(LoginClaimResult.already, state);
      }
      return LoginClaimOutcome(LoginClaimResult.failed, state);
    }
  }

  @override
  Future<RedeemOutcome> redeem(String uid, String code, DateTime now) async {
    final codeRef = _db.collection('giftcodes').doc(code);
    try {
      return await _db.runTransaction((tx) async {
        final doc = GiftcodeDoc.fromMap(code, (await tx.get(codeRef)).data());
        if (doc == null) return RedeemOutcome(RedeemResult.invalid);
        final batchRef = _db.collection('giftcodeBatches').doc(doc.batchId);
        final batchSnap = await tx.get(batchRef);
        final batch = batchSnap.exists
            ? GiftcodeBatch.fromMap(doc.batchId, batchSnap.data()!, date: _date)
            : null;
        final mine = _db
            .collection('users')
            .doc(uid)
            .collection('redeemed')
            .doc(doc.batchId);
        final redeemed = (await tx.get(mine)).exists;
        final problem = checkRedeem(
          code: doc,
          batch: batch,
          redeemedBatch: redeemed,
          uid: uid,
          now: now,
        );
        if (problem != null) return RedeemOutcome(problem, code: code);
        if (doc.type == GiftcodeType.single) {
          tx.update(codeRef, {
            'usedBy': uid,
            'usedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(codeRef, {'uses': doc.uses + 1});
        }
        tx.set(mine, {
          'code': code,
          'redeemedAt': FieldValue.serverTimestamp(),
        });
        return RedeemOutcome(
          RedeemResult.success,
          rewards: batch!.rewards,
          code: code,
        );
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return RedeemOutcome(RedeemResult.invalid);
      // The rules refused: the server clock disagrees on dates, or another
      // tab redeemed first. Nothing was added.
      return RedeemOutcome(RedeemResult.failed, code: code);
    }
  }

  @override
  Future<List<WelfareSlide>> slides() async {
    final snap = await _db.collection('slides').limit(_slidesLimit).get();
    return [
      for (final doc in snap.docs) ?WelfareSlide.fromMap(doc.id, doc.data()),
    ];
  }
}

/// Admin side: the login table, giftcodes and slides.
class FirestoreWelfareAdmin implements WelfareAdmin {
  FirestoreWelfareAdmin({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _batches =>
      _db.collection('giftcodeBatches');
  CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('giftcodes');
  CollectionReference<Map<String, dynamic>> get _slides =>
      _db.collection('slides');

  @override
  Future<LoginRewardConfig?> loadLoginConfig() async {
    final raw = (await _db.doc(_configPath).get()).data();
    if (LoginRewardConfig.isLegacyMap(raw)) throw const LegacyLoginConfig();
    return LoginRewardConfig.fromMap(raw);
  }

  @override
  Future<void> saveLoginConfig(LoginRewardConfig config) => _db
      .doc(_configPath)
      .set({...config.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  String newBatchId() => _batches.doc().id;

  @override
  Future<List<GiftcodeBatch>> loadBatches() async {
    final snap = await _batches
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final doc in snap.docs)
        ?GiftcodeBatch.fromMap(doc.id, doc.data(), date: _date),
    ];
  }

  @override
  Future<bool> codeExists(String code) async =>
      (await _codes.doc(code).get()).exists;

  Map<String, Object?> _batchMap(GiftcodeBatch batch) => {
    ..._stamps(batch.toMap()),
    'createdAt': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> createShared(GiftcodeBatch batch) async {
    final code = batch.code!;
    final write = _db.batch();
    write.set(_batches.doc(batch.id), _batchMap(batch));
    write.set(_codes.doc(code), {
      ...GiftcodeDoc(
        code: code,
        type: GiftcodeType.shared,
        batchId: batch.id,
        maxUses: batch.maxUses,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await write.commit();
  }

  @override
  Future<void> createBulk(
    GiftcodeBatch batch,
    List<String> codes, {
    void Function(int written)? onProgress,
  }) async {
    await _batches.doc(batch.id).set(_batchMap(batch));
    var written = 0;
    for (var start = 0; start < codes.length; start += giftcodeWriteChunk) {
      final end = (start + giftcodeWriteChunk).clamp(0, codes.length);
      final write = _db.batch();
      for (final code in codes.sublist(start, end)) {
        write.set(_codes.doc(code), {
          'type': GiftcodeType.single.name,
          'batchId': batch.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await write.commit();
      written = end;
      onProgress?.call(written);
    }
  }

  @override
  Future<void> setBatchEnabled(String batchId, bool enabled) =>
      _batches.doc(batchId).update({'enabled': enabled});

  @override
  Future<List<GiftcodeRow>> exportBatch(String batchId) async {
    final snap = await _codes
        .where('batchId', isEqualTo: batchId)
        .limit(maxGiftcodeBatch)
        .get();
    final rows = [
      for (final doc in snap.docs)
        GiftcodeRow(
          doc.id,
          usedBy: doc.data()['usedBy'] is String
              ? doc.data()['usedBy'] as String
              : null,
        ),
    ];
    rows.sort((a, b) => a.code.compareTo(b.code));
    return rows;
  }

  @override
  String newSlideId() => _slides.doc().id;

  @override
  Future<List<WelfareSlide>> loadSlides() async {
    final snap = await _slides.limit(100).get();
    return sortSlides([
      for (final doc in snap.docs) ?WelfareSlide.fromMap(doc.id, doc.data()),
    ]);
  }

  @override
  Future<void> saveSlide(WelfareSlide slide) => _slides.doc(slide.id).set({
    ...slide.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> deleteSlide(String id) => _slides.doc(id).delete();
}
