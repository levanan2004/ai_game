import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/season_pass_controller.dart';

/// Season Pass reads (functions/season_pass.js writes them; the client
/// cannot): `config/seasonPass.themeByPeriod` (readable by everyone) and the
/// owner's `season_pass/{uid}/seasons/{period}`.
class FirestoreSeasonPass implements SeasonPassSource {
  FirestoreSeasonPass({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<Map<String, String>> themeByPeriod() async {
    final snap = await _db.doc('config/seasonPass').get();
    final m = snap.data()?['themeByPeriod'];
    return {
      if (m is Map)
        for (final e in m.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
    };
  }

  @override
  Future<Map<String, Object?>?> seasonDoc(String uid, String period) async {
    final snap = await _db.doc('season_pass/$uid/seasons/$period').get();
    return snap.data();
  }
}
