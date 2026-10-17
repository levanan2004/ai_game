import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/logic/world_chat_admin.dart';
import 'package:ai_game/logic/profile_report.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/game_root.dart' show menuEntries;
import 'package:ai_game/ui/report_admin_panel.dart';
import 'package:ai_game/ui/world_chat_admin_panel.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:ai_game/ui/world_chat_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

ChatMessage msg(int seq, String uid, {String? name}) => ChatMessage(
  id: 'm${seq.toString().padLeft(10, '0')}',
  uid: uid,
  name: name ?? 'Tiệm $uid',
  text: 'tin $seq',
  seq: seq,
  createdAt: DateTime.now(),
);

void main() {
  Future<(ShopSession, MemoryWorldChat)> open(
    WidgetTester tester, {
    int day = 7,
    bool signedIn = true,
    bool accepted = true,
    bool on = true,
    List<ChatMessage> seed = const [],
  }) async {
    final chat = MemoryWorldChat(on: on);
    for (final m in seed) {
      chat.add(m);
    }
    final backing = <String, String>{};
    if (accepted) backing[ProgressStore.chatRulesKey] = 'true';
    final store = ProgressStore.memory(backing);
    final s = newSession(store: store, worldChat: chat);
    if (signedIn) s.accountUid = 'me';
    s.state.day = day;
    await s.chat.useStore(store);
    await s.board.useHiddenPlayers(store);
    s.chat.openChat();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorldChatSheet(session: s)),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (s, chat);
  }

  testWidgets('C1: header, empty state, input with counter', (tester) async {
    await open(tester);
    expect(find.text(ChatText.emptyBody), findsOneWidget);
    expect(find.byKey(const Key('world-chat-input')), findsOneWidget);
    expect(find.text('0/80'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('world-chat-field'))).height,
      WorldChatSheet.fieldHeight,
    );
    expect(
      tester.getSize(find.byKey(const Key('world-chat-send'))),
      const Size(44, 44),
    );
  });

  testWidgets('first open: the rules popup needs the checkbox', (tester) async {
    final (s, _) = await open(tester, accepted: false);
    expect(find.text(ChatText.popupTitle), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-chat-rules-ok')));
    await tester.pump();
    expect(s.chat.rulesAccepted, isFalse);
    await tester.tap(find.byKey(const Key('world-chat-rules-check')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('world-chat-rules-ok')));
    await tester.pump();
    expect(s.chat.rulesAccepted, isTrue);
    expect(find.text(ChatText.popupTitle), findsNothing);
  });

  testWidgets('send shows the message and the cooldown on the button', (
    tester,
  ) async {
    final (s, chat) = await open(tester);
    await tester.enterText(find.byKey(const Key('world-chat-input')), 'chào');
    await tester.pump();
    expect(find.text('4/80'), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-chat-send')));
    await tester.pump();
    await tester.pump();
    expect(chat.all.single.text, 'chào');
    expect(find.text('tin 1'), findsNothing);
    expect(find.text('chào'), findsOneWidget);
    expect(find.byKey(const Key('world-chat-cooldown')), findsOneWidget);
    expect(find.text(ChatText.cooldownPlaceholder(10)), findsOneWidget);
    // The session clock is the real one: end the cooldown by hand.
    s.chat.cooldownUntil = DateTime.now();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('world-chat-cooldown')), findsNothing);
  });

  testWidgets('a filtered message keeps the text and shows Nhất\'s line', (
    tester,
  ) async {
    final (_, chat) = await open(tester);
    chat.nextResult = const ChatSendResult.refused('blocked');
    await tester.enterText(find.byKey(const Key('world-chat-input')), 'xấu');
    await tester.pump();
    await tester.tap(find.byKey(const Key('world-chat-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ChatText.blocked), findsOneWidget);
    expect(find.text('xấu'), findsOneWidget);
  });

  testWidgets('too long: counter red, send off', (tester) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('world-chat-input')),
      'a' * 81,
    );
    await tester.pump();
    expect(find.text('81/80'), findsOneWidget);
    final send = tester.widget<InkWell>(
      find.byKey(const Key('world-chat-send')),
    );
    expect(send.onTap, isNull);
  });

  testWidgets('day 4: the o_khoa card replaces the input', (tester) async {
    await open(tester, day: 4);
    expect(find.byKey(const Key('world-chat-lock-day')), findsOneWidget);
    expect(find.text(ChatText.lockedDay(5, 1)), findsOneWidget);
    expect(find.byKey(const Key('world-chat-input')), findsNothing);
  });

  testWidgets('guest: read only with the sign-in button', (tester) async {
    await open(tester, signedIn: false, seed: [msg(1, 'p1')]);
    expect(find.text('tin 1'), findsOneWidget);
    expect(find.text(ChatText.guestLocked), findsOneWidget);
    expect(find.byKey(const Key('world-chat-login')), findsOneWidget);
  });

  testWidgets('switched off: the "tạm nghỉ" text', (tester) async {
    await open(tester, on: false);
    expect(find.byKey(const Key('world-chat-disabled')), findsOneWidget);
  });

  testWidgets('report with 6 reasons, then "Chặn luôn" hides the sender', (
    tester,
  ) async {
    final (s, chat) = await open(
      tester,
      seed: [msg(1, 'p1', name: 'Tiệm Lan'), msg(2, 'p2')],
    );
    await tester.tap(find.byKey(const Key('world-chat-more-m0000000001')));
    await tester.pump();
    expect(find.text(ChatText.menuBlock('Tiệm Lan')), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-chat-menu-report')));
    await tester.pump();
    for (final r in ChatReportReason.values) {
      expect(find.text(r.label), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('world-chat-reason-scam')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('world-chat-report-send')));
    await tester.pump();
    expect(chat.reports.keys.single, 'me_m0000000001');
    expect(find.text(ChatText.thanksBody('Tiệm Lan')), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-chat-thanks-yes')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(s.board.isHidden('p1'), isTrue);
    expect(find.text('tin 1'), findsNothing);
    expect(find.text('tin 2'), findsOneWidget);
    expect(find.text(ChatText.someBlocked), findsOneWidget);
  });

  testWidgets('blocked list: unblock with confirm', (tester) async {
    final (s, _) = await open(tester, seed: [msg(1, 'p1', name: 'Tiệm Lan')]);
    await s.board.hidePlayer('p1', 'Tiệm Lan');
    s.chat.openBlockedList();
    await tester.pump();
    expect(find.text(ChatText.blockedCount(1)), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-chat-unblock-p1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('world-chat-unblock-yes')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(s.board.isHidden('p1'), isFalse);
  });

  test('corner menu: a Tin thế giới entry only when the chat is offered', () {
    final offered = newSession(worldChat: MemoryWorldChat());
    expect(
      menuEntries(session: offered).map((e) => e.id),
      contains('world_chat'),
    );
    expect(
      menuEntries(session: newSession()).map((e) => e.id),
      isNot(contains('world_chat')),
    );
  });

  testWidgets('/quan-tri: switch, delete a message, set a mute', (
    tester,
  ) async {
    final chat = MemoryWorldChat(on: false)
      ..add(msg(1, 'p1'))
      ..add(msg(2, 'p2'));
    final admin = MemoryWorldChatAdmin(chat);
    await tester.pumpWidget(
      MaterialApp(home: WorldChatAdminPanel(admin: admin, onClose: () {})),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-admin-switch')));
    await tester.pump();
    expect(chat.on, isTrue);
    await tester.tap(find.byKey(const Key('chat-admin-delete-m0000000001')));
    await tester.pump();
    expect(chat.all.map((m) => m.id), ['m0000000002']);
    await tester.tap(find.byKey(const Key('chat-admin-mute-m0000000002')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-mute-mute_24h')));
    await tester.pumpAndSettle();
    expect(chat.mutes['p2']!.level, 'mute_24h');
  });

  testWidgets('/quan-tri Báo cáo lists chat reports with their actions', (
    tester,
  ) async {
    final chat = MemoryWorldChat()..add(msg(1, 'p1'));
    final admin = MemoryWorldChatAdmin(chat);
    admin.reportList.add(
      ChatReport(
        id: 'me_m0000000001',
        reporterUid: 'me',
        targetUid: 'p1',
        targetName: 'Tiệm p1',
        messageId: 'm0000000001',
        text: 'tin 1',
        reason: ChatReportReason.harassment,
        context: [msg(1, 'p1')],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReportAdminPanel(
          reports: MemoryProfileReports(),
          chat: admin,
          onClose: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Quấy rối'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-report-done-me_m0000000001')));
    await tester.pump();
    await tester.pump();
    expect(admin.done, {'me_m0000000001'});
    await tester.tap(
      find.byKey(const Key('chat-report-delete-me_m0000000001')),
    );
    await tester.pump();
    expect(chat.all, isEmpty);
  });
}
