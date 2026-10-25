import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/avatar_frames.dart';
import '../data/charm_board.dart';
import '../data/chat_frames.dart';
import '../data/skins.dart' show SkinDef, skinAvatarFrameSlot;
import '../data/titles.dart';
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
  const PublicProfile({this.day, this.entry, this.titles = PlayerTitles.empty});

  /// "Ngày thứ {n}" (public_profiles/{uid}.day); null when unknown.
  final int? day;

  /// Their Mị lực board row this season (charm, pet, worn items), if any.
  final CharmBoardEntry? entry;

  /// Champion titles held now or before, the pin and best ranks
  /// (public_profiles + titles/, functions/titles.js).
  final PlayerTitles titles;
}

/// What titlePin answered.
enum TitlePinResult { done, notHeld, failed }

enum FrameEquipResult { done, notOwned, failed }

/// The player's khung tin nhắn as player_avatars/{uid} holds it
/// (functions/chat_frames.js): the one chosen, the last non-title one (a
/// lost title frame goes back to it) and the title whose frame was just
/// taken off ('' none).
@immutable
class ChatFrameChoice {
  const ChatFrameChoice({
    this.chosen = '',
    this.base = '',
    this.lostTitle = '',
  });

  static ChatFrameChoice fromMap(Map<String, dynamic>? d) {
    String s(String k) => d != null && d[k] is String ? d[k] as String : '';
    return ChatFrameChoice(
      chosen: s('chatFrame'),
      base: s('chatFrameBase'),
      lostTitle: s('chatFrameLost'),
    );
  }

  final String chosen;
  final String base;
  final String lostTitle;
}

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

  /// Callable titlePin: wears [titleId] ('' takes it off). Only a title the
  /// player holds now can be worn (the server checks).
  Future<TitlePinResult> pinTitle(String titleId);

  /// The signed-in player's khung tin nhắn (player_avatars/{uid}).
  Future<ChatFrameChoice> chatFrame();

  /// Callable chatFrameEquip: the server checks VIP max / the title held.
  Future<FrameEquipResult> equipChatFrame(String frameId);
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
    Set<String>? skins,
  }) : granted = granted ?? {},
       skins = skins ?? {},
       worn = worn ?? {},
       vips = vips ?? {},
       profiles = profiles ?? {};

  final AvatarFramesConfig config;
  int vipLevel;
  final Set<String> granted;

  /// Skin frames the wallet/save holds (functions/avatar_frames.js).
  final Set<String> skins;

  /// uid -> frame, as player_avatars would hold it.
  final Map<String, String> worn;

  /// uid -> public VIP tier (player_avatars.vip).
  final Map<String, int> vips;
  final Map<String, PublicProfile> profiles;

  /// The signed-in player of this fake.
  String me = 'me';

  /// The khung tin nhắn of [me]; [vipMax] / [holding] are what the server
  /// would check.
  ChatFrameChoice chat = const ChatFrameChoice();
  int vipMax = 0;
  Set<String> holding = {};
  ChatFramesConfig? chatConfig;
  bool fail = false;
  int framesReads = 0;

  Set<String> get _owned =>
      config.ownedBy(vipLevel: vipLevel, granted: granted, skins: skins);

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
  Future<ChatFrameChoice> chatFrame() async {
    if (fail) throw StateError('offline');
    return chat;
  }

  @override
  Future<FrameEquipResult> equipChatFrame(String frameId) async {
    if (fail) return FrameEquipResult.failed;
    final f = chatConfig?.byId(frameId);
    if (f == null ||
        f.vip > vipMax ||
        (f.title.isNotEmpty && !holding.contains(f.title))) {
      return FrameEquipResult.notOwned;
    }
    chat = ChatFrameChoice(
      chosen: frameId,
      base: f.title.isEmpty ? frameId : chat.base,
    );
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

  /// The pins sent, in order.
  final List<String> pins = [];

  @override
  Future<TitlePinResult> pinTitle(String titleId) async {
    if (fail) return TitlePinResult.failed;
    final p = profiles[me] ?? const PublicProfile();
    if (titleId.isNotEmpty && !p.titles.holds(titleId)) {
      return TitlePinResult.notHeld;
    }
    pins.add(titleId);
    final t = p.titles;
    profiles[me] = PublicProfile(
      day: p.day,
      entry: p.entry,
      titles: t.withPin(titleId),
    );
    return TitlePinResult.done;
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

  /// economy.json avatarFrames followed by the khungAvatar skins (one
  /// frame worn at a time: a skin frame and a VIP / season / event frame
  /// share player_avatars.frame, wearing one takes the other off).
  AvatarFramesConfig get config => _s.e.avatarFrames.withSkins({
    for (final k in _s.skins.ofSlot(skinAvatarFrameSlot)) k.id: k.tier,
  });

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
      : {
          ...(loaded ? _mine.owned : config.ownedBy()),
          // A skin frame just bought here shows as owned before the server
          // is asked again.
          for (final k in _s.skins.ofSlot(skinAvatarFrameSlot))
            if (_s.skinHas(k.id)) k.id,
        };

  /// The skin behind a skin frame (null for the other frames).
  SkinDef? skinOf(String frameId) {
    final f = config.byId(frameId);
    return f?.source == FrameOrigin.skin ? _s.skins.byId(frameId) : null;
  }

  /// Buys skin frame [id] in the skin shop way (xu in the save, Pha lê on
  /// the server), then asks the server what is owned again.
  Future<bool> buyFrame(String id) async {
    if (skinOf(id) == null || busy) return false;
    busy = true;
    notifyListeners();
    final ok = await _s.buySkin(id);
    busy = false;
    notifyListeners();
    if (ok) await refresh();
    return ok;
  }

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
    } catch (_) {
      return;
    }
    await _wearSavedSkinFrame();
  }

  /// A save from before the frame moved to the avatar keeps its worn
  /// khung_chau frame as equippedSkins.khungAvatar (migrated): when nothing
  /// is worn yet, it is put on once through the server, then dropped from
  /// the save so taking it off later sticks.
  Future<void> _wearSavedSkinFrame() async {
    final id = _s.state.equippedSkins[skinAvatarFrameSlot];
    if (id == null) return;
    final def = _s.skins.byId(id);
    if (_mine.equipped.isNotEmpty || def == null || def.isDefault) {
      _s.state.equippedSkins.remove(skinAvatarFrameSlot);
      return;
    }
    if (!owned.contains(id)) return;
    if (await equip(id) == FrameEquipResult.done) {
      _s.state.equippedSkins.remove(skinAvatarFrameSlot);
    }
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

  // ---- Khung tin nhắn ------------------------------------------------------

  ChatFramesConfig get chatConfig => _s.e.chatFrames;

  /// Offered online (signed in) with a `chatBubbleFrames` block.
  bool get chatOffered =>
      source != null && _s.signedIn && chatConfig.frames.isNotEmpty;

  ChatFrameChoice chat = const ChatFrameChoice();

  /// Reads player_avatars/{me}'s chat frame (own profile card).
  Future<void> refreshChat() async {
    final src = source;
    if (src == null || !_s.signedIn) return;
    try {
      chat = await src.chatFrame();
      notifyListeners();
    } catch (_) {}
  }

  /// "Dùng khung này" for a chat frame: the server checks and writes it.
  Future<FrameEquipResult> equipChat(String id) async {
    final src = source;
    if (src == null || busy || !_s.signedIn) return FrameEquipResult.failed;
    busy = true;
    notifyListeners();
    FrameEquipResult r;
    try {
      r = await src.equipChatFrame(id);
    } catch (_) {
      r = FrameEquipResult.failed;
    }
    if (r == FrameEquipResult.done) {
      final f = chatConfig.byId(id);
      chat = ChatFrameChoice(
        chosen: id,
        base: f != null && f.title.isEmpty ? id : chat.base,
      );
    }
    busy = false;
    notifyListeners();
    return r;
  }

  /// Wears [titleId] ('' none) through titlePin; failed when offline.
  Future<TitlePinResult> pinTitle(String titleId) async {
    final src = source;
    if (src == null) return TitlePinResult.failed;
    try {
      return await src.pinTitle(titleId);
    } catch (_) {
      return TitlePinResult.failed;
    }
  }
}
