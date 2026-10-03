import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A picture on a notice or a mail: fixed height, cropped to fit, tap to
/// see the whole picture. A broken link shows a quiet placeholder.
class NoticeImage extends StatelessWidget {
  const NoticeImage({super.key, required this.url, this.height = 140});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('notice-image'),
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: AppColors.bgOverlay,
        builder: (context) => _ImageViewer(url: url),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, _, _) => const ImageMissing(),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const ColoredBox(color: AppColors.surfaceSunken),
          ),
        ),
      ),
    );
  }
}

/// Shown when a picture cannot be loaded.
class ImageMissing extends StatelessWidget {
  const ImageMissing({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('image-missing'),
      color: AppColors.surfaceSunken,
      child: Center(
        // Scales down inside a small thumbnail.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textDisabled,
              ),
              Text('Không tải được ảnh', style: AppText.caption(size: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('notice-image-viewer'),
      onTap: () => Navigator.of(context).pop(),
      child: InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, _, _) =>
                const SizedBox(width: 240, height: 160, child: ImageMissing()),
          ),
        ),
      ),
    );
  }
}
