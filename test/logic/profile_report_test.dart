import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/profile_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

CharmBoardRow _row(String uid, {String name = 'Hoa Lan'}) => CharmBoardRow(
  3,
  CharmBoardEntry.forPlayer(uid: uid, displayName: name, charm: 200),
);

void main() {
  test('reasons are Nhất\'s five, in her order', () {
    expect(ReportReason.values.map((r) => r.label), [
      'Tên hoặc avatar tục tĩu, xúc phạm',
      'Giả mạo người khác',
      'Không phù hợp với lứa tuổi nhỏ',
      'Quảng cáo, spam hoặc đường dẫn lạ',
      'Lý do khác',
    ]);
    expect(ReportReason.byName('spam'), ReportReason.spam);
    expect(ReportReason.byName('nope'), isNull);
  });

  test(
    'one report per player: sent, then already; the note is cut to 200',
    () async {
      final reports = MemoryProfileReports();
      final s = newSession(reports: reports)..accountUid = 'me';
      s.board.openProfile(_row('p1'));
      expect(s.board.canReport, isTrue);
      s.board.openReport();
      expect(s.board.reportOpen, isTrue);
      expect(
        await s.board.sendReport(ReportReason.profane, '  ${'a' * 250} '),
        ReportSend.sent,
      );
      expect(s.board.reportOpen, isFalse);
      final sent = reports.sent[profileReportId('me', 'p1')]!;
      expect(sent.targetName, 'Hoa Lan');
      expect(sent.note.length, reportNoteMax);
      expect(sent.source, reportSourceCharmBoard);
      s.board.openReport();
      expect(
        await s.board.sendReport(ReportReason.spam, ''),
        ReportSend.already,
      );
      expect(reports.sent.length, 1);
    },
  );

  test(
    'no report on your own row, as a guest, or with nowhere to send',
    () async {
      final reports = MemoryProfileReports();
      final s = newSession(reports: reports)..accountUid = 'me';
      s.board.openProfile(_row('me'));
      expect(s.board.canReport, isFalse);
      s.board.openReport();
      expect(s.board.reportOpen, isFalse);
      expect(
        await s.board.sendReport(ReportReason.other, ''),
        ReportSend.failed,
      );

      final guest = newSession(reports: reports);
      guest.board.openProfile(_row('p1'));
      expect(guest.board.canReport, isFalse);

      final offline = newSession()..accountUid = 'me';
      offline.board.openProfile(_row('p1'));
      expect(
        await offline.board.sendReport(ReportReason.other, ''),
        ReportSend.failed,
      );
      expect(reports.sent, isEmpty);
    },
  );

  test('a failed send keeps the form open', () async {
    final s = newSession(reports: _Down())..accountUid = 'me';
    s.board.openProfile(_row('p1'));
    s.board.openReport();
    expect(await s.board.sendReport(ReportReason.spam, ''), ReportSend.failed);
    expect(s.board.reportOpen, isTrue);
    s.board.closeProfile();
    expect(s.board.reportOpen, isFalse);
  });
}

class _Down implements ProfileReports {
  @override
  Future<ReportSend> send(ProfileReport report) async => ReportSend.failed;

  @override
  Future<List<ProfileReport>> latest({int limit = 100}) async => const [];
}
