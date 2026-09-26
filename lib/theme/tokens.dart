import 'package:flutter/painting.dart';

/// Dart mirror of `design/tiem-hoa/design_tokens.json` (Phú, v0.2.0-xanh).
/// `test/theme/tokens_test.dart` checks every colour against the JSON.
abstract final class AppColors {
  static const bgBase = Color(0xFFF8F5EA);
  static const bgShop = Color(0xFFE9F2E1);
  static const bgOverlay = Color(0x732E3A2C);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF1F4E8);
  static const surfaceBorder = Color(0xFFDCE5D0);
  static const surfaceBorderStrong = Color(0xFFBCCDB0);
  static const primaryBase = Color(0xFF3F7F52);
  static const primaryPressed = Color(0xFF2F6340);
  static const primarySoft = Color(0xFFDCEFD9);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondaryBase = Color(0xFFF2A477);
  static const secondaryPressed = Color(0xFFD9825A);
  static const secondarySoft = Color(0xFFFDE6D6);
  static const onSecondary = Color(0xFF4A2B1E);
  static const accentBase = Color(0xFFF5C451);
  static const accentSoft = Color(0xFFFDEFC6);
  static const textPrimary = Color(0xFF43392F);
  static const textSecondary = Color(0xFF6E6455);
  static const textDisabled = Color(0xFFBDB5A6);
  static const textInverse = Color(0xFFFFFFFF);
  static const freshnessFresh = Color(0xFF5DB58C);
  static const freshnessAging = Color(0xFFF5C451);
  static const freshnessWilting = Color(0xFFE26D5A);
  static const freshnessTrack = Color(0xFFE6ECDD);
  static const matchLow = Color(0xFFE26D5A);
  static const matchOk = Color(0xFFF5C451);
  static const matchPerfect = Color(0xFF5DB58C);
  static const statusSuccess = Color(0xFF1F7F66);
  static const statusWarning = Color(0xFFE0A030);
  static const statusDanger = Color(0xFFC94F3A);
  static const statusInfo = Color(0xFF4F8FB5);
  static const currencyCoin = Color(0xFFF2B632);
  static const currencyStar = Color(0xFFF5C451);
  static const occasionBirthday = Color(0xFFF4A6C0);
  static const occasionOpening = Color(0xFFF5C451);
  static const occasionWedding = Color(0xFFFFFFFF);
  static const occasionConfession = Color(0xFFE8738A);
  static const occasionHoliday = Color(0xFFE26D5A);
  static const templeSkyTop = Color(0xFFF3B08F);
  static const templeSkyBottom = Color(0xFFFBE3C8);
  static const templeRoof = Color(0xFF6B3A2E);
  static const templePillar = Color(0xFFC8553D);
  static const templeWood = Color(0xFF8A5A3C);
  static const templeWoodDark = Color(0xFF5E3B28);
  static const templeGold = Color(0xFFE9C46A);
  static const templeLantern = Color(0xFFE4572E);
  static const templeText = Color(0xFFFFF3DA);
  static const headerTop = Color(0xFF3F7F52);
  static const headerBottom = Color(0xFF74AD80);
  static const headerChip = Color(0xD9FFFFFF);
  static const backdropBase = Color(0xFFDCE8D2);
  static const navBg = Color(0xFFFFFFFF);
  static const navActivePill = Color(0xFFDCEFD9);
  static const navActiveLabel = Color(0xFF2F6340);
  static const navLabel = Color(0xFF6E6455);

  /// `shadow.popup` (`#2E3A2C33` is RRGGBBAA). Not a `color.*` token.
  static const popupShadow = Color(0x332E3A2C);

  /// Token path to colour, used by the tokens test.
  static const byPath = <String, Color>{
    'bg.base': bgBase,
    'bg.shop': bgShop,
    'bg.overlay': bgOverlay,
    'surface.card': surfaceCard,
    'surface.sunken': surfaceSunken,
    'surface.border': surfaceBorder,
    'surface.borderStrong': surfaceBorderStrong,
    'primary.base': primaryBase,
    'primary.pressed': primaryPressed,
    'primary.soft': primarySoft,
    'primary.onPrimary': onPrimary,
    'secondary.base': secondaryBase,
    'secondary.pressed': secondaryPressed,
    'secondary.soft': secondarySoft,
    'secondary.onSecondary': onSecondary,
    'accent.base': accentBase,
    'accent.soft': accentSoft,
    'text.primary': textPrimary,
    'text.secondary': textSecondary,
    'text.disabled': textDisabled,
    'text.inverse': textInverse,
    'freshness.fresh': freshnessFresh,
    'freshness.aging': freshnessAging,
    'freshness.wilting': freshnessWilting,
    'freshness.track': freshnessTrack,
    'match.low': matchLow,
    'match.ok': matchOk,
    'match.perfect': matchPerfect,
    'status.success': statusSuccess,
    'status.warning': statusWarning,
    'status.danger': statusDanger,
    'status.info': statusInfo,
    'currency.coin': currencyCoin,
    'currency.star': currencyStar,
    'occasion.birthday': occasionBirthday,
    'occasion.opening': occasionOpening,
    'occasion.wedding': occasionWedding,
    'occasion.confession': occasionConfession,
    'occasion.holiday': occasionHoliday,
    'temple.skyTop': templeSkyTop,
    'temple.skyBottom': templeSkyBottom,
    'temple.roof': templeRoof,
    'temple.pillar': templePillar,
    'temple.wood': templeWood,
    'temple.woodDark': templeWoodDark,
    'temple.gold': templeGold,
    'temple.lantern': templeLantern,
    'temple.text': templeText,
    'header.top': headerTop,
    'header.bottom': headerBottom,
    'header.chip': headerChip,
    'backdrop.base': backdropBase,
    'nav.bg': navBg,
    'nav.activePill': navActivePill,
    'nav.activeLabel': navActiveLabel,
    'nav.label': navLabel,
  };

  /// Occasion chip colour (`color.occasion.*`). `thanks` and `graduation`
  /// have no token yet. TODO(Phú): add them; until then they use the
  /// closest soft tokens.
  static Color occasion(String id) => switch (id) {
    'birthday' => occasionBirthday,
    'opening' => occasionOpening,
    'wedding' => occasionWedding,
    'confession' => occasionConfession,
    'holiday' => occasionHoliday,
    'thanks' => secondaryBase, // TODO(Phú): no token
    'graduation' => statusInfo, // TODO(Phú): no token
    _ => primarySoft,
  };

  /// Text on an occasion chip: white, except on the white wedding chip.
  static Color onOccasion(String id) =>
      occasion(id) == occasionWedding ? textPrimary : textInverse;
}

abstract final class AppSpace {
  static const xxs = 2.0, xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0;
  static const xl = 24.0, xxl = 32.0;
}

abstract final class AppRadius {
  static const sm = 8.0, md = 12.0, lg = 20.0, pill = 999.0;
}

abstract final class AppBorder {
  static const thin = 1.5, thick = 2.5;
}

abstract final class AppSize {
  static const frameWidth = 360.0, frameHeight = 640.0;
  static const touchMin = 44.0, topBar = 48.0;
  static const button = 48.0, buttonSmall = 36.0;
  static const trayCardW = 72.0, trayCardH = 92.0;
  static const avatar = 56.0, freshnessBar = 4.0;
  static const shadowOffset = 4.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const celebrate = Duration(milliseconds: 600);
}

/// Font families bundled in pubspec.yaml (`font.family`).
abstract final class AppFonts {
  static const display = 'Baloo 2';
  static const body = 'Nunito';
}

/// `font.style.*`. Variable fonts get both [FontWeight] and a `wght` axis.
abstract final class AppText {
  static TextStyle make(
    String family,
    double size,
    int weight, {
    double? height,
    Color color = AppColors.textPrimary,
    bool tabular = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    height: height,
    color: color,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle display({double size = 28, Color? color}) => make(
    AppFonts.display,
    size,
    800,
    height: 1.1,
    color: color ?? AppColors.textPrimary,
  );
  static TextStyle title({double size = 20, int weight = 700, Color? color}) =>
      make(
        AppFonts.display,
        size,
        weight,
        height: 1.2,
        color: color ?? AppColors.textPrimary,
      );
  static TextStyle heading({double size = 16, Color? color}) => make(
    AppFonts.body,
    size,
    800,
    height: 1.25,
    color: color ?? AppColors.textPrimary,
  );
  static TextStyle body({double size = 14, int weight = 600, Color? color}) =>
      make(
        AppFonts.body,
        size,
        weight,
        height: 1.35,
        color: color ?? AppColors.textPrimary,
      );
  static TextStyle caption({
    double size = 12,
    int weight = 700,
    Color? color,
  }) => make(
    AppFonts.body,
    size,
    weight,
    height: 1.3,
    color: color ?? AppColors.textSecondary,
  );
  static TextStyle number({double size = 18, int weight = 800, Color? color}) =>
      make(
        AppFonts.display,
        size,
        weight,
        height: 1.0,
        tabular: true,
        color: color ?? AppColors.textPrimary,
      );
  static TextStyle button({double size = 16, int weight = 700, Color? color}) =>
      make(
        AppFonts.display,
        size,
        weight,
        height: 1.0,
        color: color ?? AppColors.onPrimary,
      );
}
