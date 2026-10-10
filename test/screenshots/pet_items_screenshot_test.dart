// Renders the pet room, the item picker, the item shop and the item gift
// popups to PNGs. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/pet_items_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/pet_item_room.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/pet_item_shop.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Future<void> _save(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _frame(Key key, Widget child) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        type: MaterialType.transparency,
        child: GameFrame(child: child),
      ),
    ),
  ),
);

ShopSession _room({
  String pet = 'meo',
  int stage = 1,
  Map<String, int> items = const {},
  Map<String, String> worn = const {},
}) {
  final s = newSession();
  s.state.day = strayCatDay;
  s.state.hasCat = true;
  s.state.addPet(pet);
  s.state.ownedPet(pet)!.stage = stage;
  s.state.petItems.addAll(items);
  s.state.ownedPet(pet)!.worn.addAll(worn);
  s.state.money = 50000000;
  s.state.phaLe = 400;
  s.openPetRoom(pet);
  return s;
}

Widget _screen(ShopSession s) => ListenableBuilder(
  listenable: s,
  builder: (context, _) => Stack(
    children: [
      PetScreen(session: s),
      if (s.petItemShopOpen)
        Positioned.fill(child: PetItemShopScreen(session: s)),
      if (s.petItemBuyId != null)
        Positioned.fill(child: PetItemBuyPopup(session: s)),
      if (s.petItemGift != null)
        Positioned.fill(child: PetItemGiftPopup(session: s)),
    ],
  ),
);

Future<void> _shoot(WidgetTester tester, String name, ShopSession s) async {
  await tester.pumpWidget(_frame(ValueKey('shot-$name'), _screen(s)));
  await _settle(tester);
  await _save(tester, ValueKey('shot-$name'), name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pet item shots', skip: _dir == null, (tester) async {
    await loadTestFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final none = newSession()..state.day = strayCatDay;
    none.openPets();
    await _shoot(tester, 'petdo_0_khong_co_pet_360x640', none);

    await _shoot(tester, 'petdo_1_phong_chua_co_do_360x640', _room());

    await _shoot(
      tester,
      'petdo_2_phong_dang_deo_360x640',
      _room(
        items: {'no_co_vai': 1, 'mao_lua': 2, 'canh_binh_minh': 1},
        worn: {
          'neck': 'no_co_vai',
          'head': 'mao_lua',
          'accessory': 'canh_binh_minh',
        },
      ),
    );

    await _shoot(
      tester,
      'petdo_3_toi_da_3_huyen_thoai_360x640',
      _room(
        pet: 'hac',
        stage: 2,
        items: {
          'day_chuyen_suong_mai': 1,
          'vuong_mien_som_mai': 1,
          'canh_binh_minh': 1,
        },
        worn: {
          'neck': 'day_chuyen_suong_mai',
          'head': 'vuong_mien_som_mai',
          'accessory': 'canh_binh_minh',
        },
      ),
    );

    final empty = _room();
    empty.openPetItemPicker('neck');
    await _shoot(tester, 'petdo_4_chon_do_kho_trong_360x640', empty);

    final pick = _room(
      items: {'no_co_vai': 3, 'vong_hoa_nho': 1, 'chuong_ngoc': 1},
      worn: {'neck': 'no_co_vai'},
    );
    pick.openPetItemPicker('neck');
    await _shoot(tester, 'petdo_5_chon_do_360x640', pick);

    final detail = _room(
      items: {'no_co_vai': 3, 'vong_hoa_nho': 1, 'chuong_ngoc': 1},
      worn: {'neck': 'no_co_vai'},
    );
    detail.openPetItemPicker('neck');
    detail.selectPetItemDetail('chuong_ngoc');
    await _shoot(tester, 'petdo_6_chi_tiet_do_360x640', detail);

    final sell = _room(
      items: {'no_co_vai': 3, 'vong_hoa_nho': 1},
      worn: {'neck': 'no_co_vai'},
    );
    sell.openPetItemPicker('neck');
    sell.openPetItemSell('no_co_vai');
    await _shoot(tester, 'petdo_7_ban_xac_nhan_360x640', sell);

    final shop = _room();
    shop.openPetItemShop(slot: 'neck');
    await _shoot(tester, 'petdo_8_tiem_do_360x640', shop);

    final shopLeg = _room();
    shopLeg.openPetItemShop(slot: 'head');
    shopLeg.selectPetItemShopTab('head');
    await _shoot(tester, 'petdo_9_tiem_do_mu_360x640', shopLeg);

    final buy = _room();
    buy.openPetItemShop(slot: 'neck');
    buy.openPetItemBuy('chuong_ngoc');
    await _shoot(tester, 'petdo_10_mua_xac_nhan_360x640', buy);

    final giftNew = _room();
    giftNew.petItemGifts.add(
      const PetItemGift(
        itemId: 'vuong_mien_som_mai',
        kind: PetItemGiftKind.rank,
        rank: 2,
      ),
    );
    await _shoot(tester, 'petdo_11_qua_hang_moi_360x640', giftNew);

    final giftDup = _room(items: {'canh_binh_minh': 2});
    giftDup.petItemGifts.add(
      const PetItemGift(
        itemId: 'canh_binh_minh',
        kind: PetItemGiftKind.mystery,
      ),
    );
    await _shoot(tester, 'petdo_12_khach_la_trung_360x640', giftDup);
  });
}
