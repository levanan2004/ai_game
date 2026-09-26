import 'dart:typed_data';

import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/supporters.dart';
import 'package:ai_game/ui/donors_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// In-memory board that is both the public source and the admin backend.
class _FakeBoard implements SupporterSource, SupporterAdmin {
  _FakeBoard({this.admin = true});

  final bool admin;
  final people = <String, Supporter>{};
  final phones = <String, String>{};
  var _next = 0;

  @override
  Future<List<Supporter>> load() async => people.values.toList();

  @override
  Future<bool> isAdmin() async => admin;

  @override
  String newId() => 'id${_next++}';

  @override
  Future<List<Supporter>> loadAll() => load();

  @override
  Future<String> loadPhone(String id) async => phones[id] ?? '';

  @override
  Future<void> save(Supporter s, {required String phone}) async {
    people[s.id] = s;
    if (phone.isEmpty) {
      phones.remove(s.id);
    } else {
      phones[s.id] = phone;
    }
  }

  @override
  Future<void> delete(Supporter s) async {
    people.remove(s.id);
    phones.remove(s.id);
  }

  @override
  Future<String> uploadAvatar(String id, Uint8List jpeg) async =>
      'supporters/$id.jpg';

  @override
  Future<void> deleteAvatar(String path) async {}
}

Future<void> _pumpDonors(WidgetTester tester, _FakeBoard board) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  final s = newSession(supporters: board, supporterAdmin: board)
    ..applySignedIn(const AccountProfile(uid: 'admin', email: 'a@b.c'));
  await tester.pumpWidget(MaterialApp(home: DonorsScreen(session: s)));
  await tester.pump(const Duration(milliseconds: 100));
}

/// A focused field scrolls its caret back into view, so drop focus before
/// reaching for a control further down the form.
Future<void> _tapBelow(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('non-admins never see the Quản lý button', (tester) async {
    await _pumpDonors(tester, _FakeBoard(admin: false));
    expect(find.byKey(const Key('donors-admin')), findsNothing);
  });

  testWidgets('admin adds, edits and deletes a supporter', (tester) async {
    final board = _FakeBoard();
    await _pumpDonors(tester, board);

    await tester.tap(find.byKey(const Key('donors-admin')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Quản lý bảng'), findsOneWidget);

    // Add.
    await tester.tap(find.byKey(const Key('admin-add')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('admin-name')), 'Chị Lan');
    await tester.enterText(find.byKey(const Key('admin-amount')), '200k');
    await tester.enterText(
      find.byKey(const Key('admin-phone')),
      '090 123 4567',
    );
    await tester.enterText(find.byKey(const Key('admin-message')), 'Cố lên');
    await tester.tap(find.byKey(const Key('admin-avatar-bao_ngoc')));
    await tester.pump();
    await _tapBelow(tester, 'admin-save');

    final saved = board.people.values.single;
    expect(saved.name, 'Chị Lan');
    expect(saved.amount, 200000);
    expect(saved.avatar, 'bao_ngoc');
    expect(saved.message, 'Cố lên');
    expect(board.phones[saved.id], '0901234567');
    expect(find.text('Chị Lan'), findsOneWidget);

    // Edit: bad amount is refused, then hide from the board.
    await tester.tap(find.byKey(Key('admin-row-${saved.id}')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('admin-phone')))
          .controller!
          .text,
      '0901234567',
    );
    await tester.enterText(find.byKey(const Key('admin-amount')), 'nhiều');
    await _tapBelow(tester, 'admin-save');
    expect(find.byKey(const Key('admin-error')), findsOneWidget);
    expect(board.people[saved.id]!.amount, 200000);

    await tester.enterText(find.byKey(const Key('admin-amount')), '');
    await _tapBelow(tester, 'admin-visible');
    await _tapBelow(tester, 'admin-save');
    expect(board.people[saved.id]!.visible, isFalse);
    expect(board.people[saved.id]!.amount, isNull);

    // Delete needs a second tap.
    await tester.tap(find.byKey(Key('admin-row-${saved.id}')));
    await tester.pump(const Duration(milliseconds: 100));
    await _tapBelow(tester, 'admin-delete');
    expect(board.people, isNotEmpty);
    expect(find.text('Bấm lần nữa để xoá hẳn'), findsOneWidget);
    await _tapBelow(tester, 'admin-delete');
    expect(board.people, isEmpty);
    expect(board.phones, isEmpty);

    await tester.tap(find.byKey(const Key('admin-back')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('donors-board')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
