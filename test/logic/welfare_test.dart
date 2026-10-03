import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/giftcodes.dart';
import 'package:ai_game/logic/login_rewards.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/logic/welfare_slides.dart';
import 'package:ai_game/logic/welfare_text.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/login_tiles.dart';
import 'package:ai_game/ui/welfare_admin_panel.dart';
import 'package:ai_game/ui/welfare_sheet.dart';
import 'package:ai_game/ui/welfare_slides_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 10:00 on 3 Oct 2026 in Việt Nam.
final _start = DateTime.utc(2026, 10, 3, 3);

/// One Firestore in memory. Claims and redeems are atomic like the
/// transactions in FirestoreWelfare and follow the same checks.
class _Server implements WelfareService {
  LoginRewardConfig? config;
  final login = <String, LoginState>{};
  final codes = <String, GiftcodeDoc>{};
  final batches = <String, GiftcodeBatch>{};
  final redeemed = <String, Set<String>>{};
  List<WelfareSlide> slideList = const [];
  Completer<void>? gate;
  var loginWrites = 0;

  @override
  Future<LoginRewardConfig?> loginConfig() async => config;

  @override
  Future<LoginState> loginState(String uid) async =>
      login[uid] ?? LoginState.none;

  @override
  Future<LoginClaimOutcome> claimLogin(
    String uid,
    LoginRewardConfig table,
    DateTime now,
  ) async {
    final wait = gate;
    if (wait != null) await wait.future;
    final state = login[uid] ?? LoginState.none;
    final plan = planLogin(state, table, vnDayNumber(now));
    final next = plan.next;
    if (next == null) {
      return LoginClaimOutcome(
        plan.finished ? LoginClaimResult.finished : LoginClaimResult.already,
        state,
      );
    }
    loginWrites++;
    login[uid] = next;
    return LoginClaimOutcome(LoginClaimResult.claimed, next, day: plan.day);
  }

  @override
  Future<RedeemOutcome> redeem(String uid, String code, DateTime now) async {
    final wait = gate;
    if (wait != null) await wait.future;
    final doc = codes[code];
    final batch = doc == null ? null : batches[doc.batchId];
    final mine = redeemed.putIfAbsent(uid, () => {});
    final problem = checkRedeem(
      code: doc,
      batch: batch,
      redeemedBatch: doc != null && mine.contains(doc.batchId),
      uid: uid,
      now: now,
    );
    if (problem != null) return RedeemOutcome(problem, code: code);
    codes[code] = GiftcodeDoc(
      code: code,
      type: doc!.type,
      batchId: doc.batchId,
      uses: doc.type == GiftcodeType.shared ? doc.uses + 1 : 0,
      maxUses: doc.maxUses,
      usedBy: doc.type == GiftcodeType.single ? uid : null,
    );
    mine.add(doc.batchId);
    return RedeemOutcome(
      RedeemResult.success,
      rewards: batch!.rewards,
      code: code,
    );
  }

  @override
  Future<List<WelfareSlide>> slides() async => slideList;

  void addShared(
    String code, {
    String batch = 'sb',
    int? maxUses,
    bool enabled = true,
    DateTime? startsAt,
    DateTime? expiresAt,
    RewardBundle? rewards,
  }) {
    batches[batch] = GiftcodeBatch(
      id: batch,
      type: GiftcodeType.shared,
      code: code,
      rewards: rewards ?? RewardBundle(const [RewardItem.phaLe(50)]),
      enabled: enabled,
      startsAt: startsAt,
      expiresAt: expiresAt,
      maxUses: maxUses,
    );
    codes[code] = GiftcodeDoc(
      code: code,
      type: GiftcodeType.shared,
      batchId: batch,
      maxUses: maxUses,
    );
  }

  void addBulk(String batch, List<String> list, {RewardBundle? rewards}) {
    batches[batch] = GiftcodeBatch(
      id: batch,
      type: GiftcodeType.single,
      count: list.length,
      rewards: rewards ?? RewardBundle(const [RewardItem.pot('koi')]),
    );
    for (final c in list) {
      codes[c] = GiftcodeDoc(
        code: c,
        type: GiftcodeType.single,
        batchId: batch,
      );
    }
  }
}

class _Clock {
  DateTime now = _start;
  DateTime call() => now;
  void nextDay([int days = 1]) => now = now.add(Duration(days: days));
}

WelfareFeed _feed(_Server server, _Clock clock) =>
    WelfareFeed(service: server, now: clock.call);

void main() {
  test('writer copy for the status lines', () {
    expect(
      WelfareText.loginFinished(repeat: true),
      'Bạn đã nhận đủ quà 7 ngày rồi! Vòng mới sẽ bắt đầu sớm thôi.',
    );
    expect(
      WelfareText.loginFinished(repeat: false),
      'Bạn đã nhận đủ quà 7 ngày rồi, cảm ơn chủ tiệm!',
    );
    expect(WelfareText.loginBusy, 'Đang ghi tên vào sổ điểm danh...');
    expect(
      WelfareText.loginRefused,
      'Chưa điểm danh được. Bạn đăng nhập lại rồi thử nhé.',
    );
    expect(
      WelfareText.loginFailed,
      'Mạng hơi chậm, chưa điểm danh được. Bạn thử lại sau chút nhé.',
    );
    expect(
      redeemMessage(RedeemResult.empty),
      'Bạn nhập mã quà tặng vào ô trên nhé.',
    );
    expect(redeemMessage(RedeemResult.busy), 'Đang mở quà...');
    expect(
      redeemMessage(RedeemResult.refused),
      'Chưa đổi được mã này. Bạn đăng nhập lại rồi thử nhé.',
    );
    expect(
      redeemMessage(RedeemResult.failed),
      'Mạng hơi chậm, chưa đổi được mã. Bạn thử lại sau chút nhé.',
    );
  });

  group('Việt Nam calendar day', () {
    test('the day turns at 17:00 UTC (midnight UTC+7)', () {
      final before = DateTime.utc(2026, 10, 3, 16, 59, 59);
      final after = DateTime.utc(2026, 10, 3, 17);
      expect(vnDayNumber(after), vnDayNumber(before) + 1);
      expect(vnDateKey(before), '2026-10-03');
      expect(vnDateKey(after), '2026-10-04');
      // 06:59 in Việt Nam on the 4th is still the 4th.
      expect(vnDateKey(DateTime.utc(2026, 10, 3, 23, 59)), '2026-10-04');
      expect(vnDayNumber(DateTime.utc(1970, 1, 1, 17)), 1);
    });
  });

  group('7-day table', () {
    test('the default table is the owner\'s, with real pot ids', () {
      final t = defaultLoginRewards;
      expect(t.days, hasLength(7));
      expect(t.repeat, isFalse);
      expect(t.consecutive, isFalse);
      expect(t.day(1), RewardBundle(const [RewardItem.giotHoa(10)]));
      expect(t.day(2), RewardBundle(const [RewardItem.pot('dragon')]));
      expect(t.day(3), RewardBundle(const [RewardItem.phaLe(100)]));
      expect(t.day(4), RewardBundle(const [RewardItem.pot('koi')]));
      expect(t.day(5), RewardBundle(const [RewardItem.pot('crane')]));
      expect(
        t.day(6),
        RewardBundle(const [RewardItem.pot('tiger'), RewardItem.giotHoa(20)]),
      );
      expect(
        t.day(7),
        RewardBundle(const [RewardItem.phaLe(900), RewardItem.giotHoa(25)]),
      );
      for (final id in ['dragon', 'koi', 'crane', 'tiger']) {
        expect(giftKind(id)?.art, GiftArt.pot, reason: id);
      }
      expect(giftKind('dragon')!.name, 'Chậu rồng thiên');
      expect(giftKind('koi')!.name, 'Chậu cá chép');
      expect(giftKind('crane')!.name, 'Chậu hạc');
      expect(giftKind('tiger')!.name, 'Chậu bạch hổ');
    });

    test('a config from Firestore overrides it; a broken one does not', () {
      final custom = defaultLoginRewards
          .withDay(1, RewardBundle(const [RewardItem.phaLe(7)]))
          .copyWith(repeat: true);
      final back = LoginRewardConfig.fromMap(custom.toMap())!;
      expect(back, custom);
      expect(back.day(1).amountOf(RewardKind.phaLe), 7);
      expect(back.repeat, isTrue);
      expect(LoginRewardConfig.fromMap(null), isNull);
      expect(LoginRewardConfig.fromMap({'days': []}), isNull);
      expect(LoginRewardConfig.fromMap({'days': 'x'}), isNull);
    });

    test('one tile per day, gaps allowed, stops after day 7', () {
      final t = defaultLoginRewards;
      var s = LoginState.none;
      var day = 20000;
      for (var n = 1; n <= 7; n++) {
        final plan = planLogin(s, t, day);
        expect(plan.day, n);
        expect(plan.tile(n), LoginTile.today);
        if (n > 1) expect(plan.tile(n - 1), LoginTile.claimed);
        if (n < 7) expect(plan.tile(n + 1), LoginTile.locked);
        s = plan.next!;
        final again = planLogin(s, t, day);
        expect(again.canClaim, isFalse);
        expect(again.claimedToday, isTrue);
        // Skipping days is fine by default.
        day += n.isEven ? 3 : 1;
      }
      final done = planLogin(s, t, day);
      expect(done.finished, isTrue);
      expect(done.canClaim, isFalse);
      expect(done.tile(7), LoginTile.claimed);
    });

    test('repeat starts a new cycle; consecutive restarts after a gap', () {
      final full = const LoginState(
        claimedCount: 7,
        lastClaimDay: 100,
        cycle: 1,
      );
      final again = planLogin(
        full,
        defaultLoginRewards.copyWith(repeat: true),
        101,
      );
      expect(again.day, 1);
      expect(
        again.next,
        const LoginState(claimedCount: 1, lastClaimDay: 101, cycle: 2),
      );
      const mid = LoginState(claimedCount: 3, lastClaimDay: 100);
      expect(planLogin(mid, defaultLoginRewards, 105).day, 4);
      final strict = defaultLoginRewards.copyWith(consecutive: true);
      expect(planLogin(mid, strict, 101).day, 4);
      final reset = planLogin(mid, strict, 102);
      expect(reset.day, 1);
      expect(reset.next!.cycle, 2);
      // A clock behind the last claim never claims.
      expect(planLogin(mid, defaultLoginRewards, 99).canClaim, isFalse);
    });
  });

  group('Điểm danh claims', () {
    test('a guest cannot claim and sees no badge', () async {
      final server = _Server();
      final feed = _feed(server, _Clock());
      await feed.refresh();
      expect(feed.canClaimToday, isFalse);
      final r = await feed.claimLogin(allowed: true, grant: (b) => b);
      expect(r, LoginClaimResult.refused);
      expect(server.loginWrites, 0);
    });

    test('once per day across double taps, tabs and re-sign-in', () async {
      final server = _Server();
      final clock = _Clock();
      final feed = _feed(server, clock);
      await feed.bindUser('u1');
      expect(feed.canClaimToday, isTrue);
      final granted = <RewardBundle>[];
      RewardBundle grant(RewardBundle b) {
        granted.add(b);
        return b;
      }

      server.gate = Completer<void>();
      final first = feed.claimLogin(allowed: true, grant: grant);
      expect(
        await feed.claimLogin(allowed: true, grant: grant),
        LoginClaimResult.busy,
      );
      server.gate!.complete();
      server.gate = null;
      expect(await first, LoginClaimResult.claimed);
      expect(granted, [defaultLoginRewards.day(1)]);
      expect(feed.canClaimToday, isFalse);

      // A tab opened before the claim still thinks day 1 is waiting.
      final stale = _feed(server, clock);
      stale.uid = 'u1';
      expect(stale.plan.canClaim, isTrue);
      expect(
        await stale.claimLogin(allowed: true, grant: grant),
        LoginClaimResult.already,
      );
      expect(stale.loginState.claimedCount, 1);

      await feed.bindUser(null);
      await feed.bindUser('u1');
      expect(feed.plan.claimedToday, isTrue);
      expect(
        await feed.claimLogin(allowed: true, grant: grant),
        LoginClaimResult.already,
      );
      expect(granted, hasLength(1));
      expect(server.loginWrites, 1);

      // 23:59 in Việt Nam is still the same day; 00:00 is the next.
      clock.now = DateTime.utc(2026, 10, 3, 16, 59);
      expect(feed.canClaimToday, isFalse);
      clock.now = DateTime.utc(2026, 10, 3, 17);
      expect(feed.canClaimToday, isTrue);
      expect(
        await feed.claimLogin(allowed: true, grant: grant),
        LoginClaimResult.claimed,
      );
      expect(granted.last, defaultLoginRewards.day(2));
    });

    test('a tab that may not write the account claims nothing', () async {
      final server = _Server();
      final feed = _feed(server, _Clock());
      await feed.bindUser('u1');
      expect(
        await feed.claimLogin(allowed: false, grant: (b) => b),
        LoginClaimResult.refused,
      );
      expect(server.loginWrites, 0);
    });

    test('the admin table is what gets granted, into the save', () async {
      final server = _Server()
        ..config = defaultLoginRewards.withDay(
          1,
          RewardBundle(const [RewardItem.phaLe(123), RewardItem.pot('koi')]),
        );
      final backing = <String, String>{};
      final s = newSession(backing: backing);
      s.startNewGame();
      await s.pendingSaves;
      final feed = _feed(server, _Clock());
      await feed.bindUser('u1');
      expect(feed.config.day(1).amountOf(RewardKind.phaLe), 123);
      RewardBundle grant(RewardBundle b) =>
          s.grantRewards(b, source: RewardSource.loginReward);
      await feed.claimLogin(allowed: true, grant: grant);
      await feed.claimLogin(allowed: true, grant: grant);
      await s.pendingSaves;
      expect(s.state.phaLe, 123);
      expect(s.state.potCounts['koi'], 1);
      final stored = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(stored.phaLe, 123);
    });
  });

  group('giftcodes', () {
    test('the generator is unambiguous, prefixed and unique', () {
      final codes = generateGiftcodes(10000, prefix: 'TET');
      expect(codes.toSet(), hasLength(10000));
      final shape = RegExp(r'^TET[A-HJ-NP-Z2-9]{10}$');
      for (final c in codes) {
        expect(shape.hasMatch(c), isTrue, reason: c);
        expect(c.substring(3), isNot(matches(RegExp('[01OI]'))));
        expect(normalizeGiftcode(c), c);
      }
      expect(giftcodeAlphabet, isNot(matches(RegExp('[01OI]'))));
      expect(giftcodeAlphabet.length, 32);
      final a = generateGiftcodes(5, random: Random(1));
      expect(generateGiftcodes(5, random: Random(1)), a);
      expect(
        generateGiftcodes(3, random: Random(1), avoid: {a.first}),
        isNot(contains(a.first)),
      );
    });

    test('typing is normalized only on submit', () {
      expect(normalizeGiftcode('  tiem-hoa 2026 '), 'TIEMHOA2026');
      expect(normalizeGiftcode('mã quà'), isNull);
      expect(normalizeGiftcode('ab'), isNull);
      expect(normalizeGiftcodePrefix('tet'), 'TET');
      expect(normalizeGiftcodePrefix(''), '');
      expect(normalizeGiftcodePrefix('tết'), isNull);
      expect(normalizeGiftcodePrefix('ABCDEFGHI'), isNull);
    });

    test('a shared code: each player once, up to its limit', () async {
      final server = _Server()..addShared('TIEMHOA', maxUses: 2);
      final clock = _Clock();
      final granted = <RewardBundle>[];
      RewardBundle grant(RewardBundle b) {
        granted.add(b);
        return b;
      }

      final an = _feed(server, clock);
      await an.bindUser('an');
      final ok = await an.redeem(' tiemhoa ', allowed: true, grant: grant);
      expect(ok.result, RedeemResult.success);
      expect(ok.rewards.amountOf(RewardKind.phaLe), 50);
      expect(an.lastRedeem!.message, 'Đổi mã thành công! Quà đã vào tiệm.');
      expect(
        (await an.redeem('TIEMHOA', allowed: true, grant: grant)).result,
        RedeemResult.already,
      );
      final lan = _feed(server, clock);
      await lan.bindUser('lan');
      expect(
        (await lan.redeem('TIEMHOA', allowed: true, grant: grant)).result,
        RedeemResult.success,
      );
      final binh = _feed(server, clock);
      await binh.bindUser('binh');
      final full = await binh.redeem('TIEMHOA', allowed: true, grant: grant);
      expect(full.result, RedeemResult.used);
      expect(full.message, 'Mã này đã có người dùng rồi.');
      expect(granted, hasLength(2));
    });

    test('a bulk batch: one code per player, one player per code', () async {
      final server = _Server()..addBulk('b1', ['AAAA2222', 'BBBB3333']);
      final clock = _Clock();
      var granted = 0;
      RewardBundle grant(RewardBundle b) {
        granted++;
        return b;
      }

      final an = _feed(server, clock);
      await an.bindUser('an');
      expect(
        (await an.redeem('aaaa2222', allowed: true, grant: grant)).result,
        RedeemResult.success,
      );
      expect(
        (await an.redeem('BBBB3333', allowed: true, grant: grant)).result,
        RedeemResult.already,
      );
      final lan = _feed(server, clock);
      await lan.bindUser('lan');
      expect(
        (await lan.redeem('AAAA2222', allowed: true, grant: grant)).result,
        RedeemResult.used,
      );
      expect(
        (await lan.redeem('BBBB3333', allowed: true, grant: grant)).result,
        RedeemResult.success,
      );
      expect(granted, 2);
    });

    test('expired, not started, disabled, unknown and empty', () async {
      final now = _start;
      final server = _Server()
        ..addShared(
          'OLDCODE',
          batch: 'old',
          expiresAt: now.subtract(const Duration(minutes: 1)),
        )
        ..addShared(
          'SOONCODE',
          batch: 'soon',
          startsAt: now.add(const Duration(days: 1)),
        )
        ..addShared('OFFCODE', batch: 'off', enabled: false);
      final feed = _feed(server, _Clock());
      await feed.bindUser('an');
      Future<RedeemResult> r(String raw) async =>
          (await feed.redeem(raw, allowed: true, grant: (b) => b)).result;
      expect(await r('OLDCODE'), RedeemResult.expired);
      expect(await r('SOONCODE'), RedeemResult.notStarted);
      expect(await r('OFFCODE'), RedeemResult.disabled);
      expect(await r('NOPE1234'), RedeemResult.invalid);
      expect(await r('   '), RedeemResult.empty);
      expect(await r('mã'), RedeemResult.invalid);
      expect(redeemMessage(RedeemResult.expired), 'Mã này đã hết hạn mất rồi.');
      expect(
        redeemMessage(RedeemResult.disabled),
        'Mã này không đúng, bạn kiểm tra lại nhé.',
      );
      expect(
        redeemMessage(RedeemResult.notStarted),
        redeemMessage(RedeemResult.invalid),
      );
      expect(redeemMessage(RedeemResult.already), 'Bạn đã đổi mã này rồi nha.');
      expect(
        redeemMessage(RedeemResult.signedOut),
        'Đăng nhập để đổi mã quà tặng nhé.',
      );
    });

    test(
      'a guest or a blocked tab redeems nothing; double tap is busy',
      () async {
        final server = _Server()..addShared('TIEMHOA');
        final guest = _feed(server, _Clock());
        expect(
          (await guest.redeem(
            'TIEMHOA',
            allowed: true,
            grant: (b) => b,
          )).result,
          RedeemResult.signedOut,
        );
        final feed = _feed(server, _Clock());
        await feed.bindUser('an');
        expect(
          (await feed.redeem(
            'TIEMHOA',
            allowed: false,
            grant: (b) => b,
          )).result,
          RedeemResult.refused,
        );
        var granted = 0;
        server.gate = Completer<void>();
        final first = feed.redeem(
          'TIEMHOA',
          allowed: true,
          grant: (b) {
            granted++;
            return b;
          },
        );
        expect(
          (await feed.redeem('TIEMHOA', allowed: true, grant: (b) => b)).result,
          RedeemResult.busy,
        );
        server.gate!.complete();
        expect((await first).result, RedeemResult.success);
        expect(granted, 1);
      },
    );

    test('the CSV lists every code', () {
      expect(
        giftcodeCsv(const [
          GiftcodeRow('AAAA'),
          GiftcodeRow('BBBB', usedBy: 'u'),
        ]),
        'code,used_by\nAAAA,\nBBBB,u\n',
      );
    });

    test('the rules guard codes, claims and slides', () {
      final rules = File('firestore.rules').readAsStringSync();
      expect(rules, contains('match /welfare/{docId}'));
      expect(rules, contains('resource.data.lastClaimDay < vnDay()'));
      expect(rules, contains('d.lastClaimAt == request.time'));
      expect(rules, contains('match /redeemed/{batchId}'));
      expect(rules, contains('match /giftcodes/{code}'));
      expect(
        rules,
        contains('allow update: if isAdmin() || giftcodeRedeem();'),
      );
      expect(rules, contains('!exists(mine)'));
      expect(rules, contains('match /giftcodeBatches/{batchId}'));
      expect(rules, contains('match /config/{docId}'));
      expect(rules, contains('match /slides/{id}'));
      final codes = rules.substring(rules.indexOf('match /giftcodes/{code}'));
      expect(
        codes.substring(0, codes.indexOf('allow update')),
        allOf(
          contains('allow get: if request.auth != null;'),
          contains('allow list: if isAdmin();'),
        ),
      );
      final storage = File('storage.rules').readAsStringSync();
      expect(storage, contains('match /welfare_slides/{file}'));
      expect(File('assets/audio/sfx/diem_danh.mp3').existsSync(), isTrue);
      expect(File('assets/audio/sfx/mo_thu.mp3').existsSync(), isTrue);
    });
  });

  group('slides', () {
    test('only enabled slides, by order; bad links open nothing', () {
      final list = visibleSlides(const [
        WelfareSlide(id: 'b', imageUrl: 'https://x/b.jpg', order: 2),
        WelfareSlide(id: 'a', imageUrl: 'https://x/a.jpg', order: 1),
        WelfareSlide(id: 'off', imageUrl: 'https://x/c.jpg', enabled: false),
      ]);
      expect([for (final s in list) s.id], ['a', 'b']);
      final bad = WelfareSlide.fromMap('x', {
        'imageUrl': 'https://x/a.jpg',
        'linkType': 'url',
        'link': 'javascript:alert(1)',
      })!;
      expect(bad.linkType, SlideLinkType.none);
      final route = WelfareSlide.fromMap('y', {
        'imageUrl': 'https://x/a.jpg',
        'linkType': 'route',
        'link': 'garden',
        'order': 3,
      })!;
      expect(route.linkType, SlideLinkType.route);
      expect(route.order, 3);
      expect(WelfareSlide.fromMap('z', {'imageUrl': 'http://x'}), isNull);
      expect(
        slideFormError(
          const WelfareSlide(
            id: 'q',
            imageUrl: 'https://x/a.jpg',
            linkType: SlideLinkType.route,
            link: 'nowhere',
          ),
        ),
        'Chọn màn hình.',
      );
    });

    test('the 3 built-in text cards show while slides/ is empty', () async {
      final server = _Server();
      final feed = _feed(server, _Clock());
      await feed.refresh();
      expect([for (final s in feed.slides) s.body], WelfareText.defaultSlides);
      expect(feed.slides.every((s) => !s.hasImage), isTrue);
      expect(
        feed.slides.every((s) => s.linkType == SlideLinkType.none),
        isTrue,
      );
      expect(
        WelfareText.defaultSlides.first,
        'Hoa để lâu sẽ héo và mất luôn. Mua vừa đủ bán trong ngày là bí quyết của chủ tiệm giỏi.',
      );
      server.slideList = const [
        WelfareSlide(id: 'mine', title: 'Mẹo', body: 'Tưới vườn mỗi sáng.'),
      ];
      await feed.refresh();
      expect([for (final s in feed.slides) s.id], ['mine']);
      final text = WelfareSlide.fromMap('t', {'body': 'Chỉ chữ'})!;
      expect(text.hasImage, isFalse);
      expect(WelfareSlide.fromMap('e', {}), isNull);
    });

    testWidgets('a slide without a picture is a text card at 2.25:1', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 292,
              child: WelfareSlidesView(
                slides: defaultWelfareSlides,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SlideTextCard), findsOneWidget);
      expect(find.text(WelfareText.defaultSlides.first), findsOneWidget);
      expect(find.byKey(const Key('slide-dot-2')), findsOneWidget);
      final card = tester.getSize(find.byType(SlideTextCard));
      expect(card.width / card.height, closeTo(slideAspect, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the carousel turns by itself and opens the tapped slide', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 292,
              child: WelfareSlidesView(
                slides: const [
                  WelfareSlide(
                    id: 'a',
                    imageUrl: 'https://example.invalid/a.jpg',
                    title: 'Vườn mới',
                    linkType: SlideLinkType.route,
                    link: 'garden',
                  ),
                  WelfareSlide(
                    id: 'b',
                    imageUrl: 'https://example.invalid/b.jpg',
                    linkType: SlideLinkType.url,
                    link: 'https://tiemhoasommai.com',
                  ),
                ],
                onTap: (s) => tapped.add(s.id),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Vườn mới'), findsOneWidget);
      expect(find.byKey(const Key('slide-dot-1')), findsOneWidget);
      final box = tester.getSize(find.byKey(const Key('slides-pages')));
      expect(box.width / box.height, closeTo(slideAspect, 0.01));
      await tester.tap(find.byKey(const Key('slides-pages')));
      expect(tapped, ['a']);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('slides-pages')));
      expect(tapped, ['a', 'b']);
    });
  });

  group('Phúc lợi sheet', () {
    Future<List<String>> pumpSheet(
      WidgetTester tester,
      WelfareFeed feed, {
      bool signedIn = true,
      RewardBundle Function(RewardBundle)? grant,
      String? Function(WelfareSlide)? onSlide,
    }) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final heard = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SoundScope(
            sounds: Sounds(heard: heard),
            child: Material(
              child: Stack(
                children: [
                  Positioned(
                    left: 92,
                    top: 8,
                    child: WelfareButton(feed: feed),
                  ),
                  Positioned.fill(
                    child: WelfareSheet(
                      feed: feed,
                      signedIn: signedIn,
                      canClaim: () => true,
                      grantLogin: grant ?? (b) => b,
                      grantCode: grant ?? (b) => b,
                      onSlide: onSlide ?? (_) => null,
                      onSignIn: () async {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return heard;
    }

    testWidgets('a guest is asked to sign in but can read slides', (
      tester,
    ) async {
      final server = _Server()
        ..slideList = const [
          WelfareSlide(id: 's1', imageUrl: 'https://example.invalid/1.jpg'),
        ];
      final feed = _feed(server, _Clock());
      await pumpSheet(tester, feed, signedIn: false);
      expect(find.byKey(const Key('welfare-badge')), findsNothing);
      await tester.tap(find.byKey(const Key('welfare-button')));
      await tester.pump();
      expect(find.byKey(const Key('welfare-guest')), findsOneWidget);
      expect(
        find.text('Đăng nhập để điểm danh và giữ quà trên tài khoản nhé.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('welfare-sign-in')), findsOneWidget);
      expect(find.byKey(const Key('login-claim')), findsNothing);
      await tester.tap(find.byKey(const Key('welfare-tab-giftcode')));
      await tester.pump();
      expect(find.text('Đăng nhập để đổi mã quà tặng nhé.'), findsOneWidget);
      expect(find.byKey(const Key('giftcode-input')), findsNothing);
      await tester.tap(find.byKey(const Key('welfare-tab-slides')));
      await tester.pump();
      expect(find.byKey(const Key('welfare-guest')), findsNothing);
      expect(find.byKey(const Key('slide-s1')), findsOneWidget);
    });

    testWidgets('tiles show claimed, today and locked; claim plays the sound', (
      tester,
    ) async {
      final server = _Server()
        ..login['u1'] = LoginState(
          claimedCount: 2,
          lastClaimDay: vnDayNumber(_start) - 1,
        );
      final feed = _feed(server, _Clock());
      await feed.bindUser('u1');
      var granted = 0;
      final heard = await pumpSheet(
        tester,
        feed,
        grant: (b) {
          granted++;
          return b;
        },
      );
      expect(find.byKey(const Key('welfare-badge')), findsOneWidget);
      feed.show(WelfareTab.login);
      await tester.pump();
      expect(find.byKey(const Key('login-day-1-claimed')), findsOneWidget);
      expect(find.byKey(const Key('login-day-2-claimed')), findsOneWidget);
      expect(find.byKey(const Key('login-day-3-today')), findsOneWidget);
      expect(find.byKey(const Key('login-day-7-locked')), findsOneWidget);
      final day7 = tester.getSize(find.byKey(const Key('login-day-7')));
      final day6 = tester.getSize(find.byKey(const Key('login-day-6')));
      // Day 7 stands across both rows of small tiles.
      expect(day7.height, greaterThan(day6.height * 1.4));
      expect(day7.width, greaterThan(day6.width));
      expect(find.text('Điểm danh mỗi ngày'), findsOneWidget);
      expect(find.text('Ngày 7'), findsOneWidget);
      expect(find.text('Nhận quà'), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-claim')));
      await tester.pump();
      await tester.pump();
      expect(granted, 1);
      expect(heard.where((s) => s == 'diem_danh.mp3'), hasLength(1));
      expect(find.byKey(const Key('login-day-3-claimed')), findsOneWidget);
      expect(
        find.text('Đã nhận quà ngày 3! Mai ghé tiệm nhận tiếp nhé.'),
        findsOneWidget,
      );
      expect(
        tester.widget<ChunkyButton>(find.byKey(const Key('login-claim'))).label,
        'Đã nhận',
      );
      expect(find.byType(ClaimedBadge), findsNWidgets(3));
      expect(find.text('Đã nhận 3/7 ngày'), findsOneWidget);
      expect(find.byKey(const Key('welfare-badge')), findsNothing);
    });

    testWidgets('the code field has no formatter; results speak Vietnamese', (
      tester,
    ) async {
      final server = _Server()..addShared('TIEMHOA');
      final feed = _feed(server, _Clock());
      await feed.bindUser('u1');
      final heard = await pumpSheet(tester, feed);
      feed.show(WelfareTab.giftcode);
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('giftcode-input')),
      );
      expect(field.inputFormatters, anyOf(isNull, isEmpty));
      expect(field.maxLength, isNull);
      // UniKey-style text stays exactly as typed until "Nhập".
      await tester.enterText(find.byKey(const Key('giftcode-input')), 'mã ');
      await tester.pump();
      expect(find.text('mã '), findsOneWidget);
      await tester.tap(find.byKey(const Key('giftcode-submit')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Mã này không đúng, bạn kiểm tra lại nhé.'),
        findsOneWidget,
      );
      expect(find.text('Nhập mã quà tặng'), findsOneWidget);
      expect(find.text('Đổi quà'), findsOneWidget);
      expect(heard.last, 'error.mp3');
      await tester.enterText(
        find.byKey(const Key('giftcode-input')),
        ' tiemhoa ',
      );
      await tester.tap(find.byKey(const Key('giftcode-submit')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Đổi mã thành công! Quà đã vào tiệm.'), findsOneWidget);
      expect(find.byKey(const Key('giftcode-reward')), findsOneWidget);
      expect(heard.last, 'login_ok.mp3');
      await tester.enterText(
        find.byKey(const Key('giftcode-input')),
        'TIEMHOA',
      );
      await tester.tap(find.byKey(const Key('giftcode-submit')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Bạn đã đổi mã này rồi nha.'), findsOneWidget);
    });

    testWidgets('a slide link goes through the game handler', (tester) async {
      final server = _Server()
        ..slideList = const [
          WelfareSlide(
            id: 's1',
            imageUrl: 'https://example.invalid/1.jpg',
            linkType: SlideLinkType.route,
            link: 'garden',
          ),
        ];
      final feed = _feed(server, _Clock());
      final opened = <String>[];
      await pumpSheet(
        tester,
        feed,
        onSlide: (s) {
          opened.add('${s.linkType.name}:${s.link}');
          return 'Vào tiệm rồi mở mục này nhé.';
        },
      );
      feed.show(WelfareTab.slides);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('slide-s1')));
      await tester.pump();
      expect(opened, ['route:garden']);
      expect(find.text('Vào tiệm rồi mở mục này nhé.'), findsOneWidget);
    });
  });

  group('/quan-tri Phúc lợi', () {
    Future<_Admin> pumpAdmin(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final admin = _Admin();
      await tester.pumpWidget(
        MaterialApp(
          home: WelfareAdminPanel(
            admin: admin,
            onClose: () {},
            now: () => _start,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return admin;
    }

    testWidgets('the admin edits one day and saves the table', (tester) async {
      final admin = await pumpAdmin(tester);
      expect(find.byKey(const Key('login-admin-default')), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-admin-day-3')));
      await tester.pump();
      // Day 3 is 100 Pha lê: turn it off, then saving complains.
      await tester.tap(find.byKey(const Key('gift-card-pha_le')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login-admin-save')));
      await tester.pump();
      expect(find.text('Ngày 3 chưa có quà.'), findsOneWidget);
      expect(admin.config, isNull);
      await tester.tap(find.byKey(const Key('gift-card-pha_le')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('gift-qty-pha_le')), '250');
      await tester.pump();
      await tester.tap(find.byKey(const Key('login-admin-repeat')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login-admin-save')));
      await tester.pumpAndSettle();
      final saved = admin.config!;
      expect(saved.day(3), RewardBundle(const [RewardItem.phaLe(250)]));
      expect(saved.day(7), defaultLoginRewards.day(7));
      expect(saved.repeat, isTrue);
      expect(find.byKey(const Key('login-admin-saved')), findsOneWidget);
    });

    testWidgets('a bulk batch writes in chunks of 500 with progress', (
      tester,
    ) async {
      final admin = await pumpAdmin(tester);
      await tester.tap(find.byKey(const Key('welfare-admin-codes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gc-create')));
      await tester.pump();
      expect(find.text('Chọn quà cho mã.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gift-card-koi')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('gc-type-single')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('gc-prefix')), 'tet');
      await tester.enterText(find.byKey(const Key('gc-count')), '1200');
      await tester.tap(find.byKey(const Key('gc-create')));
      await tester.pumpAndSettle();
      expect(admin.progress, [500, 1000, 1200]);
      final codes = admin.bulk!;
      expect(codes.toSet(), hasLength(1200));
      expect(codes.every((c) => c.startsWith('TET')), isTrue);
      expect(admin.batches.single.type, GiftcodeType.single);
      expect(admin.batches.single.prefix, 'TET');
      expect(
        admin.batches.single.rewards,
        RewardBundle(const [RewardItem.pot('koi')]),
      );
      expect(find.text('Đã tạo 1200 mã.'), findsOneWidget);
      expect(find.byKey(const Key('gc-output')), findsOneWidget);
      expect(find.byKey(const Key('gc-download')), findsOneWidget);
    });

    testWidgets('a shared code must be new', (tester) async {
      final admin = await pumpAdmin(tester);
      admin.existing.add('TIEMHOA');
      await tester.tap(find.byKey(const Key('welfare-admin-codes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gift-card-pha_le')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('gc-code')), ' tiemhoa ');
      await tester.tap(find.byKey(const Key('gc-create')));
      await tester.pumpAndSettle();
      expect(find.text('Mã TIEMHOA đã có rồi.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('gc-code')), 'mung tet');
      await tester.enterText(find.byKey(const Key('gc-max-uses')), '100');
      await tester.tap(find.byKey(const Key('gc-create')));
      await tester.pumpAndSettle();
      final b = admin.batches.single;
      expect(b.code, 'MUNGTET');
      expect(b.maxUses, 100);
      expect(b.type, GiftcodeType.shared);
    });

    testWidgets('a slide saves with an in-game link', (tester) async {
      final admin = await pumpAdmin(tester);
      await tester.tap(find.byKey(const Key('welfare-admin-slides')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('slide-save')));
      await tester.pump();
      expect(find.text('Cần ảnh hoặc chữ cho slide.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('slide-image')),
        'https://example.invalid/s.jpg',
      );
      await tester.tap(find.byKey(const Key('slide-link-route')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('slide-save')));
      await tester.pumpAndSettle();
      final s = admin.slides.single;
      expect(s.linkType, SlideLinkType.route);
      expect(s.link, welfareRoutes.keys.first);
      expect(s.imageUrl, 'https://example.invalid/s.jpg');

      // Text only, while the pictures are not ready.
      await tester.enterText(find.byKey(const Key('slide-body')), 'Mẹo nhỏ');
      await tester.pump();
      expect(find.byType(SlideTextCard), findsOneWidget);
      await tester.tap(find.byKey(const Key('slide-save')));
      await tester.pumpAndSettle();
      final t = admin.slides.last;
      expect(t.hasImage, isFalse);
      expect(t.body, 'Mẹo nhỏ');
    });
  });
}

class _Admin implements WelfareAdmin {
  LoginRewardConfig? config;
  final batches = <GiftcodeBatch>[];
  final existing = <String>{};
  List<String>? bulk;
  final progress = <int>[];
  final slides = <WelfareSlide>[];
  var _n = 0;

  @override
  Future<LoginRewardConfig?> loadLoginConfig() async => config;

  @override
  Future<void> saveLoginConfig(LoginRewardConfig c) async => config = c;

  @override
  String newBatchId() => 'batch${_n++}';

  @override
  Future<List<GiftcodeBatch>> loadBatches() async => batches;

  @override
  Future<bool> codeExists(String code) async => existing.contains(code);

  @override
  Future<void> createShared(GiftcodeBatch batch) async {
    batches.add(batch);
    existing.add(batch.code!);
  }

  @override
  Future<void> createBulk(
    GiftcodeBatch batch,
    List<String> codes, {
    void Function(int written)? onProgress,
  }) async {
    batches.add(batch);
    bulk = codes;
    for (var i = 0; i < codes.length; i += giftcodeWriteChunk) {
      final end = min(i + giftcodeWriteChunk, codes.length);
      progress.add(end);
      onProgress?.call(end);
    }
  }

  @override
  Future<void> setBatchEnabled(String batchId, bool enabled) async {}

  @override
  Future<List<GiftcodeRow>> exportBatch(String batchId) async => [
    for (final c in bulk ?? const <String>[]) GiftcodeRow(c),
  ];

  @override
  String newSlideId() => 'slide${_n++}';

  @override
  Future<List<WelfareSlide>> loadSlides() async => slides;

  @override
  Future<void> saveSlide(WelfareSlide slide) async => slides.add(slide);

  @override
  Future<void> deleteSlide(String id) async =>
      slides.removeWhere((s) => s.id == id);
}
