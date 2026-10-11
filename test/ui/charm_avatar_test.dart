import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/preset_avatars.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/supporters.dart';
import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/player_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'charm_board_screen_test.dart' show loadFonts, mount, open;

const _upload = 'users/u9/avatar.jpg';
const _photo = 'https://lh3.googleusercontent.com/a/photo-9=s96-c';

/// A board whose rows 1-3 (podium) and 4-8 carry the avatar kinds under test.
Future<
  ({
    ShopSession s,
    MemoryCharmBoard board,
    DateTime Function() now,
    void Function(Duration) wait,
  })
>
_rig(WidgetTester tester) async {
  var clock = DateTime.utc(2026, 10, 20, 8);
  final board = MemoryCharmBoard(now: () => clock);
  final s = newSession(charmBoard: board, now: () => clock);
  const avatars = <String>[
    _photo, // 1: podium, Google photo URL
    'users/u2/avatar.jpg', // 2: podium, uploaded photo as a Storage path
    'minh_anh', // 3: podium, preset
    'https://firebasestorage.googleapis.com/v0/b/b/o/users%2Fu4%2Favatar.jpg'
        '?alt=media&v=7', // 4: uploaded photo URL with revision
    'users/u5/avatar.jpg', // 5: Storage path
    'khanh_linh', // 6: preset
    '', // 7: none
    'google', // 8: Google without a known photo
  ];
  await tester.runAsync(() async {
    for (var i = 0; i < avatars.length; i++) {
      clock = clock.add(const Duration(minutes: 1));
      await board.publish(
        period: s.e.charmBoard.periodKey,
        entry: CharmBoardEntry.forPlayer(
          uid: 'p$i',
          displayName: 'Tiệm Hoa Số ${i + 1}',
          avatar: avatars[i],
          charm: 900 - i * 10,
          petId: 'kim_long',
        ),
      );
    }
  });
  clock = clock.add(const Duration(hours: 1));
  s.accountUid = 'me';
  s.state.shopName = 'Tiệm Hoa Sớm Mai';
  s.state.day = 8;
  s.state.addPet('kim_long', fedDay: 1);
  s.state.ownedPet('kim_long')!.stage = 1;
  s.state.petCharm = 'kim_long';
  return (
    s: s,
    board: board,
    now: () => clock,
    wait: (Duration d) => clock = clock.add(d),
  );
}

NetworkImage _net(WidgetTester tester, Finder within) {
  final photo = find.descendant(
    of: within,
    matching: find.byKey(const Key('player-avatar-photo')),
  );
  expect(photo, findsOneWidget);
  return tester.widget<Image>(photo).image as NetworkImage;
}

String _asset(WidgetTester tester, Finder within) {
  final img = find.descendant(
    of: within,
    matching: find.byKey(const Key('player-avatar-preset')),
  );
  expect(img, findsOneWidget);
  return (tester.widget<Image>(img).image as AssetImage).assetName;
}

/// Scrolls the board until row [rank] is built, and returns its finder.
Future<Finder> _row(WidgetTester tester, int rank) async {
  final row = find.byKey(Key('bxh-row-$rank'));
  await tester.scrollUntilVisible(
    row,
    80,
    scrollable: find.descendant(
      of: find.byKey(const Key('bxh-list')),
      matching: find.byType(Scrollable),
    ),
  );
  return row;
}

void main() {
  setUpAll(loadFonts);

  group('the shared resolver', () {
    test('kinds: photo URL, Storage path, preset, none', () {
      expect(avatarKindOf(_photo), AvatarKind.photo);
      expect(avatarKindOf(_upload), AvatarKind.photo);
      expect(avatarKindOf('minh_anh'), AvatarKind.preset);
      expect(avatarKindOf(''), AvatarKind.none);
      expect(avatarKindOf('google'), AvatarKind.none);
      expect(avatarPhotoUrl(_photo), _photo);
      expect(avatarPhotoUrl(_upload), storageAvatarUrl(_upload));
      expect(avatarPhotoUrl('minh_anh'), isNull);
    });
  });

  group('board rows', () {
    testWidgets('every kind of avatar renders on the podium and in rows', (
      tester,
    ) async {
      final r = await _rig(tester);
      await mount(tester, r.s);
      await open(tester, r.s);
      await tester.runAsync(() => r.s.board.refresh(force: true));
      await tester.pump();

      // podium: photo URL, Storage path (public URL), preset
      expect(_net(tester, find.byKey(const Key('bxh-podium-1'))).url, _photo);
      expect(
        _net(tester, find.byKey(const Key('bxh-podium-2'))).url,
        storageAvatarUrl('users/u2/avatar.jpg'),
      );
      expect(
        _asset(tester, find.byKey(const Key('bxh-podium-3'))),
        Art.customer('minh_anh'),
      );
      // rows: revisioned URL, Storage path, preset, then the placeholders
      expect(
        _net(tester, find.byKey(const Key('bxh-row-4'))).url,
        contains('v=7'),
      );
      expect(
        _net(tester, find.byKey(const Key('bxh-row-5'))).url,
        storageAvatarUrl('users/u5/avatar.jpg'),
      );
      expect(_asset(tester, await _row(tester, 6)), Art.customer('khanh_linh'));
      for (final rank in [7, 8]) {
        final row = await _row(tester, rank);
        // the placeholder: the shop's initial, no picture
        expect(
          find.descendant(of: row, matching: find.byType(PlayerAvatar)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.byKey(const Key('player-avatar-photo')),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.byKey(const Key('player-avatar-preset')),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: row, matching: find.text('T')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('own card and own row show the live avatar, not the old row', (
      tester,
    ) async {
      final r = await _rig(tester);
      await mount(tester, r.s);
      await tester.runAsync(() => r.s.board.publishIfDue());
      await open(tester, r.s);
      await tester.runAsync(() => r.s.board.refresh(force: true));
      await tester.pump();
      final rank = r.s.board.myRank!;
      final card = find.byKey(const Key('bxh-card'));
      final row = await _row(tester, rank);
      // default preset avatar of a new shop
      expect(_asset(tester, card), Art.customer('minh_anh'));
      expect(_asset(tester, row), Art.customer('minh_anh'));

      // An uploads a photo: the card and the row switch at once, before the
      // board has the new value
      r.s.setOwnerAvatar(_upload, bumpRev: true);
      await tester.pump();
      final url = storageAvatarUrl(_upload, rev: r.s.state.ownerAvatarRev);
      expect(_net(tester, card).url, url);
      expect(_net(tester, row).url, url);
      expect(
        r.s.board.rows.firstWhere((x) => x.entry.uid == 'me').entry.avatar,
        'minh_anh',
        reason: 'the stored row is still the old one',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Google photo: the row carries the photo URL, empty without', (
      tester,
    ) async {
      final r = await _rig(tester);
      r.s.state.ownerAvatar = 'google';
      expect(r.s.publishedAvatar, '');
      expect(r.s.board.mine!.avatar, '');
      r.s.accountPhotoUrl = _photo;
      expect(r.s.publishedAvatar, _photo);
      expect(r.s.board.mine!.avatar, _photo);
      // a preset is its id, an upload its public URL with the revision
      r.s.state.ownerAvatar = 'khanh_linh';
      expect(r.s.publishedAvatar, 'khanh_linh');
      r.s.state.ownerAvatar = _upload;
      r.s.state.ownerAvatarRev = 42;
      expect(r.s.publishedAvatar, storageAvatarUrl(_upload, rev: 42));
      expect(r.s.publishedAvatar.length, lessThan(500));
    });
  });

  group('writing the avatar to the board', () {
    testWidgets('a changed avatar is republished at the next 15-minute push', (
      tester,
    ) async {
      final r = await _rig(tester);
      Future<String?> stored() async {
        final rows = await r.board.top(period: r.s.e.charmBoard.periodKey);
        for (final x in rows) {
          if (x.entry.uid == 'me') return x.entry.avatar;
        }
        return null;
      }

      await tester.runAsync(() => r.s.board.publishIfDue());
      expect(await tester.runAsync(stored), 'minh_anh');

      r.s.setOwnerAvatar(_upload, bumpRev: true);
      final want = r.s.publishedAvatar;
      expect(want, startsWith('https://'));
      // inside the 15 minutes: nothing is written yet
      r.wait(const Duration(minutes: 5));
      await tester.runAsync(() => r.s.board.publishIfDue());
      expect(await tester.runAsync(stored), 'minh_anh');
      // the next push after 15 minutes writes the new avatar
      r.wait(const Duration(minutes: 11));
      await tester.runAsync(() => r.s.board.publishIfDue());
      expect(await tester.runAsync(stored), want);
      // why: the row's content compare includes the avatar
      expect(
        CharmBoardEntry.forPlayer(
          uid: 'me',
          displayName: 'a',
          avatar: 'minh_anh',
          charm: 1,
        ).sameContent(
          CharmBoardEntry.forPlayer(
            uid: 'me',
            displayName: 'a',
            avatar: want,
            charm: 1,
          ),
        ),
        isFalse,
        reason: 'sameContent compares the avatar',
      );
    });
  });

  test('presets of the picker all resolve to a customer picture', () {
    for (final id in presetAvatarIds) {
      expect(avatarKindOf(id), AvatarKind.preset, reason: id);
    }
  });
}
