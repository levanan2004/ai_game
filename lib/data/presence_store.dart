import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/presence.dart';

/// `presence/{id}` is the heartbeat. `players/{id}` is created once.
class FirestorePresence implements PresenceClient {
  FirestorePresence({FirebaseFirestore? firestore, Random? random})
    : _db = firestore ?? FirebaseFirestore.instance,
      _random = random ?? Random();

  final FirebaseFirestore _db;
  final Random _random;

  static const _guestKey = 'presenceId';
  static const onlineWindow = Duration(seconds: 90);

  @override
  Future<String> identity(String? uid) async {
    if (uid != null && uid.isNotEmpty) return uid;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id =
        'g${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(0xFFFFFF).toRadixString(36)}';
    await prefs.setString(_guestKey, id);
    return id;
  }

  @override
  Future<void> pulse(String id) async {
    await _db.collection('presence').doc(id).set({
      'seen': FieldValue.serverTimestamp(),
    });
    final player = _db.collection('players').doc(id);
    final snap = await player.get();
    if (!snap.exists) {
      await player.set({'since': FieldValue.serverTimestamp()});
    }
  }

  @override
  Future<CrowdCounts> counts() async {
    final cutoff = Timestamp.fromDate(
      DateTime.now().toUtc().subtract(onlineWindow),
    );
    final online = await _db
        .collection('presence')
        .where('seen', isGreaterThan: cutoff)
        .count()
        .get();
    final ever = await _db.collection('players').count().get();
    return CrowdCounts(online: online.count ?? 0, ever: ever.count ?? 0);
  }
}
