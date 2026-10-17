import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/profile_report.dart';

/// `profile_reports/{reporterUid}_{targetUid}`. Players may only create one
/// (rules check the fields); only admins read them.
class FirestoreProfileReports implements ProfileReports {
  FirestoreProfileReports({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('profile_reports');

  @override
  Future<ReportSend> send(ProfileReport report) async {
    try {
      await _reports
          .doc(profileReportId(report.reporterUid, report.targetUid))
          .set(reportDocument(report));
      return ReportSend.sent;
    } on FirebaseException catch (e) {
      // Create-only: writing the same pair again is an update, which the
      // rules refuse. The fields are checked before sending, so a refusal
      // means the report is already there.
      return e.code == 'permission-denied'
          ? ReportSend.already
          : ReportSend.failed;
    } catch (_) {
      return ReportSend.failed;
    }
  }

  @override
  Future<List<ProfileReport>> latest({int limit = 100}) async {
    final snap = await _reports
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final doc in snap.docs) ?_read(doc.data())];
  }

  static ProfileReport? _read(Map<String, dynamic> d) {
    final reason = ReportReason.byName(d['reason']);
    final reporter = d['reporterUid'];
    final target = d['targetUid'];
    if (reason == null || reporter is! String || target is! String) {
      return null;
    }
    final at = d['createdAt'];
    return ProfileReport(
      reporterUid: reporter,
      targetUid: target,
      targetName: d['targetName'] is String ? d['targetName'] as String : '',
      reason: reason,
      note: d['note'] is String ? d['note'] as String : '',
      source: d['source'] is String ? d['source'] as String : '',
      createdAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

/// The document a player writes. The name and note are cut to the rules'
/// limits; createdAt is the server's time.
Map<String, Object?> reportDocument(ProfileReport report) {
  String clip(String s, int max) {
    final t = s.trim();
    return t.length <= max ? t : t.substring(0, max);
  }

  return {
    'reporterUid': report.reporterUid,
    'targetUid': report.targetUid,
    'targetName': clip(report.targetName, 80),
    'reason': report.reason.name,
    'note': clip(report.note, reportNoteMax),
    'source': report.source,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
