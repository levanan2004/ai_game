import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/cloud_merge.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/save_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

Widget _host(ShopSession s) => MaterialApp(
  home: Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: 360,
      child: ListenableBuilder(
        listenable: s,
        builder: (_, _) => SaveStatusRow(session: s),
      ),
    ),
  ),
);

ShopSession _guest({Map<String, String>? backing, bool dismissed = false}) =>
    newSession(
      store: ProgressStore.memory(backing ?? {}),
      guestSaves: false,
      guestBannerDismissed: dismissed,
    );

void main() {
  setUpAll(loadTestFonts);
  testWidgets('guest strip shows the new text and an X of at least 40 px', (
    tester,
  ) async {
    final s = _guest();
    await tester.pumpWidget(_host(s));
    expect(find.text(guestBannerLabel), findsOneWidget);
    expect(
      guestBannerLabel,
      'Bạn chưa đăng nhập nên tiến độ chưa được lưu.',
    );
    final x = find.byKey(const Key('save-guest-close'));
    expect(x, findsOneWidget);
    final size = tester.getSize(x);
    expect(size.width, greaterThanOrEqualTo(40));
    expect(size.height, greaterThanOrEqualTo(40));
    // Still fits the strip: the sentence is not cut off at 360 dp (2 lines).
    final para = tester.renderObject<RenderParagraph>(
      find.text(guestBannerLabel),
    );
    expect(para.didExceedMaxLines, isFalse);
    final h = tester.getSize(find.byKey(const Key('save-guest-strip'))).height;
    expect(h, lessThanOrEqualTo(56));
  });

  testWidgets('the X has the accessibility label Đóng thông báo', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final s = _guest();
    await tester.pumpWidget(_host(s));
    expect(find.bySemanticsLabel('Đóng thông báo'), findsOneWidget);
    expect(guestBannerCloseLabel, 'Đóng thông báo');
    handle.dispose();
  });

  testWidgets('tapping the X hides the strip and saves the flag', (
    tester,
  ) async {
    final backing = <String, String>{};
    final s = _guest(backing: backing);
    await tester.pumpWidget(_host(s));
    await tester.tap(find.byKey(const Key('save-guest-close')));
    await tester.pump();
    expect(find.byKey(const Key('save-guest-strip')), findsNothing);
    expect(s.showGuestBanner, isFalse);
    await tester.runAsync(() => s.pendingSaves);
    expect(backing['guestBannerDismissed'], 'true');
  });

  testWidgets('tapping the X does not start sign-in', (tester) async {
    final s = _guest();
    await tester.pumpWidget(_host(s));
    await tester.tap(find.byKey(const Key('save-guest-close')));
    await tester.pump();
    expect(s.authBusy, isFalse);
  });

  testWidgets('stays hidden after a reload that reads the saved flag', (
    tester,
  ) async {
    final backing = <String, String>{};
    final first = _guest(backing: backing);
    await tester.pumpWidget(_host(first));
    await tester.tap(find.byKey(const Key('save-guest-close')));
    await tester.pump();
    await tester.runAsync(() => first.pendingSaves);

    // "Reload": a new store over the same storage, a new session.
    final store = ProgressStore.memory(backing);
    final dismissed = await tester.runAsync(store.loadGuestBannerDismissed);
    expect(dismissed, isTrue);
    final second = newSession(
      store: store,
      guestSaves: false,
      guestBannerDismissed: dismissed!,
    );
    await tester.pumpWidget(_host(second));
    expect(find.byKey(const Key('save-guest-strip')), findsNothing);
  });

  testWidgets('shows again when the flag was never saved', (tester) async {
    final store = ProgressStore.memory({});
    expect(await store.loadGuestBannerDismissed(), isFalse);
    final s = _guest();
    await tester.pumpWidget(_host(s));
    expect(find.byKey(const Key('save-guest-strip')), findsOneWidget);
  });

  testWidgets('a signed-in player never sees the strip', (tester) async {
    final s = newSession(guestSaves: false)..accountUid = 'u1';
    expect(s.signedIn, isTrue);
    await tester.pumpWidget(_host(s));
    expect(find.byKey(const Key('save-guest-strip')), findsNothing);
    expect(find.byKey(const Key('save-guest-close')), findsNothing);
  });

  testWidgets('an account still opening shows no strip either', (tester) async {
    final s = newSession(
      guestSaves: false,
      lastAccount: const AccountProfile(uid: 'u1', email: 'an@example.com'),
    );
    expect(s.accountOpening, isTrue);
    await tester.pumpWidget(_host(s));
    expect(find.byKey(const Key('save-guest-strip')), findsNothing);
  });
}
