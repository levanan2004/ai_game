import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/avatar_jpeg.dart';
import 'package:ai_game/logic/cloud_merge.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

import '../helpers.dart';

GameState _day(int day) {
  final state = newSession().state;
  state.day = day;
  return state;
}

class _MemoryAccount extends OfflineAccount {
  _MemoryAccount(this.cloud);

  GameState? cloud;
  var pushed = 0;
  var pulls = 0;

  @override
  Future<CloudRecord?> pull() async {
    pulls++;
    final saved = cloud;
    if (saved == null) return null;
    return CloudRecord(state: saved, updatedAt: DateTime.utc(2026, 1, 2));
  }

  @override
  Future<void> push(GameState state) async {
    pushed++;
    cloud = GameState.decode(state.encode());
  }

  @override
  Future<AccountProfile?> signIn() async {
    return const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');
  }
}

void main() {
  test('the further day wins; a tie keeps the local save', () {
    final local = _day(3);
    final cloud = _day(5);
    final further = CloudMerge.decide(
      local: local,
      hasLocalSave: true,
      cloud: cloud,
    );
    expect(further.useCloud, isTrue);
    expect(further.pushLocal, isFalse);

    final behind = CloudMerge.decide(
      local: _day(8),
      hasLocalSave: true,
      cloud: _day(4),
    );
    expect(behind.useCloud, isFalse);
    expect(behind.pushLocal, isTrue);

    final tie = CloudMerge.decide(
      local: _day(4),
      hasLocalSave: true,
      cloud: _day(4),
    );
    expect(tie.useCloud, isFalse);
    expect(tie.pushLocal, isTrue);

    final emptyCloud = CloudMerge.decide(
      local: local,
      hasLocalSave: true,
      cloud: null,
    );
    expect(emptyCloud.pushLocal, isTrue);

    final onlyCloud = CloudMerge.decide(
      local: local,
      hasLocalSave: false,
      cloud: cloud,
    );
    expect(onlyCloud.useCloud, isTrue);
    expect(onlyCloud.pushLocal, isFalse);
  });

  test('signing in uploads a local save when the cloud is empty', () async {
    final account = _MemoryAccount(null);
    final s = newSession(account: account);
    s.startNewGame();
    await s.pendingSaves;
    expect(s.state.day, 1);
    await s.signIn();
    expect(s.signedIn, isTrue);
    expect(s.accountEmail, 'an@example.com');
    expect(account.pushed, 1);
    expect(account.cloud!.day, 1);
    expect(s.lastSavedAt, isNotNull);
  });

  test('signing in adopts a cloud save that is further along', () async {
    final cloud = _day(6);
    cloud.shopName = 'Hoa Ơi';
    final account = _MemoryAccount(cloud);
    final s = newSession(account: account);
    s.startNewGame();
    await s.pendingSaves;
    expect(s.state.day, 1);
    await s.signIn();
    expect(s.state.day, 6);
    expect(s.state.shopName, 'Hoa Ơi');
    expect(s.screen, Screen.title);
    expect(account.pushed, 0);
  });

  test('a failed cloud pull leaves the local game alone', () async {
    final s = newSession(account: _ThrowingAccount());
    s.startNewGame();
    await s.pendingSaves;
    final day = s.state.day;
    await s.signIn();
    expect(s.authError, 'Chưa đăng nhập được, thử lại nhé');
    expect(s.signedIn, isFalse);
    expect(s.state.day, day);
  });

  test('avatar upload is a 256 jpeg under 512KB', () {
    final src = im.Image(width: 400, height: 180);
    im.fill(src, color: im.ColorRgb8(200, 80, 90));
    final jpeg = squareAvatarJpeg(im.encodePng(src));
    expect(jpeg, isNotNull);
    expect(jpeg!.length, lessThan(512 * 1024));
    final back = im.decodeJpg(jpeg)!;
    expect(back.width, 256);
    expect(back.height, 256);
  });
}

class _ThrowingAccount extends OfflineAccount {
  @override
  Future<AccountProfile?> signIn() async {
    throw StateError('offline');
  }
}
