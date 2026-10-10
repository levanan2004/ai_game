import 'dart:io';
import 'dart:math';

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/data/game_data.dart';
import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/supporters.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/save/terms_consent.dart';

/// The real data files shipped in assets/data. [economy] swaps the economy
/// JSON text (a test fixture, e.g. with a pet item catalog).
GameData loadTestData({String? economy}) => GameData.fromJsonStrings(
  economy: economy ?? File('assets/data/economy.json').readAsStringSync(),
  reviews: File('assets/data/reviews.json').readAsStringSync(),
  orders: File('assets/data/orders.json').readAsStringSync(),
  cosmetics: File('assets/data/cosmetics.json').readAsStringSync(),
  avatarIndex: File('assets/images/customers/index.json').readAsStringSync(),
);

ShopSession newSession({
  GameData? data,
  Map<String, String>? backing,
  GameState? saved,
  int seed = 1,
  AccountGateway? account,
  Sounds? sounds,
  String? tabId,
  SupporterSource? supporters,
  SupporterAdmin? supporterAdmin,
  PlayerDirectory? playerDirectory,
  CharmBoardSource? charmBoard,
  bool acceptedTerms = true,
  DateTime Function()? now,
  bool guestSaves = true,
  AccountProfile? lastAccount,
  ProgressStore? store,
  Future<void> Function(int attempt)? retryWait,
}) {
  return ShopSession(
    data: data ?? loadTestData(),
    store: store ?? ProgressStore.memory(backing ?? {}),
    saved: saved,
    random: Random(seed),
    supporters: supporters,
    supporterAdmin: supporterAdmin,
    playerDirectory: playerDirectory,
    charmBoard: charmBoard,
    account: account,
    sounds: sounds,
    tabId: tabId,
    terms: acceptedTerms ? acceptedTermsNow() : null,
    now: now,
    // Older tests check saves on the guest slot; account tests pass false
    // to get the game's real rule (guest play is not saved).
    guestSaves: guestSaves,
    lastAccount: lastAccount,
    retryWait: retryWait ?? (_) async {},
  );
}

/// Consent to the current terms version, as if tapped just now.
TermsConsent acceptedTermsNow() =>
    TermsConsent(version: termsVersion, acceptedAt: DateTime.now());

/// A store backing that already holds consent, so ShopApp skips the terms
/// screen.
Map<String, String> withTerms([Map<String, String>? backing]) =>
    (backing ?? <String, String>{})
      ..[ProgressStore.termsKey] = acceptedTermsNow().encode();

var _uid = 0;

Bouquet bouquetOf(
  Map<String, int> stems, {
  String? paper,
  String? ribbon,
  int freshness = 3,
}) {
  final b = Bouquet(paperId: paper, ribbonId: ribbon);
  for (final e in stems.entries) {
    for (var i = 0; i < e.value; i++) {
      b.stems.add(Stem(uid: _uid++, flowerId: e.key, freshnessLeft: freshness));
    }
  }
  return b;
}

/// Buys one bundle of every unlocked flower, opens the shop.
void stockAndOpen(ShopSession s) {
  for (final f in s.unlockedFlowers) {
    s.addBundle(f.id);
  }
  s.buyAndGoToShop();
  s.openShop();
}

/// Runs the clock until a customer has walked in.
Customer waitForCustomer(ShopSession s, {double maxSeconds = 400}) {
  var t = 0.0;
  while (s.nextForPlayer == null && t < maxSeconds) {
    if (s.eventOffer != null) {
      s.chooseEvent(s.eventOffer!.choices.last.id);
    }
    s.tick(0.1);
    t += 0.1;
  }
  return s.nextForPlayer!;
}

/// Plays out the rest of the day and taps "Sang ngày mới", which is when
/// progress gets saved.
void finishDayAndCommit(ShopSession s) {
  if (s.state.phase == DayPhase.market) s.buyAndGoToShop();
  if (s.state.phase == DayPhase.preparing) s.openShop();
  s.state.pendingArrivals.clear();
  for (var i = 0; i < 20000 && s.state.phase != DayPhase.summary; i++) {
    if (s.eventOffer != null) {
      s.chooseEvent(s.eventOffer!.choices.last.id);
    }
    s.tick(0.5);
  }
  s.startNextDay();
}
