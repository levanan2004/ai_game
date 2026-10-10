# Spec Chợ hoa buổi sáng và Tổng kết cuối ngày (v0.1)

Tác giả: Phú. Khung dọc 360×640, px logic. Màu, font, bo góc, bóng và chuyển động lấy từ `design_tokens.json`. Mọi số liệu (giá, cỡ bó, số ngày tươi, giá mở khóa, tiền thuê, hạng tiệm, mục tiêu) đọc từ `economy.json`. Số trong bản phác chỉ minh họa một trạng thái ví dụ.

Vòng một ngày: **Chợ hoa** (không tính giờ), rồi **Tiệm chính** (mở cửa 8:00 đến 20:00, 240 giây thật), rồi **Tổng kết** (không tính giờ), rồi quay lại Chợ hoa của ngày hôm sau.

## 1. Chợ hoa buổi sáng (`cho_hoa_v0.1.png`)

| Vùng | x, y, rộng × cao | Nội dung |
|---|---|---|
| Thanh trên | 0, 0, 360×48 | Ô tiền và ô "Ngày N · Sáng". Ô tiền hiển thị tiền mặt **trừ đi** giỏ hàng hiện tại, để người chơi thấy mua xong còn bao nhiêu. Âm thì chữ `status.danger`. |
| Tiêu đề | y 58 | "Chợ hoa buổi sáng" (`title` 22) và một dòng gợi ý `caption`. |
| Băng thông báo | 12, 106, 336×34 | Nền `accent.soft`, viền `accent.base`. Chỉ hiện khi có chuyện đáng báo, theo thứ tự ưu tiên: đang dùng mua chịu (`safetyNet`), ngày lễ sắp tới (`holidays.posterDaysBefore`), hoa đang lên giá (`holidayPriceWindowDays`). Không có gì thì ẩn băng và danh sách dịch lên. |
| Danh sách hoa | từ y 152, mỗi hàng 336×76, cách 8 | Cuộn dọc. Hoa đã mở khóa ở trên, hoa khóa ở dưới. |
| Thanh giỏ hàng | 0, 556, 360×84 | Nền trắng, viền trên `surface.border`. Bên trái là "N bó · M cành" và tổng tiền (`number` 20). Bên phải là nút `primary` 200×52 "Mua & mở cửa". |

**Một hàng hoa đã mở khóa:** ô ảnh 52×52 nền `surface.sunken`, tên hoa (`heading` 15), dòng "Bó [bundleSize] cành · tươi [freshnessDays] ngày", dòng tồn kho "Kho: X cành, còn Y ngày" kèm thanh độ tươi 28×4 của lô cũ nhất (hoặc "Kho: trống"). Góc phải trên là giá một bó (`buyPrice × bundleSize`, nhân hệ số ngày lễ nếu có). Góc phải dưới là bộ chọn số lượng: nút trừ viền 28×28, số bó, nút cộng nền `primary.base`. Số bó bằng 0 thì nút trừ mờ đi.

**Một hàng hoa bị khóa:** phủ lớp `bg.base` mờ 60%, chữ `text.secondary`, dòng "Mở khóa: [unlockCost] ở Nâng cấp", và nhãn "Khóa" thay cho bộ chọn. Chạm vào hàng thì mở màn Nâng cấp.

**Quy tắc bấm:** nút cộng bị tắt khi mua thêm sẽ vượt tiền mặt, hoặc vượt `minMarketBudget` khi đang mua chịu. Giỏ trống thì nút chính đổi thành "Mở cửa luôn" (kiểu viền), để người chơi còn hoa trong kho vẫn mở cửa được. Bấm nút chính thì trừ tiền, cộng hoa vào kho với độ tươi đầy, rồi chuyển sang Tiệm chính ở trạng thái Chuẩn bị.

## 2. Tổng kết cuối ngày (`tong_ket_v0.1.png`)

Hiện ngay khi đồng hồ tới `closeHour` và khách cuối cùng đã xong. Nền `bg.shop`.

| Vùng | x, y, rộng × cao | Nội dung |
|---|---|---|
| Tiêu đề | tâm y 30 và 54 | "Tổng kết Ngày N" (`title` 22), dòng phụ gồm tên hạng tiệm và giờ mở cửa. |
| Thẻ lãi | 12, 72, 336×86 | "Lãi hôm nay", số lãi lớn (`display` 30) màu `status.success` khi dương, `status.danger` khi âm, kèm tiền mặt sau khi kết sổ. Số chạy từ 0 lên trong khoảng 600ms. |
| Ba ô thống kê | y 170, mỗi ô 104×64, cách 12 | Bó đã bán (`primary.base`), Khách bỏ về (`status.warning`), Cành bị héo (`freshness.wilting`). |
| Thu chi | 12, 246, 336×168 | Từng dòng: Tiền hoa, Tiền boa, Thưởng mục tiêu, Nhập hoa buổi sáng, Tiền thuê và điện nước, Phí duy trì nâng cấp (chỉ hiện khi có). Khoản thu màu xanh có dấu cộng, khoản chi màu `status.danger` có dấu trừ. Dòng "Cộng" ở dưới đường kẻ. |
| Đánh giá | 12, 426, 164×78 | Sao hiện tại, nhãn thay đổi so với sáng nay ("tăng 0,2" nền `secondary.soft`, hoặc "giảm 0,1" nền `primary.soft`, không đổi thì ẩn), số nhận xét mới trong ngày. |
| Hạng tiệm | 184, 426, 164×78 | Tên hạng hiện tại, thanh tiến độ tới hạng sau (theo `shopRanks.minBouquetsSold`), dòng "Còn X bó để lên hạng". Đạt hạng cao nhất thì thay bằng "Hạng cao nhất". |
| Dòng hoa héo | 12, 514, 336×34 | Nền `surface.sunken`. Liệt kê hoa đã bỏ đi, ví dụ "Bỏ đi 4 cành cúc họa mi đã héo". Không có hoa héo thì hiện "Không có cành nào bị héo, giỏi lắm!" màu `status.success`. |
| Nút | y 560, cao 52 | "Xem nhận xét" (viền, 160 rộng) mở màn Đánh giá lọc "Hôm nay". "Sang ngày mới" (`primary`, 164 rộng) lưu tiến độ, trừ 1 ngày tươi của mọi cành, rồi mở Chợ hoa ngày hôm sau. |

**Thứ tự hiện:** thẻ lãi, ba ô thống kê, thu chi, rồi hai thẻ dưới, mỗi phần trượt lên và hiện dần cách nhau 80ms (`easing.standard`). Nếu hôm nay lên hạng hoặc mở khóa được thứ gì mới thì popup chúc mừng hiện **sau** khi người chơi bấm "Sang ngày mới", trước khi vào Chợ hoa.

## Chưa có trong v0.1

Hình hoa thật, âm thanh đếm tiền, popup lên hạng và mở khóa (sẽ có trong spec popup).
