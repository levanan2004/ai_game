import 'package:flutter/foundation.dart';

import 'game_notice.dart';
import 'welfare_text.dart';

/// Slides are drawn at 1080×480.
const slideAspect = 1080 / 480;
const maxSlideTitleChars = 80;
const maxSlideBodyChars = 300;

enum SlideLinkType { none, route, url }

/// In-game places a slide may open, id to label. The game maps each id to
/// a screen or sheet (game_root.dart); unknown ids do nothing.
const welfareRoutes = <String, String>{
  'login': 'Phúc lợi: Điểm danh',
  'giftcode': 'Phúc lợi: Giftcode',
  'mailbox': 'Hộp thư',
  'notices': 'Thông báo',
  'reviews': 'Đánh giá',
  'stock': 'Kho hoa',
  'prices': 'Giá bán',
  'garden': 'Vườn',
  'pets': 'Thú cưng',
  'petShop': 'Cửa hàng thú cưng',
  'upgrades': 'Nâng cấp',
  'donors': 'Đại thiện nhân',
};

/// `slides/{id}`: one "Bạn biết?" card. Without a picture it is drawn as
/// a text card ([title] and [body]) at the same 2.25:1 ratio.
@immutable
class WelfareSlide {
  const WelfareSlide({
    required this.id,
    this.imageUrl = '',
    this.title = '',
    this.body = '',
    this.linkType = SlideLinkType.none,
    this.link = '',
    this.order = 0,
    this.enabled = true,
    this.art = '',
  });

  /// Built-in picture id under `assets/images/ban_biet/` (Phú's art, left
  /// half left empty for [body]). Only the built-in cards set it; it is
  /// never read from or written to Firestore.
  final String art;

  bool get hasArt => art.isNotEmpty;

  final String id;

  /// `https://…`, or empty for a text-only card.
  final String imageUrl;
  final String title;
  final String body;

  bool get hasImage => imageUrl.isNotEmpty;
  final SlideLinkType linkType;

  /// A [welfareRoutes] id, or an https URL.
  final String link;
  final int order;
  final bool enabled;

  Map<String, Object?> toMap() => {
    'imageUrl': imageUrl.trim(),
    'title': title.trim(),
    'body': body.trim(),
    'linkType': linkType.name,
    'link': linkType == SlideLinkType.none ? '' : link.trim(),
    'order': order,
    'enabled': enabled,
  };

  static WelfareSlide? fromMap(String id, Map<String, Object?> data) {
    final image = normalizeImageUrl(
      data['imageUrl'] is String ? data['imageUrl'] as String : null,
    );
    final title = data['title'] is String
        ? (data['title'] as String).trim()
        : '';
    final body = data['body'] is String ? (data['body'] as String).trim() : '';
    if (image == null && title.isEmpty && body.isEmpty) return null;
    final type = SlideLinkType.values.firstWhere(
      (t) => t.name == data['linkType'],
      orElse: () => SlideLinkType.none,
    );
    final link = data['link'] is String ? (data['link'] as String).trim() : '';
    final order = data['order'];
    final ok = switch (type) {
      SlideLinkType.none => true,
      SlideLinkType.route => welfareRoutes.containsKey(link),
      SlideLinkType.url => normalizeImageUrl(link) != null,
    };
    return WelfareSlide(
      id: id,
      imageUrl: image ?? '',
      title: title,
      body: body,
      linkType: ok ? type : SlideLinkType.none,
      link: ok ? link : '',
      order: order is int ? order : 0,
      enabled: data['enabled'] != false,
    );
  }
}

/// Null when an admin may save [slide].
String? slideFormError(WelfareSlide slide) {
  final image = slide.imageUrl.trim();
  if (image.isNotEmpty && normalizeImageUrl(image) == null) {
    return 'Link ảnh cần bắt đầu bằng https://';
  }
  if (image.isEmpty &&
      slide.title.trim().isEmpty &&
      slide.body.trim().isEmpty) {
    return 'Cần ảnh hoặc chữ cho slide.';
  }
  if (slide.title.trim().length > maxSlideTitleChars) {
    return 'Tiêu đề tối đa $maxSlideTitleChars ký tự.';
  }
  if (slide.body.trim().length > maxSlideBodyChars) {
    return 'Nội dung tối đa $maxSlideBodyChars ký tự.';
  }
  switch (slide.linkType) {
    case SlideLinkType.none:
      break;
    case SlideLinkType.route:
      if (!welfareRoutes.containsKey(slide.link)) return 'Chọn màn hình.';
    case SlideLinkType.url:
      if (normalizeImageUrl(slide.link) == null) {
        return 'Link cần bắt đầu bằng https://';
      }
  }
  return null;
}

/// Enabled slides by [WelfareSlide.order], then id.
List<WelfareSlide> visibleSlides(Iterable<WelfareSlide> slides) =>
    sortSlides(slides.where((s) => s.enabled));

List<WelfareSlide> sortSlides(Iterable<WelfareSlide> slides) {
  final list = [...slides];
  list.sort((a, b) {
    final c = a.order.compareTo(b.order);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}

/// Built-in pictures for the default cards, by position (empty: text card
/// until the art arrives). Slide 1 waits for An's picture.
const defaultSlideArt = ['', 'ban_biet_2', 'ban_biet_3'];

/// Cards shown while `slides/` has nothing to show: Nhất's text, over
/// Phú's picture where there is one.
final defaultWelfareSlides = [
  for (var i = 0; i < WelfareText.defaultSlides.length; i++)
    WelfareSlide(
      id: 'default-${i + 1}',
      body: WelfareText.defaultSlides[i],
      art: i < defaultSlideArt.length ? defaultSlideArt[i] : '',
    ),
];
