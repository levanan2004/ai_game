# Assets v0.1 (Phú)
Mỗi hình có bản SVG (viewBox 128x128) và PNG 256x256 nền trong suốt. Viền chung #5A4038, màu lấy từ design_tokens.json.
- `customers/<avatarId>.png|svg` và `customers/index.json` (name, avatarId, gender, age, khớp `customers` trong orders.json). Avatar nửa người, dùng trong hàng chờ, bong bóng đơn và popup đánh giá.
- `flowers/<id>`, `papers/<id>`, `ribbons/<id>`, `upgrades/<id>`: tên file trùng `id` trong economy.json.
Hiển thị: ô khay 64-72px, avatar hàng chờ 72px, avatar popup 96px, icon nâng cấp 80px. Dùng PNG là đủ, không cần thêm flutter_svg.
