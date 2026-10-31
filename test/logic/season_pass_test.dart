import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_game/logic/season_pass.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/save/game_state.dart';

import '../helpers.dart';

class _FakeApi implements WalletApi {
  final calls = <(String, Map<String, Object?>)>[];
  Map<String, Object?> reply = {};
  String? refuse;

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> data,
  ) async {
    calls.add((name, data));
    if (refuse != null) throw WalletException(refuse!);
    return reply;
  }
}

void main() {
  final economy = jsonDecode(
    File('assets/data/economy.json').readAsStringSync(),
  );

  test('config reads economy.json seasonPass; absent block = off', () {
    final cfg = SeasonPassConfig.fromEconomy(economy)!;
    final sp = (economy as Map)['seasonPass'] as Map;
    expect(cfg.tierCount, (sp['tiers'] as List).length);
    expect(cfg.premiumPrice, (sp['premium'] as Map)['price']);
    expect(
      cfg.tierXp.fold<int>(0, (a, b) => a + b),
      (sp['xp'] as Map)['totalToMax'],
    );
    expect(cfg.tierAt(0), 0);
    expect(cfg.tierAt(cfg.tierXp.first), 1);
    expect(SeasonPassConfig.fromEconomy({}), isNull);
    expect(SeasonPassConfig.fromEconomy(null), isNull);
  });

  test('service calls the callables and reads the result', () async {
    final api = _FakeApi()
      ..reply = {
        'status': 'claimed',
        'mailId': 'sp_u_season-2_free_2',
        'period': 'season-2',
        'xp': 450,
        'premium': false,
        'claimed': ['free_2'],
      };
    final r = await SeasonPassService(api).claim(2, SeasonPassTrack.free);
    expect(api.calls.single.$1, 'seasonPassClaim');
    expect(api.calls.single.$2, {'tier': 2, 'track': 'free'});
    expect(r.mailId, 'sp_u_season-2_free_2');
    expect(r.pass.isClaimed(2, SeasonPassTrack.free), isTrue);
    api.refuse = 'balance';
    await expectLater(
      SeasonPassService(api).buyPremium(),
      throwsA(isA<WalletException>().having((e) => e.code, 'code', 'balance')),
    );
  });

  test('a claim answer carries the granted skins', () async {
    final api = _FakeApi()
      ..reply = {
        'status': 'claimed',
        'period': 'season-2',
        'skins': ['skin_quay_tri_an_2011', 7],
      };
    final r = await SeasonPassService(api).claim(30, SeasonPassTrack.premium);
    expect(r.skins, ['skin_quay_tri_an_2011']);
  });

  test('server skins land in the save; event skin, never for sale', () {
    final s = newSession();
    final def = s.skins.byId('skin_quay_tri_an_2011')!;
    expect(def.slot, 'quay');
    expect(def.isEvent, isTrue);
    expect(s.skinPrice(def).amount, 0);
    expect(s.skinHas(def.id), isFalse);
    s.addServerSkins(['skin_quay_tri_an_2011', 'unknown_skin']);
    expect(s.skinHas(def.id), isTrue);
    expect(s.state.ownedSkins, ['skin_quay_tri_an_2011']);
    s.state.phase = DayPhase.preparing;
    expect(s.wearSkins({'quay': def.id}), 1);
    expect(s.skinWorn('quay'), def.id);
  });
}
