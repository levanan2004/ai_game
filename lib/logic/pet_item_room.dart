/// Small types of the pet room (SPEC_phong_pet_vat_pham): what a card of the
/// item picker shows, how many copies of an item there are, and the receipt
/// popups for an item that arrives as a gift.
library;

import 'rewards.dart';

/// How a card of the item picker (P2, P5d) looks for the pet in the room.
enum PetItemCardState {
  /// This pet wears it: green frame, tick, "Đang đeo".
  worn,

  /// A copy is in the store room: "Đeo".
  inStock,

  /// Every copy is on other pets: chip "Đang ở {pet}".
  elsewhere,

  /// Not owned, enough money: a price button.
  canPay,

  /// Not owned, not enough money: a faded price button.
  short,
}

/// Copies of one item: all of them, the ones on pets, the ones left over.
class PetItemCounts {
  const PetItemCounts({required this.owned, required this.worn});

  final int owned;

  /// Copies worn by any pet.
  final int worn;

  /// Copies in the store room (not worn).
  int get spare => owned - worn < 0 ? 0 : owned - worn;
}

/// Where a received item came from.
enum PetItemGiftKind {
  /// The season reward of the Mị lực board (P4a, P4c).
  rank,

  /// A mystery visitor (P4b, P4c).
  mystery,
}

/// One received item waiting to be shown (P4). The item is in the store room
/// already; the popup only tells the player and offers to sell a spare.
class PetItemGift {
  const PetItemGift({
    required this.itemId,
    required this.kind,
    this.rank,
    this.extras = const [],
  });

  final String itemId;
  final PetItemGiftKind kind;

  /// The player's rank, for [PetItemGiftKind.rank].
  final int? rank;

  /// The other lines that came with it (Pha lê, Giọt hoa of a season reward).
  final List<RewardItem> extras;
}
