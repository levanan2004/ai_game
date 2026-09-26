# Spec popup, màn mở đầu và hướng dẫn ngày đầu (v0.1)

Tác giả: Phú. Khung dọc 360×640, px logic. Màu, font, bo góc, bóng và chuyển động lấy từ `design_tokens.json`. Số liệu (hạng, ngày lễ, hệ số) lấy từ `economy.json`. Hình hoa, khách, nhân viên lấy từ `design/assets/`. Chữ và số trong bản phác chỉ là ví dụ. Bảng tổng hợp: `popup_mo_dau_sheet_v0.1.png`.

## Quy tắc chung cho mọi popup

- Nền phía sau phủ `bg.overlay`. Thẻ `surface.card`, bo `radius.lg`, bóng đặc lệch 4px màu `surface.borderStrong`.
- Vào theo `motion.pattern.popupIn`, ra theo `popupOut`.
- Popup chúc mừng (lên hạng, mở khóa, ngày lễ) có hoa giấy: khoảng 40 mảnh 6×3 màu `primary.base`, `accent.base`, `secondary.base`, `status.info`, rơi từ trên xuống trong 1,2 giây rồi mờ dần. Chỉ chạy một lần.
- Chạm ra ngoài thẻ không đóng popup chúc mừng, để người chơi không lỡ tay bỏ qua. Popup tạm dừng thì chạm ra ngoài bằng bấm "Tiếp tục".
- Nhiều popup cùng lúc thì xếp hàng theo thứ tự: lên hạng, mở khóa, rồi ngày lễ. Mỗi lần chỉ hiện một cái.

## 1. Popup tạm dừng (`popup_tam_dung_v0.1.png`)

Mở từ nút tạm dừng ở thanh trên (Tiệm chính và Bàn bó hoa). Game cũng tự mở popup này khi tab trình duyệt bị ẩn.

| Phần tử | Vị trí, kích thước | Ghi chú |
|---|---|---|
| Thẻ | x 40, y 170, 280×300 | |
| Tiêu đề | tâm y 206 | "Tạm dừng", `title` 24. Dòng phụ `caption`: "Giờ bán và khách đang đứng yên". |
| Nút | x 64, rộng 232 | "Tiếp tục" (`primary`, cao 48, y 262), "Xem hướng dẫn" (viền, cao 44, y 322), "Về màn đầu" (viền, cao 44, y 378). |
| Ghi chú | tâm y 444 | `caption` "Tiến độ lưu tới sáng nay". |

Khi tạm dừng, đồng hồ ngày, thanh kiên nhẫn và độ tươi đều dừng. "Xem hướng dẫn" mở lại các bước hướng dẫn ở dạng xem (không bắt làm theo). "Về màn đầu" không lưu giữa ngày: bản lưu vẫn là sáng hôm đó, nên khi chơi tiếp người chơi bắt đầu lại ngày đang chơi. Khoa báo lại nếu cách này khó làm.

## 2. Popup lên hạng (`popup_len_hang_v0.1.png`)

Hiện sau khi bấm "Sang ngày mới" ở Tổng kết, nếu tổng số bó đã bán vượt `minBouquetsSold` của hạng tiếp theo trong `shopRanks`.

| Phần tử | Vị trí, kích thước | Ghi chú |
|---|---|---|
| Thẻ | x 32, y 150, 296×340 | |
| Huy hiệu | tâm (180, 196), bán kính 52 | Nền `accent.soft`, viền `accent.base` 4px, số ngôi sao bằng số hạng (từ 1 đến 5, xếp một hàng). |
| Nhãn | tâm y 257, 128×26 | Chip `primary.base` chữ trắng "LÊN HẠNG [rank]". |
| Tên hạng | tâm y 296 | `nameVi`, `title` 24. Dòng phụ "Đã bán tổng cộng [minBouquetsSold] bó hoa". |
| Hộp thay đổi | x 52, y 344, 256×72 | Nền `surface.sunken`. Ba dòng `body` 11: "Mục tiêu mỗi ngày lớn hơn, thưởng nhiều hơn", "Vùng xanh khi gói hoa hẹp lại một chút", và dòng màu `text.secondary` "Hạng tiếp theo: [minBouquetsSold của hạng sau] bó". Ở hạng cao nhất thì dòng cuối là "Đây là hạng cao nhất". |
| Nút | x 56, y 434, 248×44 | "Tuyệt quá!" (`primary`). |

Chuyển động: huy hiệu phóng từ 0 lên 1 với `easing.pop`, các ngôi sao sáng lần lượt cách nhau 80ms, rồi nhãn và chữ hiện dần.

## 3. Popup mở khóa (`popup_mo_khoa_v0.1.png`)

Hiện ngay sau khi người chơi xác nhận mở khóa một loài hoa, loại giấy hoặc loại nơ ở màn Nâng cấp.

| Phần tử | Vị trí, kích thước | Ghi chú |
|---|---|---|
| Thẻ | x 40, y 170, 280×300 | |
| Tiêu đề | tâm y 200 | `heading` 20 màu `primary.base`: "Mở khóa hoa mới!", "Mở khóa giấy mới!" hoặc "Mở khóa nơ mới!". |
| Hình | tâm (180, 270), vòng nền bán kính 50 `accent.soft` | Ảnh từ `assets/flowers`, `papers` hoặc `ribbons`, cỡ 96. |
| Tên | tâm y 340 | `nameVi`, `title` 22. |
| Dòng phụ | tâm y 366 | Hoa: "Đã có bán ở Chợ hoa từ sáng mai". Giấy hoặc nơ: "Đã có trong khay ở Bàn bó hoa". |
| Nút | y 398, cao 44 | Hoa: "Đóng" (viền) và "Ra chợ" (`primary`). Giấy và nơ chỉ có một nút "Đóng" rộng 232. |

"Ra chợ" chỉ hiện khi đang ở buổi sáng. Nếu mở khóa ở trạng thái Chuẩn bị (đã qua chợ) thì chỉ có nút "Đóng".

## 4. Ngày lễ (`poster_ngay_le_v0.1.png`, `popup_ngay_le_v0.1.png`)

Dữ liệu từ `holidays.list`. Ngày trong năm game tính theo `yearLengthDays`.

**Áp phích ở Chợ hoa:** từ `posterDaysBefore` ngày trước ngày lễ, Chợ hoa có thẻ 336×84 ở y 86, đẩy danh sách hoa xuống. Nền `primary.soft`, viền `primary.base`. Dòng nhỏ "Còn [n] ngày tới" (hoặc "Ngày mai là"), tên lễ `heading` 19, dòng "Khách thích: [featuredFlowers]", và hình các loài hoa đó ở bên phải (tối đa 3 hình). Loài nào chưa mở khóa thì hình mờ 50% kèm nhãn nhỏ "Khóa".

**Popup sáng ngày lễ:** hiện khi vào Chợ hoa đúng ngày lễ, sau popup lên hạng và mở khóa nếu có.

| Phần tử | Vị trí, kích thước | Ghi chú |
|---|---|---|
| Thẻ | x 32, y 150, 296×330 | Dải đầu cao 70 nền `primary.base`: "Hôm nay là" (`caption` trắng) và tên lễ (`title` 22 trắng). |
| Hình hoa | y 264, cỡ 72 | Các loài trong `featuredFlowers`, tối đa 3, dàn đều. |
| Dòng chính | tâm y 312 | "Khách thích [danh sách]", `heading` 15. |
| Ba dòng hiệu ứng | từ y 344, cách 22 | Chấm màu 8px và chữ `body` 12. "Khách đông gấp [customerMultiplier] lần" và "Tiền boa nhiều hơn" dùng chấm `status.success`. "Giá hoa ở chợ cao hơn" dùng chấm `status.warning`. Số nhân viết kiểu Việt: 1,8 chứ không phải 1.8. |
| Nút | x 56, y 420, 248×44 | "Ra chợ thôi". |

Trong ngày lễ, không thêm chip riêng. Ô ngày trên thanh trên (Chợ hoa, Tiệm, Bàn bó hoa) đổi chữ "Ngày N" thành ngày lễ dạng ngắn, ví dụ "14/2 · Sáng" hoặc "14/2 · 15:05", nền `primary.soft`, viền 1.5 `primary.base`, chữ `primary.pressed`. Tên đầy đủ chỉ nằm trên áp phích và popup. Hoa trong `featuredFlowers` ở Chợ hoa có nhãn "Đang hot".

## 5. Màn mở đầu (`man_mo_dau_v0.1.png`)

| Vùng | Vị trí, kích thước | Ghi chú |
|---|---|---|
| Nền | toàn màn | `bg.shop`, trên cùng là mái hiên sọc `primary.base` và trắng cao 40 như Tiệm chính. |
| Tên game | tâm y 110 và 154 | Hai dòng Baloo 2 cỡ 44, dòng trên `primary.pressed`, dòng dưới `primary.base`. Tên chính thức là "Tiệm Hoa Sớm Mai" (An chốt ngày 26/9). |
| Tranh tiệm | x 40, y 196, 280×210 | Cô chủ (`upgrades/staff.png`) đứng sau quầy gỗ, trên quầy là 5 loài hoa. |
| Nút chính | x 56, y 440, 248×56 | "Chơi tiếp" khi có bản lưu, "Bắt đầu" khi chưa có. Dưới nút là dòng `caption` "Ngày [n] · [tên hạng] · [tiền]". |
| Nút phụ | x 96, y 536, 168×40 | "Chơi mới" (viền), chỉ hiện khi có bản lưu. Bấm thì hỏi lại: "Bắt đầu lại từ ngày 1? Tiến độ hiện tại sẽ mất." với hai nút "Hủy" và "Chơi mới" (nút này màu `status.danger`). |
| Phiên bản | tâm y 620 | `caption` màu `text.disabled`. |

Chuyển động: tên game nhảy vào bằng `easing.pop`, các bông hoa trên quầy đung đưa nhẹ lặp lại (xoay ±3°, chu kỳ 2 giây).

## 6. Hướng dẫn ngày đầu (`huong_dan_v0.1.png`)

Chỉ chạy ở ngày 1 khi chưa có cờ `tutorialDone` trong bản lưu. Mỗi bước phủ nền tối (`bg.overlay`, đậm hơn popup một chút) lên cả màn, khoét một lỗ bo tròn quanh đúng phần tử cần bấm, viền lỗ `accent.base` 3px nhấp nháy nhẹ. Chỉ phần tử trong lỗ bấm được. Thẻ lời thoại 312×104 có hình cô chủ bên trái, tiêu đề `heading` 15, lời dặn `body` 12 tối đa 2 dòng, và số bước "n/8" ở góc. Thẻ nằm ở nửa màn không che phần tử đang chỉ. Góc dưới bên phải có chữ trắng "Bỏ qua". Bỏ qua thì đặt `tutorialDone` luôn.

| Bước | Màn | Chỉ vào | Lời dặn | Xong khi |
|---|---|---|---|---|
| 1 | Chợ hoa | Nút cộng của hoa hồng | "Chào chủ tiệm mới! Bấm dấu + để mua một bó hoa hồng nhé." | Giỏ có ít nhất 1 bó |
| 2 | Chợ hoa | Nút chính | "Mua đủ rồi thì bấm để mang hoa về tiệm." | Sang Tiệm chính |
| 3 | Tiệm chính | Nút "Mở cửa" | "Mở cửa đón khách thôi!" | Mở cửa |
| 4 | Tiệm chính | Khách đầu tiên và bong bóng | "Khách cần hoa gì thì ghi trong bong bóng. Chạm vào khách để bó hoa." | Mở Bàn bó hoa |
| 5 | Bàn bó hoa | Phiếu khách | "Đây là yêu cầu của khách: loài hoa, số cành, giấy và nơ." | Chạm vào thẻ lời thoại |
| 6 | Bàn bó hoa | Khay hoa, rồi khay giấy và nơ | "Chạm thẻ hoa để thêm cành, rồi chọn giấy và nơ cho đúng phiếu." | Bó đủ số cành và đã chọn giấy |
| 7 | Bàn bó hoa | Nút "Gói & giao hoa", rồi nút giữ của mini-game | "Giữ nút, thả tay khi vòng nằm trong vùng xanh để được boa thêm." | Thả tay lần đầu |
| 8 | Popup đánh giá | Hàng sao | "Bó càng đúng yêu cầu thì càng nhiều sao và tiền boa. Chúc tiệm đắt khách!" | Bấm "Tiếp tục" |

Trong lúc hướng dẫn, khách đầu tiên luôn đặt một đơn dễ, chỉ dùng hoa, giấy và nơ đã mở từ đầu (`start`), và thanh kiên nhẫn của khách này đứng yên. Khách thứ hai chỉ vào sau khi xong bước 8. Đồng hồ ngày cũng dừng từ bước 3 đến bước 8. Cuối ngày 1, ở Tổng kết có thêm một lời nhắc không bắt buộc chỉ vào nút "Nâng cấp": "Có tiền rồi thì ghé Nâng cấp để tiệm xịn hơn nhé."
