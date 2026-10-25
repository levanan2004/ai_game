import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/popups.dart';
import 'package:ai_game/ui/so_tay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'so_tay_screen_test.dart' show soTaySession;

Widget _frame(Widget child) => MaterialApp(
  home: SoundScope(
    sounds: Sounds(heard: []),
    child: Material(child: GameFrame(child: child)),
  ),
);

/// Plays the day out to the summary screen.
void _toSummary(ShopSession s) {
  if (s.state.phase == DayPhase.market) s.buyAndGoToShop();
  if (s.state.phase == DayPhase.preparing) s.openShop();
  s.state.pendingArrivals.clear();
  for (var i = 0; i < 20000 && s.state.phase != DayPhase.summary; i++) {
    if (s.eventOffer != null) s.chooseEvent(s.eventOffer!.choices.last.id);
    s.tick(0.5);
  }
}

void main() {
  testWidgets('badge: nothing, a dot, then a count pill', (tester) async {
    await tester.pumpWidget(_frame(const NotebookBadge(count: 0)));
    expect(find.byKey(const Key('notebook-dot')), findsNothing);
    expect(find.byKey(const Key('notebook-count')), findsNothing);
    await tester.pumpWidget(_frame(const NotebookBadge(count: 1)));
    expect(find.byKey(const Key('notebook-dot')), findsOneWidget);
    await tester.pumpWidget(_frame(const NotebookBadge(count: 3)));
    expect(find.byKey(const Key('notebook-count')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('shop button opens the notebook, badge counts unread', (
    tester,
  ) async {
    final s = soTaySession();
    expect(s.notebookBadgeCount, greaterThanOrEqualTo(1));
    await tester.pumpWidget(
      _frame(
        Stack(
          children: [
            Positioned(left: 12, top: 56, child: NotebookButton(session: s)),
          ],
        ),
      ),
    );
    final box = tester.getSize(find.byKey(const Key('notebook-button')));
    expect(box, const Size(44, 44));
    expect(
      find.byType(NotebookBadge).evaluate().single.widget,
      isA<NotebookBadge>().having(
        (b) => b.count,
        'count',
        s.notebookBadgeCount,
      ),
    );
    await tester.tap(find.byKey(const Key('notebook-button')));
    expect(s.notebookShown, isTrue);
  });

  testWidgets('map row: locked is dimmed and shows the unlock tooltip', (
    tester,
  ) async {
    final s = newSession(seed: 3);
    expect(s.notebookUnlocked, isFalse);
    var closed = false;
    await tester.pumpWidget(
      _frame(
        Builder(
          builder: (context) => Column(
            children: [mapNotebookRow(context, s, () => closed = true)(70)],
          ),
        ),
      ),
    );
    expect(find.text('Sổ tay khách quen'), findsOneWidget);
    expect(find.byKey(const Key('map-notebook-lock')), findsOneWidget);
    expect(find.byType(Opacity), findsWidgets);
    await tester.tap(find.byKey(const Key('map-notebook')));
    await tester.pump();
    expect(find.text(notebookLockedHint(s)), findsOneWidget);
    expect(s.notebookShown, isFalse);
    expect(closed, isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('map row: open closes the map and opens the notebook', (
    tester,
  ) async {
    final s = soTaySession();
    var closed = false;
    await tester.pumpWidget(
      _frame(
        Builder(
          builder: (context) => Column(
            children: [mapNotebookRow(context, s, () => closed = true)(70)],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('map-notebook-lock')), findsNothing);
    await tester.tap(find.byKey(const Key('map-notebook')));
    expect(closed, isTrue);
    expect(s.notebookShown, isTrue);
  });

  test('unlock tooltip fills the numbers from the block', () {
    final s = newSession(seed: 3);
    final r = s.regulars;
    s.state.lifetimeGreat = 1;
    expect(
      notebookLockedHint(s),
      r.t.ui('unlockTooltip', {
        'minGameDay': r.notebookMinGameDay,
        'minLifetimeGreat': r.notebookMinLifetimeGreat,
        'n': r.notebookMinLifetimeGreat - 1,
      }),
    );
  });

  testWidgets('summary: unlock popup once, "Mở sổ" opens the notebook', (
    tester,
  ) async {
    final s = soTaySession();
    expect(s.notebookUnlocked, isTrue);
    _toSummary(s);
    expect(s.popups.whereType<NotebookPopup>(), hasLength(1));
    while (s.currentPopup is! NotebookPopup) {
      s.closePopup();
    }
    await tester.pumpWidget(_frame(PopupLayer(session: s)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('notebook-intro')), findsOneWidget);
    expect(find.text(s.regulars.t.ui('unlockPopup.body')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notebook-intro-open')));
    expect(s.state.notebookIntroSeen, isTrue);
    expect(s.notebookShown, isTrue);
    expect(s.popups.whereType<NotebookPopup>(), isEmpty);
    await tester.pump(const Duration(seconds: 2));

    // Seen: the next summary has no popup.
    s.closeNotebook();
    s.startNextDay();
    _toSummary(s);
    expect(s.popups.whereType<NotebookPopup>(), isEmpty);
  });

  test('summary: no popup while the notebook is closed', () {
    final s = newSession(seed: 3);
    _toSummary(s);
    expect(s.popups.whereType<NotebookPopup>(), isEmpty);
  });
}
