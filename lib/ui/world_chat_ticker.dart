import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../logic/world_chat.dart';
import '../theme/tokens.dart';

/// Phú's Tin thế giới ticker on the main shop: right under the xu/Pha lê
/// bar, over the scene. 28 dp high, 12 dp from each side, radius 14,
/// #2E5E3D at 85%; a 16 dp speaker, then "**Tên tiệm**: tin" (name bold
/// #F2C94C, text #FFF8E7 13 sp) scrolling right to left with a 1 s pause
/// after each message. Tap opens the chat. 8 s with no new message: 40%.
/// No news at all: only the speaker, at 40% (Phú).
/// Hidden while the chat is off or open, and under any popup
/// ([tickerHiddenBy]); the table screen (wrapping a bouquet) never has it.
class WorldChatTicker extends StatefulWidget {
  const WorldChatTicker({
    super.key,
    required this.session,
    this.sheets = const [],
    this.sheetOpen,
    this.popupOpen = false,
  });

  final ShopSession session;

  /// Hộp thư / Phúc lợi feeds (game_root): hidden while [sheetOpen].
  final List<Listenable> sheets;
  final bool Function()? sheetOpen;

  /// A popup of the main shop itself is open (map, end day, pot hint...).
  final bool popupOpen;

  static const height = 28.0;
  static const margin = 12.0;

  /// What sits under the bar moves down this much while the ticker is on.
  static const push = 32.0;
  static const background = Color(0xD92E5E3D); // #2E5E3D at 85%
  static const textColor = Color(0xFFFFF8E7);
  static const nameColor = Color(0xFFF2C94C);
  static const iconSize = 16.0;
  static const pause = Duration(seconds: 1);
  static const fadeAfter = WorldChatController.tickerFadeAfter;
  static const faded = 0.4;

  /// Scroll speed (not in the spec; a calm reading pace).
  static const speed = 60.0; // dp per second

  /// The ticker shows with the chat on (it takes room), even with no news
  /// yet: then only the speaker, faded (Phú).
  static bool on(ShopSession s) => s.chat.offered && s.chat.enabled;

  @override
  State<WorldChatTicker> createState() => _WorldChatTickerState();
}

/// Session-wide layers that hide the ticker (popups, sheets, tutorial).
bool tickerHiddenBy(ShopSession s) =>
    s.chat.open ||
    s.currentPopup != null ||
    s.pauseMenuOpen ||
    s.tutorialActive ||
    s.tutorialViewStep > 0 ||
    s.namePrompt != null ||
    s.termsLaterOpen ||
    s.deleteAccountOpen ||
    s.deleteDone ||
    s.phaleShopOpen ||
    s.charmBoardOpen ||
    s.petSlotsOpen ||
    s.petCatalogOpen ||
    s.potPickerOpen ||
    s.placeModeActive ||
    s.frames.pickerOpen;

class _WorldChatTickerState extends State<WorldChatTicker> {
  WorldChatController get _c => widget.session.chat;

  @override
  void initState() {
    super.initState();
    _c.startTicker();
  }

  @override
  void dispose() {
    _c.stopTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return ListenableBuilder(
      listenable: Listenable.merge([s, s.chat, s.frames, ...widget.sheets]),
      builder: (context, _) {
        final show =
            WorldChatTicker.on(s) &&
            !widget.popupOpen &&
            !tickerHiddenBy(s) &&
            !(widget.sheetOpen?.call() ?? false);
        // TickerMode stops the scroll while hidden; the place stays.
        return TickerMode(
          enabled: show,
          child: Offstage(
            offstage: !show,
            child: _TickerStrip(session: s),
          ),
        );
      },
    );
  }
}

class _TickerStrip extends StatefulWidget {
  const _TickerStrip({required this.session});

  final ShopSession session;

  @override
  State<_TickerStrip> createState() => _TickerStripState();
}

class _TickerStripState extends State<_TickerStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  Timer? _pause;
  Timer? _fade;
  ChatMessage? _msg;
  double _textWidth = 0;
  double _boxWidth = 0;
  int _arrivals = 0;
  bool _faded = false;

  WorldChatController get _c => widget.session.chat;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChat);
    _onChat();
  }

  @override
  void dispose() {
    _c.removeListener(_onChat);
    _pause?.cancel();
    _fade?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onChat() {
    if (_c.tickerArrivals != _arrivals) {
      _arrivals = _c.tickerArrivals;
      _armFade(stale: _c.tickerStale);
    }
    // Nothing scrolling yet: start with the first message.
    if (_msg == null && !_scroll.isAnimating && _pause == null) _next();
  }

  void _armFade({required bool stale}) {
    _fade?.cancel();
    if (stale) {
      _setFaded(true);
      return;
    }
    _setFaded(false);
    _fade = Timer(WorldChatTicker.fadeAfter, () {
      if (mounted) setState(() => _faded = true);
    });
  }

  void _setFaded(bool v) {
    if (_faded == v) return;
    if (mounted) setState(() => _faded = v);
  }

  void _next() {
    _pause = null;
    final m = _c.nextTicker();
    if (!mounted) return;
    setState(() => _msg = m);
    if (m != null) _restart();
  }

  void _restart() {
    final m = _msg;
    if (m == null || _boxWidth <= 0) return; // after the first layout
    _textWidth = _measure(m);
    final travel = _boxWidth + _textWidth;
    _scroll.duration = Duration(
      milliseconds: (travel / WorldChatTicker.speed * 1000).round(),
    );
    _scroll.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _pause = Timer(WorldChatTicker.pause, _next);
  }

  static TextSpan _span(ChatMessage m) => TextSpan(
    children: [
      TextSpan(
        text: m.name,
        style: AppText.body(
          size: 13,
          weight: 800,
          color: WorldChatTicker.nameColor,
        ),
      ),
      TextSpan(
        text: ': ${m.text}',
        style: AppText.body(size: 13, color: WorldChatTicker.textColor),
      ),
    ],
  );

  double _measure(ChatMessage m) {
    final p = TextPainter(
      text: _span(m),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final m = _msg;
    return GestureDetector(
      key: const Key('world-chat-ticker'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.session.chat.openChat(),
      child: Semantics(
        button: true,
        label: m == null ? null : '${m.name}: ${m.text}',
        child: AnimatedOpacity(
          key: const Key('world-chat-ticker-fade'),
          opacity: _faded || m == null ? WorldChatTicker.faded : 1,
          duration: AppMotion.base,
          child: Container(
            height: WorldChatTicker.height,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: WorldChatTicker.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  key: Key('world-chat-ticker-icon'),
                  size: WorldChatTicker.iconSize,
                  color: WorldChatTicker.textColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      if (box.maxWidth != _boxWidth) {
                        _boxWidth = box.maxWidth;
                        if (m != null && !_scroll.isAnimating) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted &&
                                !_scroll.isAnimating &&
                                _pause == null) {
                              _restart();
                            }
                          });
                        }
                      }
                      if (m == null) return const SizedBox.shrink();
                      return ClipRect(
                        child: AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              _boxWidth -
                                  _scroll.value * (_boxWidth + _textWidth),
                              0,
                            ),
                            child: child,
                          ),
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: 0,
                            maxWidth: double.infinity,
                            child: Text.rich(
                              _span(m),
                              key: Key('world-chat-ticker-text-${m.id}'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
