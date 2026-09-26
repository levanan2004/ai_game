# Spec màn hình Bàn bó hoa (v0.1)

Tác giả: Phú. Khung dọc 360×640 (đơn vị px logic, co giãn đều theo khung của Khoa). Mọi màu, font, bo góc, bóng và chuyển động lấy từ `design_tokens.json`, không viết cứng mã màu trong code. Mọi số liệu (giá, số cành, độ tươi, mốc độ khớp, tiền boa) lấy từ `economy.json` của Hà Phương.

Phong cách bám theo Tiệm Trà Nhỏ: nền kem, dải mái hiên sọc hồng trắng dưới thanh trên cùng, khách nói bằng bong bóng lời thoại, có thanh kiên nhẫn.

## Bố cục (tọa độ y tính từ trên xuống)

| Vùng | x, y, rộng × cao | Nội dung |
|---|---|---|
| Thanh trên | 0, 0, 360×48 | 3 viên thuốc bo tròn (radius pill): tiền (icon đồng xu `currency.coin`), điểm sao (`currency.star`), ngày và giờ. Chữ số dùng style `number`. |
| Mái hiên | 0, 48, 360×6 | Sọc `primary.base` và trắng, mỗi sọc rộng 12. Chỉ để trang trí. |
| Phiếu khách | 12, 58, 336×116 | Thẻ `surface.card`, radius `lg`, bóng `card`. Bên trái: avatar 56 với vòng kiên nhẫn (nét 5, màu chạy từ `freshness.fresh` qua `aging` sang `wilting` khi còn dưới 50% và 25%). Bên phải: nhãn dịp (màu theo `color.occasion.*`), câu thoại (style `body`, tối đa 2 dòng), rồi hàng chip yêu cầu (loài hoa kèm số cành, giấy, nơ). |
| Khung bó hoa | 12, 186, 336×236 | Nền `bg.base`. Bó hoa vẽ ở giữa, cành mới thêm vào xếp tỏa quanh tâm. Giấy gói vẽ phía sau cành, nơ ở cổ bó. |
| Thanh độ khớp | 80, 398, 200×12 | Nằm trong khung bó hoa. Màu thanh là `match.low`, `match.ok` hoặc `match.perfect` tùy mức. Hai vạch mốc (mặc định 50% và 85%, lấy từ `economy.json`). Phần trăm hiện bên phải. |
| Tab | 12, 432, mỗi tab 108×36, cách nhau 6 | Hoa, Giấy, Nơ. Tab đang chọn tô `primary.base`, chữ trắng. |
| Khay chọn | 12, 478, thẻ 72×92, cách nhau 8 | Cuộn ngang. Mỗi thẻ có icon, tên, "còn N" và thanh độ tươi 4px (chỉ tab Hoa). Hết hàng thì làm mờ bằng `text.disabled` và không bấm được. |
| Hàng nút | 12, 588, cao 44 | "Làm lại" (104 rộng, nền trắng, viền) và "Gói & giao hoa" (phần còn lại, `primary.base`). Nút giao bị khóa cho tới khi bó có ít nhất 1 cành và đã chọn giấy. |

## Thao tác

- Chạm thẻ hoa để thêm 1 cành. Cành bay từ thẻ vào bó (motion `addStem`). Số cành tối đa mỗi bó lấy từ `economy.json`.
- Chạm một cành trong bó để bỏ cành đó ra, cành trả về kho.
- Chạm thẻ giấy hoặc nơ để chọn. Mỗi bó chỉ có 1 giấy và 1 nơ, chọn cái khác sẽ thay cái cũ.
- Nhấn giữ thẻ khoảng 400ms để hiện popup thông tin: tên loài, số ngày còn tươi, giá nhập.
- "Làm lại": trả toàn bộ cành về kho, bỏ giấy và nơ.
- "Gói & giao hoa": mở mini-game gói hoa (bên dưới), rồi khách trả tiền.

## Mini-game gói hoa (chỉ có thưởng)

Một vòng tròn lớn dần khi người chơi giữ nút. Thả tay khi vòng nằm trong vùng xanh thì khách boa thêm và bật hiệu ứng tim. Thả trượt thì bó hoa vẫn giao và tính tiền bình thường, chỉ không có tiền boa. Không bao giờ làm khách bỏ về hay trừ sao vì trượt mini-game. Độ rộng vùng xanh và tiền boa lấy từ `economy.json`.

## Trạng thái cần có

1. Chưa có cành nào: khung bó hoa hiện chữ gợi ý "Chạm hoa bên dưới để bắt đầu bó" (style `caption`, màu `text.secondary`).
2. Đang bó: như bản phác.
3. Khách sắp hết kiên nhẫn (dưới 25%): vòng kiên nhẫn đỏ và avatar lắc nhẹ mỗi 2 giây.
4. Giao xong: đồng xu bay lên thanh tiền (motion `coinGain`), phiếu khách trượt ra, khách tiếp theo trượt vào.

## Chưa có trong v0.1

Hình minh họa hoa và khách thật (hiện tạm vẽ bằng hình khối), âm thanh, và bố cục ngang cho máy tính bảng.
