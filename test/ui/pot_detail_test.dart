import 'dart:io';
import 'dart:typed_data';

import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/pot_popup.dart';
import 'package:ai_game/ui/pot_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../logic/vip_test.dart' show FakeVipWallet, vipSession;

/// FakeVipWallet plus the server's own VIP pot list (functions/vip.js
/// ownedVipPots), so the app is seen to follow the server.
class _PotsWallet extends FakeVipWallet {
  _PotsWallet({super.level, this.pots});

  List<String>? pots;

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> data,
  ) async {
    final raw = await super.call(name, data);
    final vip = Map<String, Object?>.from(raw['vip']! as Map);
    if (pots != null) vip['pots'] = pots;
    return {...raw, 'vip': vip};
  }
}

const _vipPots = ['chau_ngoc_bich', 'chau_hoang_kim'];

(int, int) _webpSize(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(b);
  // VP8X: canvas size at 24..29 (24-bit, minus one).
  expect(String.fromCharCodes(b.sublist(12, 16)), 'VP8X', reason: path);
  final w = (d.getUint8(24) | d.getUint8(25) << 8 | d.getUint8(26) << 16) + 1;
  final h = (d.getUint8(27) | d.getUint8(28) << 8 | d.getUint8(29) << 16) + 1;
  return (w, h);
}

Future<void> _mount(WidgetTester tester, ShopSession s) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => s.potPickerOpen
              ? Center(child: PotPopup(session: s))
              : const SizedBox(key: Key('closed')),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openDetail(WidgetTester tester, String id) async {
  final cell = find.byKey(Key('pot-cell-$id'));
  await tester.scrollUntilVisible(cell, 80);
  await tester.pump();
  await tester.tap(cell);
  await tester.pump();
}

void main() {
  group('economy.json: the 2 VIP pots (Hà Phương vip.vipPots)', () {
    test('in pots[] as set vip, decoration only, not sold, levels 3 and 6', () {
      final e = newSession().e;
      expect(e.potSets.map((x) => x.id), contains('vip'));
      for (final id in _vipPots) {
        final p = e.pot(id);
        expect(p.set, 'vip');
        expect(p.purchasable, isFalse);
        expect(p.charm, 0);
        expect(p.stats, isEmpty);
      }
      expect(e.vip.pots['chau_ngoc_bich']!.level, 3);
      expect(e.vip.pots['chau_hoang_kim']!.level, 6);
      expect(e.pot('chau_ngoc_bich').nameVi, 'Chậu Ngọc Bích');
      expect(e.pot('chau_hoang_kim').nameVi, 'Chậu Hoàng Kim');
    });

    test('art: 490x490 webp like the other pots, small', () {
      for (final id in _vipPots) {
        final path = Art.pot(id);
        expect(_webpSize(path), (490, 490), reason: path);
        expect(File(path).lengthSync(), lessThan(70 * 1024), reason: path);
      }
    });
  });

  group('VIP pots are owned only through the server tier', () {
    test('no VIP: not owned, even with copies in the save', () async {
      final s = vipSession(FakeVipWallet(level: 2));
      s.state.potCounts['chau_ngoc_bich'] = 2;
      await s.syncWallet();
      expect(s.potOwned('chau_ngoc_bich'), 0);
      expect(s.potHas('chau_ngoc_bich'), isFalse);
      expect(s.potListed(s.e.pot('chau_ngoc_bich')), isTrue);
      s.openPotPicker(bar: true, index: 0);
      expect(s.placePot('chau_ngoc_bich'), isFalse);
    });

    test(
      'VIP 3 owns Ngọc Bích, VIP 6 both; the book total leaves them out',
      () async {
        final api = FakeVipWallet(level: 3);
        final s = vipSession(api);
        final kinds = s.potKindsTotal;
        await s.syncWallet();
        expect(s.potOwned('chau_ngoc_bich'), 1);
        expect(s.potOwned('chau_hoang_kim'), 0);
        api.level = 6;
        await s.syncWallet();
        expect(s.potOwned('chau_hoang_kim'), 1);
        expect(s.potKindsTotal, kinds);
        expect(s.potKindsTotal, s.e.pots.where((p) => !p.unlimited).length - 2);
        expect(s.potsOwnedCount, 0);
      },
    );

    test('the server list wins over the level', () async {
      final s = vipSession(_PotsWallet(level: 6, pots: ['chau_ngoc_bich']));
      await s.syncWallet();
      expect(s.potOwned('chau_ngoc_bich'), 1);
      expect(s.potOwned('chau_hoang_kim'), 0);
    });

    test('a drop takes the VIP pot off the shelf (free bucket back)', () async {
      final api = FakeVipWallet(level: 6);
      final s = vipSession(api);
      await s.syncWallet();
      s.openPotPicker(bar: false, index: 1);
      expect(s.placePot('chau_hoang_kim'), isTrue);
      expect(s.state.displayPots[1], 'chau_hoang_kim');
      api.level = 5;
      await s.syncWallet();
      expect(s.state.displayPots[1], defaultPotId);
    });

    test('before the server answered, the shelf stays as saved', () async {
      final s = vipSession(FakeVipWallet(level: 0));
      s.state.barPots[0] = 'chau_ngoc_bich';
      // No syncWallet yet: no VIP answer.
      s.vip.potUnlocked('chau_ngoc_bich');
      expect(s.state.barPots[0], 'chau_ngoc_bich');
      await s.syncWallet();
      expect(s.state.barPots[0], defaultPotId);
    });

    test('VIP perks list the pots now (VIP 3, VIP 6)', () {
      final v = newSession().vip;
      expect(v.potsAt(3), ['chau_ngoc_bich']);
      expect(v.potsAt(6), ['chau_hoang_kim']);
    });
  });

  group('popup chi tiết chậu (Nhất chu_chi_tiet_chau.md)', () {
    testWidgets(
      'a Sơn Hải pot in the cupboard: Mị lực, stats as %, how to activate',
      (tester) async {
        final s = newSession();
        s.state.potCounts['chau_chuc_long'] = 1;
        s.openPotPicker(bar: true, index: 0);
        await _mount(tester, s);
        await _openDetail(tester, 'chau_chuc_long');
        expect(find.text(PotText.detailTitle), findsOneWidget);
        expect(find.text('Sơn Hải'), findsOneWidget);
        expect(find.text(PotText.charm(60)), findsOneWidget);
        expect(find.text(PotText.charmRule), findsOneWidget);
        expect(find.text(PotText.statsTitle), findsOneWidget);
        // 0.015 in economy.json -> "1,5%".
        expect(find.text('Thu nhập +1,5%'), findsOneWidget);
        expect(find.text(PotText.statusInStorage), findsOneWidget);
        expect(find.text(PotText.statusShelfOnly), findsOneWidget);
        expect(find.text(PotText.sourceSonHai), findsOneWidget);
        expect(find.text(PotText.sourceSonHaiOwned), findsOneWidget);
        expect(find.text(PotText.descs['chau_chuc_long']!), findsOneWidget);
        expect(find.text(PotText.shelfCount(0, 11)), findsOneWidget);
        await tester.tap(find.byKey(const Key('place-chau_chuc_long')));
        await tester.pump();
        expect(s.state.barPots[0], 'chau_chuc_long');
        expect(
          find.text(PotText.placedToast('Chậu Chúc Long')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets('on the shelf: Đang có tác dụng, Cất vào tủ frees the slot', (
      tester,
    ) async {
      final s = newSession();
      s.state.potCounts['koi'] = 1;
      s.state.barPots[2] = 'koi';
      s.openPotPicker(bar: true, index: 2);
      await _mount(tester, s);
      await _openDetail(tester, 'koi');
      expect(find.text('Linh vật'), findsOneWidget);
      expect(find.byKey(const Key('pot-detail-charm-koi')), findsNothing);
      expect(find.text(PotText.statusActive), findsOneWidget);
      expect(find.text(PotText.shelfCount(1, 11)), findsOneWidget);
      expect(find.byKey(const Key('place-koi')), findsNothing);
      await tester.tap(find.byKey(const Key('store-koi')));
      await tester.pump();
      expect(s.state.barPots[2], defaultPotId);
      expect(find.text(PotText.storedToast('Chậu cá chép')), findsOneWidget);
      expect(find.text(PotText.statusInStorage), findsOneWidget);
      expect(find.text(PotText.shelfCount(0, 11)), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a Hoàng đạo pot: Chậu trang trí, no status', (tester) async {
      final s = newSession();
      s.state.potCounts['chau_su_tu'] = 1;
      s.openPotPicker(bar: true, index: 0);
      await _mount(tester, s);
      await _openDetail(tester, 'chau_su_tu');
      expect(find.text('Hoàng đạo'), findsOneWidget);
      expect(find.text(PotText.statNone), findsOneWidget);
      expect(
        find.byKey(const Key('pot-detail-status-chau_su_tu')),
        findsNothing,
      );
    });

    testWidgets('a VIP pot without the tier: Quà VIP 3, not in the shop yet', (
      tester,
    ) async {
      final s = vipSession(FakeVipWallet(level: 1));
      await tester.runAsync(s.syncWallet);
      s.openPotPicker(bar: true, index: 0);
      await _mount(tester, s);
      await _openDetail(tester, 'chau_ngoc_bich');
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text(PotText.statNone), findsOneWidget);
      expect(find.text(PotText.statusNotOwned), findsOneWidget);
      expect(find.text(PotText.sourceVip(3)), findsOneWidget);
      expect(find.text(PotText.descs['chau_ngoc_bich']!), findsOneWidget);
      expect(find.byKey(const Key('place-chau_ngoc_bich')), findsNothing);
      expect(find.byKey(const Key('buy-chau_ngoc_bich')), findsNothing);
    });

    testWidgets('a VIP pot with the tier: placed like any pot', (tester) async {
      final s = vipSession(FakeVipWallet(level: 6));
      await tester.runAsync(s.syncWallet);
      s.openPotPicker(bar: true, index: 0);
      await _mount(tester, s);
      await _openDetail(tester, 'chau_hoang_kim');
      expect(find.text(PotText.sourceVip(6)), findsOneWidget);
      expect(find.text(PotText.statusNotOwned), findsNothing);
      await tester.tap(find.byKey(const Key('place-chau_hoang_kim')));
      await tester.pump();
      expect(s.state.barPots[0], 'chau_hoang_kim');
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
