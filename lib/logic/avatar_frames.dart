import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/avatar_frames.dart';
import '../data/charm_board.dart';
import 'shop_session.dart';

/// What the server says this player may wear (functions/avatar_frames.js
/// `list`).
class OwnedFrames {
  const OwnedFrames({
    this.owned = const {},
    this.equipped = '',
    this.vipLevel = 0,
  });

  final Set<String> owned;
  final String equipped;
  final int vipLevel;
}

/// The public facts of another player's profile card (spec 6).
class PublicProfile {
  const PublicProfile({this.day, this.entry});

  /// "Ngày thứ {n}" (public_profiles/{uid}.day); null when unknown.
  final int? day;

  /// Their Mị lực board row this season (charm, pet, worn items), if any.
  final CharmBoardEntry? entry;
}

enum FrameEquipResult { done, notOwned, failed }

/// What player_avatars/{uid} shows of a player besides the portrait: the
/// frame worn and the public VIP tier (both server-written).
@immutable
class PlayerLook {
  const PlayerLook({this.frame = '', this.vip = 0});

  final String frame;

  /// 0 none, 1..10 (functions/vip.js).
  final int vip;
}

/// Where frames live: the callables avatarFrameList / avatarFrameEquip, the
/// public player_avatars/{uid}.frame (server-written), public_profiles.
abstract class AvatarFrameSource {
  Future<OwnedFrames> owned();
  Future<FrameEquipResult> equip(String frameId);

  /// The frame each of [uids] wears and their VIP tier. Missing uids: none.
  Future<Map<String, PlayerLook>> looksOf(List<String> uids);

  Future<PublicProfile> profile(String uid, {required String period});
}

/// In memory, with the server's ownership rule (tests, offline).
class MemoryAvatarFrames implements AvatarFrameSource {
  MemoryAvatarFrames(
    this.config, {
    this.vipLevel = 0,
    Set<String>? granted,
    Map<String, String>? worn,
    Map<String, int>? vips,
    Map<String, PublicProfile>? profiles,
  }) : granted = granted ?? {},
       worn = worn ?? {},
       vips = vips ?? {},
       profiles = profiles ?? {};

  final AvatarFramesConfig config;
  int vipLevel;
  final Set<String> granted;

  /// uid -> frame, as player_avatars would hold it.
  final Map<String, String> worn;

  /// uid -> public VIP tier (player_avatars.vip).
  final Map<String, int> vips;
  final Map<String, PublicProfile> profiles;

  /// The signed-in player of this fake.
  String me = 'me';
  bool fail = false;
  int framesReads = 0;

  Set<String> get _owned =>
      config.ownedBy(vipLevel: vipLevel, granted: granted);

  @override
  Future<OwnedFrames> owned() async {
    if (fail) throw StateError('offline');
    final w = worn[me] ?? '';
    return OwnedFrames(
      owned: _owned,
      equipped: _owned.contains(w) ? w : '',
      vipLevel: vipLevel,
    );
  }

  @override
  Future<FrameEquipResult> equip(String frameId) async {
    if (fail) return FrameEquipResult.failed;
    if (frameId.isNotEmpty && !_owned.contains(frameId)) {
      return FrameEquipResult.notOwned;
    }
    worn[me] = frameId;
    return FrameEquipResult.done;
  }

  @override
  Future<Map<String, PlayerLook>> looksOf(List<String> uids) async {
    if (fail) throw StateError('offline');
    framesReads++;
    return {
      for (final u in uids)
        u: PlayerLook(frame: worn[u] ?? '', vip: vips[u] ?? 0),
    };
  }

  @override
  Future<PublicProfile> profile(String uid, {required String period}) async {
    if (fail) throw StateError('offline');
    return profiles[uid] ?? const PublicProfile();
  }
}

/// Khung avatar for the session: what this player owns and wears, the
/// frames other players wear (read from the server, cached), and the picker
/// sheet (F1).
class AvatarFramesController extends ChangeNotifier {
  AvatarFramesController(this._s, {this.source, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ShopSession _s;
  final AvatarFrameSource? source;
  final DateTime Function() _now;

  /// Other players' frames are read again after this long.
  static const cacheFor = Duration(minutes: 15);

  AvatarFramesConfig get config => _s.e.avatarFrames;

  /// Frames are offered online (signed in) with an `avatarFrames` block.
  bool get offered => source != null && config.frames.isNotEmpty;

  OwnedFrames _mine = const OwnedFrames();
  bool loaded = false;
  bool busy = false;

  /// The F1 sheet ("Khung avatar").
  bool pickerOpen = false;

  /// The frame selected in the sheet (not worn until "Dùng khung này").
  String selected = '';

  final Map<String, ({PlayerLook look, DateTime at})> _cache = {};

  int get vipLevel => _mine.vipLevel;

  /// What this player may wear: the server's answer, or (before it came)
  /// the default frames every signed-in player has.
  Set<String> get owned => !_s.signedIn
      ? const {}
      : loaded
      ? _mine.owned
      : config.ownedBy();

  String get equipped => _s.signedIn ? _mine.equipped : '';

  /// The frame [uid] wears ('' none or not read yet). Own uid: [equipped].
  String frameOf(String uid) {
    if (uid.isEmpty) return '';
    if (uid == _s.accountUid) return equipped;
    final id = _cache[uid]?.look.frame ?? '';
    return config.byId(id) == null ? '' : id;
  }

  /// The public VIP tier of [uid] (0 none or not read yet). Own uid: the
  /// server wallet's.
  int vipOf(String uid) {
    if (uid.isEmpty) return 0;
    if (uid == _s.accountUid) return _s.vip.shownLevel;
    return _cache[uid]?.look.vip ?? 0;
  }

  /// Reads the frames and VIP tiers of [uids] not read in the last
  /// [cacheFor].
  Future<void> prefetch(Iterable<String> uids) async {
    final src = source;
    if (src == null || (config.frames.isEmpty && !_s.vip.offered)) return;
    final now = _now();
    final want = [
      for (final u in uids.toSet())
        if (u.isNotEmpty &&
            u != _s.accountUid &&
            (_cache[u] == null || now.difference(_cache[u]!.at) > cacheFor))
          u,
    ];
    if (want.isEmpty) return;
    try {
      final got = await src.looksOf(want);
      for (final u in want) {
        _cache[u] = (look: got[u] ?? const PlayerLook(), at: now);
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Asks the server what this player owns and wears (on sign-in and when
  /// the sheet opens).
  Future<void> refresh() async {
    final src = source;
    if (src == null || !_s.signedIn) return;
    try {
      _mine = await src.owned();
      loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  void openPicker() {
    if (!offered || !_s.signedIn) return;
    pickerOpen = true;
    selected = equipped.isNotEmpty
        ? equipped
        : (config.frames.isEmpty ? '' : config.frames.first.id);
    notifyListeners();
    unawaited(refresh());
  }

  void closePicker() {
    if (!pickerOpen) return;
    pickerOpen = false;
    notifyListeners();
  }

  void select(String id) {
    if (config.byId(id) == null) return;
    selected = id;
    notifyListeners();
  }

  /// "Dùng khung này": the server checks ownership and writes it.
  Future<FrameEquipResult> equip(String id) async {
    final src = source;
    if (src == null || busy || !_s.signedIn) return FrameEquipResult.failed;
    busy = true;
    notifyListeners();
    FrameEquipResult r;
    try {
      r = await src.equip(id);
    } catch (_) {
      r = FrameEquipResult.failed;
    }
    if (r == FrameEquipResult.done) {
      _mine = OwnedFrames(owned: owned, equipped: id, vipLevel: _mine.vipLevel);
    } else if (r == FrameEquipResult.notOwned) {
      unawaited(refresh());
    }
    busy = false;
    notifyListeners();
    return r;
  }

  /// Signed out: forget what this player owned.
  void reset() {
    _mine = const OwnedFrames();
    loaded = false;
    pickerOpen = false;
    notifyListeners();
  }

  Future<PublicProfile?> profile(String uid) async {
    final src = source;
    if (src == null) return null;
    try {
      return await src.profile(uid, period: _s.board.period);
    } catch (_) {
      return null;
    }
  }
}
