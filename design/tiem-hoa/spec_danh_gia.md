# Spec phần Đánh giá có nhận xét (v0.1)

Tác giả: Phú. Khung dọc 360×640, px logic. Màu, font, bo góc, bóng và chuyển động lấy từ `design_tokens.json`. Quy tắc chấm sao lấy từ `economy.json` (`customers.reviewStars`, `ratingWindow`), còn bộ câu nhận xét do Hà Phương cung cấp. Tên khách, câu nhận xét và mọi con số trong bản phác chỉ là ví dụ.

Phần này có hai chỗ hiển thị: **popup đánh giá** hiện ngay sau khi giao hoa, và **màn Đánh giá** để xem lại toàn bộ.

## 1. Popup đánh giá sau khi giao hoa (`popup_danh_gia_v0.1.png`)

Hiện trên màn Bàn bó hoa sau khi mini-game gói hoa kết thúc. Nền phía sau phủ `bg.overlay`.

| Phần tử | Vị trí, kích thước | Ghi chú |
|---|---|---|
| Thẻ popup | x 32, y 150, 296×300 | `surface.card`, bo `radius.lg`, bóng đặc lệch 4px màu `surface.borderStrong`. |
| Ảnh khách | tâm (180, 194), bán kính 28 | Cùng hình khách ở phiếu yêu cầu. |
| Tên khách | tâm y 238 | `heading` 18. |
| Chip dịp | tâm y 261 | Màu theo `color.occasion.*`. |
| 5 ngôi sao | tâm y 296, mỗi sao rộng 26, cách 30 | Sao sáng `currency.star`, sao tắt `freshness.track`. |
| Bong bóng nhận xét | x 48, y 320, 264×52 | Nền `surface.sunken`, bo `radius.md`, có đuôi nhọn chĩa lên sao. Chữ `body` 12, canh giữa, tối đa 2 dòng. Câu dài hơn thì cắt bằng dấu "...". |
| Dòng tiền | y 390 và 408 | "Tiền hoa" và "Tiền boa". Số tiền boa màu `status.success`. Không có tiền boa thì ẩn dòng đó. |
| Nút Tiếp tục | x 48, y 464, 264×48 | Nút `primary`, nằm dưới thẻ. |

Chuyển động: thẻ vào theo `motion.pattern.popupIn`. Sao sáng lần lượt từng ngôi, mỗi ngôi dùng `easing.pop`, cách nhau khoảng 80ms. Bong bóng nhận xét hiện sau ngôi sao cuối. Tiền bay lên thanh tiền theo `coinGain` khi bấm Tiếp tục. Bấm Tiếp tục hoặc chạm ra ngoài thẻ thì đóng, sau đó khách tiếp theo lên quầy.

**Khách bỏ về** (hết kiên nhẫn) thì không hiện popup, vì người chơi đang bận việc khác. Thay vào đó, trên màn Tiệm chính, khách hiện bong bóng nhỏ có icon giận kèm số sao trong khoảng 1,5 giây rồi mới đi ra. Nhận xét của khách đó vẫn được lưu vào màn Đánh giá.

## 2. Màn Đánh giá (`danh_gia_v0.1.png`)

Mở từ nút "Đánh giá" ở thanh điều hướng của Tiệm chính, hoặc khi chạm vào ô sao trên thanh trên.

| Vùng | x, y, rộng × cao | Nội dung |
|---|---|---|
| Thanh tiêu đề | 0, 10, 360×32 | Nút quay lại 36×32 bên trái, tiêu đề "Đánh giá của khách" `heading` 20 canh giữa. |
| Thẻ tổng quan | 12, 54, 336×128 | Bên trái là điểm trung bình (Baloo 2 cỡ 40, một chữ số thập phân, dấu phẩy kiểu Việt), 5 sao tô theo điểm (cho phép tô nửa sao), dòng phụ "[ratingWindow] khách gần nhất". Bên phải là 5 thanh phân bố từ 5 sao xuống 1 sao, rộng 136, cao 8, màu `currency.star`, kèm số lượng. |
| Chip lọc | y 198, cao 28 | Tất cả, Hôm nay, 5 sao, 4 sao, 3 sao trở xuống. Chip đang chọn nền `primary.base` chữ trắng. Hàng chip cuộn ngang khi tràn. |
| Danh sách nhận xét | từ y 240, mỗi thẻ 336×96, cách nhau 10 | Cuộn dọc, mới nhất ở trên. Mỗi thẻ gồm ảnh khách (bán kính 16), tên, sao nhỏ (rộng 12), chip dịp ở góc phải, câu nhận xét `body` 12 tối đa 2 dòng, và dòng phụ `caption` ghi ngày cùng bó hoa đã giao (ví dụ "Ngày 3 · 3 Hồng · giấy kem · nơ đỏ"). Nếu khách bỏ về thì dòng phụ ghi "Khách bỏ về". |
| Trạng thái trống | giữa vùng danh sách | Khi chưa có nhận xét hoặc bộ lọc không có kết quả: chữ `text.secondary` "Chưa có nhận xét nào". |

Điểm trung bình và thanh phân bố chỉ tính trên `ratingWindow` khách gần nhất, đúng như cách `economy.json` tính sao của tiệm. Danh sách thì giữ tối đa 50 nhận xét gần nhất để bản lưu trên trình duyệt không phình to. Khách có `reviewStars` bằng `null` (đi ngang qua khi hàng đầy) thì không có thẻ nhận xét.

## Dữ liệu mỗi nhận xét cần lưu

`day`, `customerName`, `avatarId`, `occasionId`, `stars`, `commentId` (hoặc chuỗi câu), `bouquet` (loài hoa và số cành, `paperId`, `ribbonId`, có thể rỗng nếu khách bỏ về), `outcome` (great, okay, unhappy, leftUnserved, onlineMissed).

## Chưa có trong v0.1

Hình minh họa thật cho khách, icon giận, âm thanh khi sao sáng, trả lời nhận xét của khách.
