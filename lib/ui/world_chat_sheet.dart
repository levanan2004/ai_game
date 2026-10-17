import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/shop_session.dart';
import '../logic/world_chat.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'player_avatar.dart';
import 'vip_badge.dart';
import 'profile_card.dart';
import 'world_chat_text.dart';
import 'chat_bubble.dart';

/// Tin thế giới, Phú's layout C1 (spec 5.3): header 52, the newest messages
/// (newest at the bottom), input row 68. Text: Nhất (world_chat_text.dart).
class WorldChatSheet extends StatefulWidget {
  const WorldChatSheet({super.key, required this.session});

  final ShopSession session;

  static const headerHeight = 52.0;
  static const inputHeight = 68.0;
  static const fieldHeight = 44.0;
  static const sendSize = 44.0;
  static const avatarSize = 28.0;
  static const bubbleRadius = 12.0;

  @override
  State<WorldChatSheet> createState() => _WorldChatSheetState();
}

enum _Layer { none, menu, profile, report, thanks, block, unblock }

class _WorldChatSheetState extends State<WorldChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _tick;
  var _shake = 0;
  var _layer = _Layer.none;
  ChatMessage? _target;
  String? _unblockUid;
  ChatReportReason? _reason;
  final _note = TextEditingController();
  var _reportBusy = false;
  var _atBottom = true;
  var _lastSeq = 0;
  var _newBelow = false;
  var _rulesChecked = false;

  WorldChatController get _c => widget.session.chat;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // reverse list: offset 0 is the newest message
      final bottom = !_scroll.hasClients || _scroll.offset < 40;
      if (bottom != _atBottom) {
        setState(() {
          _atBottom = bottom;
          if (bottom) _newBelow = false;
        });
      }
    });
    _input.addListener(() {
      if (_c.inputError != null) _c.inputError = null;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _input.dispose();
    _note.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _armTick() {
    if (_tick != null) return;
    _tick = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) return;
      if (_c.cooldownLeft <= 0) {
        t.cancel();
        _tick = null;
      }
      setState(() {});
    });
  }

  Future<void> _send() async {
    final before = _c.inputError;
    final clear = await _c.send(_input.text);
    if (!mounted) return;
    if (clear) {
      _input.clear();
      if (_c.maskedNotice) {
        _c.maskedNotice = false;
        showGameToast(context, ChatText.masked);
      }
    } else if (_c.inputError != null && _c.inputError != before ||
        _c.inputError == 'blocked' ||
        _c.inputError == 'blocked_link') {
      setState(() => _shake++);
    }
    _armTick();
    setState(() {});
  }

  void _openMenu(ChatMessage m) {
    if (_c.isOwn(m)) return;
    setState(() {
      _target = m;
      _layer = _Layer.menu;
    });
  }

  /// "Xem hồ sơ": the profile card (spec 6) of the message's sender.
  void _openProfile(ChatMessage m) {
    if (_c.isOwn(m)) return;
    setState(() {
      _target = m;
      _layer = _Layer.profile;
    });
  }

  void _close() => setState(() {
    _layer = _Layer.none;
    _reason = null;
    _note.clear();
  });

  Future<void> _sendReport() async {
    final m = _target;
    final reason = _reason;
    if (m == null || reason == null || _reportBusy) return;
    setState(() => _reportBusy = true);
    final res = await _c.report(m, reason, _note.text);
    if (!mounted) return;
    setState(() => _reportBusy = false);
    switch (res) {
      case ChatReportSend.sent:
        showGameToast(context, ChatText.reportSent);
        setState(() => _layer = _Layer.thanks);
      case ChatReportSend.already:
        showGameToast(context, ChatText.reportAlready);
        _close();
      case ChatReportSend.gone:
        showGameToast(context, ChatText.reportDeleted);
        _close();
      case ChatReportSend.failed:
        showGameToast(context, ChatText.reportFail, error: true);
    }
  }

  Future<void> _block() async {
    final m = _target;
    if (m == null) return;
    if (m.official) {
      showGameToast(context, ChatText.blockOfficial);
      return _close();
    }
    if (_c.isOwn(m)) {
      showGameToast(context, ChatText.blockSelf);
      return _close();
    }
    final ok = await _c.block(m);
    if (!mounted) return;
    if (ok) showGameToast(context, ChatText.blocked1(m.name));
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c, widget.session.board]),
      builder: (context, _) {
        final list = _c.visible;
        if (list.isNotEmpty) {
          final last = list.last.seq;
          if (last > _lastSeq && _lastSeq != 0 && !_atBottom) _newBelow = true;
          _lastSeq = math.max(_lastSeq, last);
        }
        if (_c.cooldownLeft > 0) _armTick();
        final inset = MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0;
        return Material(
          key: const Key('world-chat'),
          color: AppColors.bgBase,
          child: Stack(
            children: [
              Positioned.fill(
                bottom: inset,
                child: Column(
                  children: [
                    _header(),
                    Expanded(child: _body(list)),
                    _inputArea(),
                  ],
                ),
              ),
              if (_newBelow)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: inset + WorldChatSheet.inputHeight + 8,
                  child: Center(
                    child: GestureDetector(
                      key: const Key('world-chat-new'),
                      onTap: () {
                        setState(() => _newBelow = false);
                        if (_scroll.hasClients) {
                          _scroll.animateTo(
                            0,
                            duration: AppMotion.base,
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBase,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          ChatText.newMessages,
                          style: AppText.body(
                            size: 13,
                            weight: 800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // The blocked list draws its own unblock confirm on top.
              if (_layer != _Layer.none && !_c.blockedListOpen)
                Positioned.fill(child: _overlay()),
              if (_c.rulesOpen) Positioned.fill(child: _rulesSheet()),
              if (_c.blockedListOpen) Positioned.fill(child: _blockedList()),
              if (!_c.rulesAccepted &&
                  !_c.blockedListOpen &&
                  !_c.rulesOpen &&
                  widget.session.signedIn)
                Positioned.fill(child: _rulesPopup()),
            ],
          ),
        );
      },
    );
  }

  Widget _header() => SizedBox(
    height: WorldChatSheet.headerHeight,
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            key: const Key('world-chat-back'),
            onPressed: _c.close,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: ChatText.title,
              style: AppText.title(size: 18),
              children: [
                TextSpan(
                  text: ' · ${ChatText.caption}',
                  style: AppText.caption(),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          key: const Key('world-chat-rules'),
          onPressed: _c.openRules,
          icon: const Icon(Icons.more_horiz, size: 18),
          label: Text(ChatText.rulesBtn, style: AppText.caption(size: 12)),
        ),
      ],
    ),
  );

  Widget _body(List<ChatMessage> list) {
    if (_c.load == ChatLoad.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ChatText.loadFail, style: AppText.body()),
            const SizedBox(height: 8),
            SizedBox(
              width: 140,
              height: 44,
              child: ChunkyButton(
                key: const Key('world-chat-retry'),
                label: ChatText.loadFailBtn,
                onPressed: _c.retryLoad,
              ),
            ),
          ],
        ),
      );
    }
    if (_c.load != ChatLoad.ready) {
      return Center(child: Text(ChatText.loading, style: AppText.caption()));
    }
    if (!_c.enabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            ChatText.disabled,
            key: const Key('world-chat-disabled'),
            style: AppText.body(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final pending = _c.pending;
    if (list.isEmpty && pending.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ChatText.emptyTitle, style: AppText.title(size: 18)),
              const SizedBox(height: 4),
              Text(
                ChatText.emptyBody,
                key: const Key('world-chat-empty'),
                style: AppText.body(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    // Newest first in a reversed list = newest at the bottom.
    final rows = <Widget>[
      for (final p in pending.reversed) _pendingRow(p),
      for (final m in list.reversed) _row(m),
      if (_c.someBlocked)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            ChatText.someBlocked,
            style: AppText.caption(size: 11),
            textAlign: TextAlign.center,
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          ChatText.limitNote,
          style: AppText.caption(size: 11),
          textAlign: TextAlign.center,
        ),
      ),
    ];
    return ListView(
      key: const Key('world-chat-list'),
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: rows,
    );
  }

  String _ago(DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return ChatText.minutes(math.max(1, d.inMinutes));
    final l = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  /// Phú's khung tin nhắn, as the server stamped it ([frameId] '' = thường).
  Widget _bubble(
    String text, {
    required bool own,
    String frameId = '',
    double opacity = 1,
  }) => Opacity(
    opacity: opacity,
    child: ChatBubble(frameId: frameId, text: text, own: own),
  );

  Widget _row(ChatMessage m) {
    final own = _c.isOwn(m);
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // VIP colour and 16 dp badge right after the name (spec 4.3), as
        // the server stamped them on the message.
        Flexible(
          child: VipName(
            name: m.name,
            level: m.vip,
            style: AppText.body(size: 12, weight: 800),
            badgeSize: 16,
            badgeKey: Key('world-chat-vip-${m.id}'),
          ),
        ),
        if (m.official) ...[
          const SizedBox(width: 4),
          Container(
            key: Key('world-chat-official-${m.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryBase,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ChatText.official,
              style: AppText.caption(size: 10, color: AppColors.onPrimary),
            ),
          ),
        ],
        Text(' · ${_ago(m.createdAt)}', style: AppText.caption(size: 11)),
      ],
    );
    final content = Column(
      crossAxisAlignment: own
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        meta,
        // "Chủ Tiệm Ngọc" on the sender line of a VIP 10 (spec 4.5).
        if (m.vip >= 10)
          VipTitleLine(
            key: Key('world-chat-vip-title-${m.id}'),
            level: 10,
            size: 10,
          ),
        const SizedBox(height: 2),
        _bubble(m.text, own: own, frameId: m.bubble),
      ],
    );
    return Padding(
      key: Key('world-chat-msg-${m.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: own ? null : () => _openMenu(m),
        child: Row(
          mainAxisAlignment: own
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!own) ...[
              GestureDetector(
                key: Key('world-chat-avatar-${m.id}'),
                onTap: () => _openProfile(m),
                child: PlayerAvatar(
                  avatar: m.avatar,
                  name: m.name,
                  radius: WorldChatSheet.avatarSize / 2,
                  // Stamped by the server when it was sent (player_avatars).
                  frameId: m.frame,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(child: content),
            if (!own)
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: Key('world-chat-more-${m.id}'),
                  onPressed: () => _openMenu(m),
                  icon: const Icon(Icons.more_horiz, size: 18),
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pendingRow(PendingChat p) => Padding(
    key: Key('world-chat-pending-${p.localId}'),
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: p.failed ? () => _c.retry(p) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (p.failed)
                const Icon(Icons.error, size: 18, color: AppColors.statusDanger)
              else
                const Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              const SizedBox(width: 4),
              Flexible(
                child: _bubble(p.text, own: true, opacity: p.failed ? 1 : 0.6),
              ),
            ],
          ),
          if (p.failed)
            Text(
              ChatText.sendFail,
              key: Key('world-chat-failed-${p.localId}'),
              style: AppText.caption(size: 11, color: AppColors.statusDanger),
            ),
        ],
      ),
    ),
  );

  // -- input row (and what replaces it) ---------------------------------------

  Widget _inputArea() {
    final r = _c.rules;
    if (r == null) return const SizedBox.shrink();
    final lock = _c.lock;
    if (lock != ChatLock.none) return _locked(lock);
    final count = chatCharCount(_input.text);
    final over = count > r.maxChars;
    final wait = _c.cooldownLeft;
    final error = switch (_c.inputError) {
      null => null,
      'blocked' => ChatText.blocked,
      'blocked_link' => ChatText.blockedLink,
      'too_long' => ChatText.tooLong(r.maxChars),
      'empty' => ChatText.empty,
      'duplicate' => ChatText.duplicate,
      'locked_day' => ChatText.lockedDay(r.unlockDay, _c.daysLeft),
      _ => ChatText.sendFail,
    };
    final bad = error != null || over;
    final canSend = !over && wait == 0 && _input.text.trim().isNotEmpty;
    return Container(
      color: AppColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('shake-$_shake'),
                  tween: Tween(begin: _shake == 0 ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 360),
                  builder: (context, t, child) => Transform.translate(
                    offset: Offset(math.sin(t * math.pi * 6) * 6 * (1 - t), 0),
                    child: child,
                  ),
                  child: Container(
                    key: const Key('world-chat-field'),
                    height: WorldChatSheet.fieldHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: bad
                            ? AppColors.statusDanger
                            : Colors.transparent,
                        width: AppBorder.thin,
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('world-chat-input'),
                            controller: _input,
                            enabled: wait == 0,
                            maxLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => canSend ? _send() : null,
                            style: AppText.body(size: 14),
                            decoration: InputDecoration.collapsed(
                              hintText: wait > 0
                                  ? ChatText.cooldownPlaceholder(wait)
                                  : ChatText.placeholder,
                              hintStyle: AppText.body(
                                size: 14,
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          ChatText.counter(count, r.maxChars),
                          key: const Key('world-chat-counter'),
                          style: AppText.caption(
                            size: 11,
                            color: over
                                ? AppColors.statusDanger
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(canSend, wait, r.cooldownSeconds),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                key: const Key('world-chat-error'),
                style: AppText.caption(size: 11, color: AppColors.statusDanger),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sendButton(bool canSend, int wait, int total) => SizedBox(
    width: WorldChatSheet.sendSize,
    height: WorldChatSheet.sendSize,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Material(
          color: canSend ? AppColors.primaryBase : AppColors.textDisabled,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('world-chat-send'),
            customBorder: const CircleBorder(),
            onTap: canSend ? _send : null,
            child: SizedBox(
              width: WorldChatSheet.sendSize,
              height: WorldChatSheet.sendSize,
              child: Center(
                child: wait > 0
                    ? Text(
                        '$wait',
                        key: const Key('world-chat-cooldown'),
                        style: AppText.body(
                          size: 15,
                          weight: 800,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Semantics(
                        label: ChatText.send,
                        child: const Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: AppColors.onPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (wait > 0)
          IgnorePointer(
            child: SizedBox(
              width: WorldChatSheet.sendSize,
              height: WorldChatSheet.sendSize,
              child: CircularProgressIndicator(
                value: wait / total,
                strokeWidth: 3,
                color: AppColors.primaryBase,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _locked(ChatLock lock) {
    final r = _c.rules!;
    Widget card(String text, {Widget? leading, Widget? action, Key? key}) =>
        Container(
          key: key,
          height: WorldChatSheet.inputHeight,
          color: AppColors.surfaceCard,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Expanded(
                child: Text(
                  text,
                  style: AppText.body(size: 13, weight: 700),
                  maxLines: 2,
                ),
              ),
              ?action,
            ],
          ),
        );
    switch (lock) {
      case ChatLock.none || ChatLock.disabled:
        return card(ChatText.disabled, key: const Key('world-chat-lock-off'));
      case ChatLock.guest:
        return card(
          ChatText.guestLocked,
          key: const Key('world-chat-lock-guest'),
          action: SizedBox(
            width: 120,
            height: 44,
            child: ChunkyButton(
              key: const Key('world-chat-login'),
              label: ChatText.guestLogin,
              fontSize: 15,
              onPressed: () {
                _c.close();
                widget.session.signIn();
              },
            ),
          ),
        );
      case ChatLock.lockedDay:
        return card(
          ChatText.lockedDay(r.unlockDay, _c.daysLeft),
          key: const Key('world-chat-lock-day'),
          leading: ArtImage(Art.phucLoi('o_khoa'), size: 40),
        );
      case ChatLock.muted:
        final until = _c.muteState?.until;
        return card(
          until == null ? ChatText.banned : ChatText.muted(_left(until)),
          key: const Key('world-chat-lock-muted'),
        );
      case ChatLock.banned:
        return card(ChatText.banned, key: const Key('world-chat-lock-banned'));
    }
  }

  /// muted.time.*: minutes under an hour, hours under a day, then days.
  String _left(DateTime until) {
    final d = until.difference(DateTime.now());
    final mins = math.max(1, (d.inSeconds / 60).ceil());
    if (mins < 60) return ChatText.minutes(mins);
    if (mins < 1440) return ChatText.hours(mins ~/ 60, mins % 60);
    return ChatText.days(mins ~/ 1440, (mins % 1440) ~/ 60);
  }

  // -- overlays ----------------------------------------------------------------

  Widget _scrim({required Widget child, Key? key}) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _reportBusy ? null : _close,
    child: ColoredBox(
      color: AppColors.bgOverlay,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            key: key,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );

  Widget _menuItem(String label, Key key, VoidCallback onTap, {Color? color}) =>
      InkWell(
        key: key,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: AppText.body(size: 15, weight: 800, color: color),
            ),
          ),
        ),
      );

  Widget _overlay() {
    final m = _target;
    switch (_layer) {
      case _Layer.none:
        return const SizedBox.shrink();
      case _Layer.menu:
        if (m == null) return const SizedBox.shrink();
        return _scrim(
          key: const Key('world-chat-menu'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuItem(
                ChatText.menuProfile,
                const Key('world-chat-menu-profile'),
                () => setState(() => _layer = _Layer.profile),
              ),
              _menuItem(
                ChatText.menuCopy,
                const Key('world-chat-menu-copy'),
                () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  showGameToast(context, ChatText.copied);
                  _close();
                },
              ),
              _menuItem(
                ChatText.menuReport,
                const Key('world-chat-menu-report'),
                () => setState(() => _layer = _Layer.report),
              ),
              _menuItem(
                ChatText.menuBlock(m.name),
                const Key('world-chat-menu-block'),
                () => setState(() => _layer = _Layer.block),
                color: AppColors.statusDanger,
              ),
            ],
          ),
        );
      case _Layer.profile:
        if (m == null) return const SizedBox.shrink();
        return PlayerProfileCard(
          key: Key('world-chat-profile-${m.uid}'),
          session: widget.session,
          uid: m.uid,
          name: m.name,
          avatar: m.avatar,
          frameId: m.frame,
          vip: m.vip,
          official: m.official,
          onReport: () => setState(() => _layer = _Layer.report),
          onBlock: () => setState(() => _layer = _Layer.block),
          onUnblock: () => setState(() {
            _unblockUid = m.uid;
            _layer = _Layer.unblock;
          }),
          onClose: _close,
        );
      case _Layer.report:
        return _scrim(
          key: const Key('world-chat-report'),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ChatText.reportTitle, style: AppText.title(size: 18)),
                const SizedBox(height: 4),
                Text(ChatText.reportIntro, style: AppText.caption()),
                for (final r in ChatReportReason.values)
                  InkWell(
                    key: Key('world-chat-reason-${r.name}'),
                    onTap: () => setState(() => _reason = r),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Icon(
                            _reason == r
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: AppColors.primaryBase,
                          ),
                          const SizedBox(width: 8),
                          Text(r.label, style: AppText.body(size: 15)),
                        ],
                      ),
                    ),
                  ),
                TextField(
                  key: const Key('world-chat-report-note'),
                  controller: _note,
                  maxLength: _c.rules?.reportNoteMax,
                  decoration: InputDecoration(
                    hintText: ChatText.reportNoteHint,
                    hintStyle: AppText.caption(),
                  ),
                ),
                Text(ChatText.urgentHint, style: AppText.caption(size: 11)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ChunkyButton(
                          key: const Key('world-chat-report-cancel'),
                          label: ChatText.reportCancel,
                          kind: ButtonKind.secondary,
                          onPressed: _close,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ChunkyButton(
                          key: const Key('world-chat-report-send'),
                          label: ChatText.reportSend,
                          enabled: _reason != null && !_reportBusy,
                          onPressed: _sendReport,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case _Layer.thanks:
        if (m == null) return const SizedBox.shrink();
        return _confirm(
          key: const Key('world-chat-thanks'),
          title: ChatText.thanksTitle,
          body: ChatText.thanksBody(m.name),
          yes: ChatText.thanksBlock,
          no: ChatText.thanksClose,
          onYes: _block,
          danger: true,
        );
      case _Layer.block:
        if (m == null) return const SizedBox.shrink();
        return _confirm(
          key: const Key('world-chat-block'),
          title: ChatText.blockTitle(m.name),
          body: ChatText.blockBody,
          yes: ChatText.blockBtn,
          no: ChatText.blockCancel,
          onYes: _block,
          danger: true,
        );
      case _Layer.unblock:
        final uid = _unblockUid;
        final name = _c.blockedPlayers[uid] ?? '';
        return _confirm(
          key: const Key('world-chat-unblock'),
          title: ChatText.unblockTitle(name),
          body: ChatText.unblockBody,
          yes: ChatText.unblockBtn,
          no: ChatText.unblockCancel,
          onYes: () async {
            if (uid != null) await _c.unblock(uid);
            if (!mounted) return;
            showGameToast(context, ChatText.unblocked(name));
            _close();
          },
        );
    }
  }

  Widget _confirm({
    required Key key,
    required String title,
    required String body,
    required String yes,
    required String no,
    required VoidCallback onYes,
    bool danger = false,
  }) => _scrim(
    key: key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.title(size: 18)),
        const SizedBox(height: 6),
        Text(body, style: AppText.body()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ChunkyButton(
                  key: Key('${(key as ValueKey).value}-no'),
                  label: no,
                  kind: ButtonKind.secondary,
                  onPressed: _close,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ChunkyButton(
                  key: Key('${key.value}-yes'),
                  label: yes,
                  textColor: danger ? AppColors.textInverse : null,
                  onPressed: onYes,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _page({
    required Key key,
    required String title,
    required VoidCallback onBack,
    required List<Widget> children,
  }) => Material(
    key: key,
    color: AppColors.bgBase,
    child: Column(
      children: [
        SizedBox(
          height: WorldChatSheet.headerHeight,
          child: Row(
            children: [
              IconButton(
                key: Key('${(key as ValueKey).value}-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(child: Text(title, style: AppText.title(size: 18))),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: children,
          ),
        ),
      ],
    ),
  );

  Widget _rulesSheet() => _page(
    key: const Key('world-chat-rules-sheet'),
    title: ChatText.rulesTitle,
    onBack: _c.closeRules,
    children: [
      Text(ChatText.rulesIntro, style: AppText.body(weight: 700)),
      for (var i = 0; i < ChatText.rules.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${i + 1}. ${ChatText.rules[i]}', style: AppText.body()),
        ),
      const SizedBox(height: 12),
      Text(ChatText.rulesHelp, style: AppText.caption()),
    ],
  );

  Widget _blockedList() {
    final blocked = _c.blockedPlayers;
    return Stack(
      children: [
        Positioned.fill(
          child: _page(
            key: const Key('world-chat-blocked'),
            title: ChatText.blockedTitle,
            onBack: () {
              _c.closeBlockedList();
            },
            children: [
              Text(ChatText.blockedSubtitle, style: AppText.caption()),
              const SizedBox(height: 8),
              if (blocked.isEmpty)
                Text(
                  ChatText.blockedEmpty,
                  key: const Key('world-chat-blocked-empty'),
                  style: AppText.body(),
                )
              else ...[
                Text(
                  ChatText.blockedCount(blocked.length),
                  style: AppText.body(weight: 800),
                ),
                for (final e in blocked.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: CardBox(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.value,
                              style: AppText.body(weight: 800),
                            ),
                          ),
                          TextButton(
                            key: Key('world-chat-unblock-${e.key}'),
                            onPressed: () => setState(() {
                              _unblockUid = e.key;
                              _layer = _Layer.unblock;
                            }),
                            child: Text(ChatText.unblockBtn),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (_layer == _Layer.unblock) Positioned.fill(child: _overlay()),
      ],
    );
  }

  Widget _rulesPopup() => ColoredBox(
    color: AppColors.bgOverlay,
    child: Center(
      child: Container(
        key: const Key('world-chat-rules-popup'),
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ChatText.popupTitle, style: AppText.title(size: 18)),
            for (final l in ChatText.popupLines)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $l', style: AppText.body(size: 13)),
              ),
            TextButton(
              key: const Key('world-chat-rules-full'),
              onPressed: _c.openRules,
              child: Text(ChatText.popupFull),
            ),
            InkWell(
              key: const Key('world-chat-rules-check'),
              onTap: () => setState(() => _rulesChecked = !_rulesChecked),
              child: Row(
                children: [
                  Icon(
                    _rulesChecked
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: AppColors.primaryBase,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ChatText.popupCheck,
                      style: AppText.body(size: 13, weight: 700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ChunkyButton(
                      key: const Key('world-chat-rules-later'),
                      label: ChatText.popupCancel,
                      kind: ButtonKind.secondary,
                      onPressed: _c.close,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ChunkyButton(
                      key: const Key('world-chat-rules-ok'),
                      label: ChatText.popupConfirm,
                      enabled: _rulesChecked,
                      onPressed: _c.acceptRules,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
