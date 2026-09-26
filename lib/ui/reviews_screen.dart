import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/review_picker.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'frame_metrics.dart';

/// Màn Đánh giá (spec_danh_gia.md §2).
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  static const _filters = [
    'Tất cả',
    'Hôm nay',
    '5 sao',
    '4 sao',
    '3 sao trở xuống',
  ];
  late int _filter = widget.session.reviewsInitialFilter;
  final ScrollController _chips = ScrollController();
  bool _chipFade = false;
  ReviewRecord? _replying;

  @override
  void initState() {
    super.initState();
    _chips.addListener(_syncChipFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncChipFade());
  }

  @override
  void dispose() {
    _chips.removeListener(_syncChipFade);
    _chips.dispose();
    super.dispose();
  }

  void _syncChipFade() {
    if (!mounted || !_chips.hasClients) return;
    final m = _chips.position;
    final fade = m.maxScrollExtent > 1 && m.pixels < m.maxScrollExtent - 1;
    if (fade != _chipFade) setState(() => _chipFade = fade);
  }

  bool _match(ReviewRecord r) => switch (_filter) {
    1 => r.day == widget.session.state.day,
    2 => r.stars == 5,
    3 => r.stars == 4,
    4 => r.stars <= 3,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final list = s.state.reviews.reversed.where(_match).toList();
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
            child: BackButtonBox(
              key: const Key('reviews-back'),
              onTap: s.closeReviews,
            ),
          ),
          Positioned(
            left: 56,
            right: 56,
            top: 10,
            height: 32,
            child: Center(
              child: Text(
                'Đánh giá của khách',
                style: AppText.title(size: 20, weight: 800),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 54,
            width: 336,
            height: 128,
            child: _Summary(session: s),
          ),
          Positioned(
            left: 0,
            top: 198,
            width: 360,
            height: 30,
            child: Stack(
              children: [
                ListView.separated(
                  controller: _chips,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    key: Key('filter-$i'),
                    onTap: () => setState(() => _filter = i),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: _filter == i
                            ? AppColors.primaryBase
                            : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: _filter == i
                            ? null
                            : Border.all(
                                color: AppColors.surfaceBorder,
                                width: AppBorder.thin,
                              ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _filters[i],
                        style: AppText.caption(
                          size: 11,
                          weight: 800,
                          color: _filter == i
                              ? AppColors.textInverse
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_chipFade)
                  const Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 24,
                    child: IgnorePointer(child: _ChipFade()),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 240,
            width: 360,
            height: 400,
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có nhận xét nào',
                      style: AppText.body(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ReviewCard(
                      session: s,
                      review: list[i],
                      onReply: () => setState(() => _replying = list[i]),
                    ),
                  ),
          ),
          if (_replying != null)
            Positioned.fill(
              child: ReplySheet(
                session: s,
                review: _replying!,
                onClose: () => setState(() => _replying = null),
              ),
            ),
        ],
      ),
    );
  }
}

/// 24 px fade on the right of the filter chips (bg.base).
class _ChipFade extends StatelessWidget {
  const _ChipFade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00FFF6EC), AppColors.bgBase],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final r = session.rating;
    final total = r.count;
    return CardBox(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            width: 124,
            top: 16,
            child: Text(
              formatRating(r.average),
              key: const Key('rating-average'),
              textAlign: TextAlign.center,
              style: AppText.number(size: 40),
            ),
          ),
          Positioned(
            left: 22,
            top: 66,
            child: StarRow(value: r.average, radius: 8, gap: 16),
          ),
          Positioned(
            left: 0,
            width: 124,
            top: 88,
            child: Text(
              '${total == 0 ? session.e.ratingWindow : total} khách gần nhất',
              textAlign: TextAlign.center,
              style: AppText.caption(size: 10),
            ),
          ),
          for (var i = 0; i < 5; i++)
            Positioned(
              left: 134,
              top: 22 - 8 + i * 20.0,
              height: 16,
              width: 192,
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    child: Text(
                      '${5 - i}',
                      textAlign: TextAlign.center,
                      style: AppText.number(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const StarIcon(radius: 5),
                  const SizedBox(width: 7),
                  ProgressBar(
                    width: 136,
                    height: 8,
                    fraction: total == 0
                        ? 0
                        : (r.distribution[5 - i] ?? 0) / total,
                    color: AppColors.currencyStar,
                  ),
                  const Spacer(),
                  Text(
                    '${r.distribution[5 - i] ?? 0}',
                    style: AppText.caption(size: 11, weight: 800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.session,
    required this.review,
    required this.onReply,
  });

  final ShopSession session;
  final ReviewRecord review;
  final VoidCallback onReply;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late bool _showReply = widget.review.replyText != null;

  ShopSession get session => widget.session;
  ReviewRecord get review => widget.review;

  @override
  void didUpdateWidget(_ReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.replyText == null && review.replyText != null) {
      _showReply = false;
      Future<void>.delayed(AppMotion.base, () {
        if (mounted) setState(() => _showReply = true);
      });
    } else if (!identical(oldWidget.review, review)) {
      _showReply = review.replyText != null;
    }
  }

  /// Every review can be answered once. A missing suggestion group only
  /// hides the chips (reviews.json `ownerReplyRule`).
  bool get _canReply => review.replyText == null;

  String _meta() {
    final e = session.e;
    if (review.online && review.deliveryIssue == 'late') {
      return 'Ngày ${review.day} · Giao trễ';
    }
    if (review.online && review.deliveryIssue == 'missed') {
      return 'Ngày ${review.day} · Lỡ đơn';
    }
    if (review.outcome == 'leftUnserved') {
      return 'Ngày ${review.day} · Khách bỏ về';
    }
    final parts = <String>['Ngày ${review.day}'];
    for (final entry in review.stems.entries) {
      parts.add('${entry.value} ${e.flower(entry.key).nameVi}');
    }
    if (review.paperId != null) {
      parts.add(e.paper(review.paperId!).nameVi.toLowerCase());
    }
    if (review.ribbonId != null) {
      parts.add(e.ribbon(review.ribbonId!).nameVi.toLowerCase());
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final occ = session.e.occasion(review.occasionId);
    final reply = review.replyText;
    return AnimatedSize(
      duration: AppMotion.base,
      alignment: Alignment.topCenter,
      curve: Curves.easeOutCubic,
      child: CardBox(
        shadow: false,
        child: Column(
          children: [
            SizedBox(
              height: 96,
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    top: 10,
                    child: Avatar(
                      name: review.customerName,
                      avatarId: review.avatarId,
                      radius: 16,
                    ),
                  ),
                  Positioned(
                    left: 52,
                    top: 8,
                    right: 110,
                    child: Text(
                      review.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(size: 14, weight: 800),
                    ),
                  ),
                  Positioned(
                    left: 52,
                    top: 28,
                    child: StarRow(
                      value: review.stars.toDouble(),
                      radius: 6,
                      gap: 14,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: review.online
                        ? Container(
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: AppColors.statusInfo,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Đơn online',
                              style: AppText.caption(
                                size: 10,
                                weight: 800,
                                color: AppColors.textInverse,
                              ),
                            ),
                          )
                        : OccasionChip(occasionId: occ.id, label: occ.nameVi),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 42,
                    child: Text(
                      review.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 12, weight: 700),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: _canReply ? 100 : 12,
                    top: 78,
                    child: Text(
                      _meta(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(size: 10),
                    ),
                  ),
                  if (_canReply)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      width: 104,
                      height: 44,
                      child: GestureDetector(
                        key: Key(
                          'review-reply-${review.day}-${review.customerName}',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onReply,
                        child: const Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 12, bottom: 6),
                            child: _ReplyPill(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (reply != null)
              AnimatedOpacity(
                opacity: _showReply ? 1 : 0,
                duration: AppMotion.base,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 12, 8),
                  child: Container(
                    width: 296,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: const Border(
                        left: BorderSide(
                          color: AppColors.primaryBase,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chủ tiệm',
                          style: AppText.caption(
                            size: 10,
                            weight: 800,
                            color: AppColors.primaryPressed,
                          ),
                        ),
                        Text(
                          reply,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPill extends StatelessWidget {
  const _ReplyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        'Phản hồi',
        style: AppText.caption(
          size: 11,
          weight: 800,
          color: AppColors.primaryPressed,
        ),
      ),
    );
  }
}

/// Bottom sheet for typing one reply (spec_danh_gia.md §3).
class ReplySheet extends StatefulWidget {
  const ReplySheet({
    super.key,
    required this.session,
    required this.review,
    required this.onClose,
  });

  final ShopSession session;
  final ReviewRecord review;
  final VoidCallback onClose;

  @override
  State<ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<ReplySheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..forward();
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  late final TextEditingController _text = TextEditingController()
    ..addListener(() => setState(() {}));
  late final List<OwnerReplyChoice> _choices = ownerReplyChoices(
    widget.session.data.reviews,
    widget.review.outcome,
    widget.session.rng,
  );
  var _closing = false;

  @override
  void dispose() {
    _text.dispose();
    _curve.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _anim.duration = AppMotion.base;
    await _anim.reverse();
    if (mounted) widget.onClose();
  }

  void _fill(String line) {
    final text = line.length > 80 ? line.substring(0, 80) : line;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _send() {
    if (widget.session.replyToReview(widget.review, _text.text)) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final metrics = FrameMetrics.maybeOf(context);
    // Phone (≤480) reports bottomGap 0, so this stays viewInsets / frame scale.
    // The desktop box is not the full window, so use its real scale and the
    // gap under the box.
    final scale =
        metrics?.scale ??
        math.min(
          mq.size.width / AppSize.frameWidth,
          mq.size.height / AppSize.frameHeight,
        );
    final lift = scale <= 0
        ? 0.0
        : math.max(0.0, mq.viewInsets.bottom - (metrics?.bottomGap ?? 0)) /
              scale;
    final review = widget.review;
    final canSend = normalizeReply(_text.text) != null;
    return FadeTransition(
      opacity: _anim,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('reply-dismiss'),
              onTap: _close,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: lift,
            height: 320,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_curve),
              child: Material(
                color: AppColors.surfaceCard,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Phản hồi ${review.customerName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.heading(size: 17),
                              ),
                            ),
                            GestureDetector(
                              key: const Key('reply-close'),
                              onTap: _close,
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          StarRow(
                            value: review.stars.toDouble(),
                            radius: 5,
                            gap: 12,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '“${review.comment}”',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 96,
                        child: Stack(
                          children: [
                            TextField(
                              key: const Key('reply-field'),
                              controller: _text,
                              maxLength: 80,
                              maxLines: 3,
                              style: AppText.body(size: 13),
                              decoration: InputDecoration(
                                hintText: 'Viết vài lời cho khách…',
                                hintStyle: AppText.body(
                                  size: 13,
                                  color: AppColors.textDisabled,
                                ),
                                counterText: '',
                                contentPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  22,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceCard,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.surfaceBorder,
                                    width: AppBorder.thin,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryBase,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 6,
                              child: Text(
                                '${_text.text.length}/80',
                                style: AppText.caption(size: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_choices.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Gợi ý (chạm để điền vào ô):',
                          style: AppText.caption(size: 11),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 30,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _choices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final choice = _choices[i];
                              return GestureDetector(
                                key: Key('reply-chip-${choice.tone}'),
                                onTap: () => _fill(choice.text),
                                child: Container(
                                  height: 30,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    choice.label,
                                    style: AppText.caption(
                                      size: 12,
                                      weight: 800,
                                      color: AppColors.primaryPressed,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        height: 48,
                        child: ChunkyButton(
                          key: const Key('reply-send'),
                          label: 'Gửi phản hồi',
                          enabled: canSend,
                          onPressed: canSend ? _send : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
