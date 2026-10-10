import 'dart:ui';

/// Colours that exist only in Phú's mock scripts (`ui.py`, `mock_tiem.py`),
/// not in design_tokens.json yet. TODO(Phú): move these into the tokens.
abstract final class MockPalette {
  static const shelfWood = Color(0xFFD9B89C);
  static const counterTop = Color(0xFFE8C9A8);
  static const bucket = Color(0xFF9FC7D9);

  /// Wrapping paper in the bouquet preview and paper chips ("Giấy kem").
  static const paperCream = Color(0xFFFFF1D6);

  /// Petal and centre colours per flower (`ui.py` PET).
  static const petals = <String, (Color, Color)>{
    'rose': (Color(0xFFF4A6C0), Color(0xFFE8738A)),
    'daisy': (Color(0xFFFFFFFF), Color(0xFFF5C451)),
    'baby': (Color(0xFFFFFFFF), Color(0xFFEAD8CC)),
    'carnation': (Color(0xFFF7B0A0), Color(0xFFE26D5A)),
    'sunflower': (Color(0xFFF5C451), Color(0xFF8A5A3C)),
    'lily': (Color(0xFFFFF0F3), Color(0xFFF4A6C0)),
    'tulip': (Color(0xFFE8738A), Color(0xFFC9546C)),
    'orchid': (Color(0xFFC9B6E4), Color(0xFF8E79B8)),
  };

  static (Color, Color) petalsFor(String flowerId) =>
      petals[flowerId] ?? petals['orchid']!;
}
