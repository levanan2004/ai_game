part of 'shop_session.dart';

/// Arms at most one event for today. The card opens later, once the shop
/// has been open for a little while.
void armShopEvent(ShopSession s) {
  s._eventAt = null;
  if (!s.state.tutorialDone || s.state.day < 3) return;
  if (s.rng.nextDouble() > 0.35) return;
  final id = _pickEvent(s);
  if (id == null) return;
  final span = s.e.dayRealSeconds;
  s._eventAt = span * (0.15 + s.rng.nextDouble() * 0.25);
}

void resetShopEventDay(ShopSession s) {
  s.eventOffer = null;
  s.eventStatus = null;
  s.eventSummaryNote = null;
  s._eventAt = null;
  s._grandmaPay = 0;
  s._extraWilt = false;
  s._theftHeld = 0;
  s._mouseLost = 0;
  s._mouseSaved = 0;
  s._mouseDetail = '';
  s._policePending = false;
  s._wholesaleLeft = 0;
  s._wholesaleDeadline = 0;
  s._wholesaleSum = 0;
  s._patienceDrain = 1;
  s._patienceUntil = 0;
}

void maybeShowShopEvent(ShopSession s) {
  final at = s._eventAt;
  if (at == null || s.eventOffer != null || s.state.elapsed < at) return;
  s._eventAt = null;
  final id = _pickEvent(s);
  if (id == null) return;
  _showEvent(s, id);
}

void chooseShopEvent(ShopSession s, String choiceId) {
  final offer = s.eventOffer;
  if (offer == null) return;
  if (!offer.choices.any((c) => c.id == choiceId)) return;
  s.eventOffer = null;
  switch (offer.id) {
    case 'rain':
      _chooseRain(s, choiceId);
    case 'power':
      _choosePower(s, choiceId);
    case 'theft':
      _chooseTheft(s, choiceId);
    case 'wholesale':
      _chooseWholesale(s, choiceId);
    case 'grandma':
      _chooseGrandma(s, choiceId);
    case 'mouse':
      _chooseMouse(s);
  }
  s.sounds.effect('popup_close');
  s._changed();
}

double patienceDrain(ShopSession s) {
  if (s.state.elapsed >= s._patienceUntil) return 1;
  return s._patienceDrain;
}

void noteWholesale(ShopSession s, Bouquet bouquet, int price) {
  if (s._wholesaleLeft <= 0) return;
  if (bouquet.paperId != 'basket') return;
  if (s.state.elapsed > s._wholesaleDeadline) return;
  s._wholesaleLeft -= 1;
  s._wholesaleSum += price;
  if (s._wholesaleLeft == 0) {
    final bonus = (s._wholesaleSum * 0.3).round();
    s.state.money += bonus;
    s.eventStatus = null;
    s.showNotice('Khách sỉ trả thêm ${formatK(bonus)}.');
  } else {
    s.eventStatus = 'Còn ${s._wholesaleLeft} giỏ hoa cho khách sỉ.';
  }
}

void tickWholesale(ShopSession s) {
  if (s._wholesaleLeft <= 0) return;
  if (s.state.elapsed <= s._wholesaleDeadline) return;
  _failWholesale(s);
}

void resolveShopEventDay(ShopSession s) {
  if (s.eventOffer != null) {
    chooseShopEvent(s, s.eventOffer!.choices.last.id);
  }
  if (s._wholesaleLeft > 0) _failWholesale(s);
  if (s._policePending) {
    s._policePending = false;
    if (s.rng.nextDouble() < 0.7) {
      s.state.money += s._theftHeld;
      s.eventSummaryNote = 'Cảnh sát đã bắt trộm';
    } else {
      s.eventSummaryNote = 'Cảnh sát chưa tìm thấy người lấy tiền';
    }
    s._theftHeld = 0;
  }
}

void rememberDayRevenue(ShopSession s) {
  final m = s.state.metrics;
  final rev = m.flowerIncome + m.tipIncome + m.onlineIncome;
  s.state.recentRevenue.add(rev);
  while (s.state.recentRevenue.length > 3) {
    s.state.recentRevenue.removeAt(0);
  }
}

void applyMorningEvent(ShopSession s) {
  if (s._grandmaPay > 0) {
    s.state.money += s._grandmaPay;
    s.state.addReview(
      ReviewRecord(
        day: s.state.day,
        customerName: 'Bà Năm',
        avatarId: 'ba_nam',
        occasionId: s.e.occasions.first.id,
        stars: 5,
        comment: 'Sáng nay bà trả gấp đôi và cảm ơn.',
        outcome: 'great',
      ),
    );
    s._grandmaPay = 0;
  }
  if (s._extraWilt) {
    for (final batch in s.state.stock) {
      batch.freshnessLeft -= 1;
    }
    s._extraWilt = false;
  }
  s.eventSummaryNote = null;
}

String? _pickEvent(ShopSession s) {
  final holiday = s.holidayToday != null;
  final broke = s.state.money < 0;
  final tooSoon =
      s.state.lastBadEventDay > 0 && s.state.day - s.state.lastBadEventDay < 3;
  final ids = <String>[
    'rain',
    if ((s.state.upgradeLevels['cold_storage'] ?? 0) >= 1) 'power',
    'theft',
    if (s.state.unlockedItems.contains('basket')) 'wholesale',
    'grandma',
    if (_mouseReady(s)) 'mouse',
  ];
  bool bad(String id) => id == 'power' || id == 'theft' || id == 'mouse';
  final open = [
    for (final id in ids)
      if (!(holiday && bad(id)) && !(broke && bad(id)) && !(tooSoon && bad(id)))
        id,
  ];
  if (open.isEmpty) return null;
  return open[s.rng.nextInt(open.length)];
}

void _showEvent(ShopSession s, String id) {
  if (id == 'mouse' && !_beginMouse(s)) return;
  if (id == 'power' || id == 'theft' || id == 'mouse') {
    s.state.lastBadEventDay = s.state.day;
  }
  if (id == 'theft') {
    final sales =
        s.state.metrics.flowerIncome +
        s.state.metrics.tipIncome +
        s.state.metrics.onlineIncome;
    final amount = _money(sales > 0 ? sales * 0.1 : _eventBase(s) * 0.1);
    s.state.money -= amount;
    s._theftHeld = amount;
  }
  s.eventOffer = _offer(s, id);
  s.sounds.effect('popup_open');
  s._changed();
}

EventOffer _offer(ShopSession s, String id) {
  final cost8 = formatK(_money(_eventBase(s) * 0.08));
  final cost10 = formatK(_money(_eventBase(s) * 0.1));
  final stolen = formatK(s._theftHeld);
  return switch (id) {
    'rain' => EventOffer(
      id: id,
      title: 'Mưa to',
      body:
          'Mưa lớn quá. Giăng bạt tốn $cost8, khách sẽ đông hơn đến hết ngày. '
          'Bỏ qua thì hai giờ tới vắng khách.',
      choices: const [
        EventChoice('tarp', 'Giăng bạt'),
        EventChoice('skip', 'Để vậy'),
      ],
    ),
    'power' => EventOffer(
      id: id,
      title: 'Cúp điện',
      body:
          'Tủ mát tắt. Thuê máy phát tốn $cost10. Không thuê thì tối nay hoa '
          'mất thêm một ngày tươi.',
      choices: const [
        EventChoice('generator', 'Thuê máy phát'),
        EventChoice('skip', 'Không thuê'),
      ],
    ),
    'theft' => EventOffer(
      id: id,
      title: 'Trộm vào tiệm',
      body:
          'Có người lấy $stolen trong ngăn kéo. Báo cảnh sát thì cuối ngày '
          'có thể được trả lại. Đuổi theo thì lấy lại ngay một nửa cơ hội, '
          'nhưng khách đang chờ sẽ sốt ruột hơn.',
      choices: const [
        EventChoice('police', 'Báo cảnh sát'),
        EventChoice('chase', 'Đuổi theo'),
        EventChoice('ignore', 'Bỏ qua'),
      ],
    ),
    'wholesale' => const EventOffer(
      id: 'wholesale',
      title: 'Khách sỉ',
      body:
          'Khách cần 3 giỏ hoa trong 2 giờ. Gói kịp thì họ trả thêm 30% '
          'trên 3 giỏ đó. Trễ thì một đánh giá 2 sao.',
      choices: [
        EventChoice('accept', 'Nhận'),
        EventChoice('decline', 'Từ chối'),
      ],
    ),
    'mouse' => EventOffer(
      id: id,
      title: 'Chuột gặm hoa',
      body: _mouseBody(s),
      choices: const [EventChoice('ok', 'Được rồi')],
    ),
    _ => const EventOffer(
      id: 'grandma',
      title: 'Bà cụ quên ví',
      body:
          'Bà cụ quên ví. Cho nợ một ít hoa, sáng mai bà trả gấp đôi và '
          'để 5 sao.',
      choices: [
        EventChoice('lend', 'Cho nợ'),
        EventChoice('decline', 'Từ chối'),
      ],
    ),
  };
}

void _chooseRain(ShopSession s, String choiceId) {
  if (choiceId == 'tarp') {
    _charge(s, 0.08);
    _retimes(s, 1.2, null);
    s.showNotice('Đã giăng bạt. Khách sẽ ghé đông hơn.');
  } else {
    _retimes(s, 0.75, 2);
    s.showNotice('Hai giờ tới vắng khách hơn.');
  }
}

void _choosePower(ShopSession s, String choiceId) {
  if (choiceId == 'generator') {
    _charge(s, 0.1);
    s.showNotice('Máy phát chạy. Tủ mát vẫn lạnh.');
  } else {
    s._extraWilt = true;
    s.showNotice('Tối nay hoa mất thêm một ngày tươi.');
  }
}

void _chooseTheft(ShopSession s, String choiceId) {
  if (choiceId == 'police') {
    s._policePending = true;
    s.showNotice('Đã báo cảnh sát. Cuối ngày sẽ rõ.');
    return;
  }
  if (choiceId == 'chase') {
    if (s.rng.nextDouble() < 0.5) {
      s.state.money += s._theftHeld;
      s.showNotice('Đuổi kịp. Tiền đã về ngăn kéo.');
    } else {
      s.showNotice('Không đuổi kịp.');
    }
    s._patienceDrain = 1 / 0.7;
    s._patienceUntil = s.state.elapsed + s.e.secondsPerHour * 0.5;
  }
  s._theftHeld = 0;
}

void _chooseWholesale(ShopSession s, String choiceId) {
  if (choiceId != 'accept') {
    s.showNotice('Khách sỉ gật đầu rồi đi.');
    return;
  }
  s._wholesaleLeft = 3;
  s._wholesaleSum = 0;
  s._wholesaleDeadline = s.state.elapsed + s.e.secondsPerHour * 2;
  s.eventStatus = 'Còn 3 giỏ hoa cho khách sỉ.';
  s.showNotice('Gói 3 giỏ hoa trước khi hết giờ.');
}

void _chooseMouse(ShopSession s) {
  if (s._mouseLost <= 0) {
    s.showNotice('Mèo bắt kịp con chuột.');
    return;
  }
  if (s.state.hasCat) {
    s.showNotice('Mèo bắt chuột, vẫn mất ${s._mouseLost} cành.');
    return;
  }
  s.showNotice('Chuột gặm mất ${s._mouseLost} cành.');
}

String _mouseBody(ShopSession s) {
  if (s._mouseLost <= 0) {
    return 'Chuột lẻn vào kệ. Mèo bắt kịp, hoa vẫn còn nguyên.';
  }
  final detail = s._mouseDetail;
  if (!s.state.hasCat) return 'Chuột gặm mất $detail.';
  if (s._mouseSaved <= 0) return 'Mèo đuổi chuột nhưng vẫn mất $detail.';
  return 'Mèo bắt chuột. Đỡ được ${s._mouseSaved} cành, vẫn mất $detail.';
}

int _freeStems(ShopSession s) {
  var n = 0;
  final seen = <String>{};
  for (final batch in s.state.stock) {
    if (seen.add(batch.flowerId)) n += s.stockAvailable(batch.flowerId);
  }
  return n;
}

bool _mouseReady(ShopSession s) =>
    mouseAimedStems(day: s.state.day, available: _freeStems(s)) > 0;

/// Gnaws the oldest stems first and leaves reserved online orders alone.
/// Returns false when the mouse would take nothing.
bool _beginMouse(ShopSession s) {
  final aimed = mouseAimedStems(day: s.state.day, available: _freeStems(s));
  final want = mouseStemsLost(
    aimed: aimed,
    hasCat: s.state.hasCat,
    stage: s.state.petStage,
  );
  if (aimed <= 0) return false;
  final room = <String, int>{};
  for (final batch in s.state.stock) {
    room.putIfAbsent(batch.flowerId, () => s.stockAvailable(batch.flowerId));
  }
  final batches = [...s.state.stock]
    ..sort((a, b) {
      final byFresh = a.freshnessLeft.compareTo(b.freshnessLeft);
      if (byFresh != 0) return byFresh;
      return a.flowerId.compareTo(b.flowerId);
    });
  final taken = <String, int>{};
  var left = want;
  for (final batch in batches) {
    if (left <= 0) break;
    final can = room[batch.flowerId] ?? 0;
    if (can <= 0 || batch.count <= 0) continue;
    var n = left;
    if (n > can) n = can;
    if (n > batch.count) n = batch.count;
    batch.count -= n;
    room[batch.flowerId] = can - n;
    left -= n;
    taken[batch.flowerId] = (taken[batch.flowerId] ?? 0) + n;
  }
  s.state.stock.removeWhere((batch) => batch.count <= 0);
  s._mouseLost = want - left;
  s._mouseSaved = aimed - s._mouseLost;
  s._mouseDetail = [
    for (final entry in taken.entries)
      if (entry.value > 0) '${entry.value} ${s.e.flower(entry.key).nameVi}',
  ].join(', ');
  return true;
}

void _chooseGrandma(ShopSession s, String choiceId) {
  if (choiceId != 'lend') {
    s.showNotice('Bà cụ gật đầu rồi đi.');
    return;
  }
  StockBatch? batch;
  for (final item in s.state.stock) {
    if (item.count > 0) {
      batch = item;
      break;
    }
  }
  if (batch == null) {
    s.showNotice('Hết hoa để cho nợ.');
    return;
  }
  final taken = batch.count >= 5 ? 5 : batch.count;
  final value = taken * s.e.flower(batch.flowerId).sellPrice;
  batch.count -= taken;
  if (batch.count == 0) s.state.stock.remove(batch);
  s._grandmaPay = value * 2;
  s.showNotice('Sáng mai bà trả ${formatK(s._grandmaPay)}.');
}

void _failWholesale(ShopSession s) {
  s._wholesaleLeft = 0;
  s.eventStatus = null;
  s.state.addReview(
    ReviewRecord(
      day: s.state.day,
      customerName: 'Khách sỉ',
      avatarId: 'chu_binh',
      occasionId: 'opening',
      stars: 2,
      comment: 'Lẵng hoa giao trễ.',
      outcome: 'leftUnserved',
    ),
  );
  s.showNotice('Khách sỉ không chờ nữa.');
}

void _charge(ShopSession s, double fraction) {
  s.state.money -= _money(_eventBase(s) * fraction);
}

int _eventBase(ShopSession s) {
  final days = s.state.recentRevenue;
  if (days.isEmpty) return 220000;
  return days.reduce((a, b) => a + b) ~/ days.length;
}

int _money(num vnd) => (vnd / 1000).round() * 1000;

void _retimes(ShopSession s, double mul, double? hours) {
  final now = s.state.elapsed;
  final end = hours == null
      ? s.e.dayRealSeconds
      : (now + hours * s.e.secondsPerHour).clamp(now, s.e.dayRealSeconds);
  final pending = s.state.pendingArrivals;
  if (mul < 1) {
    var drop = (pending.where((t) => t >= now && t < end).length * (1 - mul))
        .round();
    pending.removeWhere((t) {
      if (drop <= 0 || t < now || t >= end) return false;
      drop -= 1;
      return true;
    });
    return;
  }
  final inWindow = pending.where((t) => t >= now && t < end).length;
  final add = (inWindow * (mul - 1)).round();
  if (add <= 0) return;
  final span = (end - now).clamp(1.0, s.e.dayRealSeconds);
  for (var i = 0; i < add; i++) {
    pending.add(now + span * (i + 0.5) / add);
  }
  pending.sort();
}
