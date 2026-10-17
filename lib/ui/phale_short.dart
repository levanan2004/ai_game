import 'package:flutter/material.dart';

import '../logic/shop_session.dart';

/// A buy was refused for lack of money: Pha lê → [PhaleShortPopup]; xu →
/// [XuShortPopup] (đổi Pha lê, nạp, quảng cáo trên Android).
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
    s.askXuShort(name, price);
  }
}
