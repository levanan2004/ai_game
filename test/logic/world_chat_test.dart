import 'dart:convert';

import 'package:ai_game/data/firestore_world_chat.dart';
import 'package:ai_game/data/world_chat_rules.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final t0 = DateTime(2026, 10, 17, 10);

ChatMessage msg(int seq, String uid, {String? name, bool official = false}) =>
    ChatMessage(
      id: 'm${seq.toString().padLeft(10, '0')}',
      uid: uid,
      name: name ?? 'Tiệm $uid',
      text: 'tin $seq',
      seq: seq,
      createdAt: t0,
      official: official,
    );

void main() {
  late DateTime now;
  setUp(() => now = t0);

  ({ShopSession s, MemoryWorldChat chat, Map<String, String> backing}) world({
    int day = 7,
    bool signedIn = true,
    bool on = true,
  }) {
    final backing = <String, String>{};
    final chat = MemoryWorldChat(on: on, now: () => now);
    final s = newSession(
      store: ProgressStore.memory(backing),
      worldChat: chat,
      now: () => now,
    );
    if (signedIn) s.accountUid = 'me';
    s.state.day = day;
    return (s: s, chat: chat, backing: backing);
  }

  test('economy.json worldChat: spec 5.1 numbers, missing block = no chat', () {
    final r = loadTestData().economy.worldChat!;
    expect(r.unlockDay, 5);
    expect(r.maxChars, 80);
    expect(r.cooldownSeconds, 10);
    expect(r.duplicateWindowSeconds, 60);
    expect(r.keepLatest, 100);
    expect(r.reportNoteMax, 200);
    expect([for (final l in r.muteLevels) '${l.id}:${l.minutes}'], [
      'warning:0',
      'mute_1h:60',
      'mute_24h:1440',
      'mute_7d:10080',
      'ban:null',
    ]);
    expect(WorldChatRules.fromJson(null), isNull);
    expect(
      () => WorldChatRules.fromJson({'unlockDay': 5}),
      throwsFormatException,
    );
  });

  test('offered only with a source; not without one', () {
    expect(world().s.chat.offered, isTrue);
    expect(newSession().chat.offered, isFalse);
  });

  test('locks: off, guest, day 4, muted, banned; warning does not lock', () async {
    final off = world(on: false);
    off.s.chat.openChat();
    await pumpEventQueue();
    expect(off.s.chat.lock, ChatLock.disabled);

    final guest = world(signedIn: false);
    guest.s.chat.openChat();
    await pumpEventQueue();
    expect(guest.s.chat.lock, ChatLock.guest);

    final early = world(day: 4);
    early.s.chat.openChat();
    await pumpEventQueue();
    expect(early.s.chat.lock, ChatLock.lockedDay);
    expect(early.s.chat.daysLeft, 1);

    final w = world(day: 5);
    w.s.chat.openChat();
    await pumpEventQueue();
    expect(w.s.chat.lock, ChatLock.none);
    w.chat.mutes['me'] = ChatMute(level: 'warning', at: now);
    await w.s.chat.refreshMute();
    expect(w.s.chat.lock, ChatLock.none);
    w.chat.mutes['me'] = ChatMute(
      level: 'mute_1h',
      at: now.subtract(const Duration(minutes: 30)),
    );
    await w.s.chat.refreshMute();
    expect(w.s.chat.lock, ChatLock.muted);
    expect(w.s.chat.muteState!.until, now.add(const Duration(minutes: 30)));
    now = now.add(const Duration(minutes: 31));
    expect(w.s.chat.lock, ChatLock.none);
    w.chat.mutes['me'] = ChatMute(level: 'ban', at: t0);
    await w.s.chat.refreshMute();
    expect(w.s.chat.lock, ChatLock.banned);
  });

  test('send: empty and 81 characters stay local; a send starts the 10 s cooldown', () async {
    final w = world();
    final c = w.s.chat;
    c.openChat();
    await pumpEventQueue();
    expect(await c.send('   '), isFalse);
    expect(c.inputError, 'empty');
    expect(await c.send('ư' * 81), isFalse);
    expect(c.inputError, 'too_long');
    expect(w.chat.all, isEmpty);
    expect(chatCharCount('ư' * 80), 80);

    expect(await c.send(' chào cả phố '), isTrue);
    await pumpEventQueue();
    expect(w.chat.all.single.text, 'chào cả phố');
    expect(c.visible.single.uid, 'me');
    expect(c.cooldownLeft, 10);
    expect(await c.send('nữa'), isFalse);
    now = now.add(const Duration(seconds: 10));
    expect(c.cooldownLeft, 0);
    expect(await c.send('nữa'), isTrue);
  });

  test('server refusals keep the text; cooldown, mute and off are applied', () async {
    final w = world();
    final c = w.s.chat;
    c.openChat();
    await pumpEventQueue();
    w.chat.nextResult = const ChatSendResult.refused('blocked_link');
    expect(await c.send('zalo 0912345678'), isFalse);
    expect(c.inputError, 'blocked_link');
    expect(c.pending, isEmpty);
    w.chat.nextResult = const ChatSendResult.refused('duplicate');
    expect(await c.send('chào'), isFalse);
    expect(c.inputError, 'duplicate');
    w.chat.nextResult = const ChatSendResult.refused('cooldown', seconds: 7);
    expect(await c.send('chào'), isFalse);
    expect(c.cooldownLeft, 7);
    now = now.add(const Duration(seconds: 7));
    w.chat.mutes['me'] = ChatMute(level: 'mute_24h', at: now);
    w.chat.nextResult = const ChatSendResult.refused('muted');
    expect(await c.send('chào'), isFalse);
    expect(c.lock, ChatLock.muted);
    w.chat.mutes.clear();
    await c.refreshMute();
    w.chat.nextResult = const ChatSendResult.refused('disabled');
    expect(await c.send('chào'), isFalse);
    expect(c.lock, ChatLock.disabled);
  });

  test('a network failure leaves a failed bubble that retries', () async {
    final w = world();
    final c = w.s.chat;
    c.openChat();
    await pumpEventQueue();
    w.chat.nextResult = const ChatSendResult.refused('network');
    expect(await c.send('chào'), isTrue);
    expect(c.pending.single.failed, isTrue);
    await c.retry(c.pending.single);
    await pumpEventQueue();
    expect(c.pending, isEmpty);
    expect(w.chat.all.single.text, 'chào');
  });

  test('masked words: the server text is shown and the toast flag set', () async {
    final w = world();
    final c = w.s.chat;
    c.openChat();
    await pumpEventQueue();
    w.chat.nextResult = const ChatSendResult.ok(
      text: 'hoa đẹp ***',
      masked: true,
    );
    await c.send('hoa đẹp đm');
    await pumpEventQueue();
    expect(c.maskedNotice, isTrue);
    expect(w.chat.all.single.text, 'hoa đẹp ***');
  });

  test('block reuses the board hidden list (saved on the device); own and Tiệm cannot', () async {
    final w = world();
    final c = w.s.chat;
    await w.s.board.useHiddenPlayers(ProgressStore.memory(w.backing));
    w.chat.add(msg(1, 'p1', name: 'Tiệm Lan'));
    w.chat.add(msg(2, 'p2'));
    w.chat.add(msg(3, 'admin', official: true));
    w.chat.add(msg(4, 'me'));
    c.openChat();
    await pumpEventQueue();
    expect(c.visible.length, 4);
    expect(await c.block(c.visible.first), isTrue);
    expect(c.visible.map((m) => m.uid), ['p2', 'admin', 'me']);
    expect(c.someBlocked, isTrue);
    expect(w.s.board.isHidden('p1'), isTrue);
    expect(
      await ProgressStore.memory(w.backing).loadHiddenPlayers(),
      {'p1': 'Tiệm Lan'},
    );
    expect(await c.block(msg(3, 'admin', official: true)), isFalse);
    expect(await c.block(msg(4, 'me')), isFalse);
    await c.unblock('p1');
    expect(c.visible.length, 4);
  });

  test('report: once per message, never one\'s own, note cut to 200', () async {
    final w = world();
    final c = w.s.chat;
    w.chat.add(msg(1, 'p1'));
    expect(
      await c.report(msg(1, 'p1'), ChatReportReason.spam, ''),
      ChatReportSend.sent,
    );
    // Taken down before the report: the server's 'gone', not a failure.
    expect(
      await c.report(msg(9, 'p2'), ChatReportReason.spam, ''),
      ChatReportSend.gone,
    );
    expect(
      await c.report(msg(1, 'p1'), ChatReportReason.other, ''),
      ChatReportSend.already,
    );
    expect(
      await c.report(msg(2, 'me'), ChatReportReason.spam, ''),
      ChatReportSend.failed,
    );
    expect(ChatReportReason.values.map((r) => r.label), [
      'Chửi bậy',
      'Quấy rối',
      'Lừa đảo/mua bán',
      'Nội dung người lớn',
      'Spam',
      'Khác',
    ]);
  });

  test('rules popup acceptance is remembered on the device', () async {
    final backing = <String, String>{};
    final store = ProgressStore.memory(backing);
    final w = world();
    await w.s.chat.useStore(store);
    expect(w.s.chat.rulesAccepted, isFalse);
    await w.s.chat.acceptRules();
    final again = world();
    await again.s.chat.useStore(store);
    expect(again.s.chat.rulesAccepted, isTrue);
  });

  test('callable answers: result, refusal code with details, network', () {
    List<int> b(Object o) => utf8.encode(jsonEncode(o));
    final ok = parseCallAnswer(200, b({'result': {'id': 'm1', 'masked': true}}));
    expect(ok.error, isNull);
    expect(ok.result['masked'], true);
    final no = parseCallAnswer(
      400,
      b({
        'error': {
          'message': 'cooldown',
          'status': 'FAILED_PRECONDITION',
          'details': {'seconds': 6},
        },
      }),
    );
    expect(no.error, 'cooldown');
    expect(no.details['seconds'], 6);
    expect(parseCallAnswer(503, b({})).error, 'network');
  });

  test('documents: message, mute and report readers skip bad data', () {
    final m = readChatMessage('m1', {
      'uid': 'u',
      'name': 'Tiệm',
      'text': 'hi',
      'seq': 3,
      'official': true,
    });
    expect(m!.official, isTrue);
    expect(readChatMessage('m2', {'uid': 'u'}), isNull);
    expect(readChatMute({'level': 'ban'}), isNull);
    expect(readChatMute({'level': 'ban', 'at': t0})!.level, 'ban');
    final r = readChatReport('a_m1', {
      'reporterUid': 'a',
      'targetUid': 'b',
      'reason': 'scam',
      'text': 'bán acc',
      'context': [
        {'uid': 'b', 'name': 'B', 'text': 'bán acc', 'seq': 1},
        {'bad': true},
      ],
    });
    expect(r!.reason, ChatReportReason.scam);
    expect(r.context.length, 1);
    expect(readChatReport('x', {'reason': 'mean'}), isNull);
  });
}
