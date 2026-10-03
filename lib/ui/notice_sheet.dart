import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/game_notice.dart';
import '../logic/notice_feed.dart';
import '../logic/notice_reply.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'notice_reply_form.dart';
import 'open_url.dart';

/// Bell on the title screen and beside the settings gear.
class NoticeButton extends StatelessWidget {
  const NoticeButton({super.key, required this.feed});

  final NoticeFeed feed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        final count = feed.unread;
        return GestureDetector(
          key: const Key('notice-button'),
          onTap: () {
            SoundScope.maybeOf(
              context,
            )?.effect(feed.open ? 'popup_close' : 'popup_open');
            feed.toggle();
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.headerChip,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: ArtImage(
                    Art.nav('thong_bao'),
                    size: 26,
                    fallback: const CustomPaint(
                      size: Size(22, 22),
                      painter: _BellPainter(),
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      key: const Key('notice-badge'),
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.statusDanger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: AppText.caption(
                          size: 9,
                          weight: 800,
                          color: AppColors.textInverse,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// List, then the body of the row that was tapped. A link opens a new tab.
class NoticeSheet extends StatelessWidget {
  const NoticeSheet({
    super.key,
    required this.feed,
    this.onOpenLink,
    this.replies,
    this.signedIn = false,
    this.uid = '',
    this.email = '',
    this.playerName = '',
    this.shopName = '',
    this.onSignIn,
  });

  final NoticeFeed feed;

  /// Defaults to [openUrl]. Tests pass a recorder.
  final void Function(String url)? onOpenLink;

  final NoticeReplies? replies;
  final bool signedIn;
  final String uid;
  final String email;
  final String playerName;
  final String shopName;
  final Future<void> Function()? onSignIn;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        if (!feed.open) return const SizedBox.shrink();
        final detail = feed.detail;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  SoundScope.maybeOf(context)?.effect('popup_close');
                  feed.close();
                },
                child: const ColoredBox(color: AppColors.bgOverlay),
              ),
            ),
            Positioned(
              left: 20,
              top: 72,
              width: 320,
              height: 500,
              child: GestureDetector(
                onTap: () {},
                child: CardBox(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: detail == null
                      ? _list(context, feed)
                      : _NoticeDetail(
                          key: ValueKey(detail.id),
                          feed: feed,
                          notice: detail,
                          onOpenLink: onOpenLink,
                          replies: replies,
                          signedIn: signedIn,
                          uid: uid,
                          email: email,
                          playerName: playerName,
                          shopName: shopName,
                          onSignIn: onSignIn,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, NoticeFeed feed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bar(context, 'Thông báo', onBack: feed.close),
        const SizedBox(height: 8),
        Expanded(
          child: feed.visible.isEmpty
              ? Center(
                  child: Text(
                    feed.notices.isEmpty
                        ? 'Chưa có thông báo.'
                        : 'Bạn đã xoá hết thông báo.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, weight: 700),
                  ),
                )
              : ListView.separated(
                  itemCount: feed.visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final notice = feed.visible[i];
                    final fresh = !feed.seen(notice.id);
                    final titleColor = fresh
                        ? AppColors.textPrimary
                        : AppColors.textDisabled;
                    return GestureDetector(
                      key: Key('notice-item-${notice.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        SoundScope.maybeOf(context)?.effect('ui_tap');
                        feed.openDetail(notice.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: fresh
                              ? AppColors.surfaceSunken
                              : AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Opacity(
                                opacity: fresh ? 1 : 0.55,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: fresh
                                            ? AppColors.statusDanger
                                            : AppColors.surfaceBorderStrong,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notice.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.body(
                                              size: 14,
                                              weight: fresh ? 800 : 700,
                                              color: titleColor,
                                            ),
                                          ),
                                          if (notice.kind == NoticeKind.form)
                                            Text(
                                              'Góp ý',
                                              style: AppText.caption(
                                                color: fresh
                                                    ? AppColors.primaryPressed
                                                    : AppColors.textDisabled,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      noticeDateLabel(notice.createdAt),
                                      style: AppText.caption(color: titleColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              key: Key('notice-hide-${notice.id}'),
                              onTap: () {
                                SoundScope.maybeOf(context)?.effect('ui_tap');
                                feed.dismiss(notice.id);
                              },
                              child: Text(
                                'Xoá',
                                style: AppText.caption(
                                  color: AppColors.statusDanger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    String title, {
    required VoidCallback onBack,
  }) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          BackButtonBox(onTap: onBack),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: AppText.heading(size: 18))),
        ],
      ),
    );
  }
}

class _NoticeDetail extends StatefulWidget {
  const _NoticeDetail({
    super.key,
    required this.feed,
    required this.notice,
    required this.onOpenLink,
    required this.replies,
    required this.signedIn,
    required this.uid,
    required this.email,
    required this.playerName,
    required this.shopName,
    required this.onSignIn,
  });

  final NoticeFeed feed;
  final GameNotice notice;
  final void Function(String url)? onOpenLink;
  final NoticeReplies? replies;
  final bool signedIn;
  final String uid;
  final String email;
  final String playerName;
  final String shopName;
  final Future<void> Function()? onSignIn;

  @override
  State<_NoticeDetail> createState() => _NoticeDetailState();
}

class _NoticeDetailState extends State<_NoticeDetail> {
  var _form = false;

  @override
  Widget build(BuildContext context) {
    if (_form) {
      return NoticeReplyForm(
        notice: widget.notice,
        replies: widget.replies,
        signedIn: widget.signedIn,
        uid: widget.uid,
        email: widget.email,
        playerName: widget.playerName,
        shopName: widget.shopName,
        onSignIn: widget.onSignIn,
        onBack: () => setState(() => _form = false),
      );
    }
    final notice = widget.notice;
    final link = notice.link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sheetBar('Thông báo', widget.feed.showList),
        const SizedBox(height: 8),
        Text(
          notice.title,
          key: const Key('notice-detail'),
          style: AppText.heading(size: 18),
        ),
        if (notice.createdAt != null)
          Text(noticeDateLabel(notice.createdAt), style: AppText.caption()),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              notice.body,
              style: AppText.body(size: 14, weight: 700),
            ),
          ),
        ),
        if (notice.kind == NoticeKind.form) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ChunkyButton(
              key: const Key('notice-open-form'),
              label: 'Điền form',
              fontSize: 15,
              onPressed: () => setState(() => _form = true),
            ),
          ),
        ],
        if (link != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ChunkyButton(
              key: const Key('notice-open-link'),
              label: notice.buttonLabel,
              fontSize: 15,
              kind: notice.kind == NoticeKind.form
                  ? ButtonKind.secondary
                  : ButtonKind.primary,
              onPressed: () {
                final url = normalizeNoticeLink(link);
                if (url == null) return;
                (widget.onOpenLink ?? openUrl)(url);
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlineButton(
          key: const Key('notice-hide'),
          label: 'Xoá thông báo',
          height: 36,
          onTap: () => widget.feed.dismiss(notice.id),
        ),
      ],
    );
  }
}

Widget _sheetBar(String title, VoidCallback onBack) {
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        BackButtonBox(onTap: onBack),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppText.heading(size: 18))),
      ],
    ),
  );
}

class _BellPainter extends CustomPainter {
  const _BellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..cubicTo(w * 0.28, h * 0.08, w * 0.16, h * 0.32, w * 0.16, h * 0.52)
      ..lineTo(w * 0.08, h * 0.72)
      ..lineTo(w * 0.92, h * 0.72)
      ..lineTo(w * 0.84, h * 0.52)
      ..cubicTo(w * 0.84, h * 0.32, w * 0.72, h * 0.08, w * 0.5, h * 0.08)
      ..close();
    canvas.drawPath(body, Paint()..color = AppColors.primaryBase);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.84),
      w * 0.1,
      Paint()..color = AppColors.accentBase,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.38,
        h * 0.28,
        w * 0.48,
        h * 0.52,
        Radius.circular(w * 0.08),
      ),
      Paint()..color = const Color(0x66F8F5EA),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
