import 'dart:io';

import 'package:ai_game/logic/supporters.dart';
import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/donors_screen.dart' show SupporterAvatar;
import 'package:ai_game/ui/settings_popup.dart';
import 'package:ai_game/ui/player_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Guards "one way to draw a player's avatar": the settings card and picker,
/// the supporters board and its admin, and the Mị lực board all go through
/// PlayerAvatarFace / PlayerAvatar (lib/ui/player_avatar.dart), so a kind of
/// avatar (preset, uploaded photo, Google photo) looks the same everywhere.
///
/// What is NOT a player avatar: the round portraits of the game's customers
/// (NPCs: order tickets, pre-orders, reviews) use the `Avatar` widget from
/// common.dart with `assets/images/customers`.
Map<String, String> _ui() => {
  for (final f in Directory('lib/ui').listSync().whereType<File>())
    if (f.path.endsWith('.dart')) f.uri.pathSegments.last: f.readAsStringSync(),
};

/// Files of lib/ui that may touch the avatar pointer / art directly.
const _resolverFiles = {'player_avatar.dart', 'common.dart', 'art.dart'};

/// The files that draw an NPC customer with the `Avatar` widget.
const _customerFiles = {
  'bouquet_table_screen.dart',
  'preorder_screen.dart',
  'review_popup.dart',
  'reviews_screen.dart',
};

/// Places that show a player's avatar and must use the shared widgets.
const _playerAvatarPlaces = {
  'settings_popup.dart': 'Settings account card + avatar picker',
  'donors_screen.dart': 'supporters board (SupporterAvatar)',
  'supporter_admin_panel.dart': 'supporters admin (SupporterAvatar)',
  'charm_board_screen.dart': 'Mị lực board: podium, rows, own card, profile',
  'world_chat_sheet.dart': 'Tin thế giới messages (with their frame)',
  'profile_card.dart': 'profile card (spec 6)',
  'avatar_frame_sheet.dart': 'Khung avatar sheet F1 preview',
};

void main() {
  final files = _ui();

  test('only the shared widget resolves avatar pictures', () {
    for (final e in files.entries) {
      if (_resolverFiles.contains(e.key)) continue;
      expect(
        e.value.contains('storageAvatarUrl('),
        isFalse,
        reason: '${e.key} resolves a Storage avatar itself',
      );
      expect(
        e.value.contains('Art.customer('),
        isFalse,
        reason: '${e.key} draws a customers/ picture itself',
      );
    }
  });

  test('the places that show a player use PlayerAvatar / PlayerAvatarFace', () {
    for (final e in _playerAvatarPlaces.entries) {
      final src = files[e.key]!;
      expect(
        src.contains('PlayerAvatar') ||
            (src.contains('SupporterAvatar') &&
                files['donors_screen.dart']!.contains('PlayerAvatarFace')),
        isTrue,
        reason: '${e.value} (${e.key}) has its own avatar drawing',
      );
      expect(
        src.contains('Image.network('),
        isFalse,
        reason: '${e.value} (${e.key}) fetches an avatar by itself',
      );
      expect(
        RegExp(r'(?<![A-Za-z])Avatar\(').hasMatch(src),
        isFalse,
        reason: '${e.value} (${e.key}) uses the NPC Avatar widget',
      );
      // (the settings picker compares the chosen id to mark the ticked preset;
      // it draws nothing from it)
      expect(
        e.key == 'settings_popup.dart' || !src.contains('.ownerAvatar'),
        isTrue,
        reason:
            '${e.value} (${e.key}) reads ownerAvatar raw (no Google photo '
            'URL, no revision): use ShopSession.publishedAvatar',
      );
    }
  });

  test('the NPC Avatar widget stays on customers only', () {
    final users = [
      for (final e in files.entries)
        if (!_resolverFiles.contains(e.key) &&
            RegExp(r'(?<![A-Za-z])Avatar\(').hasMatch(e.value))
          e.key,
    ]..sort();
    expect(users, _customerFiles.toList()..sort());
  });

  group('SupporterAvatar uses the shared face', () {
    Future<void> show(WidgetTester tester, String avatar) => tester.pumpWidget(
      MaterialApp(
        home: Center(child: SupporterAvatar(avatar: avatar)),
      ),
    );

    testWidgets('photo URL and Storage path: the photo', (tester) async {
      await show(tester, 'https://lh3.googleusercontent.com/a/x=s96-c');
      expect(find.byKey(const Key('player-avatar-photo')), findsOneWidget);
      await show(tester, 'users/u1/avatar.jpg');
      final img = tester.widget<Image>(
        find.byKey(const Key('player-avatar-photo')),
      );
      expect(
        (img.image as NetworkImage).url,
        storageAvatarUrl('users/u1/avatar.jpg'),
      );
    });

    testWidgets('preset id: the customers/ picture', (tester) async {
      await show(tester, 'minh_anh');
      final img = tester.widget<Image>(
        find.byKey(const Key('player-avatar-preset')),
      );
      expect((img.image as AssetImage).assetName, Art.customer('minh_anh'));
    });

    testWidgets('empty: the lotus, no picture', (tester) async {
      await show(tester, '');
      expect(find.byKey(const Key('player-avatar-photo')), findsNothing);
      expect(find.byKey(const Key('player-avatar-preset')), findsNothing);
      expect(find.byType(SupporterAvatar), findsOneWidget);
    });
  });

  group('Settings account card', () {
    Future<Finder> card(
      WidgetTester tester,
      String id, {
      String? photo,
      int rev = 0,
    }) async {
      final s = newSession();
      s.accountUid = 'u1';
      s.state.ownerAvatar = id;
      s.state.ownerAvatarRev = rev;
      s.accountPhotoUrl = photo;
      await tester.pumpWidget(MaterialApp(home: SettingsPopup(session: s)));
      await tester.pump();
      return find.byKey(const Key('settings-avatar'));
    }

    testWidgets('uploaded photo: the public URL with its revision', (
      tester,
    ) async {
      final f = await card(tester, 'users/u1/avatar.jpg', rev: 5);
      final img = tester.widget<Image>(
        find.descendant(
          of: f,
          matching: find.byKey(const Key('player-avatar-photo')),
        ),
      );
      expect(
        (img.image as NetworkImage).url,
        storageAvatarUrl('users/u1/avatar.jpg', rev: 5),
      );
    });

    testWidgets('Google photo: its URL; without one the lotus', (tester) async {
      var f = await card(
        tester,
        'google',
        photo: 'https://lh3.googleusercontent.com/a/me=s96-c',
      );
      expect(
        find.descendant(
          of: f,
          matching: find.byKey(const Key('player-avatar-photo')),
        ),
        findsOneWidget,
      );
      f = await card(tester, 'google');
      expect(
        find.descendant(
          of: f,
          matching: find.byKey(const Key('player-avatar-photo')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: f,
          matching: find.byKey(const Key('player-avatar-preset')),
        ),
        findsNothing,
      );
    });

    testWidgets('preset: the customers/ picture', (tester) async {
      final f = await card(tester, 'lan_anh');
      final img = tester.widget<Image>(
        find.descendant(
          of: f,
          matching: find.byKey(const Key('player-avatar-preset')),
        ),
      );
      expect((img.image as AssetImage).assetName, Art.customer('lan_anh'));
    });
  });

  testWidgets('PlayerAvatarFace: fallback for none, google, a failed file', (
    tester,
  ) async {
    const fb = SizedBox(key: Key('fallback'), width: 10, height: 10);
    for (final a in ['', 'google', 'no_such_preset_xyz']) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 40,
            child: PlayerAvatarFace(avatar: a, fallback: fb),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('fallback')), findsOneWidget, reason: a);
    }
  });
}
