// Đại item 6 (Phú spec_ho_so_cai_dat.md): Hồ sơ split from Cài đặt.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/common.dart' show HudAvatarButton;
import 'package:ai_game/ui/popups.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/settings_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('split-frame');

Future<void> _host(
  WidgetTester tester,
  ShopSession s,
  Widget Function() child,
) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _frame,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: const Color(0xFFB9D7A8),
          child: ListenableBuilder(
            listenable: Listenable.merge([s, s.frames, s.vip]),
            builder: (_, _) => child(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_dir == null) return;
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  await tester.runAsync(() async {
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${_dir!}${Platform.pathSeparator}$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

ShopSession _signedIn() {
  final e = newSession().e;
  final s = newSession(avatarFrames: MemoryAvatarFrames(e.avatarFrames));
  s.accountUid = 'me';
  s.accountName = 'Lê An';
  s.accountEmail = 'an@gmail.com';
  s.state.shopName = 'Tiệm Hoa Sớm Mai';
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('HUD avatar opens your Hồ sơ and pauses; ‹ closes it', (
    tester,
  ) async {
    final s = _signedIn();
    await _host(
      tester,
      s,
      () => Stack(
        children: [
          Positioned(left: 4, top: 4, child: HudAvatarButton(session: s)),
          Positioned.fill(child: PopupLayer(session: s)),
        ],
      ),
    );
    expect(find.bySemanticsLabel(HudAvatarButton.a11y), findsOneWidget);
    await tester.tap(find.byKey(const Key('topbar-avatar')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(s.ownProfileOpen, isTrue);
    expect(s.paused, isTrue);
    expect(find.byKey(const Key('own-profile')), findsOneWidget);
    expect(find.text(ProfileText.title), findsOneWidget);
    expect(find.text(ProfileText.statCustomers), findsOneWidget);
    expect(find.text(ProfileText.statStars), findsOneWidget);
    expect(find.text(ProfileText.statChampion), findsOneWidget);
    // Own: ✎ avatar and ✎ shop name, no "Ghé tiệm".
    expect(find.byKey(const Key('profile-card-avatar-edit')), findsOneWidget);
    expect(find.byKey(const Key('profile-card-rename')), findsOneWidget);
    expect(find.byKey(const Key('profile-card-visit')), findsNothing);
    expect(tester.takeException(), isNull);
    await _shot(tester, '17_ho_so');
    // ✎ avatar: the picker over the profile.
    await tester.tap(find.byKey(const Key('profile-card-avatar-edit')));
    await tester.pump();
    expect(find.byKey(const Key('avatar-picker')), findsOneWidget);
    s.closeAvatarPicker();
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-card-back')));
    await tester.pump();
    expect(s.ownProfileOpen, isFalse);
    expect(s.paused, isFalse);
    // Opening Cài đặt closes Hồ sơ (never both).
    s.openOwnProfile();
    s.openPause();
    expect(s.ownProfileOpen, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signed out, the HUD avatar opens Cài đặt (sign-in, avatar)', (
    tester,
  ) async {
    final s = newSession();
    s.openOwnProfile();
    expect(s.ownProfileOpen, isFalse);
    expect(s.pauseMenuOpen, isTrue);
    await _host(tester, s, () => SettingsPopup(session: s));
    // Without an account the avatar and the shop name stay in Cài đặt.
    expect(find.byKey(const Key('settings-avatar')), findsOneWidget);
    expect(find.byKey(const Key('settings-rename')), findsOneWidget);
  });

  testWidgets('Cài đặt signed in: no avatar/name/frame; Quyền riêng tư; '
      'Pha lê last; "Đã đồng ý dd/MM/yyyy"', (tester) async {
    final s = _signedIn();
    s.openPause();
    await _host(tester, s, () => SettingsPopup(session: s));
    expect(find.byKey(const Key('settings-avatar')), findsNothing);
    expect(find.byKey(const Key('settings-rename')), findsNothing);
    expect(find.byKey(const Key('settings-frame')), findsNothing);
    final date = tester.widget<Text>(
      find.byKey(const Key('settings-terms-date')),
    );
    expect(date.data, matches(RegExp(r'^Đã đồng ý \d\d/\d\d/\d{4}$')));
    // The whole date is shown (nothing cut).
    final p = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const Key('settings-terms-date')),
        matching: find.byType(RichText),
      ),
    );
    expect(p.didExceedMaxLines, isFalse);
    expect(
      p.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(p.size.width + 0.01),
    );
    final sound = tester.getTopLeft(find.text('ÂM THANH')).dy;
    final account = tester.getTopLeft(find.text('TÀI KHOẢN')).dy;
    expect(sound, lessThan(account));
    if (s.chat.offered || s.vip.offered) {
      expect(find.text('QUYỀN RIÊNG TƯ'), findsOneWidget);
    }
    if (s.vip.offered) {
      expect(find.byKey(const Key('settings-vip-hide')), findsOneWidget);
    }
    final phale = find.byKey(const Key('settings-phale'));
    if (phale.evaluate().isNotEmpty) {
      expect(
        tester.getTopLeft(phale).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('settings-terms'))).dy,
        ),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    await _shot(tester, '17_cai_dat');
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pump();
    await _shot(tester, '17_cai_dat_2');
  });
}
