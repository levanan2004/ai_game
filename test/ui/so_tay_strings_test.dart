import 'package:ai_game/ui/so_tay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'so_tay_entry_test.dart' show soTayEntryFrame;
import 'so_tay_screen_test.dart' show soTayFrame, soTaySession;

/// Labels come from Nhất's so_tay_strings.json, not the spec.
void main() {
  testWidgets('list: "Đang làm quen" from lockedCard.acquainting', (
    tester,
  ) async {
    final s = soTaySession()..openNotebook();
    await tester.pumpWidget(soTayFrame(s));
    expect(find.text(s.regulars.t.ui('lockedCard.acquainting')), findsOne);
  });

  testWidgets('page: section title, okay letter shows noSouvenir', (
    tester,
  ) async {
    final s = soTaySession()
      ..openNotebook()
      ..openRegularCard('anh_minh_khoa');
    await tester.pumpWidget(soTayFrame(s));
    final t = s.regulars.t;
    expect(find.text(t.ui('letter.sectionTitle')), findsOneWidget);
    // Step 1 great (seal, no note), step 2 okay (4★): the note.
    expect(find.byKey(const Key('letter-note-1')), findsNothing);
    expect(find.byKey(const Key('letter-note-2')), findsOneWidget);
    expect(find.text(t.ui('letter.noSouvenir')), findsOneWidget);
  });

  testWidgets('invite back: button label and toast', (tester) async {
    final s = soTaySession()
      ..openNotebook()
      ..openRegularCard('chi_ngoc');
    await tester.pumpWidget(soTayFrame(s));
    final t = s.regulars.t;
    expect(find.text(t.ui('inviteBack.button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-again')));
    final name = s.regulars.byId('chi_ngoc')!.name;
    expect(s.shopNotice, t.ui('inviteBack.toast', {'name': name}));
    expect(s.shopNotice, 'Đã gửi lời mời, $name sẽ sớm ghé tiệm');
  });

  testWidgets('map row: mapEntry title and subtitle, open and locked', (
    tester,
  ) async {
    for (final s in [soTaySession(), newSession(seed: 3)]) {
      await tester.pumpWidget(
        soTayEntryFrame(
          Builder(
            builder: (context) =>
                Column(children: [mapNotebookRow(context, s, () {})(70)]),
          ),
        ),
      );
      final t = s.regulars.t;
      expect(find.text(t.ui('mapEntry.title')), findsOneWidget);
      expect(find.text(t.ui('mapEntry.subtitle')), findsOneWidget);
    }
  });
}
