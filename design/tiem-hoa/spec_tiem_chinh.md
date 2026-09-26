# Spec màn hình Tiệm chính (v0.1)

Tác giả: Phú. Khung dọc 360×640, px logic. Màu, font, bo góc, bóng và chuyển động lấy từ `design_tokens.json`. Số liệu (mục tiêu, giá, độ tươi, kiên nhẫn) lấy từ `economy.json`. Chữ và số trong bản phác chỉ là ví dụ.

Màn này có hai trạng thái trong một ngày: **Chuẩn bị** (trước khi mở cửa) và **Đang mở cửa**. Bản phác `tiem_chinh_v0.1.png` là trạng thái Đang mở cửa.

## Bố cục

| Vùng | x, y, rộng × cao | Nội dung |
|---|---|---|
| Thanh trên | 0, 0, 360×48 | Giống bàn bó hoa: tiền, sao, ngày và giờ, thêm nút tạm dừng 30×28 ở góc phải (mở popup tạm dừng). |
| Mái hiên | 0, 48, 360×16 | Sọc `primary.base` và trắng rộng 12, mép dưới lượn tròn (vỏ sò). Trang trí. |
| Cảnh tiệm | 0, 64, 360×236 | Nền `bg.shop`. Kệ gỗ ở y 142. Trên kệ là tối đa 5 xô hoa (mỗi ô rộng 64, bắt đầu x 28), dưới mỗi xô có thanh độ tươi 36×4. Nhiều hơn 5 loài thì kệ cuộn ngang. |
| Hàng khách | y 196 đến 272 | Khách đứng từ trái sang phải, cách nhau khoảng 76. Dưới chân mỗi khách là thanh kiên nhẫn 36×4. Khách đầu hàng có bong bóng yêu cầu rút gọn (nhãn dịp và loài hoa chính). Tối đa 3 khách hiện trên màn, khách thứ 4 trở đi hiện số "+N" ở mép phải. |
| Quầy | 0, 276, 360×24 | Mặt quầy gỗ, trang trí. |
| Mục tiêu hôm nay | 12, 312, 336×92 | Thẻ `surface.card`. Tối đa 3 mục, mỗi dòng cao 18: ô tròn (xong thì tô `secondary.base`), mô tả, tiến độ "a/b" canh phải. Mục xong thì chữ chuyển `text.secondary`. |
| Nút chính | 12, 420, 336×52 | Nút `primary`. Nội dung đổi theo trạng thái (xem bên dưới). Dòng gợi ý `caption` ngay bên dưới ở y 488. |
| Thanh điều hướng | 0, 560, 360×80 | 5 nút: Kho hoa, Nâng cấp, Giá bán, Đánh giá, Sổ sách. Mỗi nút gồm ô icon 40×36 và nhãn `caption`. Icon thật sẽ vẽ sau, bản phác dùng chấm màu. |

## Trạng thái

**Chuẩn bị:** hàng khách để trống. Nút chính là "Mở cửa". Dòng gợi ý nhắc việc còn thiếu, ví dụ "Kho còn ít hoa, ghé chợ trước nhé". Ở trạng thái này thanh điều hướng có thêm nút "Chợ hoa" thay cho "Sổ sách".

**Đang mở cửa:** nút chính là "Bó hoa cho [tên khách đầu hàng]" và mở màn Bàn bó hoa. Chạm vào khách đầu hàng cũng mở màn đó. Khi hàng trống, nút chuyển sang dạng phụ (nền trắng, viền) với chữ "Đang chờ khách..." và không bấm được. Khi hết giờ bán thì chuyển sang màn Tổng kết cuối ngày.

## Chuyển động

- Khách mới đi vào từ mép phải rồi dừng ở chỗ trống cuối hàng (`motion.duration.slow`, `easing.standard`).
- Khách bỏ về: lắc nhẹ, hiện icon giận, rồi đi ra mép trái (`exit`).
- Xô hoa khi độ tươi xuống mức `wilting` thì hoa cụp nhẹ xuống.
- Hoàn thành một mục tiêu: ô tròn tô màu với hiệu ứng `pop`, đồng xu thưởng bay lên thanh tiền (`coinGain`).

## Chưa có trong v0.1

Hình minh họa thật cho khách, hoa và icon điều hướng, bố cục ngang cho máy tính bảng, âm thanh.
