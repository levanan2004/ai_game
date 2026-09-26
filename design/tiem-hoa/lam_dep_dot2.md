# Làm đẹp đợt 2 (mục 12 của Khoa) (v0.1, Phú, 26/9)

Theo cách trình bày của 2 game tham khảo (Tiệm Trà Nhỏ, SpaAnimal). Chỉ đổi màu, bo góc, bóng và cách xếp khung, không đổi luật chơi hay thêm màn. Token mới đã có trong `design_tokens.json` (`color.header`, `color.backdrop`, `color.nav`). Không có ảnh mới cần thêm vào `pubspec.yaml`, nên bấm `R` là thấy.
Bản phác: `lam_dep_dot2_tiem_v0.1.png` (màn Tiệm) và `lam_dep_dot2_desktop_v0.1.png` (máy tính). Script `mock_lamdep2.py`.

Làm theo thứ tự dưới. Nếu gần chạm 85% lượt dùng thì dừng ở mục nào cũng được, mỗi mục đứng riêng.

## 1. Khung game giữa màn trên máy tính
- Hiện giờ trên máy tính game dính mép trái, bên phải trắng trống.
- Màn rộng hơn 480: khung game rộng 390, cao tối đa 844, căn giữa cả ngang lẫn dọc, bo `radius.lg` + 4 (24), bóng `shadow.popup`.
- Ngoài khung: nền `backdrop.base`. Nếu dễ thì phủ thêm `assets/scenes/shop_bg.png` làm mờ (blur khoảng 18, độ đậm 35%); không dễ thì chỉ dùng màu.
- Màn từ 480 trở xuống (điện thoại): giữ nguyên, full màn.

## 2. Thanh trên thành một dải màu
- Nền dải: gradient dọc từ `header.top` xuống `header.bottom`, cao 56 (cộng vùng an toàn trên điện thoại), bo 2 góc dưới `radius.lg`. Nội dung màn nằm dưới và lấn lên dưới góc bo (cảnh tiệm bắt đầu từ y 44).
- Các chip tiền, sao, ngày giữ nguyên chỗ và chữ, nhưng nền đổi thành `header.chip` (trắng 85%), bỏ viền, cao 30.
- Nút bánh răng: tròn 32, nền `header.chip`, icon 22.
- Áp cho mọi màn có thanh trên (Tiệm, Bàn bó hoa, Chợ, Nâng cấp, Đánh giá, Sổ sách). Màn Đại thiện nhân giữ nền chùa riêng.

## 3. Thanh dưới có ô đang chọn rõ ràng
- Nền `nav.bg`, bo 2 góc trên `radius.lg`, bỏ đường kẻ trên.
- Ô đang chọn: viên thuốc 56×32 nền `nav.activePill` sau icon, chữ `nav.activeLabel` đậm (Baloo 11, 800).
- Ô khác: icon màu đầy đủ, chữ `nav.label` (Baloo 11, 600). Không làm mờ ô nào trừ khi ô đó thật sự chưa dùng được (luật ở đợt 1, mục A2).
- Icon và thứ tự các ô giữ nguyên như hiện có.

## 4. Thẻ nhẹ hơn
- Thẻ trắng (Mục tiêu hôm nay, hàng trong Chợ, thẻ Nâng cấp, thẻ Đánh giá): viền còn 1px `surface.border` (thay viền 2px đậm), bo 16, bóng đặc `shadow.card` giữ nguyên. Khoảng cách giữa các thẻ 10.
- Thẻ dịp lễ ở Chợ (viền hồng) giữ viền 2px vì đó là thẻ nổi bật.

## 5. Dấu tích mục tiêu
- Mục tiêu đã đạt: chấm tròn 12 nền `status.success` có dấu tích trắng vẽ bằng nét (không dùng ký tự ✓, vì phông Nunito không có ký tự này).

Không làm trong đợt này: popup dạng tấm trượt từ dưới lên như SpaAnimal, bản đồ thị trấn, đổi phông. Những thứ này tốn code, để vòng sau nếu An muốn.
