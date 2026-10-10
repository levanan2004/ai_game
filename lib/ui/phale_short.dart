import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import 'common.dart';

/// A buy was refused for lack of money. For Pha lê it opens the "Thiếu N Pha
/// lê / Nạp thêm Pha lê" popup (S4b); for xu it keeps the small hint bubble
/// ([hint], "Còn thiếu … xu").
void shortOrHint(
  BuildContext context,
  ShopSession s, {
  required bool phaLe,
  required String name,
  required int price,
  required String hint,
}) {
  if (phaLe) {
    s.askPhaleShort(name, price);
  } else {
    showTapHint(context, hint);
  }
}
