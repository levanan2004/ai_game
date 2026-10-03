import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/game_notice.dart';
import '../logic/inbox.dart';
import '../logic/mailbox.dart';
import '../logic/rewards.dart';
import '../logic/welfare_text.dart';
import '../theme/tokens.dart';
import 'ui_skin.dart';
import 'notice_image.dart';
import 'notice_sheet.dart' show CountBadge;
import 'phuc_loi_art.dart';
import 'reward_bundle_view.dart';

/// Hộp thư envelope on the shelf corner. Opens on the Thư tab; the badge
/// counts unread mail plus unread news.
class MailboxButton extends StatelessWidget {
  const MailboxButton({super.key, required this.inbox});

  final Inbox inbox;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: inbox,
      builder: (context, _) {
        final count = inbox.unread;
        return GestureDetector(
          key: const Key('mailbox-button'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            SoundScope.maybeOf(
              context,
            )?.effect(inbox.open ? 'popup_close' : 'popup_open');
            if (inbox.open) {
              inbox.close();
            } else {
              inbox.openAt(InboxTab.mail);
            }
          },
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
                  // Closed while something waits, open when all is read.
                  child: MailEnvelope(
                    key: Key(count > 0 ? 'mailbox-closed' : 'mailbox-open'),
                    open: count == 0,
                    width: 24,
                    fallback: const Icon(
                      Icons.mail_rounded,
                      size: 20,
                      color: AppColors.primaryBase,
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: CountBadge(key: const Key('mailbox-badge'), count),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Hộp thư popup. Thư: list of mails, then one mail with its gift and
/// "Nhận quà". Tin tức: [news] (a [NewsTab]), shown when the inbox has a
/// notice feed.
class MailboxSheet extends StatelessWidget {
  const MailboxSheet({
    super.key,
    required this.inbox,
    required this.signedIn,
    required this.canClaim,
    required this.grant,
    this.onSignIn,
    this.news,
  });

  final Inbox inbox;
  MailboxFeed get feed => inbox.mail;

  /// Tin tức tab body. Null (or no notice feed): Thư only, no tabs.
  final Widget? news;
  final bool signedIn;

  /// False while this tab may not write the account (seat moving, leaving).
  final bool Function() canClaim;

  /// Adds the gift to the shop. The game passes
  /// `grantRewards(source: RewardSource.mailbox)`.
  final RewardBundle Function(GameMail mail) grant;
  final Future<void> Function()? onSignIn;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: inbox,
      builder: (context, _) {
        if (!inbox.open) return const SizedBox.shrink();
        final detail = feed.detail;
        final tabs = news != null && inbox.news != null;
        final onNews = tabs && inbox.tab == InboxTab.news;
        final Widget body = onNews
            ? news!
            : !signedIn
            ? _guest(context)
            : detail == null
            ? _list(context)
            : _MailDetail(
                key: ValueKey(detail.id),
                feed: feed,
                mail: detail,
                canClaim: canClaim,
                grant: grant,
              );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  SoundScope.maybeOf(context)?.effect('popup_close');
                  inbox.close();
                },
                child: const ColoredBox(color: AppColors.bgOverlay),
              ),
            ),
            Positioned(
              left: 8,
              top: 56,
              width: 344,
              child: ConstrainedBox(
                // Shrinks to the list or letter; long ones scroll inside.
                constraints: const BoxConstraints(maxHeight: 560),
                child: GestureDetector(
                  onTap: () {},
                  child: SkinPopup(
                    key: const Key('mailbox-sheet'),
                    title: 'Hộp thư',
                    onBack: inbox.back,
                    onClose: inbox.close,
                    backKey: const Key('mailbox-back'),
                    closeKey: const Key('mailbox-close'),
                    child: !tabs
                        ? body
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _tab(
                                    context,
                                    InboxTab.mail,
                                    WelfareText.inboxTabMail,
                                  ),
                                  _tab(
                                    context,
                                    InboxTab.news,
                                    WelfareText.inboxTabNews,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Flexible(child: body),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tab(BuildContext context, InboxTab tab, String label) {
    final count = tab == InboxTab.mail ? inbox.unreadMail : inbox.unreadNews;
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SkinTab(
            key: Key('inbox-tab-${tab.name}'),
            label: label,
            selected: inbox.tab == tab,
            onTap: () {
              SoundScope.maybeOf(context)?.effect('ui_tab');
              inbox.selectTab(tab);
            },
          ),
          if (count > 0)
            Positioned(
              right: 6,
              top: 2,
              child: CountBadge(key: Key('inbox-tab-badge-${tab.name}'), count),
            ),
        ],
      ),
    );
  }

  Widget _guest(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Center(
          child: MailEnvelope(
            open: false,
            width: 72,
            fallback: Icon(
              Icons.mail_rounded,
              size: 48,
              color: AppColors.primaryBase,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đăng nhập Google để nhận thư và quà của tiệm.',
          key: const Key('mailbox-guest'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, weight: 700),
        ),
        const SizedBox(height: 12),
        if (onSignIn != null)
          SkinButton(
            key: const Key('mailbox-sign-in'),
            label: 'Đăng nhập Google',
            height: 48,
            fontSize: 16,
            onPressed: () => onSignIn!(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final mails = feed.mails;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: mails.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    feed.loading
                        ? 'Đang mở hộp thư…'
                        : feed.error ?? WelfareText.mailEmpty,
                    key: const Key('mailbox-empty'),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, weight: 700),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: mails.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(context, mails[i]),
                ),
        ),
      ],
    );
  }

  static bool _closed(GameMail mail, MailState state) =>
      !state.read || (mail.hasGift && !state.claimed);

  Widget _row(BuildContext context, GameMail mail) {
    final state = feed.stateOf(mail.id);
    final fresh = !state.read;
    final color = fresh ? AppColors.textPrimary : AppColors.textDisabled;
    final tag = !mail.hasGift
        ? ''
        : state.claimed
        ? 'Đã nhận'
        : 'Có quà';
    return GestureDetector(
      key: Key('mail-item-${mail.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SoundScope.maybeOf(context)?.effect('mo_thu');
        feed.openMail(mail.id);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: fresh ? AppColors.surfaceSunken : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Opacity(
          opacity: fresh ? 1 : 0.6,
          child: Row(
            children: [
              // Closed: unread or a gift still waiting. Open: read and
              // nothing left to take.
              KeyedSubtree(
                key: Key(
                  fresh ? 'mail-unread-${mail.id}' : 'mail-read-${mail.id}',
                ),
                child: MailEnvelope(
                  key: Key(
                    _closed(mail, state)
                        ? 'mail-closed-${mail.id}'
                        : 'mail-open-${mail.id}',
                  ),
                  open: !_closed(mail, state),
                  width: 34,
                  fallback: Icon(
                    fresh ? Icons.mail_rounded : Icons.drafts_rounded,
                    size: 22,
                    color: fresh
                        ? AppColors.primaryBase
                        : AppColors.surfaceBorderStrong,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mail.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        size: 14,
                        weight: fresh ? 800 : 700,
                        color: color,
                      ),
                    ),
                    if (tag.isNotEmpty)
                      Text(
                        tag,
                        style: AppText.caption(
                          color: state.claimed
                              ? AppColors.textDisabled
                              : AppColors.primaryPressed,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                noticeDateLabel(mail.createdAt),
                style: AppText.caption(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MailDetail extends StatefulWidget {
  const _MailDetail({
    super.key,
    required this.feed,
    required this.mail,
    required this.canClaim,
    required this.grant,
  });

  final MailboxFeed feed;
  final GameMail mail;
  final bool Function() canClaim;
  final RewardBundle Function(GameMail mail) grant;

  @override
  State<_MailDetail> createState() => _MailDetailState();
}

class _MailDetailState extends State<_MailDetail> {
  String? _message;

  Future<void> _claim() async {
    final sounds = SoundScope.maybeOf(context);
    final result = await widget.feed.claim(
      widget.mail.id,
      allowed: widget.canClaim(),
      grant: widget.grant,
    );
    if (!mounted) return;
    if (result == MailClaimResult.claimed) sounds?.effect('ad_reward');
    final message = switch (result) {
      MailClaimResult.claimed => 'Quà đã vào tiệm.',
      MailClaimResult.already => 'Quà này đã nhận rồi.',
      MailClaimResult.busy => null,
      MailClaimResult.refused =>
        widget.mail.expired(DateTime.now())
            ? WelfareText.mailExpired
            : 'Chưa nhận được. Mở lại tiệm bằng tài khoản Google rồi thử nhé.',
      MailClaimResult.failed => 'Chưa nhận được, thử lại nhé.',
    };
    if (message != null) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    final mail = widget.mail;
    final feed = widget.feed;
    final claimed = feed.stateOf(mail.id).claimed;
    final busy = feed.claiming(mail.id);
    final expiry = mailExpiryLabel(mail.expiresAt);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              key: const Key('mail-detail-icon'),
              width: 30,
              height: 30 / PhucLoiArt.thuMo.aspect,
              child: phucLoiImage(PhucLoiArt.thuMo),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mail.title,
                key: const Key('mail-detail'),
                style: AppText.heading(size: 18),
              ),
            ),
          ],
        ),
        Text(
          [
            noticeDateLabel(mail.createdAt),
            expiry,
          ].where((s) => s.isNotEmpty).join(' · '),
          style: AppText.caption(),
        ),
        const SizedBox(height: 8),
        // Letter, gifts and button flow together; scrolls if it is long.
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mail.imageUrl != null) ...[
                  NoticeImage(url: mail.imageUrl!),
                  const SizedBox(height: 8),
                ],
                Text(
                  mail.body,
                  key: const Key('mail-body'),
                  style: AppText.body(size: 14, weight: 700),
                ),
                if (mail.hasGift) ...[
                  const SizedBox(height: 12),
                  SkinTray(
                    child: Opacity(
                      opacity: claimed ? 0.5 : 1,
                      child: RewardBundleView(
                        key: const Key('mail-gift'),
                        bundle: mail.rewards,
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _message!,
                      key: const Key('mail-message'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: SkinButton(
                        key: const Key('mail-claim'),
                        label: claimed
                            ? 'Đã nhận'
                            : busy
                            ? 'Đang nhận…'
                            : 'Nhận quà',
                        height: 52,
                        fontSize: 17,
                        enabled: !claimed && !busy,
                        onPressed: claimed || busy ? null : _claim,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
