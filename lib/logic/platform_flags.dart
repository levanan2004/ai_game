import 'package:flutter/foundation.dart' show visibleForTesting;

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
