/// FNV-1a 32-bit over the UTF-16 code units of [text]. Same input, same
/// number on every platform and run (unlike [Object.hash]), so market
/// prices stay put across reloads.
int fnv1a32(String text) {
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h ^= c & 0xff;
    h = (h * 0x01000193) & 0xffffffff;
    h ^= c >> 8;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}
