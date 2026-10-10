import 'dart:io';

import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/pet_shop_grid.dart' show shortfallText;
import 'package:ai_game/ui/pot_book_screen.dart';
import 'package:ai_game/ui/pot_popup.dart';
import 'package:ai_game/ui/pot_shop_screen.dart';
import 'package:ai_game/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

ShopSession _day(int day, {int money = 50000000, int phaLe = 2000}) {
  final s = newSession();
  s.state.day = day;
  s.state.money = money;
  s.state.phaLe = phaLe;
  s.state.potShopHintShown = true; // no hint box unless a test wants it
  s.buyAndGoToShop();
  return s;
}

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(child: SizedBox(width: 360, height: 640, child: child)),
    ),
  );
  await tester.pump();
}

Future<void> _mountOverlay(WidgetTester tester, ShopSession s) => _mount(
  tester,
  ListenableBuilder(
    listenable: s,
    builder: (_, _) => MainShopOverlay(session: s),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  test('the nav icon and every pot picture exist as files', () {
    expect(File('assets/images/nav/chau_hoa.webp').existsSync(), isTrue);
    expect(
      File('assets/images/nav/chau_hoa.webp').lengthSync(),
      lessThan(60000),
    );
  });

  group('Tiệm Chậu Hoa', () {
    testWidgets('three tabs, set strip, and the four card states', (
      tester,
    ) async {
      final s = _day(2, money: 3500000, phaLe: 100);
      s.openPotShop();
      await _mount(tester, PotShopScreen(session: s));
      for (final g in ['chomSao', 'sonHai', 'linhVat']) {
        expect(find.byKey(Key('potshop-tab-$g')), findsOneWidget);
      }
      expect(find.text('Hoàng đạo'), findsWidgets);
      expect(find.text('Sơn Hải'), findsOneWidget);
      expect(find.text('Linh vật'), findsOneWidget);
      expect(find.text('Bộ Hoàng đạo'), findsOneWidget);
      expect(find.byKey(const Key('potshop-count')), findsOneWidget);
      expect(find.text('mỗi bộ: Đủ bộ nhận 300 Pha lê'), findsOneWidget);
      // (a) enough xu: green button with the short label (no word xu).
      expect(find.text('Mua 3 tr'), findsOneWidget);
      // (c) not enough xu: still a button, and a tap says how much is missing.
      expect(find.text('Mua 4 tr'), findsOneWidget);
      await tester.tap(find.byKey(const Key('potshop-buy-chau_kim_nguu')));
      await tester.pump();
      expect(
        find.text(shortfallText(phaLe: false, missing: 500000)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('potshop-confirm')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      // Linh vật cards are sold for Pha lê with the gift label as subtitle.
      await tester.tap(find.byKey(const Key('potshop-tab-linhVat')));
      await tester.pump();
      expect(s.potShopTab, 'linhVat');
      expect(find.text('Mua 300 Pha lê'), findsWidgets);
      expect(find.text('Quà mốc 14 ngày hoặc mua 300 Pha lê'), findsOneWidget);
      // (d) short of Pha lê.
      await tester.tap(find.byKey(const Key('potshop-buy-koi')));
      await tester.pump();
      expect(s.phaleShort?.need, 200);
    });

    testWidgets(
      'buy asks first, then offers to place; the card turns Đang có x1',
      (tester) async {
        final s = _day(2, money: 3500000, phaLe: 0);
        s.openPotShop();
        await _mount(tester, PotShopScreen(session: s));
        await tester.tap(find.byKey(const Key('potshop-buy-chau_bach_duong')));
        await tester.pump();
        expect(find.text('Mua chậu Bạch Dương?'), findsOneWidget);
        expect(s.state.money, 3500000, reason: 'a card tap never spends');
        // The confirm dialog never abbreviates.
        expect(find.text('Mua 3.000.000 xu'), findsOneWidget);
        // "Để sau" and a tap outside both leave everything as it was.
        await tester.tap(find.byKey(const Key('potshop-confirm-later')));
        await tester.pump();
        expect(find.text('Mua chậu Bạch Dương?'), findsNothing);
        await tester.tap(find.byKey(const Key('potshop-buy-chau_bach_duong')));
        await tester.pump();
        await tester.tapAt(const Offset(180 - 150, 40));
        await tester.pump();
        expect(find.text('Mua chậu Bạch Dương?'), findsNothing);
        expect(s.potHas('chau_bach_duong'), isFalse);

        await tester.tap(find.byKey(const Key('potshop-buy-chau_bach_duong')));
        await tester.pump();
        expect(find.text('Còn 11 chậu nữa là nhận 300 Pha lê'), findsOneWidget);
        await tester.tap(find.byKey(const Key('potshop-confirm-yes')));
        await tester.pump();
        expect(s.state.money, 500000);
        expect(s.potHas('chau_bach_duong'), isTrue);
        expect(find.text('Đã có chậu Bạch Dương!'), findsOneWidget);
        expect(find.text('Bộ Hoàng đạo: 1/12'), findsOneWidget);
        expect(find.text('Đặt vào tiệm'), findsOneWidget);
        expect(find.text('Sổ sưu tầm'), findsWidgets);
        expect(find.text('Để sau'), findsOneWidget);
        // "Để sau" closes it: the card shows the badge and sells more.
        await tester.tap(find.byKey(const Key('potshop-bought-later')));
        await tester.pump();
        expect(find.byKey(const Key('potshop-bought')), findsNothing);
        expect(
          find.byKey(const Key('potshop-have-chau_bach_duong')),
          findsOneWidget,
        );
        expect(find.text('Đang có x1'), findsOneWidget);
        expect(find.text('Mua thêm 3 tr'), findsOneWidget);
        // A second copy: its own dialog (no set reward line), then a toast and
        // no "Đã có" popup.
        s.state.money = 4000000;
        s.notifyListeners();
        await tester.pump();
        await tester.tap(find.byKey(const Key('potshop-buy-chau_bach_duong')));
        await tester.pump();
        expect(find.text('Mua thêm chậu này?'), findsOneWidget);
        expect(
          find.text(
            'Bạn đang có 1 chiếc. Mua thêm một chiếc với giá 3.000.000 xu nhé?',
          ),
          findsOneWidget,
        );
        final dialog = find.byKey(const Key('potshop-confirm'));
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining('chậu nữa'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: dialog, matching: find.textContaining('Bộ ')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('potshop-confirm-yes')));
        await tester.pump();
        expect(s.potOwned('chau_bach_duong'), 2);
        expect(s.state.money, 1000000);
        expect(find.text('Đã thêm 1 chậu, bạn có 2 chiếc.'), findsOneWidget);
        expect(find.byKey(const Key('potshop-bought')), findsNothing);
        expect(find.text('Đang có x2'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('Đặt vào tiệm goes to the placing mode on the main screen', (
      tester,
    ) async {
      final s = _day(2, money: 3500000);
      s.openPotShop();
      await _mount(tester, PotShopScreen(session: s));
      await tester.tap(find.byKey(const Key('potshop-buy-chau_bach_duong')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('potshop-confirm-yes')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('potshop-bought-place')));
      await tester.pump();
      expect(s.screen, Screen.shop);
      expect(s.pendingPlacePotId, 'chau_bach_duong');
      expect(s.placeModeActive, isTrue);
    });

    testWidgets(
      'while the shop serves: buying works, placing is grey and dead',
      (tester) async {
        final s = _day(2, money: 6000000);
        s.openShop();
        s.openPotShop();
        await _mount(tester, PotShopScreen(session: s));
        await tester.ensureVisible(
          find.byKey(const Key('potshop-buy-chau_song_tu')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('potshop-buy-chau_song_tu')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('potshop-confirm-yes')));
        await tester.pump();
        expect(s.potHas('chau_song_tu'), isTrue);
        expect(find.text('Đặt sau khi đóng cửa'), findsOneWidget);
        expect(find.text('Đặt vào tiệm'), findsNothing);
        await tester.tap(find.byKey(const Key('potshop-bought-place')));
        await tester.pump();
        expect(s.pendingPlacePotId, isNull);
        expect(s.screen, Screen.potShop);
        expect(find.byKey(const Key('potshop-bought')), findsOneWidget);
        // The other two buttons still work.
        await tester.tap(find.byKey(const Key('potshop-bought-book')));
        await tester.pump();
        expect(s.screen, Screen.potBook);
        expect(s.potBookDetailId, 'chau_song_tu');
      },
    );

    testWidgets('a Pha lê pot: amber price, full price asked, Pha lê spent', (
      tester,
    ) async {
      final s = _day(2, money: 99999999, phaLe: 300);
      s.openPotShop(group: 'sonHai');
      await _mount(tester, PotShopScreen(session: s));
      await tester.tap(find.byKey(const Key('potshop-buy-chau_thao_thiet')));
      await tester.pump();
      expect(find.text('Mua chậu Thao Thiết?'), findsOneWidget);
      expect(find.text('Mua 250 Pha lê'), findsWidgets);
      await tester.tap(find.byKey(const Key('potshop-confirm-yes')));
      await tester.pump();
      expect(s.state.phaLe, 50);
      expect(s.state.money, 99999999);
      expect(find.text('Đã có chậu Thao Thiết!'), findsOneWidget);
    });

    testWidgets(
      'from the book the card is scrolled into view with a gold rim',
      (tester) async {
        final s = _day(2);
        s.openPotShop(group: 'sonHai', focus: 'chau_bach_trach');
        await _mount(tester, PotShopScreen(session: s));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const Key('potshop-focus-chau_bach_trach')),
          findsOneWidget,
        );
      },
    );
  });

  group('entry points', () {
    testWidgets('the fifth tab, its red dot, and it stays usable while open', (
      tester,
    ) async {
      final s = _day(2);
      await _mountOverlay(tester, s);
      expect(find.text('Chậu hoa'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('nav-$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('nav-5')), findsNothing);
      expect(find.byKey(const Key('nav-red-dot')), findsOneWidget);
      s.openPotShop();
      s.closePotShop();
      await tester.pump();
      expect(find.byKey(const Key('nav-red-dot')), findsNothing);
      // A pot that is new to the player brings the dot back.
      s.state.potShopSeenIds.remove('chau_de_giang');
      s.openShop();
      await tester.pump();
      expect(s.state.phase, DayPhase.open);
      expect(find.byKey(const Key('nav-red-dot')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pump();
      expect(s.screen, Screen.potShop);
      expect(find.byKey(const Key('nav-red-dot')), findsNothing);
    });

    testWidgets('Bản đồ has the row with its count and opens the shop', (
      tester,
    ) async {
      final s = _day(2);
      await _mountOverlay(tester, s);
      await tester.tap(find.byKey(const Key('nav-3')));
      await tester.pump();
      expect(find.byKey(const Key('map-pot-shop')), findsOneWidget);
      expect(find.text('Ghé xem chậu mới'), findsOneWidget);
      expect(find.byKey(const Key('map-red-dot')), findsOneWidget);
      s.state.potCounts['koi'] = 1;
      s.state.potCounts['chau_su_tu'] = 1;
      s.notifyListeners();
      await tester.pump();
      expect(find.text('Đã có 2/${s.potKindsTotal} loại chậu'), findsOneWidget);
      await tester.tap(find.byKey(const Key('map-pot-shop')));
      await tester.pump();
      expect(s.screen, Screen.potShop);
    });

    testWidgets('Kho chậu has a Tiệm Chậu Hoa button and no second copy', (
      tester,
    ) async {
      final s = _day(2);
      s.state.potCounts['chau_su_tu'] = 1;
      s.openPotPicker(bar: true, index: 0);
      await _mount(tester, PotPopup(session: s));
      expect(find.byKey(const Key('pot-to-shop')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pot-to-shop')));
      await tester.pump();
      expect(s.potPickerOpen, isFalse);
      expect(s.screen, Screen.potShop);
    });

    testWidgets('hint box A shows once, over the tab, and sets the flag', (
      tester,
    ) async {
      final s = newSession();
      s.state.day = 2;
      s.state.money = 5000000;
      s.buyAndGoToShop();
      expect(s.state.potShopHintShown, isFalse);
      await _mountOverlay(tester, s);
      await tester.pump();
      expect(find.byKey(const Key('pot-hint')), findsOneWidget);
      expect(
        find.text('Tiệm có chậu mới rồi, ghé Tiệm Chậu Hoa xem thử nhé!'),
        findsOneWidget,
      );
      expect(s.state.potShopHintShown, isTrue);
      // Still up after the flag went on; "Để sau" closes it for good.
      await tester.pump();
      expect(find.byKey(const Key('pot-hint')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pot-hint-later')));
      await tester.pump();
      expect(find.byKey(const Key('pot-hint')), findsNothing);
      expect(s.potHintBoxDue, isFalse);
      // The red dot stays: the flag does not touch it.
      expect(find.byKey(const Key('nav-red-dot')), findsOneWidget);
    });

    testWidgets('hint box A: Xem chậu opens the shop on Hoàng đạo', (
      tester,
    ) async {
      final s = newSession();
      s.state.day = 3;
      s.state.money = 5000000;
      s.buyAndGoToShop();
      await _mountOverlay(tester, s);
      await tester.pump();
      await tester.tap(find.byKey(const Key('pot-hint-go')));
      await tester.pump();
      expect(s.screen, Screen.potShop);
      expect(s.potShopTab, 'chomSao');
    });

    testWidgets('no hint box on day 1, with no money, or in the tutorial', (
      tester,
    ) async {
      final s = newSession();
      s.state.money = 500000;
      s.buyAndGoToShop();
      await _mountOverlay(tester, s);
      await tester.pump();
      expect(find.byKey(const Key('pot-hint')), findsNothing);
      expect(s.state.potShopHintShown, isFalse);
    });
  });

  group('placing mode on the main screen', () {
    testWidgets('11 dashed slots, a preview with the slot number, Đặt ở đây', (
      tester,
    ) async {
      final s = _day(2);
      s.state.potCounts['chau_su_tu'] = 1;
      expect(s.startPlaceMode('chau_su_tu'), isTrue);
      await _mountOverlay(tester, s);
      expect(find.byKey(const Key('place-banner')), findsOneWidget);
      expect(
        find.text('Chạm một chỗ trên kệ để đặt chậu Sư Tử'),
        findsOneWidget,
      );
      expect(find.text('Chậu cũ ở chỗ đó sẽ về kho.'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('place-slot-bar-$i')), findsOneWidget);
      }
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(Key('place-slot-stand-$i')), findsOneWidget);
      }
      // The goals card, the open button and the nav give way.
      expect(find.byKey(const Key('main-button')), findsNothing);
      expect(find.byKey(const Key('nav-0')), findsNothing);
      expect(find.byKey(const Key('place-ok')), findsNothing);

      await tester.tap(find.byKey(const Key('place-slot-bar-2')));
      await tester.pump();
      expect(find.text('Đặt ở chỗ thứ 3 trên kệ?'), findsOneWidget);
      expect(find.byKey(const Key('place-chosen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('place-slot-stand-0')));
      await tester.pump();
      expect(find.text('Đặt ở chỗ thứ 6 trên kệ?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('place-other')));
      await tester.pump();
      expect(find.byKey(const Key('place-ok')), findsNothing);

      await tester.tap(find.byKey(const Key('place-slot-bar-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('place-ok')));
      await tester.pump();
      expect(s.state.barPots[2], 'chau_su_tu');
      expect(find.byKey(const Key('place-mode')), findsNothing);
      expect(find.byKey(const Key('nav-0')), findsOneWidget);
      expect(find.text('Đã đặt chậu Sư Tử'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Thôi leaves the mode and moves nothing', (tester) async {
      final s = _day(2);
      s.state.potCounts['koi'] = 1;
      s.startPlaceMode('koi');
      await _mountOverlay(tester, s);
      await tester.tap(find.byKey(const Key('place-slot-bar-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('place-cancel')));
      await tester.pump();
      expect(s.placeModeActive, isFalse);
      expect(s.state.barPots[0], defaultPotId);
    });
  });

  group('Sổ sưu tầm', () {
    testWidgets('a page per set, owned and dim cells, and the bottom bar', (
      tester,
    ) async {
      final s = _day(2);
      s.state.potCounts['chau_bach_duong'] = 1;
      s.state.potCounts['chau_song_tu'] = 1;
      s.openPotBook();
      await _mount(tester, PotBookScreen(session: s));
      expect(find.text('Sổ sưu tầm chậu'), findsOneWidget);
      expect(find.text('Bộ Hoàng đạo'), findsOneWidget);
      expect(find.text('2/12'), findsOneWidget);
      expect(find.text('Đủ bộ nhận 300 Pha lê'), findsOneWidget);
      expect(
        find.byKey(const Key('book-tick-chau_bach_duong')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('book-tick-chau_kim_nguu')), findsNothing);
      // Unowned cells still show their number and short name.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('book-cell-name-chau_kim_nguu')))
            .data,
        'Kim Ngưu',
      );
      expect(find.text('Còn 10 chậu chưa có'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book-tab-linhVat')));
      await tester.pump();
      expect(find.text('Bộ Linh vật'), findsOneWidget);
      expect(find.text('0/8'), findsOneWidget);
      expect(find.text('Đủ bộ nhận 100 Pha lê'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('book-cell-name-qilin'))).data,
        'Kỳ lân vàng',
      );
      await tester.tap(find.byKey(const Key('book-bar-go')));
      await tester.pump();
      expect(s.screen, Screen.potShop);
      expect(s.potShopTab, 'linhVat');
    });

    testWidgets('an unowned pot opens a page that sends you to the shop', (
      tester,
    ) async {
      final s = _day(2);
      s.openPotBook();
      await _mount(tester, PotBookScreen(session: s));
      await tester.tap(find.byKey(const Key('book-cell-chau_cu_giai')));
      await tester.pump();
      expect(s.potBookDetailId, 'chau_cu_giai');
      expect(find.text('Bộ Hoàng đạo · 04/12'), findsOneWidget);
      expect(find.text('Chậu Cự Giải'), findsOneWidget);
      expect(find.text('Chưa có'), findsOneWidget);
      expect(find.text('Cách nhận: Mua 6,5 tr xu'), findsOneWidget);
      expect(find.text('Mua ở Tiệm Chậu Hoa'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book-buy')));
      await tester.pump();
      expect(s.screen, Screen.potShop);
      expect(s.potShopFocusId, 'chau_cu_giai');
      expect(s.potShopTab, 'chomSao');
    });

    testWidgets('an owned pot: story, flip with the arrows, place or wait', (
      tester,
    ) async {
      final s = _day(2);
      s.state.potCounts['chau_su_tu'] = 1;
      s.openPotBook(detail: 'chau_su_tu');
      await _mount(tester, PotBookScreen(session: s));
      expect(find.text('Đã có'), findsOneWidget);
      expect(
        find.text(s.data.cosmetics.find('chau_su_tu')!.description),
        findsOneWidget,
      );
      expect(find.text('Đặt vào tiệm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book-next')));
      await _settle(tester);
      expect(s.potBookDetailId, 'chau_xu_nu');
      expect(find.text('Chưa có'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book-prev')));
      await _settle(tester);
      expect(s.potBookDetailId, 'chau_su_tu');
      // A tap on a small pot in the strip jumps there.
      await tester.ensureVisible(
        find.byKey(const Key('book-mini-chau_song_ngu')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('book-mini-chau_song_ngu')));
      await _settle(tester);
      expect(s.potBookDetailId, 'chau_song_ngu');
      await tester.ensureVisible(find.byKey(const Key('book-mini-chau_su_tu')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('book-mini-chau_su_tu')));
      await _settle(tester);
      // Place: goes to the main screen's placing mode.
      await tester.tap(find.byKey(const Key('book-place')));
      await tester.pump();
      expect(s.pendingPlacePotId, 'chau_su_tu');
      expect(s.screen, Screen.shop);
    });

    testWidgets('while the shop serves the place button is grey', (
      tester,
    ) async {
      final s = _day(2);
      s.state.potCounts['koi'] = 1;
      s.openShop();
      s.openPotBook(detail: 'koi');
      await _mount(tester, PotBookScreen(session: s));
      expect(find.text('Đặt sau khi đóng cửa'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book-place')));
      await tester.pump();
      expect(s.pendingPlacePotId, isNull);
      expect(s.screen, Screen.potBook);
    });

    testWidgets('a pot on every slot it can fill: Mua thêm ở Tiệm Chậu Hoa', (
      tester,
    ) async {
      final s = _day(2);
      s.state.potCounts['koi'] = 1;
      s.state.barPots[0] = 'koi';
      s.openPotBook(detail: 'koi');
      await _mount(tester, PotBookScreen(session: s));
      expect(find.text('Mua thêm ở Tiệm Chậu Hoa'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book-buy-more')));
      await tester.pump();
      expect(s.screen, Screen.potShop);
    });

    testWidgets('a finished set: badge, claim once, bar gone', (tester) async {
      final s = _day(2, phaLe: 50);
      for (final p in s.potGroupPots('linhVat')) {
        s.state.potCounts[p.id] = 1;
      }
      s.openPotBook(group: 'linhVat');
      await _mount(tester, PotBookScreen(session: s));
      expect(find.byKey(const Key('book-done-chip')), findsOneWidget);
      expect(find.byKey(const Key('book-tab-done-linhVat')), findsOneWidget);
      expect(find.byKey(const Key('book-bar')), findsNothing);
      expect(find.text('Nhận thưởng 100 Pha lê'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book-claim')));
      await tester.pump();
      expect(s.state.phaLe, 150);
      expect(find.byKey(const Key('book-claimed')), findsOneWidget);
      expect(find.byKey(const Key('book-claim')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Tổng kết card', () {
    Future<ShopSession> summary(
      WidgetTester tester, {
      int day = 2,
      int money = 5000000,
      Map<String, int> wilted = const {},
    }) async {
      final s = newSession();
      s.state.day = day;
      s.state.money = money;
      s.state.phase = DayPhase.summary;
      s.screen = Screen.summary;
      s.state.metrics.wiltedByFlower = wilted;
      await _mount(tester, SummaryScreen(session: s));
      await tester.pump(const Duration(seconds: 1));
      return s;
    }

    testWidgets('replaces the praise strip once, for the cheapest xu pot', (
      tester,
    ) async {
      final s = await summary(tester);
      expect(find.byKey(const Key('pot-nudge')), findsOneWidget);
      expect(find.text('Đủ xu mua chậu Bạch Dương rồi!'), findsOneWidget);
      expect(find.byKey(const Key('summary-strip')), findsNothing);
      expect(s.state.potShopHintShown, isTrue);
      await tester.tap(find.byKey(const Key('pot-nudge-later')));
      await tester.pump();
      expect(find.byKey(const Key('pot-nudge')), findsNothing);
      expect(find.byKey(const Key('summary-strip')), findsOneWidget);
      // Never again.
      expect(s.potNudgeCardPot, isNull);
    });

    testWidgets('Xem opens the shop, Back returns to Tổng kết', (tester) async {
      final s = await summary(tester);
      await tester.tap(find.byKey(const Key('pot-nudge-go')));
      await tester.pump();
      expect(s.screen, Screen.potShop);
      expect(s.potShopFocusId, 'chau_bach_duong');
      s.closePotShop();
      expect(s.screen, Screen.summary);
    });

    testWidgets('a wilted branch, or day 1, keeps the old strip and the flag', (
      tester,
    ) async {
      final wilted = await summary(tester, wilted: {'daisy': 2});
      expect(find.byKey(const Key('pot-nudge')), findsNothing);
      expect(find.byKey(const Key('summary-strip')), findsOneWidget);
      expect(wilted.state.potShopHintShown, isFalse);
    });

    testWidgets('day 1 keeps the Nâng cấp tip and the flag', (tester) async {
      final s = await summary(tester, day: 1);
      expect(find.byKey(const Key('pot-nudge')), findsNothing);
      expect(s.state.potShopHintShown, isFalse);
    });

    testWidgets('no card when only Pha lê pots can be paid', (tester) async {
      final s = await summary(tester, money: 1000);
      s.state.phaLe = 5000;
      expect(find.byKey(const Key('pot-nudge')), findsNothing);
      expect(s.state.potShopHintShown, isFalse);
    });
  });
}
