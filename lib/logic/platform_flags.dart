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

/// Tests only: `null` follows the platform the app runs on.
@visibleForTesting
bool? iosAppOverride;

/// The iOS app. It has no top-up: no Pha lê balance warning, no "pending
/// top-up order" case, and its own short consent lines
/// (chu_ung_dung_v1.md §8). The web build is never "iOS", even in Safari.
bool get isIosApp =>
    iosAppOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

/// Tests only: `null` follows the platform the app runs on.
@visibleForTesting
bool? androidAppOverride;

/// The Android app (not Chrome on Android: that is the web build).
bool get isAndroidApp =>
    androidAppOverride ??
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

/// Rewarded ads exist only in the Android and iOS apps. The web build,
/// including Chrome on a phone, never offers them.
bool get rewardedAdsOffered => isAndroidApp || isIosApp;

/// Real-money Pha lê top-up. Shown on every platform. iOS charges through
/// the App Store; web and Android use the bank-transfer shop.
bool get phaLeTopUpOffered => true;

/// iOS sells Pha lê only as App Store consumable In-App Purchases.
bool get phaLeUsesAppleIap => isIosApp;
