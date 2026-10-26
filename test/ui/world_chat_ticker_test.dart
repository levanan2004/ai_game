import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/ui/delivery_widgets.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/world_chat_ticker.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

ChatMessage msg(int seq, String uid, {DateTime? at, String? text}) =>
    ChatMessage(
      id: 'm${seq.toString().padLeft(10, '0')}',
      uid: uid,
      name: 'Tiệm $uid',
      text: text ?? 'tin $seq',
      seq: seq,
      createdAt: at ?? DateTime.now(),
    );

void main() {
  Future<(ShopSession, MemoryWorldChat)> rig(
    WidgetTester tester, {
    bool on = true,
    List<ChatMessage> seed = const [],
    bool popupOpen = false,
  }) async {
    final chat = MemoryWorldChat(on: on);
    for (final m in seed) {
      chat.add(m);
    }
    final s = newSession(worldChat: chat);
    s.accountUid = 'me';
    s.state.day = 7;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: 60,
                height: WorldChatTicker.height,
                child: WorldChatTicker(session: s, popupOpen: popupOpen),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (s, chat);
  }

  Finder text(String id) => find.byKey(Key('world-chat-ticker-text-$id'));
  double opacity(WidgetTester t) => t
      .widget<AnimatedOpacity>(find.byKey(const Key('world-chat-ticker-fade')))
      .opacity;

  testWidgets('strip: 24 dp, radius 12, cream-white 85%, 16 dp speaker, '
      '12 sp text', (tester) async {
    await rig(tester, seed: [msg(1, 'p1')]);
    final strip = find.byKey(const Key('world-chat-ticker'));
    expect(strip, findsOneWidget);
    expect(tester.getSize(strip), const Size(336, 24));
    final box = tester.widget<Container>(
      find.descendant(of: strip, matching: find.byType(Container)).first,
    );
    final deco = box.decoration! as BoxDecoration;
    expect(deco.color, const Color(0xD9FFF8E7));
    expect(deco.borderRadius, BorderRadius.circular(12));
    final icon = tester.widget<Icon>(
      find.byKey(const Key('world-chat-ticker-icon')),
    );
    expect(icon.size, 16);
    final rich = tester.widget<RichText>(
      find.descendant(of: text('m0000000001'), matching: find.byType(RichText)),
    );
    final spans = (rich.text as TextSpan).children!.first as TextSpan;
    final name = spans.children![0] as TextSpan;
    final body = spans.children![1] as TextSpan;
    expect(name.text, 'Tiệm p1');
    expect(name.style!.color, const Color(0xFF3F7F52));
    expect(name.style!.fontWeight, FontWeight.w800);
    expect(name.style!.fontSize, 12);
    expect(body.text, ': tin 1');
    expect(body.style!.color, AppColors.textPrimary);
    expect(body.style!.fontSize, 12);
  });

  testWidgets('scrolls right to left; the next message after a 1 s pause', (
    tester,
  ) async {
    final (_, chat) = await rig(tester, seed: [msg(1, 'p1')]);
    final x0 = tester.getTopLeft(text('m0000000001')).dx;
    await tester.pump(const Duration(milliseconds: 500));
    final x1 = tester.getTopLeft(text('m0000000001')).dx;
    expect(x1, lessThan(x0));
    chat.add(msg(2, 'p2'));
    await tester.pump();
    expect(text('m0000000002'), findsNothing); // the first one finishes
    // Through the whole width plus the text at 60 dp/s, then 1 s.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 900));
    expect(text('m0000000002'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(text('m0000000002'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('8 s with no new message: 40%; a new one brings it back', (
    tester,
  ) async {
    final (_, chat) = await rig(tester, seed: [msg(1, 'p1')]);
    expect(opacity(tester), 1);
    await tester.pump(const Duration(seconds: 7));
    expect(opacity(tester), 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(opacity(tester), WorldChatTicker.faded);
    chat.add(msg(2, 'p2'));
    await tester.pump();
    expect(opacity(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a message already old when the shop opens starts faded', (
    tester,
  ) async {
    await rig(
      tester,
      seed: [
        msg(1, 'p1', at: DateTime.now().subtract(const Duration(minutes: 5))),
      ],
    );
    expect(opacity(tester), WorldChatTicker.faded);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tap opens Tin thế giới; then the ticker hides', (tester) async {
    final (s, _) = await rig(tester, seed: [msg(1, 'p1')]);
    await tester.tap(find.byKey(const Key('world-chat-ticker')));
    await tester.pump();
    expect(s.chat.open, isTrue);
    expect(find.byKey(const Key('world-chat-ticker')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hidden: chat switched off, a popup, Cài đặt', (tester) async {
    await rig(tester, on: false, seed: [msg(1, 'p1')]);
    expect(find.byKey(const Key('world-chat-ticker')), findsNothing);
    await tester.pumpWidget(const SizedBox());

    await rig(tester, seed: [msg(1, 'p1')], popupOpen: true);
    expect(find.byKey(const Key('world-chat-ticker')), findsNothing);
    await tester.pumpWidget(const SizedBox());

    final (s, _) = await rig(tester, seed: [msg(1, 'p1')]);
    expect(find.byKey(const Key('world-chat-ticker')), findsOneWidget);
    s.openPause();
    await tester.pump();
    expect(find.byKey(const Key('world-chat-ticker')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a blocked sender never scrolls', (tester) async {
    final (s, chat) = await rig(tester, seed: [msg(1, 'p1')]);
    await s.board.hidePlayer('p2', 'Tiệm p2');
    chat.add(msg(2, 'p2'));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(text('m0000000002'), findsNothing);
    expect(text('m0000000001'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('main shop: own strip under the scene (clear of the sign and '
      'the bucket row), 12 dp sides; '
      'the same-day slot moves down 32 dp', (tester) async {
    final chat = MemoryWorldChat()..add(msg(1, 'p1'));
    final s = newSession(worldChat: chat);
    s.accountUid = 'me';
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: s,
            builder: (_, _) => MainShopOverlay(session: s),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final strip = find.byKey(const Key('world-chat-ticker'));
    expect(strip, findsOneWidget);
    // Under the scene (ends y 312), 2 dp gap; the goals card 2 dp below it
    // (An 26/10): never over the shop sign or the bucket row.
    expect(tester.getTopLeft(strip), const Offset(12, 314));
    expect(tester.getTopLeft(find.byType(GoalsCard)).dy, 314 + 24 + 2);
    expect(tester.getSize(strip), const Size(336, 24));
    // x closes it to the reopen button right of the sign (max x 272).
    final close = find.byKey(const Key('world-chat-ticker-close'));
    expect(tester.getSize(close).width, 48);
    await tester.tap(close);
    await tester.pump();
    final reopen = find.byKey(const Key('world-chat-reopen'));
    expect(reopen, findsOneWidget);
    expect(tester.getSize(reopen), const Size(48, 48));
    expect(tester.getTopLeft(reopen).dx, greaterThanOrEqualTo(272));
    expect(tester.getCenter(reopen).dy, 74);
    await tester.tap(reopen);
    await tester.pump();
    expect(find.byKey(const Key('world-chat-reopen')), findsNothing);
    expect(find.byKey(const Key('world-chat-ticker')), findsOneWidget);
    expect(WorldChatTicker.on(s), isTrue);
    expect(tester.getTopLeft(find.byType(SameDaySlot)).dy, 60 + 32);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no news: only the speaker, at 40% (Phú)', (tester) async {
    final (s, _) = await rig(tester);
    expect(find.byKey(const Key('world-chat-ticker')), findsOneWidget);
    expect(find.byKey(const Key('world-chat-ticker-icon')), findsOneWidget);
    expect(find.textContaining(':'), findsNothing);
    expect(opacity(tester), WorldChatTicker.faded);
    expect(WorldChatTicker.on(s), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('x collapses to the reopen button for the session; news '
      'while hidden puts a red dot on it; tap brings the strip back', (
    tester,
  ) async {
    final (s, chat) = await rig(tester, seed: [msg(1, 'p1')]);
    final close = find.byKey(const Key('world-chat-ticker-close'));
    expect(tester.getSize(close).width, WorldChatTicker.closeHit);
    await tester.tap(close);
    await tester.pump();
    expect(find.byKey(const Key('world-chat-ticker')), findsNothing);
    expect(WorldChatTicker.on(s), isFalse);
    expect(WorldChatReopenButton.on(s), isTrue);
    // Session-only: a new game day does not bring it back.
    s.state.day = 8;
    expect(WorldChatTicker.on(s), isFalse);
    // On the shop the hidden strip stays mounted (offstage), still listening.
    s.chat.startTicker();
    addTearDown(s.chat.stopTicker);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: WorldChatReopenButton(session: s)),
      ),
    );
    expect(find.byKey(const Key('world-chat-reopen-dot')), findsNothing);
    chat.add(msg(2, 'p2'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('world-chat-reopen-dot')), findsOneWidget);
    final circle = tester.widget<Icon>(find.byIcon(Icons.campaign_rounded));
    expect(circle.size, 18);
    expect(circle.color, const Color(0xFF3F7F52));
    await tester.tap(find.byKey(const Key('world-chat-reopen')));
    await tester.pump();
    expect(WorldChatTicker.on(s), isTrue);
    expect(WorldChatReopenButton.on(s), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
