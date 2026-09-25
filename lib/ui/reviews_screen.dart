import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'common.dart';

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
            child: BackButtonBox(key: const Key('reviews-back'), onTap: s.closeReviews),
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
            child: ListView.separated(
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
                    itemBuilder: (_, i) => _ReviewCard(session: s, review: list[i]),
                  ),
          ),
        ],
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
                      style: AppText.number(size: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const StarIcon(radius: 5),
                  const SizedBox(width: 7),
                  ProgressBar(
                    width: 136,
                    height: 8,
                    fraction: total == 0 ? 0 : (r.distribution[5 - i] ?? 0) / total,
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.session, required this.review});

  final ShopSession session;
  final ReviewRecord review;

  String _meta() {
    final e = session.e;
    if (review.outcome == 'leftUnserved') {
      return 'Ngày ${review.day} · Khách bỏ về';
    }
    final parts = <String>['Ngày ${review.day}'];
    for (final entry in review.stems.entries) {
      parts.add('${entry.value} ${e.flower(entry.key).nameVi}');
    }
    if (review.paperId != null) parts.add(e.paper(review.paperId!).nameVi.toLowerCase());
    if (review.ribbonId != null) parts.add(e.ribbon(review.ribbonId!).nameVi.toLowerCase());
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final occ = session.e.occasion(review.occasionId);
    return SizedBox(
      height: 96,
      child: CardBox(
        shadow: false,
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
              child: StarRow(value: review.stars.toDouble(), radius: 6, gap: 14),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: OccasionChip(occasionId: occ.id, label: occ.nameVi),
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
              right: 12,
              top: 78,
              child: Text(
                _meta(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(size: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
