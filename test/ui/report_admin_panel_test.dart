import 'package:ai_game/logic/profile_report.dart';
import 'package:ai_game/ui/report_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists the reports: name, uid, reason, note, reporter', (
    tester,
  ) async {
    final reports = MemoryProfileReports();
    await reports.send(
      const ProfileReport(
        reporterUid: 'me',
        targetUid: 'p3',
        targetName: 'Tiệm Hoa Số 4',
        reason: ReportReason.impersonation,
        note: 'Giả tên tiệm mình',
      ),
    );
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ReportAdminPanel(reports: reports, onClose: () => closed = true),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('report-me_p3')), findsOneWidget);
    expect(find.text('Tiệm Hoa Số 4 (p3)'), findsOneWidget);
    expect(find.text(ReportReason.impersonation.label), findsOneWidget);
    expect(find.text('Giả tên tiệm mình'), findsOneWidget);
    expect(find.textContaining('người báo cáo me'), findsOneWidget);
    await tester.tap(find.byKey(const Key('report-admin-back')));
    expect(closed, isTrue);
  });

  testWidgets('an empty list says so', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportAdminPanel(reports: MemoryProfileReports(), onClose: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('Chưa có báo cáo.'), findsOneWidget);
  });
}
