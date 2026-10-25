import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('old saves: seat/bowl ids map to the new skin ids, same save keys', () {
    final old = newSession().state
      ..petSeats = ['dem_xanh']
      ..petBowls = ['bat_la']
      ..petSeat = 'dem_xanh'
      ..petBowl = 'bat_la';
    final loaded = GameState.decode(old.encode())!;
    expect(loaded.petSeats, ['cho_ngoi_mac_dinh']);
    expect(loaded.petBowls, ['bat_an_mac_dinh']);
    expect(loaded.petSeat, 'cho_ngoi_mac_dinh');
    expect(loaded.petBowl, 'bat_an_mac_dinh');
    final json = loaded.toJson();
    expect(json['petSeat'], 'cho_ngoi_mac_dinh');
    expect(json.containsKey('ownedSkins'), isFalse);
  });

  test('new player wears the free skins of all 8 slots', () {
    final s = newSession();
    for (final slot in [
      'nenManHinh',
      'khungAvatar',
      'bienHieu',
      'quay',
      'choNgoi',
      'batAn',
      'doChoi',
      'nenPhong',
    ]) {
      expect(s.skinWorn(slot), s.skins.defaultId(slot));
    }
  });

  test('pot frames: khung_chau ids become khung_avatar, owned and worn', () {
    final old = newSession().state
      ..ownedSkins = ['khung_chau_tet', 'quay_he_bien']
      ..equippedSkins = {'khungChau': 'khung_chau_tet', 'quay': 'quay_he_bien'};
    final back = GameState.decode(old.encode())!;
    expect(back.ownedSkins, ['khung_avatar_tet', 'quay_he_bien']);
    expect(back.equippedSkins, {
      'khungAvatar': 'khung_avatar_tet',
      'quay': 'quay_he_bien',
    });
    final s = newSession();
    s.state
      ..ownedSkins = back.ownedSkins
      ..equippedSkins = back.equippedSkins;
    expect(s.skinWorn('khungAvatar'), 'khung_avatar_tet');
    expect(s.skinWornSet('shop').containsKey('khungAvatar'), isFalse);
    expect(s.skinWornSet('shop').containsKey('khungChau'), isFalse);
  });

  test('buy with xu, wear, and it survives encode/decode', () async {
    final s = newSession();
    s.state.phase = DayPhase.summary;
    final he = s.skins.byId('quay_he_bien')!;
    final price = s.skinPrice(he).amount;
    s.state.money = price + 5;
    expect(await s.buySkin(he.id), isTrue);
    expect(s.state.money, 5);
    expect(s.skinHas(he.id), isTrue);
    expect(await s.buySkin(he.id), isFalse, reason: 'owned forever, once');
    expect(s.wearSkins({'quay': he.id}), 1);
    expect(s.skinWorn('quay'), he.id);
    final back = GameState.decode(s.state.encode())!;
    expect(back.ownedSkins, [he.id]);
    expect(back.equippedSkins, {'quay': he.id});
  });

  test(
    'cushion skins go to petSeats/petSeat; Pha lê offline is local',
    () async {
      final s = newSession();
      final tet = s.skins.byId('cho_ngoi_tet')!;
      s.state.phaLe = s.skinPrice(tet).amount;
      expect(await s.buySkin(tet.id), isTrue);
      expect(s.state.phaLe, 0);
      expect(s.state.petSeats, contains(tet.id));
      s.wearSkins({'choNgoi': tet.id});
      expect(s.state.petSeat, tet.id);
    },
  );

  test('event skins are not sold; unowned skins cannot be worn', () async {
    final s = newSession();
    s.state.phase = DayPhase.summary;
    s.state.money = 1 << 40;
    s.state.phaLe = 99999;
    expect(await s.buySkin('quay_bxh_mua1'), isFalse);
    expect(s.wearSkins({'quay': 'quay_tet'}), 0);
    expect(s.skinWorn('quay'), 'quay_mac_dinh');
  });

  test('shop skins change only while the shop is closed', () async {
    final s = newSession();
    s.state.phase = DayPhase.open;
    s.state.money = 1 << 40;
    expect(s.skinGroupEditable('shop'), isFalse);
    expect(s.skinGroupEditable('petRoom'), isTrue);
    expect(await s.buySkin('quay_he_bien'), isFalse);
    expect(seatDefaultSkin, 'cho_ngoi_mac_dinh');
  });
}
