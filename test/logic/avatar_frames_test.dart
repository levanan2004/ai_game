import 'package:ai_game/data/avatar_frames.dart';
import 'package:ai_game/data/firestore_avatar_frames.dart' show readOwnedFrames;
import 'package:ai_game/data/firestore_world_chat.dart' show readChatMessage;
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Khung avatar (spec 3): frames and how they open come from economy.json
/// (avatarFrames + vip.tiers[].frame); what a player wears is decided by the
/// server (functions/avatar_frames.js), the app only shows it.
void main() {
  final e = loadTestData().economy;

  test('economy.json: the 8 frames, VIP levels from vip.tiers', () {
    final c = e.avatarFrames;
    expect(c.frames.map((f) => f.id), [
      'la_non',
      'hoa_dao',
      'vip_la_xanh',
      'vip_hoa_dao',
      'vip_bac',
      'vip_vang',
      'vip_ngoc_luc_bao',
      'vuong_mien_mua',
    ]);
    expect(
      {
        for (final f in c.frames)
          if (f.source == FrameOrigin.vip) f.id: f.vipLevel,
      },
      {
        'vip_la_xanh': 1,
        'vip_hoa_dao': 3,
        'vip_bac': 5,
        'vip_vang': 7,
        'vip_ngoc_luc_bao': 9,
      },
    );
    expect(c.byId('hoa_dao')!.event, 'Tết');
    expect(c.byId('vuong_mien_mua')!.maxRank, 3);
    expect(c.byId('la_non')!.source, FrameOrigin.standard);
  });

  test('owned: the same rule as the server', () {
    final c = e.avatarFrames;
    expect(c.ownedBy(), {'la_non'});
    expect(c.ownedBy(vipLevel: 4), {'la_non', 'vip_la_xanh', 'vip_hoa_dao'});
    expect(c.ownedBy(granted: {'vuong_mien_mua'}), {'la_non', 'vuong_mien_mua'});
  });

  test('controller: owned, equip through the server, other players cached', () async {
    var clock = DateTime(2026, 10, 17, 9);
    final src = MemoryAvatarFrames(e.avatarFrames, worn: {'u2': 'la_non'});
    final s = newSession(avatarFrames: src, now: () => clock);
    final f = s.frames;
    expect(f.offered, isTrue);
    expect(f.owned, isEmpty, reason: 'a guest owns nothing');
    s.accountUid = 'me';
    expect(f.owned, {'la_non'}, reason: 'the default before the server answers');
    await f.refresh();
    expect(f.loaded, isTrue);
    expect(f.equipped, '');

    expect(await f.equip('vip_vang'), FrameEquipResult.notOwned);
    expect(f.equipped, '');
    expect(await f.equip('la_non'), FrameEquipResult.done);
    expect(f.equipped, 'la_non');
    expect(f.frameOf('me'), 'la_non');

    src.vipLevel = 7;
    await f.refresh();
    expect(f.owned, contains('vip_vang'));

    await f.prefetch(['u2', 'u3', 'me']);
    expect(f.frameOf('u2'), 'la_non');
    expect(f.frameOf('u3'), '');
    expect(src.framesReads, 1);
    await f.prefetch(['u2']);
    expect(src.framesReads, 1, reason: 'cached for 15 minutes');
    src.worn['u2'] = 'khung_gia';
    clock = clock.add(const Duration(minutes: 16));
    await f.prefetch(['u2']);
    expect(src.framesReads, 2);
    expect(f.frameOf('u2'), '', reason: 'an id economy.json does not list');

    src.fail = true;
    expect(await f.equip('la_non'), FrameEquipResult.failed);

    f.reset();
    expect(f.loaded, isFalse);
    expect(f.equipped, '');
  });

  test('picker state and no source: nothing offered', () async {
    final s = newSession();
    expect(s.frames.offered, isFalse);
    s.frames.openPicker();
    expect(s.frames.pickerOpen, isFalse);

    final s2 = newSession(avatarFrames: MemoryAvatarFrames(e.avatarFrames));
    s2.frames.openPicker();
    expect(s2.frames.pickerOpen, isFalse, reason: 'guests have no frames');
    s2.accountUid = 'me';
    s2.frames.openPicker();
    expect(s2.frames.pickerOpen, isTrue);
    expect(s2.frames.selected, 'la_non');
    s2.frames.select('vip_bac');
    expect(s2.frames.selected, 'vip_bac');
    s2.frames.select('nope');
    expect(s2.frames.selected, 'vip_bac');
    s2.frames.closePicker();
    expect(s2.frames.pickerOpen, isFalse);
  });

  test('wire formats: avatarFrameList answer, a chat message frame', () {
    final o = readOwnedFrames({
      'owned': ['la_non', 3, 'vip_bac'],
      'equipped': 'la_non',
      'vipLevel': 5,
    });
    expect(o.owned, {'la_non', 'vip_bac'});
    expect(o.equipped, 'la_non');
    expect(o.vipLevel, 5);
    expect(readOwnedFrames(const {}).owned, isEmpty);
    final m = readChatMessage('m1', {
      'uid': 'u',
      'text': 'hi',
      'seq': 1,
      'frame': 'la_non',
    })!;
    expect(m.frame, 'la_non');
    expect(readChatMessage('m2', {'uid': 'u', 'text': 'hi', 'seq': 2})!.frame, '');
  });
}
