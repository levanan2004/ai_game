/// Days whose summary may offer the web install, once per device.
const installOfferEndDays = {1, 3, 5, 7, 9};

/// Web only, and only once. Day 1 qualifies when that day has just ended.
/// Day 2 or later qualifies on entry or at the summary, so a shop already
/// hundreds of days in still sees the card the next time it is opened.
bool installOfferDue({
  required bool web,
  required bool installed,
  required bool alreadySeen,
  required int day,
  required bool dayJustEnded,
}) {
  if (!web || installed || alreadySeen || day < 1) return false;
  if (day == 1) return dayJustEnded && installOfferEndDays.contains(day);
  return true;
}
