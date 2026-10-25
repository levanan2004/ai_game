import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/share_text.dart';
import '../data/skins.dart' show skinGroupShop;
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'bouquet_table_screen.dart' show BouquetArt;
import 'common.dart';
import 'decorate_screen.dart' show ShopScenePreview;
import 'game_toast.dart';
import 'png_download.dart';
import 'popups.dart' show PopupFrame;
import 'share_card.dart';

/// Hands the image and message to the system share sheet; false when it
/// could not. Tests swap it.
typedef ShareImageFn = Future<bool> Function(Uint8List png, String text);

/// File name of the saved / shared image (spec §6.4).
const shareFileName = 'tiem-hoa-som-mai.png';

Future<bool> _systemShare(Uint8List png, String text) async {
  final r = await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png', name: shareFileName)],
      fileNameOverrides: const [shareFileName],
    ),
  );
  return r.status != ShareResultStatus.unavailable;
}

/// Share sheet: the card rendered to PNG, the messages from chia_se.json,
/// then Chia sẻ / Lưu ảnh (web) / Sao chép link / Đóng.
class ShareSheet extends StatefulWidget {
  const ShareSheet({
    super.key,
    required this.session,
    required this.kind,
    required this.onClose,
  });

  final ShopSession session;
  final ShareKind kind;
  final VoidCallback onClose;

  static ShareImageFn share = _systemShare;

  /// Web: downloads the file. Tests swap it.
  static Future<void> Function(Uint8List png) save = (png) =>
      downloadPng(png, shareFileName);

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  Uint8List? _png;
  late final List<String> _captions;
  late final String _cardCaption;
  int _pick = 0;
  bool _busy = false;

  ShopSession get s => widget.session;
  ShareText get t => s.data.share;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _captions = t.captions(widget.kind, tenTiem: s.state.shopName ?? '');
    final card = shareCardCaptions[widget.kind]!;
    _cardCaption = card[rng.nextInt(card.length)];
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  ShareCard get _card => ShareCard(
    kind: widget.kind,
    shopName: s.state.shopName ?? '',
    caption: _cardCaption,
    gameTag: t.ui('image_text.game_tag'),
    photo: widget.kind == ShareKind.bouquet
        ? ShareBouquetPhoto(bouquet: BouquetArt(session: s))
        : FittedBox(
            fit: BoxFit.cover,
            child: ShopScenePreview(session: s),
          ),
  );

  Future<void> _render() async {
    if (!mounted) return;
    final png = await renderSharePng(
      context,
      _card,
      size: const Size(ShareCard.width, ShareCard.feedHeight),
      precache: [
        '${Art.root}brand/logo_0_nen${Art.ext}',
        if (widget.kind == ShareKind.shop)
          for (final id in s.skinWornSet(skinGroupShop).values)
            if (s.skins.byId(id) case final d?) d.asset,
      ],
    );
    if (mounted) setState(() => _png = png);
  }

  String get _message => [
    if (_captions.isNotEmpty) _captions[_pick],
    t.hashtags.join(' '),
  ].join('\n');

  Future<void> _share() async {
    final png = _png;
    if (png == null || _busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await ShareSheet.share(png, _message);
    } catch (_) {}
    // Web without the Web Share API: the image is downloaded instead.
    if (!ok && kIsWeb) {
      try {
        await ShareSheet.save(png);
        ok = true;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) showGameToast(context, t.ui('toast.share_failed'), error: true);
  }

  Future<void> _save() async {
    final png = _png;
    if (png == null) return;
    try {
      await ShareSheet.save(png);
      if (mounted) showGameToast(context, t.ui('toast.image_saved'));
    } catch (_) {
      if (mounted) {
        showGameToast(context, t.ui('toast.save_failed'), error: true);
      }
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: shareLink));
    if (mounted) showGameToast(context, t.ui('toast.link_copied'));
  }

  @override
  Widget build(BuildContext context) {
    final png = _png;
    return PopupFrame(
      key: const Key('share-sheet'),
      rect: const Rect.fromLTWH(12, 24, 336, 592),
      onOutsideTap: widget.onClose,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.ui(
                widget.kind == ShareKind.bouquet
                    ? 'sheet.title_bouquet'
                    : 'sheet.title_shop',
              ),
              key: const Key('share-title'),
              textAlign: TextAlign.center,
              style: AppText.title(size: 17, weight: 800),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Center(
                child: png == null
                    ? const CircularProgressIndicator(
                        color: AppColors.primaryBase,
                      )
                    : Image.memory(
                        png,
                        key: const Key('share-preview'),
                        height: 200,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.ui('sheet.subtitle'),
              textAlign: TextAlign.center,
              style: AppText.caption(size: 12),
            ),
            const SizedBox(height: 6),
            Text(
              t.ui('sheet.caption_label'),
              style: AppText.body(size: 13, weight: 800),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                key: const Key('share-captions'),
                padding: EdgeInsets.zero,
                itemCount: _captions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) => GestureDetector(
                  key: Key('share-caption-$i'),
                  onTap: () => setState(() => _pick = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: i == _pick
                          ? AppColors.primarySoft
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: i == _pick
                            ? AppColors.primaryBase
                            : AppColors.surfaceBorder,
                        width: i == _pick ? 2 : 1.5,
                      ),
                    ),
                    child: Text(
                      _captions[i],
                      style: AppText.body(size: 12, weight: 700),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${t.ui('sheet.hashtag_label')}: ${t.hashtags.join(' ')}',
              key: const Key('share-hashtags'),
              style: AppText.caption(size: 11),
            ),
            const SizedBox(height: 8),
            ChunkyButton(
              key: const Key('share-go'),
              label: t.ui('button.share'),
              height: 40,
              radius: 14,
              enabled: png != null && !_busy,
              onPressed: _share,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (kIsWeb) ...[
                  Expanded(
                    child: OutlineButton(
                      key: const Key('share-save'),
                      label: t.ui('button.save_image'),
                      height: 34,
                      onTap: _save,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: OutlineButton(
                    key: const Key('share-copy-link'),
                    label: t.ui('button.copy_link'),
                    height: 34,
                    onTap: _copyLink,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlineButton(
                    key: const Key('share-close'),
                    label: t.ui('button.close'),
                    height: 34,
                    onTap: widget.onClose,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
