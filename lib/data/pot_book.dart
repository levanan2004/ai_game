/// Tiệm Chậu Hoa and Sổ sưu tầm: which pots belong to which tab, in the
/// order of the spec (SPEC_tiem_chau_hoa.md §8.1, SPEC_C_final.md §1).
///
/// Group ids are the `set` of a pot (`PotDef.set`); `linhVat` is the eight
/// old pots, whose `set` is `linhVat` since the pots acquisition block.
library;

/// Tabs of the shop and pages of the book, left to right.
const potGroupIds = ['chomSao', 'sonHai', 'linhVat'];

/// `potCollections` id for each group (the reward of finishing it).
const potGroupCollection = {
  'chomSao': 'chomSao',
  'sonHai': 'sonHai1',
  'linhVat': 'tanThu',
};

/// Numbering inside each group: the number printed on a cell of the book
/// and the tie-break when two pots cost the same in the shop.
const potBookOrder = <String, List<String>>{
  'chomSao': [
    'chau_bach_duong',
    'chau_kim_nguu',
    'chau_song_tu',
    'chau_cu_giai',
    'chau_su_tu',
    'chau_xu_nu',
    'chau_thien_binh',
    'chau_ho_cap',
    'chau_nhan_ma',
    'chau_ma_ket',
    'chau_bao_binh',
    'chau_song_ngu',
  ],
  'sonHai': [
    'chau_thao_thiet',
    'chau_cung_ky',
    'chau_hon_don',
    'chau_dao_ngot',
    'chau_cuu_vi_ho',
    'chau_tat_phuong',
    'chau_ky_lan',
    'chau_chuc_long',
    'chau_con_bang',
    'chau_bach_trach',
    'chau_tinh_ve',
    'chau_de_giang',
  ],
  'linhVat': [
    'koi',
    'crane',
    'nghe',
    'tortoise',
    'tiger',
    'qilin',
    'phoenix',
    'dragon',
  ],
};
