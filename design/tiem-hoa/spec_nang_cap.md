# Spec màn Nâng cấp và mở khóa (v0.1)

Tác giả: Phú. Khung dọc 360×640, px logic. Màu, font, bo góc, bóng và chuyển động lấy từ `design_tokens.json`. Tên, giá, cấp và hiệu ứng đọc từ `economy.json` (`upgrades`, `flowers`, `papers`, `ribbons`). Số tiền trong bản phác chỉ là một trạng thái ví dụ.

Mở từ nút "Nâng cấp" ở thanh điều hướng của Tiệm chính, hoặc khi chạm vào một hàng hoa bị khóa ở Chợ hoa (khi đó mở thẳng tab thứ hai). Chỉ mở được lúc tiệm chưa mở cửa (Chuẩn bị) hoặc ở Chợ hoa. Trong giờ bán, nút ở thanh điều hướng mờ đi, chạm vào thì hiện dòng nhắc "Nâng cấp khi tiệm đóng cửa nhé".

## Bố cục (`nang_cap_v0.1.png`)

| Vùng | x, y, rộng × cao | Nội dung |
|---|---|---|
| Thanh trên | 0, 0, 360×48 | Tiền, sao, ngày. |
| Tiêu đề | 0, 54, 360×32 | Nút quay lại 36×32, "Nâng cấp tiệm" (`heading` 20). |
| Tab | 12, 98, 336×40 | Hai nửa: "Tiệm" và "Hoa, giấy và nơ". Nền `surface.sunken`, tab đang chọn nền `primary.base` chữ trắng. |
| Danh sách | từ y 150, mỗi thẻ 336×80, cách 8 | Cuộn dọc, giữ đúng thứ tự trong `upgrades`. |

**Thẻ nâng cấp (tab Tiệm):**
- Ô icon 52×52 nền `surface.sunken`. Icon thật vẽ sau, bản phác dùng chấm màu.
- Tên (`heading` 15), bên cạnh là các chấm cấp đường kính 8, cách 12. Số chấm bằng số cấp của món đó (có món 3, có món 2). Chấm đã đạt tô `primary.base`, chưa đạt tô `freshness.track`.
- Tối đa 2 dòng `body` 11 mô tả **cấp kế tiếp**, ví dụ "Cấp 2: hoa tươi thêm 2 ngày". Chữ nằm trong khoảng x 86 đến 262 để không đè lên nút giá.
- Dòng trạng thái `caption`: "Chưa có", hoặc "Đang có cấp N", thêm "phí Xk/ngày" nếu cấp hiện tại có `dailyUpkeep`.
- Nút giá 66×30 bên phải, canh giữa theo chiều dọc: nền `secondary.base` khi đủ tiền, nền `surface.sunken` chữ `text.disabled` khi không đủ tiền. Đạt cấp cao nhất thì thay bằng nhãn "Tối đa" màu `text.secondary`.
- Món có `requires` chưa đủ (ví dụ Nhân viên cấp 2 cần Quầy phục vụ cấp 1) thì nút ghi "Cần [tên món] cấp N" và không bấm được.
- `ads` là món dùng một lần: chấm cấp thay bằng nhãn "Dùng 1 ngày". Đang có hiệu lực thì nút ghi "Đang chạy".

**Câu mô tả hiệu ứng.** Game ghép câu từ khóa trong `effect`. Mỗi khóa có một mẫu câu, nếu một cấp có nhiều khóa thì nối bằng dấu phẩy:

| Khóa | Mẫu câu |
|---|---|
| `freshnessBonusDays` | hoa tươi thêm {n} ngày |
| `wrapTimeReduction` | gói nhanh hơn {n×100}% |
| `greenZoneBonus` | vùng xanh rộng hơn |
| `customerMultiplier` | thêm {(n−1)×100}% khách |
| `patienceMultiplier` | khách chờ lâu hơn {(n−1)×100}% |
| `counterSlots` + `maxQueue` | {counterSlots} chỗ ở quầy, hàng chờ {maxQueue} người |
| `autoPaperRibbon` | tự chọn giấy và nơ |
| `stemTimeReduction` | nhặt hoa nhanh hơn |
| `autoServeSeconds` + `autoServeMaxStems` | nhân viên tự bó đơn tối đa {autoServeMaxStems} cành, mỗi đơn {autoServeSeconds} giây (`autoServeTier` không hiện ra chữ) |
| `ordersPerDay` | {n} đơn online mỗi ngày |
| `deliveryFee` | thu phí giao {n/1000}k mỗi đơn (ghép ngay sau câu của `ordersPerDay`) |

Bỏ qua `requires`, `_note` và mọi khóa bắt đầu bằng `_` khi ghép câu.

**Tab Hoa, giấy và nơ:** lưới 2 cột, mỗi thẻ 164×132, cách 8. Chia 3 nhóm có tiêu đề nhỏ (`heading` 14): Hoa, Giấy gói, Nơ. Mỗi thẻ gồm hình 64×64, tên, một dòng thông tin (hoa: "Bó N cành · tươi N ngày"; giấy và nơ: "Giá bán Xk mỗi bó") và nút giá `unlockCost`. Món đã mở thì hiện nhãn "Đã có" màu `status.success` thay cho nút. Món giá 0 không cần hiện vì đã có từ đầu, nhưng vẫn để trong lưới với nhãn "Đã có" để người chơi thấy mình đang có gì.

**Tiền âm** (`safetyNet`): mọi nút giá đều tắt, và phía trên danh sách hiện băng `accent.soft` ghi "Trả hết nợ để nâng cấp tiếp nhé".

## Popup xác nhận (`nang_cap_xac_nhan_v0.1.png`)

Bấm nút giá thì mở popup 296×272 canh giữa, nền `bg.overlay` phía sau, vào theo `popupIn`.
- Icon 64×64, rồi tên và cấp sẽ mua (`heading` 18).
- Khối so sánh nền `surface.sunken`: dòng "Hiện tại" và dòng "Sau khi nâng" (chữ `status.success`).
- Một dòng ghi chú `caption`: phí duy trì mới nếu có, hoặc hiệu ứng phụ.
- Hai nút: "Để sau" (viền) và "Nâng · [giá]" (`secondary`).

Bấm Nâng thì trừ tiền, đóng popup, chấm cấp mới sáng lên theo `easing.pop`, có vài đồng xu bay ra khỏi ô tiền, và thẻ cập nhật mô tả cấp kế tiếp. Mở khóa hoa, giấy hay nơ thì dùng popup chúc mừng mở khóa (sẽ có trong spec popup) thay cho hiệu ứng chấm.

## Chưa có trong v0.1

Icon thật cho 8 món nâng cấp, hình tiệm thay đổi theo nâng cấp (ví dụ thấy tủ mát trong cảnh tiệm), âm thanh.
