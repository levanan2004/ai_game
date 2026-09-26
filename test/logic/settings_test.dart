import 'dart:convert';

import 'package:ai_game/logic/preset_avatars.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('old saves without music or avatar still load', () {
    final s = newSession();
    final j = jsonDecode(s.state.encode()) as Map<String, dynamic>;
    j.remove('musicOn');
    j.remove('sfxOn');
    j.remove('ownerAvatar');
    final back = GameState.decode(jsonEncode(j))!;
    expect(back.musicOn, isTrue);
    expect(back.sfxOn, isTrue);
    expect(back.ownerAvatar, GameState.defaultOwnerAvatar);
  });

  test('music and avatar are saved without committing the open day', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing);
    s.startNewGame();
    await s.pendingSaves;
    s.addBundle('rose');
    s.buyAndGoToShop();
    expect(s.state.phase, DayPhase.preparing);
    s.setMusic(false);
    s.setSfx(false);
    s.setOwnerAvatar('lan_anh');
    await s.pendingSaves;
    final saved = GameState.decode(backing[ProgressStore.storageKey])!;
    expect(saved.musicOn, isFalse);
    expect(saved.sfxOn, isFalse);
    expect(saved.ownerAvatar, 'lan_anh');
    expect(saved.phase, DayPhase.market);
    expect(saved.stock, isEmpty);
    expect(presetAvatarIds, hasLength(12));
    expect(presetAvatarIds, contains('lan_anh'));
  });

  test('a new game keeps the music switch and avatar', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing);
    s.setMusic(false);
    s.setSfx(false);
    s.setOwnerAvatar('ha_my');
    s.startNewGame();
    await s.pendingSaves;
    final saved = GameState.decode(backing[ProgressStore.storageKey])!;
    expect(saved.musicOn, isFalse);
    expect(saved.sfxOn, isFalse);
    expect(saved.ownerAvatar, 'ha_my');
    expect(saved.day, 1);
  });
}
