import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/regulars_view.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/so_tay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Day 12, 12 great bouquets: Minh Khoa a regular with two letters (one
/// unread), Tuấn met but not a regular yet (retrying), Ngọc's chain ended
/// poorly on step 2; the others not met.
ShopSession soTaySession() {
  final s = newSession(seed: 3);
  s.state
    ..day = 12
    ..lifetimeGreat = 12;
  s.regularProgress('anh_minh_khoa')
    ..stepsDone.addAll({1: 5, 2: 4})
    ..doneDay.addAll({1: 3, 2: 7})
    ..unread.add(2)
    ..lastVisitDay = 7;
  s.regularProgress('ban_tuan')
    ..retries = 1
    ..retryAfterDay = 13
    ..lastVisitDay = 11;
  s.regularProgress('chi_ngoc')
    ..stepsDone.addAll({1: 5, 2: RegularProgress.poorEnding})
    ..doneDay.addAll({1: 8, 2: 11})
    ..lastVisitDay = 11;
  return s;
}

Widget soTayFrame(ShopSession s, {Key? key}) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        type: MaterialType.transparency,
        child: GameFrame(child: SoTayScreen(session: s)),
      ),
    ),
  ),
);

void main() {
  testWidgets('the list: count pill, tabs, card states', (tester) async {
    final s = soTaySession()..openNotebook();
    expect(s.notebookShown, isTrue);
    await tester.pumpWidget(soTayFrame(s));
    await tester.pump();
    expect(find.text('Sổ tay khách quen'), findsOneWidget);
    // Minh Khoa and Ngọc are regulars, out of the 10 in the block.
    expect(find.text('2/${s.regulars.customers.length}'), findsOneWidget);
    expect(find.text('Minh Khoa'), findsOneWidget);
    expect(find.byKey(const Key('card-dot-anh_minh_khoa')), findsOneWidget);
    expect(find.text('Đang làm quen'), findsOneWidget);
    expect(find.text('???'), findsWidgets);

    await tester.tap(find.byKey(const Key('so-tay-tab-regular')));
    await tester.pump();
    expect(find.byKey(const Key('regular-card-ban_tuan')), findsNothing);
    expect(find.byKey(const Key('regular-card-chi_ngoc')), findsOneWidget);

    await tester.tap(find.byKey(const Key('so-tay-tab-locked')));
    await tester.pump();
    expect(find.byKey(const Key('regular-card-anh_minh_khoa')), findsNothing);
    expect(find.text('???'), findsWidgets);
  });

  testWidgets('Phu 26/10: content from x 24, locked hint under the card', (
    tester,
  ) async {
    final s = soTaySession()..openNotebook();
    await tester.pumpWidget(soTayFrame(s));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('so-tay-back'))).dx,
      greaterThanOrEqualTo(24),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('so-tay-tab-regular'))).dx,
      greaterThanOrEqualTo(24),
    );
    await tester.tap(find.byKey(const Key('so-tay-tab-locked')));
    await tester.pump();
    final hint = find.byKey(const Key('regular-card-hint')).first;
    final card = find
        .ancestor(of: hint, matching: find.byType(GestureDetector))
        .first;
    final cardRect = tester.getRect(card);
    final hintRect = tester.getRect(hint);
    final art = tester.getRect(
      find.descendant(of: card, matching: find.byType(Image)).first,
    );
    // GameFrame may scale the 360 dp page to the test window.
    final page = tester.getRect(find.byType(SoTayScreen));
    final k = page.width / tester.getSize(find.byType(SoTayScreen)).width;
    expect(hintRect.top - art.bottom, closeTo(4 * k, 0.01));
    expect((page.left + 24 * k) - cardRect.left, lessThanOrEqualTo(0.01));
    final lines = find.descendant(of: hint, matching: find.byType(Text));
    final text = tester.widget<Text>(lines.first);
    // Every hint line may wrap to 2 lines before the ellipsis.
    for (final e in lines.evaluate()) {
      expect((e.widget as Text).maxLines, 2);
    }
    expect(text.textAlign, TextAlign.center);
    expect(text.style!.fontSize, 12);
    expect(text.style!.color, const Color(0xFF6B5B4B));
    // A locked card without a hint keeps no caption gap.
    final hints = find.byKey(const Key('regular-card-hint'));
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('regular-card-') &&
          (w.key! as ValueKey<String>).value != 'regular-card-hint',
    );
    expect(cards.evaluate().length, greaterThan(hints.evaluate().length));
    for (final c in cards.evaluate()) {
      final f = find.byWidget(c.widget);
      final hasHint = find
          .descendant(
            of: f,
            matching: find.byKey(const Key('regular-card-hint')),
          )
          .evaluate()
          .isNotEmpty;
      if (hasHint) continue;
      final art = tester.getRect(
        find.descendant(of: f, matching: find.byType(Image)).first,
      );
      expect(tester.getRect(f).bottom, closeTo(art.bottom, 0.01));
    }
  });
  testWidgets('a regular page: hearts, letters, opening the unread one', (
    tester,
  ) async {
    final s = soTaySession()..openNotebook();
    await tester.pumpWidget(soTayFrame(s));
    await tester.tap(find.byKey(const Key('regular-card-anh_minh_khoa')));
    await tester.pump();
    expect(find.byKey(const Key('regular-page-anh_minh_khoa')), findsOneWidget);
    expect(find.text('2/3 lần ghé'), findsOneWidget);
    // round(5 * 2 / 3) = 3 full hearts.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.endsWith('tim_day.webp') &&
            w.width == 24,
      ),
      findsNWidgets(3),
    );
    expect(find.text('Thư 1 · Tỏ tình'), findsOneWidget);
    expect(find.text('Thư 2 · Valentine'), findsOneWidget);
    expect(find.text('Thư 3 · ???'), findsOneWidget);
    expect(find.byKey(const Key('letter-seal')), findsOneWidget);
    expect(find.byKey(const Key('letter-dot-2')), findsOneWidget);
    expect(s.notebookBadgeCount, 1);

    await tester.tap(find.byKey(const Key('letter-2')));
    await tester.pump();
    expect(find.byKey(const Key('letter-overlay')), findsOneWidget);
    final v = s.regulars.byId('anh_minh_khoa')!.visit(2)!;
    expect(find.text(v.thanks), findsWidgets);
    expect(find.text('— Minh Khoa'), findsOneWidget);
    expect(s.notebookBadgeCount, 0);

    await tester.tap(find.byKey(const Key('letter-close')));
    await tester.pump();
    expect(find.byKey(const Key('letter-overlay')), findsNothing);
    expect(find.byKey(const Key('letter-dot-2')), findsNothing);
  });

  testWidgets('a poor ending shows Mời ghé lại, which reopens the step', (
    tester,
  ) async {
    final s = soTaySession()
      ..openNotebook()
      ..openRegularCard('chi_ngoc');
    await tester.pumpWidget(soTayFrame(s));
    await tester.pump();
    expect(find.byKey(const Key('invite-again')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-again')));
    await tester.pump();
    expect(s.state.regulars['chi_ngoc']!.stepsDone.containsKey(2), isFalse);
    expect(find.byKey(const Key('invite-again')), findsNothing);
  });

  testWidgets('back goes letter → page → list → closed', (tester) async {
    final s = soTaySession()
      ..openNotebook()
      ..openRegularCard('anh_minh_khoa')
      ..openLetter(1);
    await tester.pumpWidget(soTayFrame(s));
    s.closeNotebook();
    expect(s.letterShownStep, isNull);
    expect(s.notebookDetailId, 'anh_minh_khoa');
    s.closeNotebook();
    expect(s.notebookDetailId, isNull);
    s.closeNotebook();
    expect(s.notebookShown, isFalse);
  });

  test('the notebook does not open before its unlock', () {
    final s = newSession(seed: 3)..openNotebook();
    expect(s.notebookShown, isFalse);
  });

  group('view rules', () {
    final s = soTaySession();
    final cat = s.regulars;

    test('locked hints come from lockedCard.*', () {
      final def = cat.byId('chi_my')!;
      expect(lockedHints(cat, s.e, def, day: 12, great: 12), [
        'Ghé tiệm từ ngày 18',
        'Cần 15 bó tuyệt vời',
      ]);
      final lan = cat.byId('co_lan')!;
      expect(lockedHints(cat, s.e, lan, day: 30, great: 30), [
        'Có thể gặp vào dịp ${cat.t.holiday('women_2010')}',
      ]);
    });

    test('next visit: retry, holiday, poor ending', () {
      final tuan = nextVisitView(
        cat,
        s.e,
        cat.byId('ban_tuan')!,
        s.state.regulars['ban_tuan']!,
        day: 12,
        owned: s.owned,
      );
      expect(tuan.lines, [
        'Tuấn muốn thử lại lần nữa',
        'Sẽ ghé lại sau ${cat.retryGapDays} ngày',
      ]);
      final khoa = nextVisitView(
        cat,
        s.e,
        cat.byId('anh_minh_khoa')!,
        s.state.regulars['anh_minh_khoa']!,
        day: 12,
        owned: s.owned,
      );
      expect(khoa.icon, 'invite');
      expect(holidayIcon('valentine'), 'le_valentine');
      expect(holidayIcon('teacher_2011'), 'le_8_3_20_10');
      expect(daysToHoliday(s.e, 'valentine', 1), 6);
    });
  });
}
