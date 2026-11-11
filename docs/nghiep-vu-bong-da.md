# Gợi ý nghiệp vụ môn BÓNG ĐÁ — SportNexus

> Trạng thái: **BẢN GỢI Ý**, chưa phải luật nhóm đã chốt. Mọi con số (K, mốc Elo, phút, số người…) nên để trong
> **Sport Ruleset** (bảng cấu hình + JSONB) để Admin/BTC chỉnh được, không viết cứng trong code.
> Mục cuối file liệt kê các điểm cần nhóm quyết.

Phạm vi bóng đá trong app hiện tại: 3 loại sân `football5`, `football7`, `football11` (xem `lib/models/court_type.dart`).

**Nguyên tắc đã thống nhất (2026-11-02):**

| Mảng | Nguyên tắc |
|---|---|
| Elo | **Chỉ có trong giải đấu**, và **chỉ Team có Elo** (cá nhân không có Elo bóng đá). Chỉ trận giải mới cộng/trừ Elo |
| Giải đấu | Phải có **Team** mới tham gia được. Đội trưởng bấm tham gia → mời thành viên → đủ số người xác nhận thì đội mới được tham gia |
| Số người trong trận | Vào trận phải **đủ số người ra sân** (5/7/11). Đá rồi mà chấn thương, hết người thay thì **vẫn đá tiếp** với số người còn lại |
| Nhân sự giải (trọng tài…) | **Người tạo giải tự đảm bảo**: khai số trọng tài + chi tiết từng người khi tạo giải, tự phân công. App chỉ lưu và nhắc |
| LFG | Chỉ **ghép người**: người lẻ ↔ team thiếu người, người lẻ ↔ người lẻ, team ↔ team. **Không tính Elo** |
| Thể thức giải | Ít đội → **loại trực tiếp**; nhiều đội → **vòng bảng rồi loại trực tiếp** (mốc cụ thể ở mục 4) |

---

## 1. Sport Ruleset bóng đá (thông số theo loại sân)

| Thông số | Sân 5 | Sân 7 | Sân 11 |
|---|---|---|---|
| Số người ra sân mỗi đội | 5 (gồm 1 thủ môn) | 7 (gồm 1 thủ môn) | 11 (gồm 1 thủ môn) |
| **Số thành viên phải xác nhận để đội được tham gia giải** | **7** | **10** | **16** |
| Số cầu thủ tối đa trong danh sách giải | 12 | 15 | 22 |
| Số người tối thiểu để **bắt đầu** trận (= đủ đội hình ra sân) | 5 | 7 | 11 |
| Đang đá mà thiếu người (chấn thương, hết quyền thay) | Đá tiếp | Đá tiếp | Đá tiếp |
| Thời gian thi đấu (phong trào) | 2 hiệp × 20' | 2 hiệp × 25' | 2 hiệp × 35' |
| Nghỉ giữa hiệp | 5' | 5' | 10' |
| Slot sân cần đặt cho 1 trận | 60' | 60' | 90' |
| Thay người | Tự do, ra vào lại được | Tự do, ra vào lại được | Tối đa 5 người, không vào lại |
| Hòa ở vòng bảng | Cho phép | Cho phép | Cho phép |
| Hòa ở vòng loại trực tiếp | Luân lưu 5 lượt ngay | Luân lưu 5 lượt ngay | Hiệp phụ 2×10' (tùy BTC) → luân lưu |
| Điểm vòng bảng | Thắng 3 – Hòa 1 – Thua 0 | như sân 5 | như sân 5 |
| Xử thua (bỏ cuộc / không đủ người) | 0 – 3 | 0 – 3 | 0 – 3 |

> Số xác nhận tối thiểu = số người ra sân + dự bị hợp lý (sân 7: 7 + 3 = 10, đúng ví dụ nhóm đưa ra).
> Sân 5/7 không đá hiệp phụ vì slot chỉ 60', hiệp phụ sẽ lấn giờ trận sau.

**Ví dụ sân 7:** Đội A đến sân chỉ có 6 người → **chưa được bắt đầu**, chờ tới T+15' (mục 6.2), không đủ 7 thì xử thua 0-3.
Đội A đủ 7, đá được 20' thì 1 người chấn thương, dự bị đã hết → A đá tiếp **6 người** tới hết trận, kết quả vẫn tính bình thường.
Người bị thẻ đỏ cũng không được thay, đội đá thiếu người tới hết trận.

**Vị trí** (hồ sơ thể thao bóng đá): Thủ môn (GK), Hậu vệ (DF), Tiền vệ (MF), Tiền đạo (FW).
Mỗi người khai 1 vị trí chính + tối đa 2 vị trí phụ. Dùng cho gợi ý LFG và hiển thị đội hình giải.

---

## 2. Điểm Elo bóng đá (CHỈ trong giải đấu, CHỈ cho Team)

### 2.1 Elo gắn với Team, không gắn với người

Bóng đá là môn đồng đội: một người đá hay ở team này chưa chắc hợp team khác. Vì vậy:

- **Mỗi Team có 1 Elo bóng đá.** Cá nhân **không có** Elo bóng đá.
- 1 người ở 3 team thì 3 team có 3 Elo riêng, không liên quan nhau.
- Team đổi người (thêm/bớt thành viên) **không làm đổi Elo** — Elo chỉ đổi sau trận giải có kết quả chốt.
- Hồ sơ cá nhân chỉ hiển thị **các team mình đang ở + Elo của từng team**, cùng thành tích cá nhân trong giải
  (số trận, bàn thắng, thẻ) cho vui — không tính điểm.

### 2.2 Điểm khởi đầu của Team (chưa đá giải nào)

Khi tạo Team, đội trưởng **tự khai trình độ đội**:

| Trình độ đội tự khai | Elo khởi đầu |
|---|---|
| Mới chơi | 1000 |
| Trung bình | 1200 |
| Khá | 1400 |
| Giỏi / bán chuyên | 1600 (mức trần khi tự khai) |

- 10 trận giải đầu tiên của team là **"Elo tạm tính"** (hiển thị `~1200`), hệ số K lớn hơn để nhanh về đúng trình.
- Không cho tự khai cao hơn 1600.

### 2.3 Hạng hiển thị của Team

| Elo | Hạng |
|---|---|
| < 1100 | Đồng |
| 1100 – 1299 | Bạc |
| 1300 – 1499 | Vàng |
| 1500 – 1699 | Bạch kim |
| ≥ 1700 | Kim cương |

### 2.4 Công thức (dựa trên World Football Elo, có tính cách biệt bàn thắng)

```
Kỳ vọng A  : E_A = 1 / (1 + 10^((Elo_B − Elo_A) / 400))      (Elo_A, Elo_B = Elo của 2 Team)
Kết quả A  : S_A = 1 (thắng) | 0.5 (hòa) | 0 (thua)
Hệ số cách biệt bàn thắng G:
    cách 0 hoặc 1 bàn → G = 1
    cách 2 bàn        → G = 1.5
    cách N ≥ 3 bàn    → G = (11 + N) / 8      (cách 3 → 1.75, cách 4 → 1.875 …)
Thay đổi   : Δ = K × G × (S_A − E_A)
→ Team A cộng Δ, Team B trừ Δ (làm tròn số nguyên).
```

**Hệ số K theo vòng đấu**

| Vòng | K |
|---|---|
| Vòng bảng | 30 |
| Vòng loại trực tiếp (trước chung kết) | 35 |
| Chung kết | 40 |
| Team còn "Elo tạm tính" (< 10 trận giải) | K × 1.5 |

**Các trường hợp đặc biệt**

| Tình huống | Cách tính Elo |
|---|---|
| Hòa rồi thắng luân lưu | Elo tính **hòa** (S = 0.5). Luân lưu chỉ quyết định đội đi tiếp |
| Đá thiếu người do chấn thương / thẻ đỏ | Tính bình thường theo tỉ số |
| Đội không đủ người lúc bắt đầu / bỏ cuộc (xử 0-3) | Đội bị xử: tính **thua**, G = 1. Đội được xử thắng: **không cộng** |
| Kết quả đang khiếu nại | Chưa tính Elo cho tới khi BTC chốt |
| Đội rút lui giữa giải và bị hủy kết quả (mục 7.4) | Hoàn lại Elo các trận bị hủy cho cả 2 bên |

### 2.5 Ví dụ cụ thể

Team A có Elo **1300**, Team B có Elo **1200**, trận vòng bảng (K = 30).

`E_A = 1 / (1 + 10^(−100/400)) = 1 / (1 + 0.562) = 0.64` → A được kỳ vọng thắng 64%.

| Kết quả | G | Δ cho A | Elo Team A | Elo Team B |
|---|---|---|---|---|
| A thắng 3-1 | 1.5 | 30 × 1.5 × (1 − 0.64) = 16.2 | 1300 → **1316** | 1200 → **1184** |
| A thắng 1-0 | 1 | 30 × 1 × 0.36 = 10.8 | 1311 | 1189 |
| Hòa 2-2 | 1 | 30 × 1 × (0.5 − 0.64) = −4.2 | 1296 | 1204 |
| B thắng 2-1 | 1 | 30 × 1 × (0 − 0.64) = −19.2 | **1281** | **1219** |

→ Đội mạnh thắng thì được ít, đội yếu thắng đội mạnh thì được nhiều. Thắng đậm được thêm.

### 2.6 Chống lách Elo khi Elo gắn với Team

| Cách lách | Cách chặn (gợi ý) |
|---|---|
| Team mạnh lập **team mới** (Elo khởi đầu thấp) để vào giải hạng thấp | BTC giải có giới hạn trình độ có thể yêu cầu "team đã đá tối thiểu X trận giải"; team mới khai trình độ bị BTC duyệt |
| Team Elo thấp "mượn" người giỏi để đá giải hạng thấp | Chỉ người đã là thành viên team **trước hạn đăng ký** mới được xác nhận tham gia (mục 7) |
| Giải tán rồi lập lại team để xóa Elo xấu | Team đã đá giải thì **không xóa được**, chỉ khóa; Elo giữ nguyên |

### 2.7 Elo dùng vào đâu

- **Xếp hạt giống** khi bốc thăm giải (mục 4.4).
- **Giới hạn trình độ** giải (tùy BTC), ví dụ giải "Phong trào" chỉ nhận team có Elo ≤ 1300.
- **Bảng xếp hạng Team** (toàn quốc / tỉnh).
- Kết quả giải do **trọng tài / BTC nhập** (mục 5) nên không cần cơ chế 2 bên tự báo – tự xác nhận như LFG.

---

## 3. LFG bóng đá (ghép người, KHÔNG tính Elo)

### 3.1 Ba kiểu ghép

| Kiểu | Ví dụ | Ai tạo kèo | Ai vào |
|---|---|---|---|
| **Người lẻ ↔ Team** | Team A đặt sân 7 nhưng mới có 5 người, cần thêm 2 | Đội trưởng Team A (chọn số slot trống) | Người lẻ Flash Claim từng slot |
| **Người lẻ ↔ người lẻ** | Host đặt sân 5, cần đủ 10 người để chia 2 bên | Host | Người lẻ Flash Claim |
| **Team ↔ Team** | Team A tìm đối cho sân 7 tối thứ 7 | Đội trưởng Team A | Đội trưởng Team B nhận kèo cho cả đội (cọc cưa đôi như hiện tại) |

- Kèo người lẻ ↔ người lẻ: khi đủ người, **Host tự chia 2 bên** tại sân (hoặc app gợi ý chia theo vị trí: mỗi bên 1 thủ môn).
  Không chia theo Elo vì LFG không dùng Elo.
- Giữ các luật LFG đã chốt: tạo trước tối đa 5 ngày, đủ người trước T−48h, Fair Play ≥ 30, mỗi người 1 QR.

### 3.2 Gợi ý kèo (không dùng Elo)

Điểm gợi ý dựa trên:

| Tiêu chí | Ví dụ lý do hiển thị |
|---|---|
| Level tự khai gần nhau | "Cùng trình độ Trung bình" |
| Vị trí còn thiếu trong kèo | "Kèo đang thiếu Thủ môn — vị trí chính của bạn" |
| Khoảng cách | "Cách bạn 2.1 km" |
| Khung giờ hay đá (log hành vi) | "Bạn thường đá tối thứ 7" |
| Fair Play | Ưu tiên người Fair Play cao |
| Team ↔ Team: số người trong team phù hợp loại sân | "Team bạn có 9 người — hợp sân 7" |

---

## 4. Thể thức giải: bao nhiêu đội thì dùng loại nào

### 4.1 Mốc chọn thể thức

| Số đội đã xác nhận lúc hết hạn đăng ký | Thể thức |
|---|---|
| **< 4** | Không đủ → **hủy giải**, hoàn 100% lệ phí |
| **4 – 8** | **Loại trực tiếp** (không đủ 4/8 thì có bye) |
| **9 – 32** | **Vòng bảng → loại trực tiếp** |
| > 32 | Không nhận (giới hạn tối đa 32 đội/giải) |

> Vì sao mốc là 8: với 9 đội trở lên mà đá loại trực tiếp thì một nửa số đội chỉ đá đúng 1 trận rồi về, đóng lệ phí rất phí.
> Vòng bảng đảm bảo mỗi đội đá **ít nhất 2 trận**.

### 4.2 Loại trực tiếp (4 – 8 đội)

| Số đội | Khung nhánh | Số đội được bye (vào thẳng vòng 2) | Số trận (chưa tính tranh hạng 3) |
|---|---|---|---|
| 4 | 4 | 0 | 3 |
| 5 | 8 | 3 | 4 |
| 6 | 8 | 2 | 5 |
| 7 | 8 | 1 | 6 |
| 8 | 8 | 0 | 7 |

Công thức: số trận = số đội − 1. Bye ưu tiên cho đội hạt giống cao (Elo cao).

### 4.3 Vòng bảng → loại trực tiếp (9 – 32 đội)

**Quy tắc chia (code được):**

1. Số bảng = `làm tròn lên (số đội / 4)` → mỗi bảng có 3 hoặc 4 đội.
2. Số đội vào vòng loại = **lũy thừa 2 lớn nhất ≤ 2 × số bảng** (4, 8 hoặc 16).
3. Lấy hết các đội **nhất bảng**, thiếu thì bù **đội nhì tốt nhất**; nếu số bảng × 2 vừa đúng thì lấy nhất + nhì.

**Bảng tra cụ thể:**

| Số đội | Số bảng | Số đội mỗi bảng | Vào vòng loại | Vòng loại bắt đầu từ | Trận vòng bảng | Trận loại | **Tổng trận** |
|---|---|---|---|---|---|---|---|
| 9 | 3 | 3-3-3 | 3 nhất + 1 nhì tốt nhất | Bán kết | 9 | 3 | 12 |
| 10 | 3 | 4-3-3 | 3 nhất + 1 nhì tốt nhất | Bán kết | 12 | 3 | 15 |
| 11 | 3 | 4-4-3 | 3 nhất + 1 nhì tốt nhất | Bán kết | 15 | 3 | 18 |
| 12 | 3 | 4-4-4 | 3 nhất + 1 nhì tốt nhất | Bán kết | 18 | 3 | 21 |
| 13 | 4 | 4-3-3-3 | Nhất + nhì | Tứ kết | 15 | 7 | 22 |
| 14 | 4 | 4-4-3-3 | Nhất + nhì | Tứ kết | 18 | 7 | 25 |
| 15 | 4 | 4-4-4-3 | Nhất + nhì | Tứ kết | 21 | 7 | 28 |
| 16 | 4 | 4-4-4-4 | Nhất + nhì | Tứ kết | 24 | 7 | 31 |
| 17 – 20 | 5 | 3–4 đội | 5 nhất + 3 nhì tốt nhất | Tứ kết | 21 – 30 | 7 | 28 – 37 |
| 21 – 24 | 6 | 3–4 đội | 6 nhất + 2 nhì tốt nhất | Tứ kết | 27 – 36 | 7 | 34 – 43 |
| 25 – 28 | 7 | 3–4 đội | 7 nhất + 1 nhì tốt nhất | Tứ kết | 33 – 42 | 7 | 40 – 49 |
| 29 – 32 | 8 | 3–4 đội | Nhất + nhì | Vòng 16 | 39 – 48 | 15 | 54 – 63 |

Công thức số trận: bảng 3 đội = 3 trận, bảng 4 đội = 6 trận; vòng loại N đội = N − 1 trận. Tranh hạng 3 (+1 trận) là tùy chọn BTC.
Số slot sân cần đặt = tổng trận (sân 5/7: 60'/trận, sân 11: 90'/trận) → BTC biết trước chi phí sân.

### 4.4 Bốc thăm & hạt giống (dùng Elo đội)

- **Chia bảng theo nhóm hạt giống (pot):** sắp đội theo Elo đội giảm dần, cắt thành các pot, mỗi pot có số đội = số bảng.
  Bốc mỗi pot 1 đội vào mỗi bảng → đội mạnh không dồn vào 1 bảng.
  - Ví dụ 12 đội, 3 bảng: Pot 1 = Elo hạng 1–3, Pot 2 = 4–6, Pot 3 = 7–9, Pot 4 = 10–12.
- **Loại trực tiếp:** hạt giống 1 và 2 ở 2 nửa nhánh (chỉ gặp nhau ở chung kết); hạt giống 1 gặp đội yếu nhất.
- **Sau vòng bảng:** nhất bảng gặp đội vào vòng loại xếp thấp nhất; 2 đội cùng bảng không gặp lại trước chung kết nếu xếp được.

> Code hiện tại: `TournamentDraw` (`lib/models/tournament.dart`) chỉ có **loại trực tiếp bốc ngẫu nhiên** (shuffle + bye).
> Cần bổ sung: chọn thể thức theo số đội, chia bảng theo pot, hạt giống theo Elo, chọn đội nhì tốt nhất.

### 4.5 Xếp hạng vòng bảng

Điểm: Thắng 3 – Hòa 1 – Thua 0. Bằng điểm thì xét lần lượt:

1. Điểm đối đầu giữa các đội bằng điểm
2. Hiệu số bàn thắng – bàn thua (toàn bảng)
3. Số bàn thắng
4. Điểm Fair Play của giải (thẻ vàng −1, thẻ đỏ gián tiếp −3, thẻ đỏ trực tiếp −4) — ít bị trừ hơn xếp trên
5. Bốc thăm

**So đội nhì tốt nhất giữa bảng 3 đội và bảng 4 đội:** bỏ kết quả gặp đội **cuối bảng 4 đội** rồi mới so, để số trận bằng nhau.

### 4.6 Xếp lịch (dùng Booking Engine)

- BTC chọn cơ sở + loại sân + các ngày thi đấu → hệ thống đặt slot qua Booking Engine (tiền sân lấy từ tiền giải).
- Ràng buộc khi xếp:
  - 1 đội không đá 2 trận liền slot; nghỉ tối thiểu **1 slot** giữa 2 trận.
  - Sân 11: mỗi đội tối đa **1 trận/ngày**; sân 5/7: tối đa **3 trận/ngày**.
  - Vòng bảng xếp theo "circle method" để các lượt đấu đều nhau.
  - Trận vòng sau chỉ hiện tên đội khi trận trước có kết quả ("Thắng trận 3 vs Thắng trận 4").

---

## 5. Nhân sự giải (trọng tài…) — người tạo giải tự đảm bảo

### 5.1 Nguyên tắc

- **Người tạo giải (BTC) chịu trách nhiệm toàn bộ nhân sự**: tìm trọng tài, phân công, thù lao, thay người khi vắng.
- App **không** cung cấp / tìm trọng tài, **không** tự phân công, **không** trả thù lao trọng tài qua ví (BTC tự trả ngoài app).
- App chỉ: **lưu danh sách nhân sự**, cho BTC **gán người vào từng trận**, **kiểm tra – cảnh báo** thiếu người / trùng giờ.

### 5.2 Khai khi tạo giải (bắt buộc)

**a) Số trọng tài yêu cầu cho mỗi trận** — app điền sẵn mặc định theo loại sân, BTC sửa được (tối thiểu 1):

| Sân | Mặc định gợi ý |
|---|---|
| Sân 5 | 1 (trọng tài chính) |
| Sân 7 | 1 (trọng tài chính) |
| Sân 11 | 3 (1 chính + 2 trợ lý) |

**b) Danh sách nhân sự — chi tiết từng người:**

| Trường | Bắt buộc | Ghi chú |
|---|---|---|
| Họ tên | ✅ | |
| Số điện thoại | ✅ | Để đội/BTC liên hệ |
| Vai trò | ✅ | Trọng tài chính / Trợ lý trọng tài / Điều phối / Y tế / Khác |
| Tài khoản SportNexus | Tùy chọn | Có tài khoản thì người đó dùng được màn "Trận của tôi" (quét QR, nhập kết quả) |
| Ảnh / ghi chú | Tùy chọn | Ví dụ chứng chỉ trọng tài |

**c) Kiểm tra khi mở đăng ký giải:**

```
Số trọng tài trong danh sách  ≥  Số trọng tài mỗi trận × Số trận đá CÙNG LÚC
```

Ví dụ: giải sân 7, 1 trọng tài/trận, BTC đặt 2 sân con đá song song → cần **ít nhất 2 trọng tài** trong danh sách.
Thiếu → app **không cho mở đăng ký**, báo "Cần thêm 1 trọng tài".

### 5.3 Phân công trận (BTC tự làm)

Sau khi bốc thăm và xếp lịch, BTC gán nhân sự vào từng trận. App chỉ **cảnh báo**, không tự gán:

| Cảnh báo | Mức |
|---|---|
| Trận chưa đủ số trọng tài yêu cầu | **Chặn**: trận không được bắt đầu tới khi đủ |
| 1 người bị gán 2 trận cùng giờ | **Chặn** |
| Trọng tài (có tài khoản) đang là thành viên 1 trong 2 team của trận | Cảnh báo, BTC vẫn quyết |
| Còn trận trong 24h tới chưa gán đủ người | Thông báo nhắc BTC |

- BTC đổi / thêm nhân sự bất cứ lúc nào trong giải; trận đã chốt kết quả thì không đổi.
- Trận không đá được vì **thiếu trọng tài** → lỗi của BTC: BTC phải **dời trận** (tự đặt lại sân),
  **không được xử thua** đội nào.

### 5.4 Nhập kết quả trận

Người nhập: **trọng tài chính được gán (nếu có tài khoản)**, không thì **BTC** nhập.

1. Trước trận: quét QR check-in cầu thủ (mục 6), chốt đội hình ra sân (phải đủ 5/7/11).
2. Trong / sau trận nhập: tỉ số, người ghi bàn (+ phút), thẻ vàng/đỏ, luân lưu (nếu có).
3. Bấm **Kết thúc trận** → 2 đội trưởng có **30 phút** để khiếu nại.
4. Hết 30' không khiếu nại → kết quả chốt → cập nhật BXH bảng, đẩy đội vào vòng sau, **tính Elo Team**, thông báo.
5. Có khiếu nại → BTC xử, BTC có quyền sửa kết quả cuối.

---

## 6. Check-in

### 6.1 Check-in kèo LFG

Giữ như luật đã chốt: **mỗi người 1 QR riêng**, chủ sân quét, ai chưa quét sau **T+15'** → tự đánh vắng (trừ Fair Play).
Kèo Team ↔ Team: quét từng người của cả 2 team. Không có kết quả trận, không tính Elo.

### 6.2 Check-in trận giải

| Mốc | Việc |
|---|---|
| T − 60' | Mở check-in cho trận đầu tiên của đội trong ngày |
| T − 60' → T | Trọng tài/BTC quét QR từng cầu thủ (QR giải riêng của mỗi người, sống tới hết giải) |
| T | Bắt đầu khi mỗi đội check-in **đủ đội hình ra sân** (sân 5: 5, sân 7: 7, sân 11: 11) và trận có đủ trọng tài (mục 5.3) |
| T → T + 15' | Đội chưa đủ người được chờ thêm |
| T + 15' | Đội vẫn chưa đủ đội hình ra sân → **xử thua 0-3**, trừ Fair Play các thành viên vắng |
| Trong trận | Không còn yêu cầu số người tối thiểu: chấn thương / thẻ đỏ mà hết người thay thì **đá tiếp** |
| Cầu thủ đến muộn (dự bị) | Vẫn quét được trong trận, vào sân từ lúc quét |

- Chỉ cầu thủ **có tên trong danh sách giải của đội** (người đã xác nhận, mục 7) mới check-in được → chống "mượn người".
- Đã check-in trong ngày thì các trận sau cùng ngày **không cần quét lại**.
- Cầu thủ đang bị **treo giò** (mục 8) → app chặn khi quét.
- Check-in sân với **chủ sân**: lượt sân của giải do BTC đặt, chủ sân check-in/check-out theo lượt của BTC (1 QR của BTC),
  không quét từng cầu thủ.

---

## 7. Tham gia giải đấu

### 7.1 Điều kiện

| Điều kiện | Gợi ý |
|---|---|
| Phải có Team | Chỉ **đội trưởng** (lead) bấm tham gia |
| Số thành viên xác nhận | ≥ mức tối thiểu theo loại sân (sân 5: 7, **sân 7: 10**, sân 11: 16), ≤ mức tối đa (12 / 15 / 22) |
| Fair Play | Mỗi người xác nhận phải ≥ 30 |
| Trùng giải | 1 người chỉ được xác nhận cho **1 đội** trong cùng 1 giải |
| Giới hạn trình độ (nếu BTC đặt) | **Elo của Team** nằm trong khoảng BTC cho phép (có thể kèm "đã đá tối thiểu X trận giải") |
| Còn chỗ | Số đội đã **chốt** < số đội tối đa của giải |

### 7.2 Luồng tham gia

Ví dụ: Team "FC Hoa Lư" có **20 thành viên**, đăng ký giải **sân 7** (cần 10 xác nhận, tối đa 15).

```
1. Đội trưởng mở giải → bấm [Tham gia] → chọn Team "FC Hoa Lư"
     → Hệ thống gửi LỜI MỜI THAM GIA GIẢI tới cả 20 thành viên (thông báo FCM)
     → Trạng thái đội: "Đang gom người (0/10)"

2. Từng thành viên mở lời mời → [Tham gia] hoặc [Từ chối]
     (hệ thống kiểm tra Fair Play ≥ 30, không trùng đội khác cùng giải)
     → "Đang gom người (7/10)" ... "(10/10)"

3. Đủ 10 người → trạng thái "Đủ người" → đội trưởng bấm [Chốt & thanh toán lệ phí]
     (trả ví / VietQR, hoặc chia đều cho những người đã xác nhận bằng Split Payment)
     → Trạng thái "ĐÃ THAM GIA" → đội chiếm 1 chỗ trong giải

4. Thành viên còn lại vẫn được xác nhận thêm đến tối đa 15 người hoặc đến hạn đăng ký.
     Người thứ 16 trở đi: lời mời báo "Đội đã đủ danh sách".

5. Hết hạn đăng ký:
     - Đội chưa đủ 10 người hoặc chưa thanh toán → TỰ HỦY đăng ký (chưa mất tiền gì)
     - Giải chốt danh sách đội → chọn thể thức theo số đội (mục 4.1) → bốc thăm
```

| Trạng thái đội trong giải | Ý nghĩa |
|---|---|
| Đang gom người (x/10) | Đã gửi lời mời, chưa đủ người, **chưa giữ chỗ** |
| Đủ người | Đủ người, chờ đội trưởng thanh toán |
| Đã tham gia | Đã thanh toán, chiếm 1 chỗ |
| Đã hủy | Đội trưởng hủy / hết hạn chưa đủ / BTC hủy giải |

> Chỗ trong giải tính theo **thứ tự thanh toán**: giải tối đa 16 đội mà đã có 16 đội "Đã tham gia" thì đội đang gom người
> nhận báo "Giải đã đủ đội".
> Thành viên mới vào Team sau khi đội trưởng bấm tham gia cũng nhận lời mời nếu giải còn hạn đăng ký.
> Code hiện tại (`TournamentRegistration`: đội trưởng tự chọn `teammates`) cần đổi sang luồng mời – xác nhận này.

### 7.3 Thay đổi danh sách

| Thời điểm | Thêm / bớt cầu thủ |
|---|---|
| Trước hạn đăng ký | Thành viên tự xác nhận / rút, miễn còn ≥ mức tối thiểu sau khi đã chốt |
| Sau hạn đăng ký, trước khai mạc | Đổi tối đa **2 người**, BTC duyệt |
| Trong giải | Đổi tối đa 2 người **trước vòng loại trực tiếp**, BTC duyệt |

### 7.4 Rút lui & hủy

| Thời điểm | Hoàn lệ phí | Kết quả |
|---|---|---|
| Trước hạn đăng ký | **100%** | Trả chỗ cho đội khác |
| Sau hạn đăng ký, trước khai mạc | **0%** | BTC bốc thăm lại nếu kịp, không kịp thì đối thủ được bye |
| Trong giải | **0%** | Vòng bảng: đội đá < 50% số trận → **hủy toàn bộ kết quả** của đội (hoàn lại Elo); ≥ 50% → các trận còn lại xử thua 0-3 |
| Hết hạn mà < 4 đội "Đã tham gia" | **100%** | Hủy giải (`TournamentStatus.cancelled`) |

Tiền thưởng giải ngân sau khi giải kết thúc và hết thời gian khiếu nại (đã có `paidOutAt`).

---

## 8. Kỷ luật (thẻ phạt trong giải)

| Vi phạm | Hậu quả trong giải | Fair Play tài khoản (gợi ý) |
|---|---|---|
| 1 thẻ vàng | Ghi nhận | 0 |
| Tích lũy 2 thẻ vàng (qua các trận) | Treo 1 trận kế tiếp | −2 |
| Thẻ đỏ (2 vàng trong 1 trận) | Rời sân + treo 1 trận | −5 |
| Thẻ đỏ trực tiếp | Rời sân + treo 1–2 trận (BTC quyết) | −10 |
| Đội bỏ cuộc | Xử thua 0-3 | −10 mỗi thành viên vắng |

Thẻ vàng **xóa khi vào bán kết** để tránh lỡ chung kết vì thẻ tích lũy.

---

## 9. Mobile cần làm (gợi ý màn hình)

| Màn | Người dùng | Nội dung |
|---|---|---|
| Hồ sơ bóng đá | Player | Level tự khai (dùng cho LFG), vị trí chính/phụ, các team đang ở + Elo từng team, thành tích cá nhân trong giải |
| Chi tiết Team | Player | Elo + hạng của team, lịch sử Elo theo từng trận giải, trình độ tự khai lúc tạo team |
| Bảng xếp hạng Team | Player | Toàn quốc / tỉnh, lọc theo hạng |
| Tham gia giải | Đội trưởng | Chọn Team, gửi lời mời, theo dõi x/10 xác nhận, chốt & thanh toán |
| Lời mời tham gia giải | Thành viên | Tham gia / Từ chối, xem giải + lịch |
| Chi tiết giải | Player | Sơ đồ nhánh, bảng + BXH bảng, lịch, vua phá lưới, thẻ phạt |
| QR giải | Cầu thủ | QR cá nhân để check-in |
| Tạo giải – Nhân sự | Người tạo giải | Số trọng tài/trận, danh sách nhân sự (tên, SĐT, vai trò, tài khoản), gán người vào từng trận, cảnh báo thiếu/trùng |
| Trận của tôi (Trọng tài) | Trọng tài có tài khoản | Quét QR, đội hình, nhập bàn/thẻ/tỉ số, kết thúc trận |
| LFG bóng đá | Player / Đội trưởng | Tạo kèo 3 kiểu (người lẻ ↔ team, người lẻ ↔ người lẻ, team ↔ team), feed gợi ý kèm lý do |

Dữ liệu BE cần trả thêm (gợi ý): Elo của Team + lịch sử, trình độ tự khai của Team, lời mời tham gia giải + trạng thái
xác nhận, trạng thái đội trong giải, đội hình ra sân từng trận, sự kiện trận (bàn thắng, thẻ), số trọng tài/trận + danh sách
nhân sự giải + phân công từng trận, thể thức + bảng đấu của giải.

> Model `Team` hiện tại (`lib/models/team.dart`) chưa có Elo / trình độ tự khai → cần thêm khi BE có.

---

## 10. Cần nhóm CHỐT

**Đã chốt (2026-11-02):** Elo chỉ trong giải và chỉ Team có Elo · bắt đầu trận phải đủ đội hình ra sân, đá rồi thiếu người
vẫn đá tiếp · nhân sự giải do người tạo giải tự đảm bảo (khai số trọng tài + chi tiết từng người lúc tạo giải).

**Còn cần chốt:**

1. Elo Team dùng chung cho sân 5/7/11 hay tách riêng từng loại sân?
2. Bảng K (30/35/40) và mốc Elo khởi đầu theo trình độ team tự khai.
3. Số xác nhận tối thiểu / tối đa: sân 5 (7/12), sân 7 (10/15), sân 11 (16/22).
4. Đủ người thì **tự động** chốt hay đội trưởng bấm chốt + thanh toán? Lệ phí do đội trưởng trả hay chia cho người xác nhận?
5. Mốc thể thức: 4–8 đội loại trực tiếp, 9–32 đội vòng bảng; tối đa 32 đội; có trận tranh hạng 3 không.
6. Trọng tài không có tài khoản SportNexus thì BTC nhập kết quả — có cần bắt buộc ít nhất trọng tài chính có tài khoản không?
7. Mốc check-in giải (T−60' / T+15').
8. Đá tiếp khi thiếu người: có cần mức "quá ít người thì dừng trận" (ví dụ sân 7 còn ≤ 3 người) hay đá tiếp trong mọi trường hợp?
9. Luật rút lui, đổi cầu thủ, mức trừ Fair Play theo thẻ.
10. Phân vai Web/Mobile: BTC tạo giải/bốc thăm/xếp lịch ở đâu (hiện Chủ sân tạo giải được trên app).
