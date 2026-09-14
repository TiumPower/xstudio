# TÀI LIỆU YÊU CẦU HỆ THỐNG (SRS)
## Team Workspace — Công cụ làm việc nội bộ

| | |
|---|---|
| **Tên hệ thống** | Team Workspace |
| **Phiên bản tài liệu** | 1.0 |
| **Ngày** | 14/09/2026 |
| **Chủ sở hữu** | Xna — DC1 |
| **Quy mô người dùng** | 5–15 người, dùng nội bộ |
| **Ngôn ngữ hệ thống** | Tiếng Việt (100%) |
| **Đơn vị tiền tệ** | VND (Việt Nam Đồng) — đơn tiền tệ |
| **Tech stack** | Ruby on Rails 7.1+ / PostgreSQL / Hotwire (Turbo + Stimulus) / TailwindCSS |

---

## 1. TỔNG QUAN

### 1.1. Bối cảnh

Team là một đơn vị phát triển & tư vấn phần mềm, hoạt động trên 2 mảng chính:

1. **Product & Sales** — tự xây sản phẩm và tự đi bán.
2. **Chuyển đổi số (Data & AI)** — tư vấn và triển khai dự án chuyển đổi số cho khách hàng, trọng tâm dữ liệu và AI.

Hiện tại công việc đang phân tán trên nhiều công cụ rời rạc (file Excel, chat, email). Không có một nơi duy nhất để nhìn thấy: dự án nào đang chạy, ai làm gì, tiến độ bao nhiêu, tiền vào ra thế nào.

### 1.2. Mục tiêu

Xây một workspace nội bộ duy nhất, nơi cả team:

- Tạo và quản lý dự án theo 2 loại hình.
- Quản lý công việc bằng danh sách task + Kanban board.
- Ghi nhận thu — chi theo từng dự án hoặc chung cho workspace.
- Nhìn thấy bức tranh tổng thể qua dashboard: tài chính + tình trạng dự án.
- Nhận thông báo qua email khi có việc liên quan đến mình.
- Vẽ và duy trì **cây định hướng** của team: các mảng lớn đang theo đuổi, mỗi mảng gồm những phần nhỏ nào.

### 1.3. Ngoài phạm vi (Out of scope)

Những phần **không** làm ở phiên bản này:

- Chat nhóm realtime.
- Timesheet / chấm công / tính lương.
- Sales pipeline (CRM, deal, lead).
- Ngân sách (budget) và quy trình duyệt chi nhiều cấp.
- Đa tiền tệ, đa ngôn ngữ.
- Ứng dụng mobile native (web responsive là đủ).
- Tích hợp kế toán/hoá đơn điện tử.

### 1.4. Thuật ngữ

| Thuật ngữ | Ý nghĩa |
|---|---|
| **Workspace** | Không gian làm việc chung của cả team. Hệ thống chỉ có 1 workspace. |
| **Thành viên (Member)** | Người dùng thuộc workspace. |
| **Dự án (Project)** | Đơn vị công việc lớn, thuộc 1 trong 2 loại hình. |
| **Công việc (Task)** | Đầu việc cụ thể trong một dự án. |
| **Bảng Kanban** | Giao diện cột trạng thái, kéo–thả task. |
| **Giao dịch (Transaction)** | Một bút toán thu hoặc chi. |
| **Giao dịch chung** | Giao dịch không gắn dự án nào (chi phí vận hành workspace). |
| **Cây định hướng** | Sơ đồ cây một gốc thể hiện định hướng của team: mảng lớn → phần nhỏ → chi tiết. Là sơ đồ tư duy độc lập, không gắn dữ liệu dự án. |
| **Nút (Node)** | Một ô trong cây định hướng. |

---

## 2. NGƯỜI DÙNG & PHÂN QUYỀN

### 2.1. Vai trò

Ở phiên bản này **tất cả thành viên có quyền như nhau**. Chỉ tách riêng một vai trò kỹ thuật:

| Vai trò | Mô tả | Quyền |
|---|---|---|
| **Quản trị (Admin)** | Người khởi tạo workspace + những người được chỉ định | Toàn quyền của Thành viên, cộng thêm: mời/vô hiệu hoá thành viên, chỉnh cấu hình workspace, xoá vĩnh viễn dữ liệu |
| **Thành viên (Member)** | Tất cả người còn lại | Xem toàn bộ dự án, task, giao dịch, dashboard. Tạo/sửa/xoá dự án, task, giao dịch, bình luận |

> **Nguyên tắc thiết kế:** minh bạch toàn team — mọi thành viên đều thấy toàn bộ dữ liệu workspace, kể cả tài chính. Không có dự án riêng tư ở phiên bản này. Cấu trúc dữ liệu vẫn giữ trường `role` để sau này mở rộng phân quyền chi tiết mà không phải migrate lớn.

### 2.2. Quy tắc bảo vệ dữ liệu tối thiểu

- Chỉ **người tạo** hoặc **Admin** được xoá một giao dịch / dự án.
- Không xoá cứng: dùng soft delete (`discarded_at`) cho Project, Task, Transaction.
- Mọi thao tác tạo/sửa/xoá đều ghi vào Nhật ký hoạt động (Activity Log).

---

## 3. YÊU CẦU CHỨC NĂNG

Ký hiệu: **[MVP]** = làm ngay · **[P2]** = giai đoạn 2.

### 3.1. Xác thực & Tài khoản (FR-AUTH)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-AUTH-01 | Đăng nhập bằng **email + mật khẩu**. | MVP |
| FR-AUTH-02 | Không có tự đăng ký công khai. Admin gửi **lời mời qua email**, người được mời bấm link để đặt mật khẩu và kích hoạt tài khoản. | MVP |
| FR-AUTH-03 | Link mời hết hạn sau **7 ngày**, có thể gửi lại. | MVP |
| FR-AUTH-04 | Quên mật khẩu → gửi link đặt lại qua email, hết hạn sau **2 giờ**. | MVP |
| FR-AUTH-05 | Đổi mật khẩu trong trang Hồ sơ cá nhân (yêu cầu nhập mật khẩu hiện tại). | MVP |
| FR-AUTH-06 | Mật khẩu tối thiểu 8 ký tự, có chữ và số. | MVP |
| FR-AUTH-07 | Ghi nhớ đăng nhập ("Duy trì đăng nhập") — phiên 30 ngày. | MVP |
| FR-AUTH-08 | Khoá tạm 15 phút sau 10 lần đăng nhập sai liên tiếp. | MVP |
| FR-AUTH-09 | Admin có thể **vô hiệu hoá** thành viên (không xoá). Thành viên bị vô hiệu hoá không đăng nhập được nhưng dữ liệu cũ (task, bình luận) vẫn giữ tên. | MVP |
| FR-AUTH-10 | Đăng nhập bằng Google / Microsoft SSO. | P2 |

### 3.2. Hồ sơ cá nhân (FR-PROFILE)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-PROFILE-01 | Sửa họ tên, chức danh, số điện thoại. | MVP |
| FR-PROFILE-02 | Tải lên ảnh đại diện (avatar). Nếu không có, hiển thị chữ cái đầu trên nền màu sinh tự động từ tên. | MVP |
| FR-PROFILE-03 | Cấu hình nhận thông báo email: bật/tắt theo từng loại sự kiện. | MVP |

### 3.3. Workspace (FR-WS)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-WS-01 | Hệ thống có **1 workspace duy nhất**, cấu hình: tên workspace, logo, múi giờ (mặc định `Asia/Ho_Chi_Minh`). | MVP |
| FR-WS-02 | Trang **Thành viên**: danh sách toàn bộ thành viên (avatar, tên, email, chức danh, trạng thái, ngày tham gia, số dự án đang tham gia). | MVP |
| FR-WS-03 | Admin mời thành viên mới bằng email (có thể mời nhiều email cùng lúc). | MVP |
| FR-WS-04 | Trang **Nhật ký hoạt động**: dòng thời gian mọi thao tác trong workspace, lọc theo người / dự án / loại thao tác / khoảng ngày. | MVP |

### 3.4. Dự án (FR-PRJ)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-PRJ-01 | Tạo dự án với các trường: **Tên** (bắt buộc), **Mã dự án** (tự sinh, ví dụ `PRD-001`, `DX-004`, sửa được), **Loại hình** (bắt buộc), **Mô tả**, **Khách hàng**, **Ngày bắt đầu**, **Ngày kết thúc dự kiến**, **Trạng thái**, **Người phụ trách**, **Thành viên tham gia**, **Màu nhãn**. | MVP |
| FR-PRJ-02 | **Loại hình dự án** — chọn 1 trong 2: <br>• `product_sales` — **Sản phẩm & Kinh doanh** <br>• `digital_transformation` — **Chuyển đổi số (Data & AI)** | MVP |
| FR-PRJ-03 | **Trạng thái dự án**: `Lên kế hoạch` · `Đang thực hiện` · `Tạm dừng` · `Hoàn thành` · `Huỷ`. | MVP |
| FR-PRJ-04 | **Tiến độ (%)** tính **tự động** = số task `Hoàn thành` / tổng số task chưa huỷ. Có thể chuyển sang chế độ **nhập tay** (khoá tự động) bằng một công tắc trong cài đặt dự án. | MVP |
| FR-PRJ-05 | Danh sách dự án: dạng **thẻ (card)** và dạng **bảng (table)**, chuyển đổi được. Lọc theo loại hình, trạng thái, người phụ trách, khách hàng. Tìm theo tên/mã. Sắp xếp theo ngày cập nhật / hạn / tiến độ. | MVP |
| FR-PRJ-06 | Trang chi tiết dự án gồm các tab: **Tổng quan** · **Công việc** (danh sách) · **Kanban** · **Thu chi** · **Thành viên** · **Hoạt động**. | MVP |
| FR-PRJ-07 | Tab Tổng quan hiển thị: mô tả, các chỉ số nhanh (tổng task / đang làm / trễ hạn / hoàn thành, tổng thu, tổng chi, lợi nhuận, tiến độ), danh sách task sắp đến hạn, 10 hoạt động gần nhất. | MVP |
| FR-PRJ-08 | Thêm/bớt thành viên tham gia dự án. Chỉ thành viên tham gia mới được gán task, nhưng **mọi người vẫn xem được** dự án. | MVP |
| FR-PRJ-09 | Lưu trữ (archive) dự án — ẩn khỏi danh sách mặc định, vẫn xem/tìm lại được qua bộ lọc "Đã lưu trữ". | MVP |
| FR-PRJ-10 | Cảnh báo trực quan khi dự án **quá hạn** (ngày kết thúc dự kiến < hôm nay và trạng thái ≠ Hoàn thành/Huỷ). | MVP |
| FR-PRJ-11 | Nhân bản dự án (copy cấu trúc task, không copy thu chi). | P2 |
| FR-PRJ-12 | Mốc quan trọng (milestone) trong dự án. | P2 |

### 3.5. Công việc & Kanban (FR-TASK)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-TASK-01 | Tạo task trong dự án với: **Tiêu đề** (bắt buộc), **Mô tả** (rich text), **Trạng thái**, **Người thực hiện** (1 người), **Độ ưu tiên**, **Ngày bắt đầu**, **Hạn hoàn thành**, **Nhãn (tags)**, **Ước lượng (giờ)**, **Tệp đính kèm**. | MVP |
| FR-TASK-02 | **Trạng thái task** (cũng là cột Kanban mặc định): `Cần làm` · `Đang làm` · `Chờ duyệt` · `Hoàn thành`. Có thêm trạng thái `Huỷ` (không hiện trên board, hiện ở danh sách khi bật bộ lọc). | MVP |
| FR-TASK-03 | Mỗi dự án **tuỳ chỉnh được cột Kanban**: đổi tên, đổi màu, thêm/xoá/sắp xếp lại cột. Cột mặc định sinh tự động khi tạo dự án. | MVP |
| FR-TASK-04 | **Độ ưu tiên**: `Thấp` · `Trung bình` · `Cao` · `Khẩn cấp` — mỗi mức 1 màu. | MVP |
| FR-TASK-05 | **Bảng Kanban**: kéo–thả task giữa các cột và sắp xếp thứ tự trong cột. Cập nhật lưu ngay, không cần bấm Lưu. | MVP |
| FR-TASK-06 | Thẻ task trên board hiển thị: mã task, tiêu đề (tối đa 2 dòng), avatar người thực hiện, chip độ ưu tiên, hạn (đỏ nếu trễ), số bình luận, số tệp đính kèm, nhãn. | MVP |
| FR-TASK-07 | Mỗi cột hiển thị **số lượng task** và **tuỳ chọn giới hạn WIP** (cảnh báo màu khi vượt, không chặn). | MVP |
| FR-TASK-08 | Bộ lọc trên board: người thực hiện, độ ưu tiên, nhãn, hạn (quá hạn / tuần này / không hạn). | MVP |
| FR-TASK-09 | **Danh sách công việc** dạng bảng: sắp xếp, lọc, chọn nhiều và sửa hàng loạt (đổi trạng thái, đổi người thực hiện). | MVP |
| FR-TASK-10 | **Task con (subtask)** dạng checklist đơn giản trong task cha. Hiển thị `3/5` trên thẻ. | MVP |
| FR-TASK-11 | Trang/panel chi tiết task: toàn bộ thông tin + bình luận + tệp đính kèm + lịch sử thay đổi. | MVP |
| FR-TASK-12 | Mã task tự sinh theo dự án: `<Mã dự án>-<số thứ tự>` (ví dụ `DX-004-17`). | MVP |
| FR-TASK-13 | **"Việc của tôi"** — màn hình tổng hợp mọi task được gán cho người đang đăng nhập, gộp từ tất cả dự án, nhóm theo: Quá hạn / Hôm nay / Tuần này / Sau đó / Không có hạn. | MVP |
| FR-TASK-14 | Phụ thuộc giữa task (blocked by / blocks). | P2 |
| FR-TASK-15 | Task lặp lại theo chu kỳ. | P2 |

### 3.6. Bình luận (FR-CMT)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-CMT-01 | Bình luận trên **task** và trên **dự án**. | MVP |
| FR-CMT-02 | Định dạng cơ bản: đậm, nghiêng, gạch đầu dòng, danh sách đánh số, link, khối mã. | MVP |
| FR-CMT-03 | **Nhắc tên (@mention)** thành viên → người được nhắc nhận thông báo (trong app + email). | MVP |
| FR-CMT-04 | Đính kèm tệp vào bình luận. | MVP |
| FR-CMT-05 | Sửa / xoá bình luận của chính mình. Bình luận đã sửa hiển thị nhãn "đã chỉnh sửa". | MVP |
| FR-CMT-06 | Bình luận hiển thị theo thứ tự thời gian, kèm avatar, tên, thời điểm tương đối ("3 giờ trước"). | MVP |
| FR-CMT-07 | Trả lời theo luồng (threaded reply) và biểu tượng cảm xúc. | P2 |

### 3.7. Thu chi (FR-FIN)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-FIN-01 | Ghi nhận **giao dịch** gồm: **Loại** (`Thu` / `Chi`), **Số tiền (VND)**, **Ngày giao dịch**, **Danh mục**, **Gắn với dự án** (hoặc *Chung workspace*), **Diễn giải**, **Đối tác/Nhà cung cấp**, **Phương thức** (Tiền mặt / Chuyển khoản / Thẻ / Khác), **Chứng từ đính kèm**, **Người tạo**. | MVP |
| FR-FIN-02 | Giao dịch **không gắn dự án** được ghi nhận là **chi phí/thu nhập chung của workspace** (ví dụ: tiền thuê văn phòng, lương công cụ, subscription). | MVP |
| FR-FIN-03 | **Danh mục thu** mặc định: `Thanh toán hợp đồng`, `Tạm ứng từ khách hàng`, `Doanh thu sản phẩm`, `Khác`. | MVP |
| FR-FIN-04 | **Danh mục chi** mặc định: `Nhân sự & Outsource`, `Hạ tầng & Cloud`, `Phần mềm & Công cụ`, `Marketing & Bán hàng`, `Văn phòng`, `Đi lại & Tiếp khách`, `Thuế & Phí`, `Khác`. | MVP |
| FR-FIN-05 | Admin quản lý (thêm/sửa/ẩn) danh mục thu chi. | MVP |
| FR-FIN-06 | **Sổ thu chi** toàn workspace: bảng giao dịch có lọc theo loại, dự án, danh mục, người tạo, khoảng ngày, khoảng số tiền; tìm theo diễn giải. Có dòng tổng cộng: Tổng thu / Tổng chi / Chênh lệch. | MVP |
| FR-FIN-07 | Tab **Thu chi** trong từng dự án: chỉ giao dịch của dự án đó + 3 thẻ tổng (Thu / Chi / Lợi nhuận) + biểu đồ theo tháng. | MVP |
| FR-FIN-08 | Nhập số tiền có **định dạng phân cách nghìn tự động** khi gõ (`15000000` → `15.000.000`). Hiển thị ở mọi nơi: `15.000.000 ₫`. Không dùng số thập phân. | MVP |
| FR-FIN-09 | **Xuất Excel/CSV** sổ thu chi theo bộ lọc hiện tại. | MVP |
| FR-FIN-10 | Sửa/xoá giao dịch — chỉ người tạo hoặc Admin. Mọi thay đổi ghi vào nhật ký. | MVP |
| FR-FIN-11 | Ngân sách dự án + cảnh báo vượt ngân sách. | P2 |
| FR-FIN-12 | Giao dịch định kỳ tự động (subscription hàng tháng). | P2 |
| FR-FIN-13 | Quy trình đề xuất — duyệt chi. | P2 |

### 3.8. Dashboard (FR-DASH)

Dashboard là **trang chủ** sau khi đăng nhập. Mọi thành viên đều thấy như nhau.

**Bộ lọc chung ở đầu trang:** khoảng thời gian (`Tháng này` · `Quý này` · `Năm nay` · `Tuỳ chọn`) và loại hình dự án (`Tất cả` · `Sản phẩm & Kinh doanh` · `Chuyển đổi số`).

| ID | Thành phần | Nội dung | Ưu tiên |
|---|---|---|---|
| FR-DASH-01 | **Hàng chỉ số tài chính** | 4 thẻ: Tổng thu · Tổng chi · Lợi nhuận (Thu − Chi) · Chi chung workspace. Mỗi thẻ có % so với kỳ trước. | MVP |
| FR-DASH-02 | **Biểu đồ Thu — Chi theo tháng** | Cột nhóm 12 tháng gần nhất + đường lợi nhuận. | MVP |
| FR-DASH-03 | **Cơ cấu chi theo danh mục** | Biểu đồ tròn/donut + bảng số liệu kèm %. | MVP |
| FR-DASH-04 | **Thu chi theo loại hình dự án** | Cột ngang so sánh 2 mảng: Sản phẩm & Kinh doanh vs Chuyển đổi số. | MVP |
| FR-DASH-05 | **Top dự án theo lợi nhuận** | Bảng 5 dự án lãi nhất và 5 dự án lỗ nhất. | MVP |
| FR-DASH-06 | **Hàng chỉ số dự án** | 4 thẻ: Đang thực hiện · Quá hạn · Hoàn thành trong kỳ · Tổng task đang mở. | MVP |
| FR-DASH-07 | **Bảng tình trạng dự án** | Mỗi dòng: tên dự án, nhãn loại hình, người phụ trách, thanh tiến độ %, trạng thái, hạn, thu/chi/lợi nhuận. Sắp xếp và click vào để mở dự án. | MVP |
| FR-DASH-08 | **Phân bổ công việc theo người** | Cột chồng: mỗi thành viên với số task theo trạng thái. Giúp thấy ai đang quá tải. | MVP |
| FR-DASH-09 | **Việc của tôi** | Widget tóm tắt: số task quá hạn, đến hạn hôm nay, đến hạn tuần này + 5 task gần nhất. | MVP |
| FR-DASH-10 | **Hoạt động gần đây** | 10 hoạt động mới nhất trong workspace. | MVP |
| FR-DASH-11 | **Xuất dashboard ra PDF** | | P2 |

### 3.9. Thông báo (FR-NOTI)

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-NOTI-01 | **Thông báo trong ứng dụng**: chuông ở thanh trên, badge số chưa đọc, danh sách thả xuống, đánh dấu đã đọc / đã đọc tất cả. | MVP |
| FR-NOTI-02 | **Thông báo qua email** cho các sự kiện: <br>① Được mời vào workspace <br>② Được gán một task <br>③ Được thêm vào dự án <br>④ Bị nhắc tên (@mention) trong bình luận <br>⑤ Có bình luận mới trên task mình thực hiện hoặc mình đang theo dõi <br>⑥ Task mình thực hiện bị đổi trạng thái bởi người khác <br>⑦ Task của mình sắp đến hạn (trước 1 ngày) <br>⑧ Task của mình đã quá hạn <br>⑨ Dự án mình phụ trách đổi trạng thái | MVP |
| FR-NOTI-03 | **Bản tin tổng hợp hàng ngày** (tuỳ chọn bật/tắt), gửi 08:00 giờ Việt Nam: tóm tắt task đến hạn, task quá hạn, hoạt động trong ngày hôm trước. | MVP |
| FR-NOTI-04 | Mỗi thành viên tự bật/tắt từng loại email trong Hồ sơ cá nhân. | MVP |
| FR-NOTI-05 | Email dùng **template HTML tiếng Việt** thống nhất: logo workspace, tiêu đề rõ ràng, nút hành động (CTA) dẫn thẳng tới task/dự án, chân trang có link tắt thông báo. | MVP |
| FR-NOTI-06 | Email gửi **bất đồng bộ** qua hàng đợi nền; lỗi gửi tự thử lại tối đa 3 lần. | MVP |
| FR-NOTI-07 | Gộp thông báo: nhiều sự kiện cùng task trong 5 phút → 1 email. | P2 |

### 3.10. Cây định hướng (FR-TREE)

**Mục đích:** một trang riêng để cả team cùng nhìn và cùng sửa bức tranh định hướng — team đang đánh những mảng nào, mỗi mảng gồm những phần nhỏ nào, đi xuống nhiều cấp.

**Phạm vi đã chốt:** workspace có **đúng một cây duy nhất**, dùng chung cho cả team. Cây là **sơ đồ tư duy độc lập** — nút không liên kết tới dự án hay công việc.

#### 3.10.1. Cấu trúc & nội dung nút

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-TREE-01 | Cây có **1 nút gốc** (mặc định tên = tên workspace, sửa được). Không xoá được nút gốc. | MVP |
| FR-TREE-02 | Nút con lồng nhau **tối đa 6 cấp** (không kể gốc). Vượt cấp thì chặn và báo rõ. | MVP |
| FR-TREE-03 | Mỗi nút gồm: **Tiêu đề** (bắt buộc, ≤ 120 ký tự), **Ghi chú** (text dài, tuỳ chọn), **Màu**, **Biểu tượng/emoji**, **Trạng thái**, **Người phụ trách** (tuỳ chọn, chọn từ thành viên). | MVP |
| FR-TREE-04 | **Trạng thái nút** (chỉ để đánh dấu tư duy, không ảnh hưởng dữ liệu khác): `Ý tưởng` · `Đang theo đuổi` · `Tạm gác` · `Đã đạt` · `Bỏ`. Mỗi trạng thái một màu viền/chip. | MVP |
| FR-TREE-05 | Nút có thể **thu gọn / mở rộng**; nút thu gọn hiện badge số nút con bên trong (đếm toàn bộ nhánh). | MVP |
| FR-TREE-06 | Tự động tính **độ sâu (depth)** và **thứ tự (position)** trong cùng cha. | MVP |

#### 3.10.2. Tạo và chỉnh sửa nhanh

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-TREE-10 | **Sửa tiêu đề tại chỗ**: click đúp (hoặc `Enter` khi đang chọn) vào nút để gõ thẳng, không cần mở form. `Esc` huỷ, `Enter`/click ra ngoài để lưu. | MVP |
| FR-TREE-11 | **Phím tắt kiểu outline** khi đang chọn một nút: <br>`Tab` → tạo nút con <br>`Enter` → tạo nút cùng cấp bên dưới <br>`Shift + Tab` → đẩy nút hiện tại lên một cấp <br>`↑ ↓ ← →` → di chuyển lựa chọn giữa các nút <br>`Space` → thu gọn / mở rộng <br>`Delete` → xoá nút (hỏi xác nhận nếu có con) <br>`Cmd/Ctrl + Z` → hoàn tác | MVP |
| FR-TREE-12 | **Dán hàng loạt (bulk paste)**: dán một danh sách văn bản có thụt lề (tab hoặc 2–4 dấu cách, hoặc `-`/`*` markdown) vào một nút → hệ thống tự dựng thành cây con đúng cấu trúc thụt lề. Có màn hình xem trước trước khi chèn. | MVP |
| FR-TREE-13 | **Kéo–thả**: kéo một nút sang làm con của nút khác, hoặc thả vào giữa 2 nút để đổi thứ tự cùng cấp. Kéo nút cha thì kéo theo cả nhánh con. | MVP |
| FR-TREE-14 | Chặn thao tác kéo không hợp lệ: không thả một nút vào chính hậu duệ của nó; không vượt quá 6 cấp. Khi không hợp lệ, con trỏ hiện dấu cấm và vùng thả không sáng lên. | MVP |
| FR-TREE-15 | **Hoàn tác / Làm lại** cho mọi thao tác trên cây, tối thiểu 20 bước trong phiên làm việc. | MVP |
| FR-TREE-16 | Nhân bản một nút kèm toàn bộ nhánh con. | MVP |
| FR-TREE-17 | Xoá nút: nếu có nút con, hỏi rõ **"Xoá cả nhánh (n mục)"** hay **"Chỉ xoá nút này, đẩy các nút con lên cấp trên"**. | MVP |

#### 3.10.3. AI gợi ý nhánh con

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-TREE-20 | Trên mỗi nút có nút lệnh **"Gợi ý nhánh con"** (icon ✨). Gọi AI với ngữ cảnh: tiêu đề nút hiện tại, đường dẫn từ gốc xuống nút đó, danh sách nút con đang có, và mô tả lĩnh vực của team. | MVP |
| FR-TREE-21 | AI trả về **5–8 gợi ý** dạng danh sách tiếng Việt, mỗi gợi ý gồm tiêu đề ngắn + một dòng giải thích. Hiển thị trong panel bên phải dưới dạng danh sách có checkbox. | MVP |
| FR-TREE-22 | Người dùng **tick chọn** những gợi ý muốn giữ, sửa lại tiêu đề nếu cần, rồi bấm **"Thêm vào cây"**. Không tự động chèn khi chưa xác nhận. | MVP |
| FR-TREE-23 | AI **không đề xuất trùng** với nút con đã có (loại trừ ngay trong prompt và lọc lại ở kết quả). | MVP |
| FR-TREE-24 | Người dùng có thể nhập thêm **chỉ dẫn tự do** trước khi gợi ý, ví dụ *"tập trung vào mảng Data & AI cho khách hàng ngành bán lẻ"*. | MVP |
| FR-TREE-25 | Nút lệnh **"Gợi ý cả cây từ một chủ đề"**: nhập một chủ đề gốc → AI dựng bản nháp cây 2–3 cấp → xem trước → chèn vào nút đang chọn. | MVP |
| FR-TREE-26 | Trong lúc chờ AI: hiện skeleton, cho phép huỷ. Khi lỗi (hết hạn mức, mạng, timeout): thông báo tiếng Việt rõ ràng, cây không bị thay đổi. | MVP |
| FR-TREE-27 | Giới hạn tần suất: tối đa **30 lượt gợi ý / người / ngày**, đếm và hiện số lượt còn lại. Ghi log mỗi lượt gọi (người gọi, nút, thời điểm) để theo dõi chi phí. | MVP |
| FR-TREE-28 | AI **không bao giờ** tự sửa hoặc xoá nút đang có — chỉ đề xuất nút mới. | MVP |
| FR-TREE-29 | AI tóm tắt / phản biện một nhánh ("nhánh này đang thiếu gì?"). | P2 |

#### 3.10.4. Chế độ xem & bố trí

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-TREE-30 | **3 chế độ xem**, chuyển đổi bằng segmented control, ghi nhớ lựa chọn của từng người: <br>① **Sơ đồ tư duy (ngang)** — gốc ở giữa–trái, nhánh toả sang phải <br>② **Cây dọc (tổ chức đồ)** — gốc trên cùng, các cấp xuống dưới <br>③ **Danh sách outline** — dạng văn bản thụt lề, gọn, dễ đọc nhanh và dễ sao chép | MVP |
| FR-TREE-31 | **Tự động bố trí**: khoảng cách nút, tránh chồng lấn, căn nhánh — tính lại mỗi khi cây đổi, có hiệu ứng chuyển động mượt (~200ms). Người dùng **không phải tự kéo cho đẹp**. | MVP |
| FR-TREE-32 | Canvas hỗ trợ **thu phóng** (25%–200%, cuộn chuột + `Cmd/Ctrl ±`), **kéo nền để di chuyển**, nút **"Vừa màn hình"** và **"Về gốc"**. | MVP |
| FR-TREE-33 | **Bản đồ thu nhỏ (minimap)** ở góc dưới phải khi cây lớn hơn màn hình. | MVP |
| FR-TREE-34 | Nút **"Mở tất cả" / "Thu tất cả"** và **"Chỉ hiện tới cấp N"** (1–6). | MVP |
| FR-TREE-35 | **Tìm kiếm trong cây**: gõ từ khoá → các nút khớp sáng lên, các nhánh chứa nó tự mở, `Enter` nhảy tới nút tiếp theo. | MVP |
| FR-TREE-36 | **Lọc theo trạng thái** và **theo người phụ trách** — nút không khớp mờ đi (không ẩn hẳn, để vẫn thấy cấu trúc). | MVP |
| FR-TREE-37 | **Xuất**: PNG (ảnh cây theo chế độ xem hiện tại), và Markdown outline (danh sách thụt lề, dán được vào tài liệu khác). | MVP |
| FR-TREE-38 | Chế độ trình bày toàn màn hình (ẩn sidebar, dùng khi họp). | MVP |

#### 3.10.5. Cộng tác & lịch sử

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-TREE-40 | Mọi thành viên đều **xem và sửa** được cây (cùng quyền). | MVP |
| FR-TREE-41 | Thay đổi của người này **hiện sang người khác trong vòng vài giây** (Turbo Stream broadcast). Nếu 2 người sửa cùng một nút, người lưu sau nhận cảnh báo "Nút này vừa được <tên> cập nhật" kèm nút tải lại. | MVP |
| FR-TREE-42 | Mỗi nút hiển thị (ở panel chi tiết) người sửa gần nhất và thời điểm. | MVP |
| FR-TREE-43 | Thao tác trên cây ghi vào **Nhật ký hoạt động** chung: tạo / sửa / xoá / di chuyển nút. | MVP |
| FR-TREE-44 | **Ảnh chụp phiên bản (snapshot)**: lưu lại trạng thái cây tại một thời điểm, đặt tên, xem lại và khôi phục. Tự động chụp 1 bản mỗi ngày nếu cây có thay đổi, giữ 30 bản gần nhất. | MVP |
| FR-TREE-45 | Bình luận trên từng nút. | P2 |
| FR-TREE-46 | Con trỏ thời gian thực của người khác trên canvas. | P2 |
| FR-TREE-47 | Nhiều cây trong workspace (cây định hướng năm, cây năng lực, cây sản phẩm...). | P2 |

---

## 4. YÊU CẦU PHI CHỨC NĂNG

| Nhóm | Yêu cầu |
|---|---|
| **Ngôn ngữ** | Toàn bộ giao diện, email, thông báo lỗi bằng **tiếng Việt**. Không hiển thị chuỗi tiếng Anh cho người dùng cuối. |
| **Định dạng ngày** | `dd/mm/yyyy` · giờ 24h · múi giờ `Asia/Ho_Chi_Minh`. Hiển thị tương đối cho sự kiện < 7 ngày ("2 giờ trước"). |
| **Định dạng tiền** | Số nguyên, phân cách nghìn bằng dấu chấm, hậu tố `₫`: `15.000.000 ₫`. Số âm hiển thị màu đỏ có dấu trừ. |
| **Hiệu năng** | Trang danh sách < 1.5s với 500 dự án / 20.000 task. Kéo–thả Kanban phản hồi tức thì (optimistic UI). |
| **Trình duyệt** | Chrome, Edge, Safari, Firefox — 2 phiên bản gần nhất. |
| **Responsive** | Desktop là chính (≥1280px). Tablet và mobile phải dùng được: Kanban cuộn ngang, bảng chuyển sang thẻ. |
| **Khả năng tiếp cận** | Tương phản đạt WCAG AA, điều hướng bàn phím trên form và modal, có nhãn cho input. |
| **Bảo mật** | HTTPS bắt buộc · mật khẩu băm bcrypt · CSRF token · chống SQL injection qua ORM · giới hạn tần suất đăng nhập · session hết hạn sau 30 ngày. |
| **Tệp đính kèm** | Tối đa 25MB/tệp. Cho phép: ảnh, PDF, Office, zip, csv, txt. Chặn tệp thực thi. |
| **Sao lưu** | Sao lưu CSDL tự động hàng ngày, giữ 30 ngày. |
| **Nhật ký** | Mọi thay đổi dữ liệu nghiệp vụ ghi vào bảng `activities`, giữ tối thiểu 12 tháng. |

---

## 5. MÔ HÌNH DỮ LIỆU

### 5.1. Sơ đồ quan hệ

```
users ──< project_memberships >── projects ──< tasks ──< subtasks
  │                                   │          │
  │                                   │          ├──< comments
  │                                   │          ├──< attachments
  │                                   │          └──< task_labels >── labels
  │                                   │
  │                                   ├──< board_columns
  │                                   ├──< transactions >── transaction_categories
  │                                   └──< comments
  │
  ├──< notifications
  ├──< activities
  └──< notification_settings

workspace (bản ghi đơn)
transactions.project_id = NULL  →  giao dịch chung workspace

strategy_nodes (tự tham chiếu: parent_id)  ──< strategy_nodes
strategy_snapshots        # ảnh chụp phiên bản cây
ai_suggestion_logs        # log gọi AI gợi ý nhánh
```

### 5.2. Chi tiết bảng

#### `users` — Người dùng

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| email | string | duy nhất, bắt buộc |
| encrypted_password | string | |
| full_name | string | bắt buộc |
| job_title | string | chức danh |
| phone | string | |
| avatar | attachment | ActiveStorage |
| role | enum | `admin` · `member` — mặc định `member` |
| status | enum | `invited` · `active` · `disabled` |
| invitation_token | string | |
| invitation_sent_at | datetime | |
| invitation_accepted_at | datetime | |
| reset_password_token | string | |
| reset_password_sent_at | datetime | |
| last_sign_in_at | datetime | |
| failed_attempts | integer | mặc định 0 |
| locked_at | datetime | |
| created_at / updated_at | datetime | |

#### `workspace` — Cấu hình workspace (chỉ 1 bản ghi)

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| name | string | tên hiển thị |
| logo | attachment | |
| timezone | string | mặc định `Asia/Ho_Chi_Minh` |
| currency | string | cố định `VND` |
| created_at / updated_at | datetime | |

#### `projects` — Dự án

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| code | string | duy nhất, ví dụ `PRD-001` |
| name | string | bắt buộc |
| description | text | |
| project_type | enum | `product_sales` · `digital_transformation` — bắt buộc |
| status | enum | `planning` · `in_progress` · `on_hold` · `completed` · `cancelled` |
| client_name | string | |
| start_date | date | |
| due_date | date | |
| completed_at | datetime | |
| progress_mode | enum | `auto` · `manual` — mặc định `auto` |
| manual_progress | integer | 0–100, dùng khi `manual` |
| color | string | mã hex nhãn màu |
| owner_id | bigint FK → users | người phụ trách |
| created_by_id | bigint FK → users | |
| archived_at | datetime | |
| discarded_at | datetime | soft delete |
| created_at / updated_at | datetime | |

*Chỉ mục:* `project_type`, `status`, `owner_id`, `discarded_at`.

#### `project_memberships` — Thành viên dự án

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| project_id | bigint FK | |
| user_id | bigint FK | |
| joined_at | datetime | |

*Ràng buộc:* duy nhất theo cặp `(project_id, user_id)`.

#### `board_columns` — Cột Kanban

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| project_id | bigint FK | |
| name | string | ví dụ "Đang làm" |
| key | string | `todo` · `doing` · `review` · `done` · tuỳ chỉnh |
| color | string | hex |
| position | integer | thứ tự hiển thị |
| wip_limit | integer | nullable |
| is_done_column | boolean | dùng để tính tiến độ tự động |

#### `tasks` — Công việc

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| project_id | bigint FK | |
| board_column_id | bigint FK | cột hiện tại |
| code | string | `DX-004-17` |
| title | string | bắt buộc |
| description | text | rich text |
| priority | enum | `low` · `medium` · `high` · `urgent` |
| assignee_id | bigint FK → users | nullable |
| reporter_id | bigint FK → users | người tạo |
| start_date | date | |
| due_date | date | |
| estimated_hours | decimal(6,2) | |
| position | decimal | thứ tự trong cột |
| status | enum | `open` · `done` · `cancelled` — dẫn xuất từ cột |
| completed_at | datetime | |
| discarded_at | datetime | |
| created_at / updated_at | datetime | |

*Chỉ mục:* `(project_id, board_column_id, position)`, `assignee_id`, `due_date`.

#### `subtasks` — Việc con

| Trường | Kiểu |
|---|---|
| id | bigint PK |
| task_id | bigint FK |
| title | string |
| done | boolean |
| position | integer |

#### `labels` / `task_labels` — Nhãn

`labels`: `id`, `project_id` (nullable → nhãn toàn cục), `name`, `color`.
`task_labels`: `id`, `task_id`, `label_id`.

#### `comments` — Bình luận

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| commentable_type | string | `Task` · `Project` |
| commentable_id | bigint | đa hình |
| user_id | bigint FK | |
| body | text | HTML đã làm sạch |
| edited_at | datetime | |
| discarded_at | datetime | |
| created_at / updated_at | datetime | |

#### `mentions` — Nhắc tên

`id`, `comment_id`, `user_id`, `notified_at`.

#### `transaction_categories` — Danh mục thu chi

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| name | string | |
| kind | enum | `income` · `expense` |
| is_active | boolean | |
| position | integer | |

#### `transactions` — Giao dịch thu chi

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| kind | enum | `income` (Thu) · `expense` (Chi) — bắt buộc |
| amount | bigint | **VND, số nguyên, luôn dương** |
| occurred_on | date | ngày giao dịch, bắt buộc |
| category_id | bigint FK | |
| project_id | bigint FK | **nullable → giao dịch chung workspace** |
| description | string | diễn giải |
| counterparty | string | đối tác / nhà cung cấp |
| payment_method | enum | `cash` · `bank_transfer` · `card` · `other` |
| created_by_id | bigint FK → users | |
| discarded_at | datetime | |
| created_at / updated_at | datetime | |

*Chỉ mục:* `(occurred_on)`, `(project_id, kind)`, `category_id`.

#### `attachments` — Tệp đính kèm

Dùng ActiveStorage gắn vào `Task` và `Comment` và `Transaction` (chứng từ).

#### `activities` — Nhật ký hoạt động

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| user_id | bigint FK | người thực hiện |
| action | string | `created` · `updated` · `deleted` · `moved` · `commented` · `assigned` … |
| trackable_type / trackable_id | string / bigint | đối tượng bị tác động |
| project_id | bigint FK | nullable, để lọc nhanh |
| changes_payload | jsonb | trước/sau |
| created_at | datetime | |

#### `notifications` — Thông báo trong app

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| user_id | bigint FK | người nhận |
| event_type | string | `task_assigned` · `mentioned` · `comment_added` · `task_due_soon` · `task_overdue` · `project_status_changed` · `added_to_project` |
| title | string | |
| body | string | |
| url | string | link mở thẳng đối tượng |
| read_at | datetime | |
| emailed_at | datetime | |
| created_at | datetime | |

#### `strategy_nodes` — Nút cây định hướng

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| parent_id | bigint FK → strategy_nodes | `NULL` = nút gốc (chỉ có đúng 1) |
| title | string(120) | bắt buộc |
| note | text | ghi chú dài |
| color | string | hex, nullable → kế thừa màu nhánh cha |
| icon | string | emoji hoặc tên icon |
| status | enum | `idea` (Ý tưởng) · `pursuing` (Đang theo đuổi) · `paused` (Tạm gác) · `achieved` (Đã đạt) · `dropped` (Bỏ) |
| owner_id | bigint FK → users | nullable |
| position | decimal | thứ tự trong cùng cha (chèn giữa bằng trung bình cộng) |
| depth | integer | 0 = gốc, tối đa 6 |
| collapsed | boolean | trạng thái thu gọn mặc định |
| children_count | integer | bộ đếm cache (counter cache) |
| ai_generated | boolean | đánh dấu nút sinh từ gợi ý AI (để thống kê) |
| created_by_id | bigint FK → users | |
| updated_by_id | bigint FK → users | |
| discarded_at | datetime | soft delete, xoá cả nhánh con |
| created_at / updated_at | datetime | |

*Chỉ mục:* `(parent_id, position)`, `depth`, `status`, `owner_id`, `discarded_at`.

*Gợi ý truy vấn:* dùng **CTE đệ quy** của PostgreSQL để lấy cả cây trong 1 truy vấn, hoặc thêm cột `path` kiểu `ltree` nếu cây lớn. Với quy mô vài trăm nút thì tải toàn bộ và dựng cây trong bộ nhớ là đủ nhanh.

#### `strategy_snapshots` — Ảnh chụp phiên bản cây

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| name | string | ví dụ "Định hướng Q4/2026" |
| payload | jsonb | toàn bộ cây tại thời điểm chụp |
| node_count | integer | |
| auto | boolean | `true` = ảnh chụp tự động hàng ngày |
| created_by_id | bigint FK → users | nullable khi tự động |
| created_at | datetime | |

#### `ai_suggestion_logs` — Log gọi AI

| Trường | Kiểu | Ghi chú |
|---|---|---|
| id | bigint PK | |
| user_id | bigint FK | |
| node_id | bigint FK → strategy_nodes | nullable |
| mode | enum | `children` (gợi ý nhánh con) · `subtree` (dựng cả cây con) |
| instruction | text | chỉ dẫn tự do của người dùng |
| suggestions | jsonb | kết quả AI trả về |
| accepted_count | integer | số gợi ý được chèn thật |
| status | enum | `success` · `failed` · `cancelled` |
| duration_ms | integer | |
| created_at | datetime | |

#### `notification_settings` — Cấu hình nhận email

`id`, `user_id`, `event_type`, `email_enabled` (boolean), `in_app_enabled` (boolean).
Thêm `daily_digest_enabled` (boolean) ở cấp user.

---

## 6. QUY TẮC NGHIỆP VỤ

| ID | Quy tắc |
|---|---|
| BR-01 | Mã dự án tự sinh theo loại hình: `product_sales` → tiền tố `PRD`, `digital_transformation` → tiền tố `DX`; số thứ tự tăng dần 3 chữ số. Sửa được nhưng phải duy nhất. |
| BR-02 | Tiến độ tự động (%) = `round(số task ở cột is_done_column / số task chưa huỷ × 100)`. Dự án không có task → 0%. |
| BR-03 | Khi task được kéo vào cột `is_done_column` → `status = done`, ghi `completed_at`. Kéo ra khỏi cột đó → `status = open`, xoá `completed_at`. |
| BR-04 | Khi dự án chuyển sang `completed`, ghi `completed_at`. Nếu còn task chưa xong, hiện cảnh báo xác nhận (không chặn). |
| BR-05 | Lợi nhuận dự án = `Σ transactions(income) − Σ transactions(expense)` trong phạm vi dự án đó. |
| BR-06 | Lợi nhuận workspace = `Σ toàn bộ income − Σ toàn bộ expense`, **bao gồm** cả giao dịch chung (`project_id = NULL`). |
| BR-07 | `transactions.amount` luôn lưu số dương; dấu do `kind` quyết định. Số tiền tối thiểu 1 ₫. |
| BR-08 | Giao dịch không cho ghi ngày ở tương lai quá 1 năm. |
| BR-09 | Chỉ gán task cho người **đã là thành viên dự án**. Gỡ một người khỏi dự án khi họ còn task đang mở → cảnh báo và yêu cầu chuyển giao hoặc bỏ gán. |
| BR-10 | Người phụ trách dự án (`owner`) mặc định được thêm vào `project_memberships`. |
| BR-11 | Xoá dự án = soft delete; task và giao dịch thuộc dự án đó cũng bị ẩn nhưng **không xoá dữ liệu tài chính** khỏi báo cáo lịch sử — hiện gắn nhãn "Dự án đã xoá". |
| BR-12 | Không gửi thông báo cho chính người vừa tạo ra hành động đó. |
| BR-13 | Task quá hạn = `due_date < hôm nay` và `status = open`. |
| BR-14 | Thành viên `disabled` không nhận email, không xuất hiện trong danh sách chọn người thực hiện, nhưng vẫn hiện đúng tên ở dữ liệu cũ. |
| BR-15 | Cây định hướng luôn tồn tại đúng **một nút gốc** (`parent_id = NULL`). Hệ thống tự tạo nút gốc khi khởi tạo workspace; không cho xoá. |
| BR-16 | `depth` của nút = `depth(cha) + 1`. Khi di chuyển một nút, **tính lại depth cho toàn bộ nhánh con**; nếu nhánh sâu nhất vượt quá 6 thì từ chối thao tác. |
| BR-17 | Không cho phép đặt một nút làm con của chính hậu duệ nó (chống vòng lặp). Kiểm tra ở cả frontend và backend. |
| BR-18 | Xoá một nút theo chế độ `cascade` → soft delete cả nhánh con. Theo chế độ `promote` → các nút con được gán `parent_id` của nút bị xoá và tính lại `depth`. |
| BR-19 | Nút không có `color` riêng thì kế thừa màu của tổ tiên gần nhất có màu; nếu không có ai đặt màu, dùng màu mặc định theo cấp 1. |
| BR-20 | AI chỉ **thêm** nút mới, không sửa và không xoá nút đang có. Nút do AI sinh ra đánh dấu `ai_generated = true`. |
| BR-21 | Mỗi người tối đa 30 lượt gọi AI gợi ý mỗi ngày (tính theo giờ Việt Nam, reset lúc 00:00). Lượt `failed` hoặc `cancelled` không tính. |
| BR-22 | Ảnh chụp tự động chạy 23:00 hằng ngày, chỉ chạy khi cây có thay đổi trong ngày. Giữ 30 bản `auto` gần nhất; bản đặt tên thủ công giữ vĩnh viễn. |
| BR-23 | Khôi phục một ảnh chụp sẽ **chụp lại trạng thái hiện tại trước** rồi mới ghi đè, để luôn quay lại được. |

---

## 7. THIẾT KẾ GIAO DIỆN

### 7.1. Bố cục khung

```
┌───────────────────────────────────────────────────────────────┐
│  Thanh trên: Logo · Tìm kiếm · [+ Tạo mới] · 🔔 · Avatar       │
├──────────┬────────────────────────────────────────────────────┤
│ Sidebar  │                                                    │
│          │                                                    │
│ Tổng quan│              Vùng nội dung chính                   │
│ Định     │                                                    │
│   hướng  │                                                    │
│ Dự án    │                                                    │
│ Việc của │                                                    │
│   tôi    │                                                    │
│ Thu chi  │                                                    │
│ Thành    │                                                    │
│   viên   │                                                    │
│ Hoạt động│                                                    │
│ ──────── │                                                    │
│ Cài đặt  │                                                    │
└──────────┴────────────────────────────────────────────────────┘
```

- Sidebar cố định 240px, thu gọn được còn 64px (chỉ icon).
- Thanh trên cao 56px, dính (sticky).
- Nút **[+ Tạo mới]** mở menu: Dự án mới · Công việc mới · Giao dịch mới.
- Ô tìm kiếm toàn cục: tìm dự án, task, giao dịch.

### 7.2. Danh sách màn hình

| # | Màn hình | Đường dẫn | Mô tả |
|---|---|---|---|
| 1 | Đăng nhập | `/dang-nhap` | Logo, email, mật khẩu, "Duy trì đăng nhập", link quên mật khẩu |
| 2 | Quên mật khẩu / Đặt lại | `/quen-mat-khau` | |
| 3 | Kích hoạt lời mời | `/loi-moi/:token` | Đặt mật khẩu + họ tên |
| 4 | **Tổng quan (Dashboard)** | `/` | Xem mục 3.8 |
| 4b | **Định hướng (cây)** | `/dinh-huong` | Canvas cây định hướng — xem mục 3.10 |
| 4c | Lịch sử phiên bản cây | `/dinh-huong/phien-ban` | Danh sách ảnh chụp, xem lại, khôi phục |
| 5 | Danh sách dự án | `/du-an` | Chế độ thẻ / bảng, bộ lọc, tìm kiếm |
| 6 | Tạo/Sửa dự án | modal | Form theo FR-PRJ-01 |
| 7 | Chi tiết dự án — Tổng quan | `/du-an/:code` | |
| 8 | Chi tiết dự án — Công việc | `/du-an/:code/cong-viec` | Bảng danh sách |
| 9 | **Chi tiết dự án — Kanban** | `/du-an/:code/kanban` | Board kéo–thả |
| 10 | Chi tiết dự án — Thu chi | `/du-an/:code/thu-chi` | |
| 11 | Chi tiết dự án — Thành viên | `/du-an/:code/thanh-vien` | |
| 12 | Chi tiết dự án — Hoạt động | `/du-an/:code/hoat-dong` | |
| 13 | Chi tiết công việc | panel trượt phải hoặc `/cong-viec/:code` | |
| 14 | Việc của tôi | `/viec-cua-toi` | Gộp task mọi dự án |
| 15 | **Sổ thu chi** | `/thu-chi` | Bảng toàn workspace + bộ lọc + xuất Excel |
| 16 | Tạo/Sửa giao dịch | modal | |
| 17 | Thành viên | `/thanh-vien` | Danh sách + nút Mời |
| 18 | Nhật ký hoạt động | `/hoat-dong` | |
| 19 | Hồ sơ cá nhân | `/ho-so` | Thông tin + đổi mật khẩu + cấu hình thông báo |
| 20 | Cài đặt workspace | `/cai-dat` | Tên, logo, danh mục thu chi (chỉ Admin) |
| 21 | Thông báo | dropdown + `/thong-bao` | |

### 7.3. Ngôn ngữ thiết kế

**Nguyên tắc:** giao diện gọn, dày đặc thông tin nhưng thoáng; ưu tiên đọc nhanh số liệu; không trang trí thừa. Tham chiếu tinh thần: Linear × Notion, nhưng ấm và thân thiện hơn cho team Việt.

**Bảng màu**

| Vai trò | Màu | Ghi chú |
|---|---|---|
| Nền chính | `#FFFFFF` | |
| Nền phụ / canvas | `#F7F8FA` | nền board, nền trang |
| Viền | `#E5E7EB` | |
| Chữ chính | `#111827` | |
| Chữ phụ | `#6B7280` | |
| Thương hiệu / hành động chính | `#2563EB` | nút chính, link |
| Thành công / Thu | `#16A34A` | |
| Cảnh báo | `#F59E0B` | |
| Nguy hiểm / Chi / Quá hạn | `#DC2626` | |
| Thông tin | `#0EA5E9` | |

**Màu loại hình dự án**
- Sản phẩm & Kinh doanh → `#7C3AED` (tím)
- Chuyển đổi số (Data & AI) → `#0891B2` (xanh cyan)

**Màu độ ưu tiên**
`Thấp` `#94A3B8` · `Trung bình` `#0EA5E9` · `Cao` `#F59E0B` · `Khẩn cấp` `#DC2626`

**Màu trạng thái dự án**
`Lên kế hoạch` xám · `Đang thực hiện` xanh dương · `Tạm dừng` vàng · `Hoàn thành` xanh lá · `Huỷ` đỏ nhạt

**Chữ**
- Font: `Inter` (hỗ trợ đầy đủ dấu tiếng Việt). Dự phòng: `system-ui`.
- Cỡ: H1 24px/600 · H2 20px/600 · H3 16px/600 · Body 14px/400 · Phụ 13px/400 · Nhãn 12px/500.
- Số tiền dùng `font-variant-numeric: tabular-nums` để cột số thẳng hàng.

**Khoảng cách & bo góc**
- Lưới 4px. Khoảng cách dùng: 4 / 8 / 12 / 16 / 24 / 32.
- Bo góc: nút & input 8px · thẻ 12px · modal 16px · chip 999px.
- Đổ bóng: nhẹ `0 1px 2px rgba(0,0,0,.06)`; thẻ đang kéo `0 8px 24px rgba(0,0,0,.12)`.

**Thành phần cần thiết kế**
Nút (chính/phụ/viền/nguy hiểm/icon) · Input · Select · Date picker · Ô nhập tiền · Textarea rich text · Chip/Badge · Avatar & nhóm avatar · Thanh tiến độ · Thẻ chỉ số (KPI card) · Bảng có sắp xếp · Thẻ Kanban · Cột Kanban · Panel trượt · Modal · Dropdown menu · Tab · Toast · Trạng thái rỗng (empty state) · Skeleton loading · Phân trang.

### 7.4. Ghi chú thiết kế theo màn hình trọng điểm

**Dashboard**
- Trên cùng: bộ lọc kỳ + loại hình (chip dạng segmented control).
- Hàng 1: 4 thẻ tài chính lớn, số tiền cỡ 28px đậm, % thay đổi kèm mũi tên.
- Hàng 2: biểu đồ Thu–Chi (chiếm 2/3) + Cơ cấu chi donut (1/3).
- Hàng 3: Bảng tình trạng dự án (2/3) + Việc của tôi (1/3).
- Hàng 4: Phân bổ công việc theo người (1/2) + Hoạt động gần đây (1/2).

**Kanban**
- Cột rộng 300px, cuộn ngang khi nhiều cột.
- Tiêu đề cột: tên · số lượng · (WIP limit) · menu ⋯ · nút `+`.
- Kéo thả có vùng thả (drop zone) hiện rõ bằng viền đứt màu thương hiệu.
- Thẻ nhỏ gọn, cao ~92px khi không có nhãn.
- Nút `+ Thêm công việc` ở cuối mỗi cột, tạo nhanh chỉ cần tiêu đề.

**Sổ thu chi**
- Thanh bộ lọc dạng hàng chip có thể xoá từng cái.
- Dòng Thu màu xanh với dấu `+`, dòng Chi màu đỏ với dấu `−`.
- Cột "Dự án": chip màu loại hình; nếu là giao dịch chung hiện chip xám **"Chung workspace"**.
- Chân bảng dính (sticky) hiện Tổng thu / Tổng chi / Chênh lệch của kết quả đang lọc.

**Chi tiết công việc**
- Panel trượt từ phải, rộng 640px, nền ngoài mờ.
- Bên trái: tiêu đề, mô tả, việc con, tệp đính kèm, bình luận.
- Bên phải (cột 240px): trạng thái, người thực hiện, độ ưu tiên, hạn, nhãn, ước lượng, người tạo, ngày tạo.

**Định hướng (cây)**

Bố cục 3 vùng:

```
┌──────────────────────────────────────────────────────────────────┐
│ Định hướng   [Sơ đồ|Cây dọc|Outline]  🔍 Tìm  Lọc▾  Cấp:3▾       │
│                                     [✨ Gợi ý] [Xuất▾] [Phiên bản]│
├───────────────────────────────────────────────┬──────────────────┤
│                                               │  Chi tiết nút    │
│            CANVAS CÂY                         │                  │
│        (pan · zoom · kéo thả)                 │  Tiêu đề         │
│                                               │  Trạng thái      │
│                                               │  Người phụ trách │
│                                               │  Màu · Icon      │
│                                               │  Ghi chú         │
│                                  ┌─────────┐  │  ──────────────  │
│                                  │ minimap │  │  ✨ Gợi ý nhánh  │
│                                  └─────────┘  │     con          │
│  [− 100% +] [Vừa màn hình] [Về gốc]           │  (danh sách tick)│
└───────────────────────────────────────────────┴──────────────────┘
```

- **Canvas** nền `#F7F8FA` có lưới chấm mờ, chiếm toàn bộ vùng còn lại.
- **Nút**: thẻ bo 10px, nền trắng, viền 1px; viền trái dày 3px mang màu nhánh. Tiêu đề 14px/500, tối đa 2 dòng rồi `…`. Chip trạng thái nhỏ ở góc dưới trái, avatar người phụ trách ở góc dưới phải.
- Nút **đang chọn**: viền 2px màu thương hiệu + đổ bóng nhẹ. Nút **đang kéo**: nghiêng 2°, bóng đậm, mờ 80%.
- Nút có con mà **đang thu gọn**: hiện badge tròn số con ở cạnh phải, click để mở.
- **Nét nối**: đường cong bézier mảnh 1.5px, màu nhạt hơn màu nhánh 40%.
- **Vùng thả hợp lệ** khi kéo: nút đích sáng viền đứt màu thương hiệu; thả xen giữa 2 nút thì hiện một đường ngang màu thương hiệu tại vị trí chèn.
- **Nút lệnh nổi**: hover vào một nút hiện 3 nút tròn nhỏ bên phải — `+` (thêm con) · `✨` (gợi ý AI) · `⋯` (menu: nhân bản, đổi màu, xoá).
- **Panel chi tiết** rộng 320px, trượt từ phải, mở khi chọn nút; đóng được để canvas rộng tối đa.
- **Panel gợi ý AI**: mỗi gợi ý là 1 dòng có checkbox + tiêu đề (sửa tại chỗ) + dòng giải thích màu xám. Dưới cùng: `Đã chọn 3` + nút **Thêm vào cây** và **Gợi ý lại**.
- **Chế độ outline**: bỏ canvas, hiện danh sách thụt lề với tam giác thu/mở, kéo thả theo hàng, đọc nhanh như văn bản.
- **Chế độ trình bày**: `F` để vào toàn màn hình, ẩn sidebar và panel, chỉ còn cây.

**Trạng thái rỗng**
Mỗi màn hình cần một empty state có minh hoạ đơn giản + một câu tiếng Việt + nút hành động. Ví dụ: *"Chưa có dự án nào. Tạo dự án đầu tiên để bắt đầu."*
Riêng cây định hướng, khi mới chỉ có nút gốc: *"Bắt đầu bằng những mảng lớn team đang theo đuổi."* + 2 nút: **Thêm mảng đầu tiên** và **✨ Để AI gợi ý**.

---

## 8. GIAO DIỆN LẬP TRÌNH (API)

Dùng cho phần động của giao diện (Kanban, bộ lọc, dashboard). Tiền tố: `/api/v1`. Xác thực bằng session cookie. Định dạng JSON.

### 8.1. Dự án

```
GET    /api/v1/projects                 ?type=&status=&owner_id=&q=&archived=&page=
GET    /api/v1/projects/:id
POST   /api/v1/projects
PATCH  /api/v1/projects/:id
DELETE /api/v1/projects/:id             # soft delete
POST   /api/v1/projects/:id/archive
POST   /api/v1/projects/:id/members     { user_ids: [] }
DELETE /api/v1/projects/:id/members/:user_id
GET    /api/v1/projects/:id/summary     # chỉ số nhanh tab Tổng quan
```

### 8.2. Cột Kanban

```
GET    /api/v1/projects/:id/columns
POST   /api/v1/projects/:id/columns     { name, color, wip_limit }
PATCH  /api/v1/columns/:id              { name, color, position, wip_limit, is_done_column }
DELETE /api/v1/columns/:id              # yêu cầu cột trống hoặc chỉ định cột chuyển sang
```

### 8.3. Công việc

```
GET    /api/v1/projects/:id/tasks       ?column_id=&assignee_id=&priority=&label_id=&due=&q=
GET    /api/v1/tasks/:id
POST   /api/v1/projects/:id/tasks
PATCH  /api/v1/tasks/:id
DELETE /api/v1/tasks/:id
PATCH  /api/v1/tasks/:id/move           { board_column_id, position }
POST   /api/v1/tasks/:id/subtasks       { title }
PATCH  /api/v1/subtasks/:id             { title, done, position }
DELETE /api/v1/subtasks/:id
GET    /api/v1/me/tasks                 ?group=overdue|today|this_week|later|no_due
```

### 8.4. Bình luận

```
GET    /api/v1/tasks/:id/comments
POST   /api/v1/tasks/:id/comments       { body, attachment_ids: [] }
PATCH  /api/v1/comments/:id
DELETE /api/v1/comments/:id
GET    /api/v1/projects/:id/comments
POST   /api/v1/projects/:id/comments
```

### 8.5. Thu chi

```
GET    /api/v1/transactions   ?kind=&project_id=&category_id=&created_by_id=
                              &from=&to=&min_amount=&max_amount=&q=&page=
GET    /api/v1/transactions/:id
POST   /api/v1/transactions
PATCH  /api/v1/transactions/:id
DELETE /api/v1/transactions/:id
GET    /api/v1/transactions/export       ?<cùng bộ lọc>&format=xlsx|csv
GET    /api/v1/transaction_categories    ?kind=
POST   /api/v1/transaction_categories
PATCH  /api/v1/transaction_categories/:id
```

**Ví dụ tạo giao dịch**

```json
POST /api/v1/transactions
{
  "kind": "expense",
  "amount": 15000000,
  "occurred_on": "2026-09-14",
  "category_id": 3,
  "project_id": null,
  "description": "Thanh toán server AWS tháng 9",
  "counterparty": "Amazon Web Services",
  "payment_method": "bank_transfer"
}
```

### 8.6. Dashboard

```
GET /api/v1/dashboard/finance        ?from=&to=&project_type=
    → { total_income, total_expense, profit, workspace_expense,
        income_change_pct, expense_change_pct, profit_change_pct }

GET /api/v1/dashboard/monthly_flow   ?months=12&project_type=
    → [ { month: "2026-09", income, expense, profit } ]

GET /api/v1/dashboard/expense_by_category ?from=&to=
    → [ { category_id, name, amount, percentage } ]

GET /api/v1/dashboard/by_project_type     ?from=&to=
    → [ { project_type, income, expense, profit, project_count } ]

GET /api/v1/dashboard/projects_status     ?from=&to=&project_type=
    → [ { id, code, name, project_type, owner, progress,
          status, due_date, income, expense, profit, is_overdue } ]

GET /api/v1/dashboard/project_stats       ?from=&to=&project_type=
    → { in_progress, overdue, completed_in_period, open_tasks }

GET /api/v1/dashboard/workload
    → [ { user_id, full_name, todo, doing, review, done, overdue } ]

GET /api/v1/dashboard/top_projects        ?from=&to=&limit=5
    → { most_profitable: [], least_profitable: [] }
```

### 8.7. Cây định hướng

```
GET    /api/v1/strategy/tree                 # trả về toàn bộ cây dạng lồng nhau
GET    /api/v1/strategy/nodes/:id
POST   /api/v1/strategy/nodes                { parent_id, title, note, color, icon, status, owner_id, position }
PATCH  /api/v1/strategy/nodes/:id
DELETE /api/v1/strategy/nodes/:id            ?mode=cascade|promote
PATCH  /api/v1/strategy/nodes/:id/move       { parent_id, position }
POST   /api/v1/strategy/nodes/:id/duplicate  # nhân bản kèm nhánh con
PATCH  /api/v1/strategy/nodes/:id/collapse   { collapsed: true|false }

POST   /api/v1/strategy/bulk_import          { parent_id, text }     # dán danh sách thụt lề
POST   /api/v1/strategy/bulk_import/preview  { parent_id, text }     # xem trước, không ghi

POST   /api/v1/strategy/ai/suggest_children  { node_id, instruction, count }
POST   /api/v1/strategy/ai/suggest_subtree   { node_id, topic, depth, instruction }
GET    /api/v1/strategy/ai/quota             # { used, limit, remaining, reset_at }

GET    /api/v1/strategy/snapshots
POST   /api/v1/strategy/snapshots            { name }
GET    /api/v1/strategy/snapshots/:id
POST   /api/v1/strategy/snapshots/:id/restore
GET    /api/v1/strategy/export               ?format=png|markdown&view=mindmap|vertical|outline
```

**Ví dụ `GET /api/v1/strategy/tree`**

```json
{
  "root": {
    "id": 1,
    "title": "Định hướng DC1",
    "status": "pursuing",
    "depth": 0,
    "children": [
      {
        "id": 2,
        "title": "Sản phẩm & Kinh doanh",
        "color": "#7C3AED",
        "status": "pursuing",
        "depth": 1,
        "owner": { "id": 5, "full_name": "Nguyễn Văn A" },
        "children": [
          { "id": 7, "title": "Nghiên cứu thị trường", "status": "achieved", "depth": 2, "children": [] },
          { "id": 8, "title": "Kênh bán trực tiếp",   "status": "pursuing", "depth": 2, "children": [] }
        ]
      },
      {
        "id": 3,
        "title": "Chuyển đổi số (Data & AI)",
        "color": "#0891B2",
        "status": "pursuing",
        "depth": 1,
        "children": []
      }
    ]
  },
  "node_count": 6,
  "updated_at": "2026-09-14T10:22:00+07:00"
}
```

**Ví dụ `POST /api/v1/strategy/ai/suggest_children`**

```json
// Yêu cầu
{
  "node_id": 3,
  "instruction": "tập trung khách hàng ngành bán lẻ tại Việt Nam",
  "count": 6
}

// Phản hồi
{
  "suggestions": [
    { "title": "Xây dựng kho dữ liệu (Data Warehouse)", "reason": "Nền tảng bắt buộc trước khi làm phân tích và AI." },
    { "title": "Báo cáo & Trực quan hoá dữ liệu",       "reason": "Giá trị nhìn thấy sớm, dễ thuyết phục khách hàng." },
    { "title": "Dự báo nhu cầu hàng hoá",                "reason": "Bài toán AI có ROI rõ ràng với ngành bán lẻ." }
  ],
  "quota": { "used": 4, "limit": 30, "remaining": 26 }
}
```

**Ví dụ `POST /api/v1/strategy/bulk_import/preview`**

```json
// Yêu cầu
{ "parent_id": 3, "text": "Data Platform\n\tThu thập dữ liệu\n\tLàm sạch dữ liệu\nỨng dụng AI\n\tChatbot nội bộ" }

// Phản hồi
{
  "preview": [
    { "title": "Data Platform", "depth": 1, "children": [
        { "title": "Thu thập dữ liệu", "depth": 2 },
        { "title": "Làm sạch dữ liệu", "depth": 2 } ] },
    { "title": "Ứng dụng AI", "depth": 1, "children": [
        { "title": "Chatbot nội bộ", "depth": 2 } ] }
  ],
  "total": 5,
  "warnings": []
}
```

### 8.8. Thông báo & Thành viên

```
GET    /api/v1/notifications          ?unread=true&page=
PATCH  /api/v1/notifications/:id/read
POST   /api/v1/notifications/read_all
GET    /api/v1/notification_settings
PATCH  /api/v1/notification_settings  { settings: [{ event_type, email_enabled, in_app_enabled }], daily_digest_enabled }

GET    /api/v1/users                  ?status=&q=
POST   /api/v1/invitations            { emails: ["a@dc1.vn"] }   # chỉ admin
POST   /api/v1/invitations/:id/resend
PATCH  /api/v1/users/:id/disable
PATCH  /api/v1/users/:id/enable

GET    /api/v1/activities             ?user_id=&project_id=&action=&from=&to=&page=
GET    /api/v1/search                 ?q=   # dự án + task + giao dịch
```

### 8.9. Quy ước phản hồi lỗi

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Dữ liệu không hợp lệ",
    "details": { "amount": ["Số tiền phải lớn hơn 0"] }
  }
}
```

Mã HTTP: `200` · `201` · `400` · `401` · `403` · `404` · `422` · `429` · `500`.
**Mọi `message` và `details` trả về bằng tiếng Việt** để hiển thị trực tiếp lên giao diện.

---

## 9. GỢI Ý KỸ THUẬT (Ruby on Rails)

| Thành phần | Lựa chọn |
|---|---|
| Framework | Rails 7.1+ (hoặc Rails 8), chế độ full-stack |
| CSDL | PostgreSQL 15+ |
| Giao diện động | Hotwire — Turbo Frames + Turbo Streams + Stimulus |
| CSS | TailwindCSS (`tailwindcss-rails`) |
| Kéo–thả Kanban | `SortableJS` bọc trong Stimulus controller; gọi `PATCH /tasks/:id/move`; cập nhật lạc quan (optimistic) rồi hoàn tác nếu lỗi |
| Canvas cây định hướng | Vẽ bằng **SVG** trong Stimulus controller. Bố trí tự động bằng **`d3-hierarchy`** (`d3.tree()` cho cây dọc, `d3.tree()` xoay 90° cho mindmap ngang); pan/zoom bằng `d3-zoom`. Nếu cần bố trí phức tạp hơn có thể thay bằng `elkjs`. |
| Kéo–thả trên cây | Tự viết bằng Pointer Events trong Stimulus (SortableJS không hợp với SVG lồng nhau). Chế độ outline thì dùng lại SortableJS. |
| AI gợi ý nhánh | Claude API (`claude-sonnet`) gọi từ background job; prompt tiếng Việt, yêu cầu trả về JSON schema cố định `{suggestions:[{title, reason}]}`; kết quả đẩy về giao diện qua Turbo Stream. Lưu khoá API trong Rails credentials. |
| Hoàn tác trên cây | Ngăn xếp lệnh (command stack) phía client, mỗi lệnh có `do`/`undo` gọi API tương ứng |
| Xuất PNG cây | Serialize SVG → canvas → PNG ở phía trình duyệt (không cần headless browser) |
| Xác thực | Devise (`:database_authenticatable`, `:recoverable`, `:rememberable`, `:lockable`, `:trackable`) + Devise Invitable cho lời mời |
| Phân quyền | Pundit — policy đơn giản ở MVP, sẵn sàng mở rộng |
| Soft delete | `discard` gem |
| Hàng đợi nền | Solid Queue (Rails 8) hoặc Sidekiq + Redis |
| Email | ActionMailer + SMTP (SendGrid / Amazon SES / Resend). Template dùng `mjml-rails` hoặc HTML inline-css |
| Việc theo lịch | `cron` job: nhắc hạn 1 ngày trước, quét quá hạn, bản tin 08:00 |
| Tệp | ActiveStorage + S3-compatible (AWS S3 / Cloudflare R2) |
| Rich text | ActionText (Trix) — cấu hình cho mô tả task và bình luận |
| Biểu đồ | Chartkick + Chart.js, hoặc ApexCharts qua Stimulus |
| Xuất Excel | `caxlsx` / `caxlsx_rails` |
| Nhật ký | `public_activity` hoặc bảng `activities` tự viết |
| i18n | `config.i18n.default_locale = :vi`, toàn bộ chuỗi trong `config/locales/vi.yml`, không hardcode |
| Định dạng tiền | Helper `format_vnd(amount)` → `"15.000.000 ₫"`; `number_to_currency(unit: "₫", delimiter: ".", precision: 0, format: "%n %u")` |
| Kiểm thử | RSpec + FactoryBot; system test bằng Capybara cho luồng Kanban |
| Triển khai | Kamal / Docker, hoặc Render / Fly.io |

**Lưu ý triển khai quan trọng**

1. **Tiền tệ:** lưu `amount` là `bigint` VND, **không dùng decimal**. Không nhân 100. Tránh mọi phép chia làm tròn sai.
2. **Thứ tự Kanban:** `position` dùng `decimal` để chèn giữa 2 thẻ mà không phải đánh số lại cả cột (`(prev + next) / 2`). Đánh số lại nền khi khoảng cách quá nhỏ.
3. **Truy vấn N+1:** dashboard và danh sách dự án dùng `includes` + truy vấn tổng hợp (`group().sum()`) thay vì lặp Ruby.
4. **Múi giờ:** đặt `config.time_zone = "Asia/Ho_Chi_Minh"`, lưu UTC trong DB, hiển thị theo giờ VN.
5. **Thông báo:** mọi email đi qua job nền, không bao giờ gửi trong request cycle.
6. **Cây định hướng:** tải toàn bộ cây trong **một truy vấn** rồi dựng cấu trúc lồng nhau trong Ruby — tuyệt đối tránh đệ quy gọi DB từng cấp. Dùng `counter_culture` hoặc counter cache cho `children_count`.
7. **Di chuyển nút:** một thao tác `move` phải nằm trong **một transaction** — cập nhật `parent_id`, `position`, và `depth` của cả nhánh con; nếu vi phạm ràng buộc thì rollback toàn bộ.
8. **Gọi AI:** luôn đặt timeout (20s) và chạy trong job nền; giao diện không được khoá. Không gửi dữ liệu tài chính hay thông tin khách hàng vào prompt — chỉ gửi tiêu đề nút và đường dẫn nhánh.

---

## 10. TIÊU CHÍ NGHIỆM THU (MVP)

Hệ thống được coi là hoàn thành MVP khi đạt toàn bộ:

- [ ] Admin mời được thành viên qua email; thành viên kích hoạt và đăng nhập thành công.
- [ ] Tạo được dự án thuộc cả 2 loại hình, mã tự sinh đúng tiền tố.
- [ ] Mỗi dự án có Kanban với 4 cột mặc định; kéo–thả task giữa cột lưu đúng và không mất thứ tự sau khi tải lại trang.
- [ ] Tuỳ chỉnh được cột Kanban (thêm/đổi tên/xoá/sắp xếp).
- [ ] Gán task cho thành viên; người được gán nhận email và thông báo trong app.
- [ ] Bình luận + @mention hoạt động, người được nhắc nhận email.
- [ ] Tiến độ dự án tự cập nhật khi task chuyển sang cột Hoàn thành.
- [ ] Ghi được giao dịch thu và chi, gắn dự án hoặc để trống (chung workspace).
- [ ] Sổ thu chi lọc đúng theo mọi tiêu chí và xuất được file Excel.
- [ ] Dashboard hiển thị đúng: tổng thu, tổng chi, lợi nhuận, cơ cấu chi, thu chi theo 2 mảng, bảng tình trạng dự án, phân bổ công việc.
- [ ] Số tiền hiển thị đúng định dạng `15.000.000 ₫` ở mọi màn hình và trong file xuất.
- [ ] Email nhắc hạn trước 1 ngày và email quá hạn gửi đúng lịch.
- [ ] Nhật ký hoạt động ghi đủ thao tác tạo/sửa/xoá/chuyển cột.
- [ ] Cây định hướng tạo được nút bằng phím tắt (`Tab` / `Enter` / `Shift+Tab`) và sửa tiêu đề tại chỗ.
- [ ] Kéo–thả nút trên cây đổi được cha và đổi thứ tự; chặn đúng trường hợp thả vào hậu duệ và vượt 6 cấp.
- [ ] Dán một danh sách thụt lề vào cây dựng ra đúng cấu trúc phân cấp.
- [ ] AI gợi ý được 5–8 nhánh con tiếng Việt, không trùng nút đã có; người dùng tick chọn rồi chèn thành công.
- [ ] Cây tự bố trí gọn gàng, không chồng nút, ở cả 3 chế độ xem; zoom và "Vừa màn hình" hoạt động.
- [ ] Xuất được cây ra PNG và Markdown outline.
- [ ] Ảnh chụp phiên bản cây lưu và khôi phục đúng.
- [ ] Toàn bộ giao diện, email, thông báo lỗi bằng tiếng Việt — không còn chuỗi tiếng Anh nào lọt ra người dùng.
- [ ] Dùng được trên tablet và điện thoại ở mức đọc và thao tác cơ bản.

---

## 11. LỘ TRÌNH

| Giai đoạn | Nội dung | Ước lượng |
|---|---|---|
| **GĐ 0 — Nền tảng** | Khởi tạo Rails, CSDL, Devise + lời mời, layout khung, i18n tiếng Việt, thư viện UI cơ bản | 1 tuần |
| **GĐ 1 — Dự án & Công việc** | CRUD dự án, thành viên dự án, task, danh sách task, task con, nhãn, tệp đính kèm | 2 tuần |
| **GĐ 2 — Kanban & Bình luận** | Board, cột tuỳ chỉnh, kéo–thả, bình luận, @mention, Việc của tôi | 1.5 tuần |
| **GĐ 3 — Thu chi** | Giao dịch, danh mục, sổ thu chi, bộ lọc, xuất Excel, tab thu chi trong dự án | 1.5 tuần |
| **GĐ 4 — Dashboard** | Toàn bộ widget tài chính + dự án + phân bổ công việc | 1.5 tuần |
| **GĐ 5 — Thông báo** | Thông báo trong app, email theo sự kiện, job nhắc hạn, bản tin hàng ngày, cấu hình nhận thông báo | 1 tuần |
| **GĐ 5b — Cây định hướng** | Mô hình dữ liệu cây, canvas SVG + tự bố trí, kéo–thả, phím tắt outline, 3 chế độ xem, dán hàng loạt, AI gợi ý nhánh, xuất PNG/Markdown, ảnh chụp phiên bản | 2 tuần |
| **GĐ 6 — Hoàn thiện** | Nhật ký hoạt động, tìm kiếm toàn cục, responsive, empty state, kiểm thử, triển khai | 1.5 tuần |
| | **Tổng MVP** | **≈ 12 tuần** |

**Giai đoạn 2 (sau MVP):** ngân sách dự án · milestone · phụ thuộc task · SSO Google/Microsoft · sales pipeline · timesheet · báo cáo PDF · giao dịch định kỳ · duyệt chi · nhiều cây định hướng · bình luận trên nút cây · con trỏ thời gian thực · chat nhóm realtime (nếu team thấy cần).

> **Ghi chú sắp thứ tự:** Cây định hướng độc lập với phần còn lại nên có thể làm song song từ GĐ 3 nếu có 2 người, hoặc kéo lên làm sớm nếu team muốn dùng ngay cho buổi hoạch định.

---

## PHỤ LỤC A — BẢNG THUẬT NGỮ GIAO DIỆN (tiếng Việt chuẩn hoá)

Dùng đúng các từ này xuyên suốt giao diện để tránh mỗi màn hình một kiểu gọi:

| Khái niệm | Từ dùng |
|---|---|
| Workspace | **Không gian làm việc** (hoặc giữ "Workspace" nếu team quen) |
| Project | **Dự án** |
| Task | **Công việc** |
| Subtask | **Việc con** |
| Assignee | **Người thực hiện** |
| Owner | **Người phụ trách** |
| Due date | **Hạn hoàn thành** |
| Priority | **Độ ưu tiên** |
| Status | **Trạng thái** |
| Progress | **Tiến độ** |
| Label / Tag | **Nhãn** |
| Comment | **Bình luận** |
| Mention | **Nhắc tên** |
| Attachment | **Tệp đính kèm** |
| Income | **Thu** |
| Expense | **Chi** |
| Profit | **Lợi nhuận** |
| Transaction | **Giao dịch** |
| Category | **Danh mục** |
| Dashboard | **Tổng quan** |
| Activity log | **Nhật ký hoạt động** |
| Archive | **Lưu trữ** |
| Notification | **Thông báo** |
| Member | **Thành viên** |
| Invite | **Mời** |
| Board column | **Cột** |
| Strategy map / Mind map | **Định hướng** (trang) · **Cây định hướng** (đối tượng) |
| Node | **Nút** |
| Branch | **Nhánh** |
| Root | **Gốc** |
| Collapse / Expand | **Thu gọn / Mở rộng** |
| Drag & drop | **Kéo thả** |
| Zoom to fit | **Vừa màn hình** |
| Outline | **Danh sách phân cấp** |
| Snapshot | **Ảnh chụp phiên bản** |
| Undo / Redo | **Hoàn tác / Làm lại** |
| AI suggestion | **Gợi ý** |
