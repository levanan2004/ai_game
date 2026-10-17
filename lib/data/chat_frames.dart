import 'dart:math' as math;
import 'dart:ui' show Rect;

/// Khung tin nhắn (economy.json `chatBubbleFrames`, Hà Phương block v2;
/// functions/chat_frames.js decides what a message shows).
class ChatFrame {
  const ChatFrame({required this.id, this.vip = 0, this.title = ''});

  final String id;

  /// Opens at VIP [vip] (vipMax, kept after a drop); 0 = not a VIP frame.
  final int vip;

  /// Only while holding title [title]; '' = not a title frame.
  final String title;
}

class ChatFramesConfig {
  const ChatFramesConfig({this.frames = const [], this.defaultId = ''});

  factory ChatFramesConfig.fromJson(Object? raw) {
    if (raw is! Map) return const ChatFramesConfig();
    final frames = <ChatFrame>[
      for (final f in raw['frames'] is List ? raw['frames'] as List : const [])
        if (f is Map && f['id'] is String && (f['id'] as String).isNotEmpty)
          ChatFrame(
            id: f['id'] as String,
            vip: f['vip'] is int && (f['vip'] as int) > 0 ? f['vip'] as int : 0,
            title: f['title'] is String ? f['title'] as String : '',
          ),
    ];
    final d = raw['default'];
    return ChatFramesConfig(
      frames: frames,
      defaultId: d is String && frames.any((f) => f.id == d)
          ? d
          : (frames.isEmpty ? '' : frames.first.id),
    );
  }

  final List<ChatFrame> frames;
  final String defaultId;

  ChatFrame? byId(String id) {
    for (final f in frames) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The frame [chosen] shows for its owner, like functions/chat_frames.js
  /// effectiveFrame: a title frame only while held (else [base]); a VIP
  /// frame shows as the default when the VIP badge is hidden.
  String effective(
    String chosen, {
    String base = '',
    bool Function(String titleId)? holds,
    bool badgeHidden = false,
  }) {
    var f = byId(chosen);
    if (f != null && f.title.isNotEmpty && !(holds?.call(f.title) ?? false)) {
      final b = byId(base);
      f = b != null && b.title.isEmpty ? b : null;
    }
    f ??= byId(defaultId);
    if (f == null) return '';
    if (f.vip > 0 && badgeHidden) return defaultId;
    return f.id;
  }
}

/// Phú's art (assets/images/khung_chat/): nine-slice insets in image pixels
/// (L/R 200, top 130 — thường 50 —, bottom 70), drawn at scale 0.25.
class ChatFrameArt {
  const ChatFrameArt(
    this.asset,
    this.width,
    this.height, {
    this.top = 130,
    this.padX = 20,
    this.padTop = 8,
  });

  final String asset;
  final double width;
  final double height;
  final double top;

  /// Phú 21:33: side padding of the text, 12 dp for thường, 20 dp for the
  /// 5 decorated frames.
  final double padX;

  /// Phú 21:33: top padding (dp) under the decoration band; 8 like the
  /// bottom, 18 for Mị Lực Nhất Trời so the first line clears the bell.
  final double padTop;

  /// Vertical padding (Phú: 8 dp) and the band the art's top inset takes
  /// at [scale]: the text always starts below the band.
  static const padY = 8.0;
  double get textTop => math.max(padY, top * scale) + padTop - padY;
  static double get textBottom => math.max(padY, bottom * scale);

  static const side = 200.0;
  static const bottom = 70.0;

  /// Phú: the art is drawn at 1/4 of its pixels.
  static const scale = 0.25;

  Rect get slice => Rect.fromLTRB(side, top, width - side, height - bottom);
}

ChatFrameArt? chatFrameArtOf(String id) => switch (id) {
  'chat_thuong' => const ChatFrameArt(
    'assets/images/khung_chat/khung_chat_thuong.webp',
    555,
    232,
    top: 50,
    padX: 12,
  ),
  'chat_vip_bac' => const ChatFrameArt(
    'assets/images/khung_chat/khung_chat_vip5.webp',
    555,
    279,
  ),
  'chat_vip_vang' => const ChatFrameArt(
    'assets/images/khung_chat/khung_chat_vip7.webp',
    573,
    277,
  ),
  'chat_vip_ngoc' => const ChatFrameArt(
    'assets/images/khung_chat/khung_chat_vip9.webp',
    582,
    269,
  ),
  'chat_de_nhat_goi_hoa' => const ChatFrameArt(
    'assets/images/khung_chat/khung_chat_de_nhat_goi_hoa.webp',
    592,
    279,
  ),
  'chat_mi_luc_nhat_troi' => const ChatFrameArt(
    'assets/images/khung_chat/khung_chat_mi_luc_nhat_troi.webp',
    583,
    276,
    padTop: 18,
  ),
  _ => null,
};

/// Nhất, chu_ho_so_chien_tich.md 20:04 (verbatim).
abstract final class ChatFrameText {
  static const section = 'Khung tin nhắn'; // chat_frame.section
  static String name(String id) => switch (id) {
    'chat_thuong' => 'Thường', // chat_frame.default
    'chat_vip_bac' => 'Lá bạc', // chat_frame.vip5
    'chat_vip_vang' => 'Cành hoa vàng', // chat_frame.vip7
    'chat_vip_ngoc' => 'Đá quý', // chat_frame.vip9
    'chat_de_nhat_goi_hoa' => 'Đệ Nhất Gói Hoa', // chat_frame.de_nhat_goi_hoa
    'chat_mi_luc_nhat_troi' =>
      'Mị Lực Nhất Trời', // chat_frame.mi_luc_nhat_troi
    _ => '',
  };
  static String lockedVip(int n) => 'Mở ở VIP $n'; // chat_frame.locked_vip
  static String lockedTitle(String title) =>
      'Chỉ người đang giữ danh hiệu "$title" mới dùng được'; // chat_frame.locked_title
  static const equipped = 'Đang dùng'; // chat_frame.equipped
  static const equip = 'Dùng khung này'; // chat_frame.equip
  static const equipToast = 'Đã đổi khung tin nhắn.'; // chat_frame.equip_toast
  static String lostTitleNote(String title) =>
      'Bạn không còn giữ danh hiệu "$title", khung tin nhắn đã về khung bạn chọn trước đó.'; // chat_frame.lost_title_note
  static const hiddenVipNote =
      'Bạn đang bật "Ẩn huy hiệu VIP", nên khung VIP hiện như khung Thường.'; // chat_frame.hidden_vip_note
}
