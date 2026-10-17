import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../logic/world_chat.dart';
import '../logic/world_chat_admin.dart';
import 'account_deletion.dart' show accountFunctionsBaseUrl;

/// Tin thế giới over Firestore (reading) and the callables worldChatSend /
/// worldChatReport (writing; functions/world_chat.js). The callable protocol
/// is done by hand like WalletClient: POST {"data": …} with the ID token.
class FirestoreWorldChat implements WorldChatSource, WorldChatAdmin {
  FirestoreWorldChat({
    FirebaseFirestore? firestore,
    Future<String?> Function()? idToken,
    this.baseUrl = accountFunctionsBaseUrl,
    http.Client? client,
  }) : _firestore = firestore,
       _idToken =
           idToken ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken()),
       _client = client ?? http.Client();

  final FirebaseFirestore? _firestore;

  /// Looked up on first use, so /quan-tri can hold one before Firebase is
  /// touched (and widget tests that never open the chat do not need it).
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  final Future<String?> Function() _idToken;
  final String baseUrl;
  final http.Client _client;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('world_chat');
  DocumentReference<Map<String, dynamic>> get _switch =>
      _db.doc('config/worldChat');

  // -- players --------------------------------------------------------------

  @override
  Stream<List<ChatMessage>> messages(int limit) => _messages
      .orderBy('seq', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs.reversed) ?readChatMessage(d.id, d.data()),
        ],
      );

  @override
  Stream<bool> enabled() =>
      _switch.snapshots().map((d) => d.data()?['enabled'] == true);

  @override
  Future<ChatMute?> mute(String uid) async {
    final d = await _db.doc('chat_mutes/$uid').get();
    return readChatMute(d.data());
  }

  @override
  Future<ChatSendResult> send(String text, {required String avatar}) async {
    final r = await _call('worldChatSend', {'text': text, 'avatar': avatar});
    if (r.error != null) {
      final d = r.details;
      final at = d['until'];
      return ChatSendResult.refused(
        r.error,
        seconds: d['seconds'] is num ? (d['seconds'] as num).toInt() : null,
        until: at is num
            ? DateTime.fromMillisecondsSinceEpoch(at.toInt())
            : null,
      );
    }
    return ChatSendResult.ok(
      text: r.result['text'] is String ? r.result['text'] as String : text,
      masked: r.result['masked'] == true,
    );
  }

  @override
  Future<ChatReportSend> report(
    String messageId,
    ChatReportReason reason,
    String note,
  ) async {
    final r = await _call('worldChatReport', {
      'messageId': messageId,
      'reason': reason.name,
      'note': note,
    });
    if (r.error == null) return ChatReportSend.sent;
    return r.error == 'already' ? ChatReportSend.already : ChatReportSend.failed;
  }

  Future<_CallResult> _call(String name, Map<String, Object?> data) async {
    final token = await _idToken();
    if (token == null || token.isEmpty) return const _CallResult.err('server');
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/$name'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return const _CallResult.err('network');
    }
    return _parse(res.statusCode, res.bodyBytes);
  }

  // -- /quan-tri ------------------------------------------------------------

  @override
  Future<bool> isEnabled() async {
    final d = await _switch.get();
    return d.data()?['enabled'] == true;
  }

  @override
  Future<void> setEnabled(bool on) => _switch.set({
    'enabled': on,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<List<ChatMessage>> latest({int limit = 100}) async {
    final snap = await _messages
        .orderBy('seq', descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs) ?readChatMessage(d.id, d.data())];
  }

  @override
  Future<void> deleteMessage(String id) => _messages.doc(id).delete();

  @override
  Future<void> setMute(
    String uid,
    String level, {
    String reason = '',
    String messageId = '',
  }) => _db.doc('chat_mutes/$uid').set({
    'level': level,
    'at': FieldValue.serverTimestamp(),
    'by': FirebaseAuth.instance.currentUser?.uid,
    if (reason.isNotEmpty) 'reason': reason,
    if (messageId.isNotEmpty) 'messageId': messageId,
  });

  @override
  Future<void> clearMute(String uid) => _db.doc('chat_mutes/$uid').delete();

  @override
  Future<List<ChatReport>> reports({int limit = 100}) async {
    final snap = await _db
        .collection('chat_reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs) ?readChatReport(d.id, d.data())];
  }

  @override
  Future<void> markDone(String reportId) =>
      _db.doc('chat_reports/$reportId').update({
        'status': 'done',
        'handledBy': FirebaseAuth.instance.currentUser?.uid,
        'handledAt': FieldValue.serverTimestamp(),
      });
}

class _CallResult {
  const _CallResult.ok(this.result) : error = null, details = const {};
  const _CallResult.err(this.error, [this.details = const {}])
    : result = const {};

  final Map<String, Object?> result;
  final String? error;
  final Map<String, Object?> details;
}

/// Reads a callable answer: `{"result": …}` or `{"error": {"message",
/// "details"}}` (functions v2 HttpsError). Exposed for tests.
({String? error, Map<String, Object?> details, Map<String, Object?> result})
parseCallAnswer(int status, List<int> body) {
  final r = _parse(status, body);
  return (error: r.error, details: r.details, result: r.result);
}

_CallResult _parse(int status, List<int> body) {
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(body));
  } catch (_) {}
  if (status != 200) {
    final e = decoded is Map ? decoded['error'] : null;
    final message = e is Map ? e['message'] : null;
    final details = e is Map && e['details'] is Map
        ? (e['details'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    if (message is String && message.isNotEmpty && status < 500) {
      return _CallResult.err(message, details);
    }
    return _CallResult.err(status >= 502 ? 'network' : 'server');
  }
  final result = decoded is Map ? decoded['result'] : null;
  if (result is! Map) return const _CallResult.err('server');
  return _CallResult.ok(result.cast<String, Object?>());
}

DateTime? _time(Object? v) => switch (v) {
  Timestamp t => t.toDate(),
  DateTime d => d,
  _ => null,
};

ChatMessage? readChatMessage(String id, Map<String, dynamic> d) {
  final uid = d['uid'];
  final text = d['text'];
  final seq = d['seq'];
  if (uid is! String || text is! String || seq is! num) return null;
  return ChatMessage(
    id: id,
    uid: uid,
    name: d['name'] is String ? d['name'] as String : '',
    avatar: d['avatar'] is String ? d['avatar'] as String : '',
    frame: d['frame'] is String ? d['frame'] as String : '',
    text: text,
    seq: seq.toInt(),
    createdAt: _time(d['createdAt']),
    official: d['official'] == true,
  );
}

ChatMute? readChatMute(Map<String, dynamic>? d) {
  if (d == null) return null;
  final level = d['level'];
  final at = _time(d['at']);
  if (level is! String || at == null) return null;
  return ChatMute(level: level, at: at);
}

ChatReport? readChatReport(String id, Map<String, dynamic> d) {
  final reason = ChatReportReason.byName(d['reason']);
  final reporter = d['reporterUid'];
  final target = d['targetUid'];
  if (reason == null || reporter is! String || target is! String) return null;
  final ctx = d['context'];
  return ChatReport(
    id: id,
    reporterUid: reporter,
    targetUid: target,
    targetName: d['targetName'] is String ? d['targetName'] as String : '',
    messageId: d['messageId'] is String ? d['messageId'] as String : '',
    text: d['text'] is String ? d['text'] as String : '',
    reason: reason,
    note: d['note'] is String ? d['note'] as String : '',
    context: [
      if (ctx is List)
        for (final c in ctx)
          if (c is Map && c['uid'] is String && c['seq'] is num)
            ChatMessage(
              id: '',
              uid: c['uid'] as String,
              name: c['name'] is String ? c['name'] as String : '',
              text: c['text'] is String ? c['text'] as String : '',
              seq: (c['seq'] as num).toInt(),
              createdAt: _time(c['at']),
            ),
    ],
    done: d['status'] == 'done',
    createdAt: _time(d['createdAt']),
  );
}
