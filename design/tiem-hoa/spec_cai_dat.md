# Spec: Cài đặt, avatar, đăng nhập Google và avatar trên bảng Đại thiện nhân (v0.3, Phú, 26/9)

Bản phác: `cai_dat_v0.1.png`. Khung 360×640, px logic. v0.2: sửa dòng dưới hai nút ảnh riêng cho khớp luật Storage 512 KB. v0.3: chữ đã được Nhất chốt (bản gốc `/workspace/tiem-hoa-marketing/chu_cai_dat_v1.md`), chữ trong spec này là chữ cuối.
Hình mới: `assets/nav/cai_dat.png` (icon bánh răng, 96px, hiển thị 24), `assets/nav/google.png` (logo Google, 96px, hiển thị 20). Avatar chọn sẵn lấy từ `assets/customers/`.

## 1. Nút Cài đặt thay cho nút tạm dừng
- Nút tròn 32 ở góc phải thanh trên (đúng chỗ nút tạm dừng hiện giờ) đổi icon thành bánh răng. Chip ngày dịch sang trái cho vừa.
- Chạm thì mở popup Cài đặt và tạm dừng giờ trong ngày. Popup này thay luôn popup tạm dừng cũ, nên thanh trên không thêm nút nào. Tab trình duyệt bị ẩn thì vẫn tự mở popup này.
- Khi popup mở, nút bánh răng có viền 2 `primary.base`.
- Màn mở đầu (trước khi vào ngày 1) cũng có nút bánh răng này ở góc phải trên.

## 2. Popup Cài đặt
Thẻ 304 rộng, cao tự theo nội dung (khoảng 500), theo quy tắc popup chung (`surface.card`, bo `radius.lg`, bóng đặc, nền phủ `bg.overlay`). Tiêu đề "Cài đặt" `title` 22, dòng phụ "Game đang tạm dừng" `caption`. Mở từ màn mở đầu (chưa vào ngày 1) thì ẩn dòng phụ này.
Ba nhóm, mỗi nhóm có nhãn nhỏ viết hoa (`caption` 10 đậm, `text.secondary`) và một khối nền `surface.sunken` bo `radius.md`:

**TÀI KHOẢN**
- Avatar tròn 56, viền 2.5 `primary.base`, góc dưới phải có nút bút chì tròn 24. Chạm avatar hoặc nút bút đều mở màn Đổi avatar.
- Bên phải: tên (`heading` 16) và trạng thái (`caption`). Chưa đăng nhập: tên "Chủ tiệm", dòng "Chưa đăng nhập". Đã đăng nhập: tên Google, dòng là email.
- Chưa đăng nhập: nút viền full rộng cao 36 có logo Google 20 và chữ "Đăng nhập bằng Google". Dưới khối: "Đăng nhập để lưu tiến độ, đổi máy vẫn chơi tiếp. Game chỉ dùng tên, email và ảnh đại diện Google của bạn." (`caption`, tối đa 3 dòng).
- Đã đăng nhập: nút đổi thành nút chữ "Đăng xuất" `text.secondary`. Thêm dòng nhỏ "Đã lưu lúc 10:42" (giờ lần lưu gần nhất).
- Đang đăng nhập: nút hiện vòng xoay nhỏ, không bấm được. Lỗi: dòng `status.danger` "Chưa đăng nhập được, thử lại nhé.".

**TÊN TIỆM** (nhóm mới, nằm giữa Tài khoản và Âm thanh)
- Một hàng cao 52: tên tiệm hiện tại (`body` 14 đậm) và nút bút chì tròn 28 bên phải. Bấm thì mở lại popup đặt tên (spec mở đầu mục 7) với tiêu đề "Đổi tên tiệm", hai nút "Hủy" (viền) và "Lưu tên" (chính) nằm cạnh nhau, và ẩn dòng "Có thể đổi tên sau trong Cài đặt." Không cần đăng nhập.

**ÂM THANH**
- Một hàng cao 52: "Nhạc nền" (`body` 14 đậm) và công tắc 44×26 (bật: `secondary.base`, tắt: nền `track`). Mặc định bật. Lưu lựa chọn trong máy, không cần đăng nhập.
- Trình duyệt chặn tự phát nhạc, nên nhạc chỉ bắt đầu sau lần chạm đầu tiên của người chơi.

**KHÁC**
- Hàng "Ủng hộ" có icon sen 28 và mũi tên ›. Hàng này thay dòng Ủng hộ trong popup tạm dừng cũ (spec Đại thiện nhân mục 1).

Nút "Tiếp tục" `primary` full rộng ở cuối, đóng popup và chạy lại giờ. Mở từ màn mở đầu thì nút này là "Đóng".

## 3. Màn Đổi avatar (popup 320 rộng)
- Tiêu đề "Đổi avatar", nút × góc phải. Avatar đang dùng tròn 80 ở giữa, viền 3 `primary.base`.
- "Chọn một avatar": lưới 4 cột, avatar tròn 56 nền `primary.soft`. Đang chọn thì viền 3 `primary.base` và chấm tích tròn 16 góc dưới phải. Dùng 12 avatar có sẵn trong `assets/customers/` (danh sách trong bản phác, chọn được mà không cần đăng nhập).
- "Hoặc dùng ảnh riêng": hai nút viền "Ảnh Google" và "Tải ảnh lên". Chưa đăng nhập thì hai nút mờ, dòng dưới "Cần đăng nhập Google. Ảnh được cắt vuông và thu nhỏ trước khi lưu." Ảnh chọn từ máy được cắt vuông giữa, thu về 128×128, lưu JPEG chất lượng 85 (khoảng 10–20 KB, dưới hẳn giới hạn 512 KB của luật Storage). Không giới hạn dung lượng file gốc, vì chỉ bản đã thu nhỏ được tải lên.
- Tải ảnh lỗi: dòng `status.danger` "Chưa tải ảnh lên được, thử lại nhé." dưới hai nút ảnh riêng; nút đang tải hiện vòng xoay nhỏ.
- Chọn xong là lưu ngay, không có nút Lưu. Ảnh tải lên cắt vuông ở giữa, thu về 128×128 trước khi lưu (An đã lên Blaze nên có thể lưu trên Storage; cách lưu do Khoa chốt).
- Avatar hiện ở: khối Tài khoản trong Cài đặt. Chưa hiện ở chỗ khác trong bản alpha.

## 4. Avatar trên bảng Đại thiện nhân
Cập nhật mục 2b của `spec_dai_thien_nhan.md`:
- Mỗi hàng cao 58. Avatar tròn 40 ở bên trái, viền 2 `temple.gold`, thay cho hoa sen nhỏ. Tên và lời nhắn dời sang phải (x 84).
- Không có ảnh thì hiện hình tròn nền `temple.woodDark` với icon sen 24 ở giữa.
- Avatar có thể là ảnh trên Storage (An đã lên Blaze) hoặc mã một trong 12 avatar làm sẵn, An ghi vào trường Khoa đặt (gợi ý `avatar`). Trống thì hiện hoa sen.
- Số tiền ủng hộ: xem `spec_dai_thien_nhan.md` cập nhật v0.3.
- Ảnh đang tải thì hiện hình tròn sen như lúc không có ảnh, tải xong thì mờ dần vào trong 200ms.

## Không làm ở bản alpha
Âm lượng dạng thanh kéo, hiệu ứng âm thanh riêng, khung avatar trang trí.
