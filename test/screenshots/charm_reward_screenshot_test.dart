// Renders the season reward flow to PNGs: the admin review in /quan-tri and
// the three states of the player's reward button.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/charm_reward_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/charm_payout.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/charm_reward_admin_panel.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../ui/charm_board_screen_test.dart' show loadFonts, rig;
import '../ui/charm_reward_admin_test.dart' show board, ran;

final _dir = Platform.environment['SHOT_DIR'];

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
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

Widget _frame(Key key, Widget child, {bool game = true}) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        type: MaterialType.transparency,
        child: game ? GameFrame(child: child) : child,
      ),
    ),
  ),
);

class _Server implements MailService {
  final mails = <GameMail>[];
  final marks = <String, Map<String, MailState>>{};

  @override
  Future<List<GameMail>> inbox(String uid) async => [
    for (final m in mails)
      if (m.target == mailToAll || m.target == uid) m,
  ];

  @override
  Future<Map<String, MailState>> states(String uid) async => {...?marks[uid]};

  @override
  Future<void> markRead(String uid, String mailId) async {}

  @override
  Future<MailClaimResult> claim(String uid, String mailId) async {
    final mine = marks.putIfAbsent(uid, () => {});
    if (mine[mailId]?.claimed == true) return MailClaimResult.already;
    mine[mailId] = const MailState(read: true, claimed: true);
    return MailClaimResult.claimed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin review shots', skip: _dir == null, (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (b, store) = await board(tester, n: 16);
    final economy = loadTestData().economy;
    final end = economy.charmBoard.seasonEnd!;
    Future<void> shoot(
      String name,
      MemoryCharmPayoutStore payout, {
      DateTime? now,
    }) async {
      await tester.pumpWidget(
        _frame(
          ValueKey('shot-$name'),
          CharmRewardAdminPanel(
            board: b,
            store: store,
            payout: payout,
            economy: economy,
            onClose: () {},
            now: () => now ?? end.add(const Duration(hours: 1)),
          ),
          game: false,
        ),
      );
      await _settle(tester);
      await _save(tester, ValueKey('shot-$name'), name);
    }

    // Before the payout: the live board as a preview.
    await shoot(
      'bxh_admin_1_xem_truoc_480x1000',
      MemoryCharmPayoutStore(),
      now: end.subtract(const Duration(days: 2)),
    );
    // After: sent / held (with flags) / skipped, switch on.
    final payout = ran();
    await shoot('bxh_admin_2_da_chot_480x1000', payout);
    // Release one held row: the confirm, then the result.
    await tester.tap(find.byKey(const Key('cra-release-p1')));
    await tester.pump();
    await _settle(tester);
    await _save(
      tester,
      const ValueKey('shot-bxh_admin_2_da_chot_480x1000'),
      'bxh_admin_3_xac_nhan_480x1000',
    );
    await tester.tap(find.byKey(const Key('cra-confirm-yes')));
    await _settle(tester);
    await _save(
      tester,
      const ValueKey('shot-bxh_admin_2_da_chot_480x1000'),
      'bxh_admin_4_da_duyet_480x1000',
    );
    // The switch off.
    await shoot('bxh_admin_5_cong_tac_tat_480x1000', ran(auto: false));
  });

  testWidgets('player reward button shots', skip: _dir == null, (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final r = await rig(
      tester,
      n: 12,
      pet: 'kim_long',
      stage: 2,
      at: DateTime.utc(2026, 11, 10, 8),
    );
    final server = _Server();
    final feed = MailboxFeed(service: server, now: r.now);
    r.s.board.attachMailbox(feed);
    await tester.runAsync(() async {
      await feed.bindUser('me');
      // The player is on the board, rank 13 of 13.
      await r.board.publish(
        period: r.s.e.charmBoard.periodKey,
        entry: r.s.board.mine!,
      );
      await r.s.board.refresh(force: true);
    });
    r.s.charmBoardOpen = true;
    r.s.board.rewardsOpen = true;

    Future<void> shoot(String name) async {
      await tester.pumpWidget(
        _frame(
          ValueKey('shot-$name'),
          ListenableBuilder(
            listenable: r.s,
            builder: (_, _) => CharmBoardScreen(session: r.s),
          ),
        ),
      );
      await _settle(tester);
      await _save(tester, ValueKey('shot-$name'), name);
    }

    await shoot('bxh_claim_1_dang_chot_bang_360x640');

    server.mails.add(
      charmRewardMail(
        period: r.s.e.charmBoard.periodKey,
        rank: 13,
        uid: 'me',
        rewards: RewardBundle([
          const RewardItem.phaLe(10),
          const RewardItem.petItem('mu_rom'),
        ]),
      ),
    );
    await tester.runAsync(feed.refresh);
    await shoot('bxh_claim_2_nhan_thuong_360x640');

    await tester.runAsync(r.s.board.claimReward);
    await shoot('bxh_claim_3_da_nhan_360x640');
  });
}
