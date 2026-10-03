import 'package:ai_game/logic/login_rewards.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/logic/welfare_slides.dart';
import 'package:ai_game/logic/welfare_text.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/welfare_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nhất wording for weeks and milestones', () {
    expect(WelfareText.loginWeekNewbie, 'Quà tân thủ');
    expect(WelfareText.loginWeekly, 'Quà hằng tuần');
    expect(WelfareText.loginTotal(5), 'Đã điểm danh 5 ngày');
    expect(WelfareText.loginMilestone(14), 'Quà mốc 14 ngày');
    expect(WelfareText.loginMilestoneDone(14), 'Đã nhận quà mốc 14 ngày');
  });

  test('slide 1 uses ban_biet_1', () {
    expect(defaultWelfareSlides.first.art, 'ban_biet_1');
  });

  testWidgets('milestone chips: progress, then the claimed line', (
    tester,
  ) async {
    final ms = [
      LoginMilestone(14, RewardBundle(const [RewardItem.pot('koi')])),
      LoginMilestone(30, RewardBundle(const [RewardItem.pot('crane')])),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoginMilestones(milestones: ms, total: 14)),
      ),
    );
    expect(find.text('Đã nhận quà mốc 14 ngày'), findsOneWidget);
    expect(find.text('Quà mốc 30 ngày (14/30)'), findsOneWidget);
    expect(find.text('Đã điểm danh 14 ngày'), findsOneWidget);
  });

  testWidgets('corner buttons hide while a sheet is open', (tester) async {
    final welfare = WelfareFeed();
    final other = WelfareFeed();
    await tester.pumpWidget(
      MaterialApp(
        home: CornerButtonGate(
          sheets: [welfare, other],
          child: const Text('nut'),
        ),
      ),
    );
    expect(find.text('nut'), findsOneWidget);
    other.toggle();
    await tester.pump();
    expect(find.text('nut'), findsNothing);
    other.close();
    await tester.pump();
    expect(find.text('nut'), findsOneWidget);
  });
}
