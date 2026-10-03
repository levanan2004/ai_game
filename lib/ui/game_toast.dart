import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shared toast (Tiệm thú cưng spec): a pill 38 tall, radius 19, padding 18,
/// white Nunito 800, 120 above the bottom, shown for 2 seconds. It lives in
/// the app Overlay, so it stays up after the popup that sent it closes.
void showGameToast(BuildContext context, String text, {bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => GameToast(text: text, error: error),
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 2), () {
    if (entry.mounted) entry.remove();
  });
}

class GameToast extends StatelessWidget {
  const GameToast({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: IgnorePointer(
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              key: Key(error ? 'game-toast-error' : 'game-toast-ok'),
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: error
                    ? AppColors.statusDanger
                    : AppColors.primaryPressed,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppText.body(
                  size: 13.5,
                  weight: 800,
                  color: AppColors.textInverse,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
