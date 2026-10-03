import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/game_notice.dart';
import '../logic/notice_feed.dart';
import '../logic/notice_reply.dart';
import '../logic/photo_uploads.dart';
import '../logic/welfare_text.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'notice_image.dart';
import 'notice_reply_form.dart';
import 'open_url.dart';

/// Red dot with a count, on the corner buttons.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// Tin tức tab of Hộp thư: the announcements list, then the one tapped.
/// The popup's back arrow returns to the list ([Inbox.back]).
class NewsTab extends StatelessWidget {
  const NewsTab({
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
    this.photos,
  });

  final NoticeFeed feed;

  /// Picture upload for the góp ý form. Null: no picture button.
  final PhotoUploads? photos;

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
        final detail = feed.detail;
        if (detail == null) return _list(context);
        return _NoticeDetail(
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
          photos: photos,
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final visible = feed.visible;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    feed.notices.isEmpty
                        ? WelfareText.newsEmpty
                        : WelfareText.newsAllHidden,
                    key: const Key('news-empty'),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, weight: 700),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(context, visible[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, GameNotice notice) {
    final fresh = !feed.seen(notice.id);
    final titleColor = fresh ? AppColors.textPrimary : AppColors.textDisabled;
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
          color: fresh ? AppColors.surfaceSunken : AppColors.surfaceCard,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                style: AppText.caption(color: AppColors.statusDanger),
              ),
            ),
          ],
        ),
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
    required this.photos,
  });

  final NoticeFeed feed;
  final PhotoUploads? photos;
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
      // The form scrolls inside a fixed box (it fills with Expanded).
      return SizedBox(
        height: 440,
        child: NoticeReplyForm(
          notice: widget.notice,
          replies: widget.replies,
          signedIn: widget.signedIn,
          uid: widget.uid,
          email: widget.email,
          playerName: widget.playerName,
          shopName: widget.shopName,
          onSignIn: widget.onSignIn,
          photos: widget.photos,
          onBack: () => setState(() => _form = false),
        ),
      );
    }
    final notice = widget.notice;
    final link = notice.link;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          notice.title,
          key: const Key('notice-detail'),
          style: AppText.heading(size: 18),
        ),
        if (notice.createdAt != null)
          Text(noticeDateLabel(notice.createdAt), style: AppText.caption()),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice.imageUrl != null) ...[
                  NoticeImage(url: notice.imageUrl!),
                  const SizedBox(height: 8),
                ],
                Text(notice.body, style: AppText.body(size: 14, weight: 700)),
              ],
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
          label: 'Xoá tin này',
          height: 36,
          onTap: () => widget.feed.dismiss(notice.id),
        ),
      ],
    );
  }
}
