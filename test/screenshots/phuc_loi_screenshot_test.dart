// Renders the Điểm danh board and the Hộp thư to PNGs. Skipped unless
// SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/giftcodes.dart';
import 'package:ai_game/logic/login_rewards.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/logic/welfare_slides.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/mailbox_sheet.dart';
import 'package:ai_game/ui/welfare_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _dir = Platform.environment['SHOT_DIR'];
final _now = DateTime(2026, 10, 3, 9);

Future<void> _loadFonts() async {
  const fonts = {
    AppFonts.body: 'assets/fonts/nunito/Nunito-VariableFont_wght.ttf',
    AppFonts.display: 'assets/fonts/baloo2/Baloo2-VariableFont_wght.ttf',
  };
  for (final e in fonts.entries) {
    final bytes = File(e.value).readAsBytesSync();
    await (FontLoader(
      e.key,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  // Material icons (the day-7 lock) come with the Flutter SDK; tests do not
  // load them by default and would draw empty squares.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      [
        root,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'materialicons-regular.otf',
      ].join(Platform.pathSeparator),
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
  }
}

class _Welfare implements WelfareService {
  @override
  Future<LoginRewardConfig?> loginConfig() async => null;

  @override
  Future<LoginState> loginState(String uid) async =>
      LoginState(claimedCount: 2, lastClaimDay: vnDayNumber(_now) - 1);

  @override
  Future<LoginClaimOutcome> claimLogin(
    String uid,
    LoginRewardConfig config,
    DateTime now,
  ) => throw UnimplementedError();

  @override
  Future<RedeemOutcome> redeem(String uid, String code, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<List<WelfareSlide>> slides() async => const [];
}

class _Mail implements MailService {
  @override
  Future<List<GameMail>> inbox(String uid) async => [
    GameMail(
      id: 'm1',
      title: 'Quà khai trương',
      body: 'Cảm ơn bạn đã ghé tiệm. Tiệm gửi bạn chút quà nhỏ nhé!',
      target: mailToAll,
      rewards: RewardBundle(const [
        RewardItem.coins(20000),
        RewardItem.phaLe(100),
        RewardItem.pot('crane'),
        RewardItem.cat(),
      ]),
      createdAt: DateTime(2026, 10, 3),
    ),
    GameMail(
      id: 'm2',
      title: 'Lịch bảo trì tối nay',
      body: 'Tiệm nghỉ 15 phút lúc 23:00.',
      target: mailToAll,
      rewards: RewardBundle(const []),
      createdAt: DateTime(2026, 10, 2),
    ),
    GameMail(
      id: 'm3',
      title: 'Quà Trung thu',
      body: 'Bánh mật cho mèo.',
      target: mailToAll,
      rewards: RewardBundle(const [RewardItem.treat(3)]),
      createdAt: DateTime(2026, 9, 28),
    ),
  ];

  @override
  Future<Map<String, MailState>> states(String uid) async => const {
    'm2': MailState(read: true),
    'm3': MailState(read: true, claimed: true),
  };

  @override
  Future<void> markRead(String uid, String mailId) async {}

  @override
  Future<MailClaimResult> claim(String uid, String mailId) =>
      throw UnimplementedError();
}

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

Widget _frame(Key key, List<Widget> children) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        type: MaterialType.transparency,
        child: GameFrame(
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.bgShop)),
              ...children,
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('Phúc lợi shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    const shot = Key('shot');

    final welfare = WelfareFeed(service: _Welfare(), now: () => _now);
    await tester.runAsync(() => welfare.bindUser('u1'));
    welfare.show(WelfareTab.login);
    await tester.pumpWidget(
      _frame(shot, [
        Positioned.fill(
          child: WelfareSheet(
            feed: welfare,
            signedIn: true,
            canClaim: () => true,
            grantLogin: (b) => b,
            grantCode: (b) => b,
            onSlide: (_) => null,
            onSignIn: () async {},
          ),
        ),
      ]),
    );
    await _settle(tester);
    await _save(tester, shot, 'phuc_loi_diem_danh_390x844');

    final mail = MailboxFeed(service: _Mail(), now: () => _now);
    await tester.runAsync(() => mail.bindUser('u1'));
    mail.toggle();
    Widget mailbox() => _frame(shot, [
      Positioned(left: 276, top: 62, child: MailboxButton(feed: mail)),
      Positioned.fill(
        child: MailboxSheet(
          feed: mail,
          signedIn: true,
          canClaim: () => true,
          grant: (m) => m.rewards,
          onSignIn: () async {},
        ),
      ),
    ]);
    await tester.pumpWidget(mailbox());
    await _settle(tester);
    await _save(tester, shot, 'phuc_loi_hop_thu_390x844');

    await tester.runAsync(() => mail.openMail('m1'));
    await tester.pump();
    await _settle(tester);
    await _save(tester, shot, 'phuc_loi_thu_qua_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
