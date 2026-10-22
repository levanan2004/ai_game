import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;

/// Build-time switches for features that are hidden but kept in the code.
///
/// [supportersEnabled]: the "Đại thiện nhân" supporters board with the donation
/// QR card (`DonorsScreen`), its Settings row ("Ủng hộ"), the day-summary
/// donate strip, and the welfare-slide link `donors`. Off since topping up
/// (nạp tiền) replaced donations. Nothing is deleted: set the build flag to
/// `true` to bring everything back (code, assets and Firestore data stay).
/// Same on web, Android and iOS. The admin panel is not a player screen and
/// is not affected.
const bool _supportersBuildFlag = false;

/// Tests only: `null` follows the build flag.
@visibleForTesting
bool? supportersEnabledOverride;

bool get supportersEnabled => supportersEnabledOverride ?? _supportersBuildFlag;

/// `open` (default): web APK / Play-style Android. `amazon`: Amazon Appstore.
const String _distribution = String.fromEnvironment(
  'DISTRIBUTION',
  defaultValue: 'open',
);

/// Tests only: `null` follows [DISTRIBUTION].
@visibleForTesting
String? distributionOverride;

String get distribution => distributionOverride ?? _distribution;

/// Amazon Appstore build (`flutter build apk --flavor amazon
/// --dart-define=DISTRIBUTION=amazon`).
bool get isAmazonDistribution => distribution == 'amazon';

/// Tests only: `null` follows the platform the app runs on.
@visibleForTesting
bool? iosAppOverride;

/// The iOS app. It tops up Pha lê only through App Store In-App Purchase
/// ([phaLeUsesAppleIap]): no bank-transfer QR, no "pending top-up order"
/// case, and its own short consent lines (chu_ung_dung_v1.md §8). The web
/// build is never "iOS", even in Safari.
bool get isIosApp =>
    iosAppOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

/// Tests only: `null` follows the platform the app runs on.
@visibleForTesting
bool? androidAppOverride;

/// The Android app (not Chrome on Android: that is the web build).
bool get isAndroidApp =>
    androidAppOverride ??
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

/// Policy-compliant Amazon Android: no Google account, cloud save, or Pha lê IAP.
bool get isAmazonApp => isAndroidApp && isAmazonDistribution;

/// Google sign-in, cloud progress, Hộp thư, BXH, tin thế giới, nạp Pha lê QR.
bool get cloudAccountOffered => !isAmazonDistribution;

/// Rewarded ads exist only in the Android and iOS apps. The web build,
/// including Chrome on a phone, never offers them.
bool get rewardedAdsOffered => isAndroidApp || isIosApp;

/// Real-money Pha lê top-up. Off on the Amazon Appstore build.
bool get phaLeTopUpOffered => cloudAccountOffered;

/// iOS sells Pha lê only as App Store consumable In-App Purchases.
bool get phaLeUsesAppleIap => isIosApp;
