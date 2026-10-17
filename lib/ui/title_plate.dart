import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A title's name as one widget, so Phú's framed nameplate (art and effects
/// coming later) can replace it in one place. For now plain bold text on a
/// soft pill.
class TitlePlate extends StatelessWidget {
  const TitlePlate({super.key, required this.name, this.size = 12.5});

  final String name;

  /// Font size; the pill follows it.
  final double size;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.7,
        vertical: size * 0.15,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(size),
        border: Border.all(color: AppColors.primaryBase),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption(
          size: size,
          color: AppColors.primaryPressed,
        ).copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
