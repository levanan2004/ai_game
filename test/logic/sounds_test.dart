import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/goals.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/settings_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test(
    'bgm_main plays only after the first tap, and only while music is on',
    () {
      final sounds = Sounds();
      sounds.musicOn = true;
      sounds.playMusic('bgm_main');
      expect(sounds.activeTrack, isNull);
      sounds.unlock();
      sounds.playMusic('bgm_main');
      expect(sounds.activeTrack, 'bgm_main');
      sounds.musicOn = false;
      sounds.playMusic('bgm_main');
      expect(sounds.activeTrack, isNull);
      sounds.musicOn = true;
      sounds.playMusic('bgm_main');
      expect(sounds.activeTrack, 'bgm_main');
    },
  );

  test('the effects switch persists and mutes effects', () async {
    final backing = <String, String>{};
    final heard = <String>[];
    final s = newSession(
      backing: backing,
      sounds: Sounds(heard: heard),
    );
    s.startNewGame();
    await s.pendingSaves;
    s.setSfx(false);
    heard.clear();
    s.addBundle('rose');
    s.buyAndGoToShop();
    expect(heard, isNot(contains('market_buy.mp3')));
    await s.pendingSaves;
    final saved = GameState.decode(backing[ProgressStore.storageKey])!;
    expect(saved.sfxOn, isFalse);
    expect(saved.phase, DayPhase.market);

    s.backToMarket();
    s.setSfx(true);
    heard.clear();
    s.addBundle('rose');
    s.buyAndGoToShop();
    expect(heard, contains('market_buy.mp3'));
  });

  test('buying, wrapping and paying play the everyday effects', () {
    final heard = <String>[];
    final s = newSession(seed: 5, sounds: Sounds(heard: heard));
    for (final f in s.unlockedFlowers) {
      s.addBundle(f.id);
      s.addBundle(f.id);
    }
    s.buyAndGoToShop();
    s.openShop();
    s.state.goals = [
      const DailyGoal(
        templateId: 'sell_bouquets',
        title: 'Bán 1 bó hoa',
        metric: 'bouquetsSold',
        compare: '>=',
        target: 1,
        reward: 1000,
      ),
    ];
    heard.clear();
    _serveFront(s);
    expect(heard, contains('customer_arrive.mp3'));
    expect(heard, contains('flower_pick.mp3'));
    expect(heard, contains('wrap_paper.mp3'));
    expect(heard, contains('ribbon_tie.mp3'));
    expect(heard, contains('bouquet_done.mp3'));
    expect(heard, contains('cash_register.mp3'));
    expect(heard, contains('goal_done.mp3'));
    s.closeDeliveryPopup();
    _serveFront(s);
    expect(heard, contains('star_up.mp3'));
  });

  test('a customer arriving and leaving plays the door and the lost star', () {
    final heard = <String>[];
    final s = newSession(sounds: Sounds(heard: heard));
    stockAndOpen(s);
    heard.clear();
    final c = waitForCustomer(s);
    expect(heard, contains('customer_arrive.mp3'));
    c.patienceLeft = 0.05;
    s.tick(0.1);
    expect(heard, contains('customer_leave.mp3'));
    expect(heard, contains('star_down.mp3'));
  });

  test('the summary and the next morning play their cues', () {
    final heard = <String>[];
    final s = newSession(sounds: Sounds(heard: heard));
    stockAndOpen(s);
    heard.clear();
    s.closeEarly();
    expect(s.screen, Screen.summary);
    expect(heard, contains('summary_count.mp3'));
    s.startNextDay();
    expect(heard, contains('day_start.mp3'));
  });

  test('a new online order plays online_order', () {
    List<String>? heard;
    for (var seed = 1; seed < 40; seed++) {
      final log = <String>[];
      final s = newSession(
        seed: seed,
        sounds: Sounds(heard: log),
      );
      s.state.day = 3;
      s.state.money = 2000000;
      expect(s.hireShipper('bike'), isTrue, reason: 'seed $seed');
      s.state.phase = DayPhase.summary;
      log.clear();
      s.startNextDay();
      if (s.onlineOrders.isEmpty) continue;
      heard = log;
      break;
    }
    expect(heard, isNotNull);
    expect(heard, contains('online_order.mp3'));
  });

  test('a failed sign-in plays error', () async {
    final heard = <String>[];
    final s = newSession(sounds: Sounds(heard: heard));
    await s.signIn();
    expect(s.authError, isNotNull);
    expect(heard, contains('error.mp3'));
  });

  testWidgets('a button tap plays ui_tap', (tester) async {
    final heard = <String>[];
    final sounds = Sounds(heard: heard);
    await tester.pumpWidget(
      MaterialApp(
        home: SoundScope(
          sounds: sounds,
          child: const ChunkyButton(label: 'Ok', onPressed: _noop),
        ),
      ),
    );
    await tester.tap(find.text('Ok'));
    expect(heard, ['ui_tap.mp3']);
    sounds.effectsOn = false;
    heard.clear();
    await tester.tap(find.text('Ok'));
    expect(heard, isEmpty);
  });

  testWidgets('Hiệu ứng âm thanh sits under Nhạc nền', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = newSession();
    s.showTitle();
    await tester.pumpWidget(MaterialApp(home: SettingsPopup(session: s)));
    await tester.pump();
    expect(find.text('Hiệu ứng âm thanh'), findsOneWidget);
    final music = tester.getRect(find.text('Nhạc nền'));
    final effects = tester.getRect(find.text('Hiệu ứng âm thanh'));
    expect(effects.top, greaterThan(music.bottom));
    expect(
      tester.getSize(find.byKey(const Key('settings-sfx-row'))).height,
      52,
    );
    expect(
      tester.getSize(find.byKey(const Key('settings-sfx'))),
      const Size(44, 26),
    );
    expect(
      tester.getSize(find.byKey(const Key('settings-music'))),
      const Size(44, 26),
    );
    await tester.tap(find.byKey(const Key('settings-sfx')));
    await tester.pump();
    expect(s.state.sfxOn, isFalse);
  });

  test('summary, temple, ambience and the later cues', () {
    final heard = <String>[];
    final sounds = Sounds(heard: heard)..unlock();
    final s = newSession(sounds: sounds);
    sounds.playMusic(s.musicTrack);
    expect(sounds.activeTrack, 'bgm_main');

    stockAndOpen(s);
    expect(heard, contains('market_add.mp3'));
    expect(heard, contains('shop_open.mp3'));
    sounds.setAmbience(s.state.phase == DayPhase.open);
    expect(sounds.ambienceOn, isTrue);

    final c = waitForCustomer(s);
    expect(heard, contains('order_bubble.mp3'));
    c.patienceLeft = c.patienceMax * s.e.patienceWarningAt + 0.2;
    heard.clear();
    s.tick(1);
    expect(heard, contains('patience_low.mp3'));

    s.openTable();
    final flower = c.request.stems.keys.first;
    expect(s.addStem(flower), isTrue);
    heard.clear();
    s.removeStem(s.draft.stems.single.uid);
    expect(heard, contains('flower_remove.mp3'));

    heard.clear();
    s.openPause();
    expect(heard, contains('popup_open.mp3'));
    s.resumeFromPause();
    expect(heard, contains('popup_close.mp3'));

    s.setSfx(false);
    expect(sounds.ambienceOn, isFalse);
    expect(heard, contains('toggle.mp3'));
    heard.clear();
    s.setOwnerAvatar('lan_anh');
    expect(heard, isEmpty);
    s.setSfx(true);
    expect(heard, contains('toggle.mp3'));
    heard.clear();
    s.setOwnerAvatar('ha_my');
    expect(heard, contains('avatar_saved.mp3'));

    s.state.stock.add(StockBatch(flowerId: 'rose', count: 1, freshnessLeft: 1));
    s.state.stock.add(
      StockBatch(flowerId: 'daisy', count: 1, freshnessLeft: 2),
    );
    s.closeEarly();
    sounds.playMusic(s.musicTrack);
    expect(sounds.activeTrack, 'bgm_summary');
    heard.clear();
    s.startNextDay();
    expect(heard, contains('wilted_discard.mp3'));
    expect(heard, contains('wilt_warning.mp3'));
    expect(heard, contains('day_start.mp3'));

    heard.clear();
    s.openDonors();
    expect(heard, contains('temple_bell.mp3'));
    sounds.playMusic(s.musicTrack);
    expect(sounds.activeTrack, 'bgm_temple');
  });
}

void _noop() {}

void _serveFront(ShopSession s) {
  final c = waitForCustomer(s);
  s.openTable();
  final r = c.request;
  for (final e in r.stems.entries) {
    for (var i = 0; i < e.value; i++) {
      expect(s.addStem(e.key), isTrue);
    }
  }
  if (r.fillerId != null) {
    for (var i = 0; i < r.fillerCount; i++) {
      expect(s.addStem(r.fillerId!), isTrue);
    }
  }
  s.selectPaper(r.paperId);
  s.selectRibbon(r.ribbonId);
  expect(s.beginWrap(), isNotNull);
  final res = s.finishWrap(hit: true);
  expect(res, isNotNull);
  expect(res!.review.outcome, 'great');
}
