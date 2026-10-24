// Tin thế giới states at 360x640 (Item 7): empty, list, switched off, muted,
// banned, loading, load error. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/world_chat_states_screenshot_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('shot-frame');

/// messages() never answers (loading) or fails (load error).
class _Chat extends MemoryWorldChat {
  _Chat({super.on, this.mode = ''});
  final String mode;

  @override
  Stream<List<ChatMessage>> messages(int limit) {
    if (mode == 'loading') return StreamController<List<ChatMessage>>().stream;
    if (mode == 'error') return Stream.error(Exception('offline'));
    return super.messages(limit);
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_frame),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadTestFonts);
  if (_dir == null) {
    test('screenshots skipped (SHOT_DIR not set)', () {}, skip: true);
    return;
  }

  final cases = <String, _Chat Function()>{
    'trong': () => _Chat(),
    'co_tin': () => _Chat()
      ..add(
        ChatMessage(
          id: 'm0000000001',
          uid: 'p1',
          name: 'Tiệm Hoa Lan',
          text: 'Chào cả phố hoa!',
          seq: 1,
          createdAt: DateTime.now(),
        ),
      ),
    'tat': () => _Chat(on: false),
    'khoa_chat': () =>
        _Chat()..mutes['me'] = ChatMute(level: 'mute_1h', at: DateTime.now()),
    'cam_chat': () =>
        _Chat()..mutes['me'] = ChatMute(level: 'ban', at: DateTime.now()),
    'dang_tai': () => _Chat(mode: 'loading'),
    'mat_mang': () => _Chat(mode: 'error'),
  };

  for (final rules in const ['noi_quy_popup', 'noi_quy']) {
    testWidgets('world chat $rules 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ProgressStore.memory({});
      final s = newSession(store: store, worldChat: _Chat());
      s.accountUid = 'me';
      s.state.day = 7;
      await s.chat.useStore(store);
      await s.board.useHiddenPlayers(store);
      s.chat.openChat();
      if (rules == 'noi_quy') s.chat.openRules();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _frame,
            child: Scaffold(body: WorldChatSheet(session: s)),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await _save(tester, 'world_chat_${rules}_360x640');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final e in cases.entries) {
    testWidgets('world chat ${e.key} 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chat = e.value();
      final store = ProgressStore.memory({ProgressStore.chatRulesKey: 'true'});
      final s = newSession(store: store, worldChat: chat);
      s.accountUid = 'me';
      s.state.day = 7;
      await s.chat.useStore(store);
      await s.board.useHiddenPlayers(store);
      s.chat.openChat();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _frame,
            child: Scaffold(body: WorldChatSheet(session: s)),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      // Let the webp art decode before the picture (first test included).
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await _save(tester, 'world_chat_${e.key}_360x640');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
