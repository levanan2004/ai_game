import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/welfare_slides.dart';
import '../logic/welfare_text.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'notice_image.dart';

/// "Bạn biết?" carousel: 1080×480 cards that turn every [interval], with
/// dots. Tapping a card calls [onTap].
class WelfareSlidesView extends StatefulWidget {
  const WelfareSlidesView({
    super.key,
    required this.slides,
    required this.onTap,
    this.interval = const Duration(seconds: 4),
  });

  final List<WelfareSlide> slides;
  final ValueChanged<WelfareSlide> onTap;
  final Duration interval;

  @override
  State<WelfareSlidesView> createState() => _WelfareSlidesViewState();
}

class _WelfareSlidesViewState extends State<WelfareSlidesView> {
  final _pages = PageController();
  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(WelfareSlidesView old) {
    super.didUpdateWidget(old);
    if (old.slides.length != widget.slides.length) {
      if (_index >= widget.slides.length) _index = 0;
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) => _advance());
  }

  void _advance() {
    if (!mounted || !_pages.hasClients || widget.slides.length < 2) return;
    final next = (_index + 1) % widget.slides.length;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Chưa có tin nào.',
          key: const Key('slides-empty'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, weight: 700),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: slideAspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: PageView.builder(
              key: const Key('slides-pages'),
              controller: _pages,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _card(slides[i]),
            ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < slides.length; i++)
                AnimatedContainer(
                  key: Key('slide-dot-$i'),
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primaryBase
                        : AppColors.surfaceBorderStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _card(WelfareSlide slide) {
    return GestureDetector(
      key: Key('slide-${slide.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTap(slide),
      child: slide.hasArt && !slide.hasImage
          ? SlideArtCard(art: slide.art, title: slide.title, body: slide.body)
          : !slide.hasImage
          ? SlideTextCard(title: slide.title, body: slide.body)
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  slide.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      slide.title.isEmpty && slide.body.isEmpty
                      ? const ImageMissing()
                      : SlideTextCard(title: slide.title, body: slide.body),
                ),
                if (slide.title.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x99000000)],
                        ),
                      ),
                      child: Text(
                        slide.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          size: 13,
                          weight: 800,
                          color: AppColors.textInverse,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A built-in card: Phú's picture with the text over its empty left half,
/// under a small "Bạn biết?" chip (preview_ban_biet.png).
class SlideArtCard extends StatelessWidget {
  const SlideArtCard({
    super.key,
    required this.art,
    this.title = '',
    this.body = '',
  });

  final String art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight.isFinite ? box.maxHeight : 147.0;
        return Stack(
          key: Key('slide-art-$art'),
          fit: StackFit.expand,
          children: [
            Image.asset(
              Art.banBiet(art),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  SlideTextCard(title: title, body: body),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              // Text stays on the faded left 44% of Phú's pictures.
              widthFactor: 0.44,
              child: Padding(
                padding: EdgeInsets.fromLTRB(h * 0.08, h * 0.08, 2, h * 0.06),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBase,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        WelfareText.slideChip,
                        textScaler: TextScaler.noScaling,
                        style: AppText.body(
                          size: 10,
                          weight: 800,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: h * 0.05),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 13, weight: 800),
                      ),
                    // The narrow text column: the body steps down from 13
                    // until it fits (not below 9).
                    Flexible(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          TextStyle style(double s) => AppText.body(
                            size: s,
                            weight: 700,
                            color: AppColors.textPrimary,
                          );
                          var size = 13.0;
                          while (size > 9) {
                            final tp = TextPainter(
                              text: TextSpan(text: body, style: style(size)),
                              textDirection: TextDirection.ltr,
                              textScaler: TextScaler.noScaling,
                            )..layout(maxWidth: c.maxWidth);
                            final fits = tp.height <= c.maxHeight;
                            tp.dispose();
                            if (fits) break;
                            size -= 0.5;
                          }
                          return Text(
                            body,
                            overflow: TextOverflow.fade,
                            textScaler: TextScaler.noScaling,
                            style: style(size),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A slide without a picture: [title] and [body] on a soft green and cream
/// card. Fills its parent (the carousel keeps the 2.25:1 ratio).
class SlideTextCard extends StatelessWidget {
  const SlideTextCard({super.key, this.title = '', this.body = ''});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('slide-text-card'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3F1D8), Color(0xFFFFF6E2)],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 28,
            color: AppColors.primaryBase,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 14, weight: 800),
                  ),
                if (body.isNotEmpty)
                  Flexible(
                    child: Text(
                      body,
                      overflow: TextOverflow.fade,
                      style: AppText.body(
                        size: 13,
                        weight: 700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
