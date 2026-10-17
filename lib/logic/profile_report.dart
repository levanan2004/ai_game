/// Why a player reports another player's profile. Labels are Nhất's
/// (chu_ung_dung_v1.md mục 5, `report.reason.*`); the profile card uses this
/// set, not the chat one (chu_tinh_nang_moi.md, thẻ hồ sơ).
enum ReportReason {
  profane('Tên hoặc avatar tục tĩu, xúc phạm'),
  impersonation('Giả mạo người khác'),
  inappropriate('Không phù hợp với lứa tuổi nhỏ'),
  spam('Quảng cáo, spam hoặc đường dẫn lạ'),
  other('Lý do khác');

  const ReportReason(this.label);

  final String label;

  static ReportReason? byName(Object? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// `report.dialog.note_hint`: the note is optional and at most this long.
const reportNoteMax = 200;

/// Where the report was made: the Mị lực board, or a profile card opened
/// from Bảng Đánh giá (firestore.rules allows exactly these two).
const reportSourceCharmBoard = 'charm_board';
const reportSourceRatingBoard = 'rating_board';

/// Who a report is about, and from which board.
class ReportTarget {
  const ReportTarget({
    required this.uid,
    required this.name,
    required this.source,
  });

  final String uid;
  final String name;
  final String source;
}

/// One report: `profile_reports/{reporterUid}_{targetUid}` (firestore.rules).
class ProfileReport {
  const ProfileReport({
    required this.reporterUid,
    required this.targetUid,
    required this.targetName,
    required this.reason,
    this.note = '',
    this.source = reportSourceCharmBoard,
    this.createdAt,
  });

  final String reporterUid;
  final String targetUid;

  /// The name shown when the report was made (the name can change later).
  final String targetName;
  final ReportReason reason;
  final String note;
  final String source;

  /// Server time; null before it is written.
  final DateTime? createdAt;
}

/// One report per reporter and player: a second one is refused by the rules.
String profileReportId(String reporterUid, String targetUid) =>
    '${reporterUid}_$targetUid';

enum ReportSend { sent, already, failed }

/// Sends reports (players) and lists them (/quan-tri).
abstract class ProfileReports {
  Future<ReportSend> send(ProfileReport report);

  /// Newest first. Admins only.
  Future<List<ProfileReport>> latest({int limit = 100});
}

/// Keeps reports in memory with the rules' limits (tests, offline).
class MemoryProfileReports implements ProfileReports {
  final Map<String, ProfileReport> sent = {};

  @override
  Future<ReportSend> send(ProfileReport report) async {
    if (report.reporterUid.isEmpty ||
        report.reporterUid == report.targetUid ||
        report.note.length > reportNoteMax) {
      return ReportSend.failed;
    }
    final id = profileReportId(report.reporterUid, report.targetUid);
    if (sent.containsKey(id)) return ReportSend.already;
    sent[id] = report;
    return ReportSend.sent;
  }

  @override
  Future<List<ProfileReport>> latest({int limit = 100}) async =>
      sent.values.toList().reversed.take(limit).toList();
}
