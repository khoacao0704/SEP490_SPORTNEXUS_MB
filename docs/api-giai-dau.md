# SportNexus – Tài liệu API Giải đấu (Tournament)

> Bản CHỐT CUỐI (user xác nhận 24/11/2026). Code mobile theo từng thẻ; thẻ có chi tiết hơn thì theo thẻ, khác tài liệu thì hỏi lại.
> Phạm vi mobile: mọi mục trừ 9 (Admin quản lý giải) và 8.5 (Admin đóng khiếu nại) — hai mục này làm trên Web.

Phiên bản API: v1 · Cập nhật: 23/11/2026 (sau khi merge develop) · Nguồn: đối chiếu trực tiếp với code BE (TournamentController, OwnerTournamentController, MatchController, AdminTournamentController, MatchComplaintController, RatingController, các service tương ứng). Đã cập nhật luồng duyệt giải theo chốt của team: người ngoài tổ chức giải chỉ cần Admin duyệt.

Phạm vi: giải đấu, bảng đấu, đăng ký, lời mời, giữ sân, nhân sự / trọng tài, trận đấu & tỉ số, khiếu nại trận, Admin quản lý giải, Elo. API Đội (Team) xem tài liệu riêng.

## 0. Quy ước chung

Base URL: /api/v1

Xác thực: Authorization: Bearer {accessToken}. Cột "Quyền" trong tài liệu:
- Public: Không cần đăng nhập
- Đăng nhập: Bất kỳ tài khoản đã đăng nhập
- Owner / Player / Admin: Role của JWT ([Authorize(Roles = ...)])
- BTC: Ban tổ chức của giải (Tournament.OrganizerId): chủ sân tổ chức tại cơ sở của mình, hoặc người chơi được Admin duyệt yêu cầu tổ chức. Admin gọi các API BTC được (thao tác thay)

Bao response chung – mọi API trả ApiResponse<T>; mã HTTP = statusCode:
```json
{
  "statusCode": 200,
  "message": "Success",
  "data": { },
  "errorCode": null,
  "errorDetail": null
}
```
- Lỗi: data = null, đọc message (tiếng Việt, hiển thị thẳng cho người dùng). Một số lỗi có errorCode (vd ONBOARDING_REQUIRED).
- Tài liệu dưới đây chỉ mô tả phần data.

Phân trang – PagedResponse<T>:
```json
{ "page": 1, "pageSize": 10, "totalItems": 42, "totalPages": 5, "items": [ ] }
```

Định dạng:
- JSON camelCase.
- DateTimeOffset trả về dạng ISO 8601 UTC (2026-12-01T01:00:00Z). Khi gửi lên nên kèm múi giờ (2026-12-01T08:00:00+07:00).
- Tham số "ngày" (from, to, dateFrom, dateTo) hiểu theo giờ Việt Nam, dạng yyyy-MM-dd.
- Enum trong body request gửi dạng số (vd categoryType: 1); trong response các enum đã được đổi sang chuỗi (vd "categoryType": "PREMADE_TEAMS").
- Tiền: VND, số thập phân (decimal).

Mô hình dữ liệu: 1 giải mẹ (giải tổng) chứa ≥ 1 bảng đấu con (hạng mục: đơn nam, đôi nữ...). Người chơi đăng ký vào bảng con. Các API nhận {id} nói rõ là id giải mẹ hay bảng con; nhiều API chấp nhận cả hai.

## 1. Giá trị liệt kê (enum) & trạng thái

- categoryType (thể thức bảng): 0 = SINGLES (cá nhân) · 1 = PREMADE_TEAMS (đội đăng ký sẵn) · 2 = RANDOM_DOUBLES (đăng ký cá nhân, BTC bốc thăm ghép đôi)
- status giải / bảng: OPEN (mở đăng ký) · IN_PROGRESS (đã sinh sơ đồ, đang thi đấu) · FINISHED · CANCELLED
- approvalStatus: APPROVED (đã công khai) · PENDING_ADMIN (BTC là người ngoài đã nộp bằng chứng thỏa thuận, chờ Admin duyệt) · REJECTED · PENDING_OWNER (không còn dùng trong luồng mới)
- session (lịch sân yêu cầu): MORNING (06:00–12:00) · AFTERNOON (12:00–18:00) · EVENING (18:00–22:00) · FULL_DAY (06:00–22:00)
- tier: AMATEUR (ao làng, không xét Elo, bốc thăm ngẫu nhiên) · SEMI_PRO (mặc định Elo ≥ 1200, ≥ 3 trận giải) · PRO (mặc định Elo ≥ 1500, ≥ 10 trận giải)
- purpose: EXCHANGE (giao lưu, mặc định) · COMMERCIAL · DEVELOPMENT (phải từ SEMI_PRO) · INTERNAL (nội bộ: không công khai, chỉ tham gia qua lời mời; BTC được tự thi đấu)
- format (sơ đồ): KNOCKOUT · ROUND_ROBIN (3–8 đấu thủ) · GROUP_KNOCKOUT (vòng bảng → loại trực tiếp, từ 6)
- paymentStatus: PENDING · PAID (lệ phí đang được giữ) · REFUNDED · ...
- Trạng thái trận: PENDING · FINISHED
- resultType trận: NORMAL · WALKOVER (bên thua không ra sân) · RETIRED (bỏ cuộc giữa trận) · DRAW
- Vai trò nhân sự: REFEREE (trọng tài) · SCORER (người nhập điểm) · OTHER
- Trạng thái lời mời: PENDING · ACCEPTED · DECLINED · CANCELLED
- ratingType: SINGLES · DOUBLES · TEAM

## 2. Ban tổ chức: tạo & quản lý giải

### 2.1 Tạo giải

POST /tournaments · Quyền: Owner, Player

- Chủ sân tạo tại cơ sở của mình → APPROVED, mở đăng ký ngay.
- Người ngoài (người chơi, hoặc chủ sân ở cơ sở người khác) → PENDING_ADMIN, chỉ chờ Admin duyệt (9.4):
  - BTC tự liên hệ, thỏa thuận với chủ sân bên ngoài hệ thống.
  - Khi tạo giải, BTC bắt buộc đính kèm bằng chứng thỏa thuận (ảnh hợp đồng hoặc biên nhận cọc), dùng trường file sẵn có (rulesFileUrl).
  - Chủ sân chỉ nhận thông báo, không phải duyệt. Họ có nút "Tôi không có thỏa thuận này" để báo Admin (2.11).
  - Admin duyệt bài đăng (nội dung + bằng chứng) → APPROVED, công khai. Nếu chủ sân đã phản đối, Admin thấy cảnh báo trước khi duyệt.
  - Ca sân: chủ sân giữ ca (5.1) sau khi đã thỏa thuận, như hiện tại. Admin có thể yêu cầu giải đã có ca giữ sân trước khi duyệt.
  - Kết quả: BTC chỉ chờ 1 người duyệt là Admin, chủ sân không phải xử lý hồ sơ, vẫn chặn được việc mạo danh cơ sở.
- Cơ sở phải đã được duyệt và không bị khóa.

Body
```json
{
  "facilityId": "4f1c...e2",
  "categoryId": "9a0b...11",
  "name": "Giải cầu lông mùa đông 2026",
  "startDate": "2026-12-20T08:00:00+07:00",
  "endDate": "2026-12-21T18:00:00+07:00",
  "registrationDeadline": "2026-12-18T23:59:00+07:00",
  "imageUrl": "https://cdn.example.com/cover.jpg",
  "rules": "Thi đấu theo luật BWF, mỗi trận 3 set 21 điểm.",
  "rulesFileUrl": "https://res.cloudinary.com/.../dieu-le.pdf",
  "defaultBracketFormat": "KNOCKOUT",
  "requestedSchedule": [
    { "date": "2026-12-20", "session": "FULL_DAY", "courtCount": 3 },
    { "date": "2026-12-21", "session": "MORNING", "courtCount": 2 }
  ],
  "tier": "AMATEUR",
  "purpose": "EXCHANGE",
  "minRating": null,
  "maxRating": null,
  "minRatedMatches": null,
  "children": [
    {
      "name": "Đơn nam",
      "categoryType": 0,
      "maxParticipants": 16,
      "minParticipants": 4,
      "entryFee": 100000,
      "minTeamSize": null,
      "maxTeamSize": null,
      "prizes": [
        { "position": "1", "rewardAmount": 1000000 },
        { "position": "2", "rewardAmount": 500000 }
      ]
    }
  ]
}
```

Các trường:
- facilityId, categoryId, name: Bắt buộc
- startDate: Nên có. Bắt buộc nếu truyền endDate / registrationDeadline
- endDate: Bỏ trống = bằng startDate; không trước startDate
- registrationDeadline: Bỏ trống = 48 giờ trước startDate; không sau startDate
- imageUrl: Link http/https
- rules: Tối đa 8000 ký tự
- rulesFileUrl: File điều lệ / nhân sự / bằng chứng thỏa thuận (PDF / ảnh), link lấy từ POST /api/v1/uploads/documents. BTC là người ngoài: bắt buộc, phải chứa bằng chứng thỏa thuận với chủ sân (ảnh hợp đồng hoặc biên nhận cọc)
- defaultBracketFormat: Chốt thể thức ngay lúc tạo: KNOCKOUT | ROUND_ROBIN | GROUP_KNOCKOUT. Bỏ trống = chọn khi sinh sơ đồ (2.5)
- requestedSchedule[]: Lịch sân BTC yêu cầu cho từng ngày thi đấu. Cần có startDate. Mỗi dòng: date (giờ VN, trong khoảng startDate–endDate), session, courtCount (≥ 1, không quá số sân con cùng môn đang hoạt động của cơ sở). Không trùng buổi trong cùng ngày (FULL_DAY trùng mọi buổi)
- tier, purpose: Mặc định AMATEUR, EXCHANGE
- minRating, maxRating, minRatedMatches: Ghi đè điều kiện Elo mặc định của cấp độ (không áp dụng AMATEUR)
- children: Bắt buộc, ≥ 1 bảng đấu
- children[].categoryType: Bắt buộc. Số: 0 / 1 / 2. Môn đồng đội (bóng đá, bóng rổ) chỉ nhận 1. Môn vợt dùng 1 = nội dung đôi (đội đúng 2 người)
- children[].maxParticipants: Bắt buộc, ≥ 2
- children[].minParticipants: 2 … maxParticipants, mặc định 2
- children[].entryFee: ≥ 0
- children[].minTeamSize, maxTeamSize: Chỉ cho bảng đội, 1–50
- children[].prizes[]: Giải thưởng chỉ để hiển thị: BTC tự trao ngoài hệ thống, SportNexus không giữ quỹ thưởng

Response 201
```json
{ "parentId": "c7d2...90", "approvalStatus": "APPROVED" }
```
approvalStatus = APPROVED (chủ sân tự tổ chức) hoặc PENDING_ADMIN (người ngoài, chờ Admin duyệt).

Lỗi thường gặp:
- 403: Đang bị cấm tạo giải (data: { "tournamentBannedUntil": "..." }) hoặc điểm Fair Play < 80 (xem mục 11)
- 404: Cơ sở không tồn tại
- 400: Cơ sở chưa duyệt / bị khóa; thiếu bảng đấu; sai thể thức theo môn; số người / lệ phí / lịch không hợp lệ; BTC là người ngoài mà thiếu bằng chứng thỏa thuận

### 2.2 Giải của tôi

GET /tournaments/my-tournaments?scope=facility · Quyền: Owner, Player

- Không truyền scope: các giải tôi làm BTC.
- scope=facility: các giải người khác tổ chức tại cơ sở của tôi (chủ sân chỉ xem, giữ sân và báo "Tôi không có thỏa thuận này" nếu cần).

Response 200 – mảng MyTournamentOwnerResponse
```json
[
  {
    "id": "c7d2...90",
    "name": "Giải cầu lông mùa đông 2026",
    "organizerId": "a1b2...",
    "organizerName": "Nguyễn Văn A",
    "isOrganizer": true,
    "purpose": "EXCHANGE",
    "tier": "AMATEUR",
    "status": "OPEN",
    "approvalStatus": "APPROVED",
    "approvalNote": null,
    "facilityId": "4f1c...e2",
    "facilityName": "Sân cầu lông ABC",
    "categoryId": "9a0b...11",
    "categoryName": "Cầu lông",
    "totalChildren": 2,
    "totalParticipants": 11,
    "startDate": "2026-12-20T01:00:00Z",
    "endDate": "2026-12-21T11:00:00Z",
    "registrationDeadline": "2026-12-18T16:59:00Z",
    "isRegistrationOpen": true,
    "imageUrl": "https://cdn.example.com/cover.jpg",
    "children": [ /* TournamentChildResponse – xem 3.3 */ ]
  }
]
```

### 2.3 Sửa thông tin giải

PUT /tournaments/{id} · Quyền: Owner, Player (BTC) hoặc Admin · {id} = giải mẹ hoặc bảng con

Trường bỏ trống = giữ nguyên. Thông tin chung áp dụng cho giải mẹ và mọi bảng con.
```json
{
  "name": "Giải cầu lông mùa đông 2026 – mở rộng",
  "startDate": "2026-12-21T08:00:00+07:00",
  "endDate": null,
  "registrationDeadline": null,
  "imageUrl": "",
  "rules": "",
  "rulesFileUrl": null,
  "entryFee": 120000
}
```
- startDate, endDate, registrationDeadline: Chỉ sửa được khi mọi bảng còn đang mở đăng ký
- imageUrl, rules, rulesFileUrl: Chuỗi rỗng "" = xóa. rules / rulesFileUrl bị khóa sau khi giải đã sinh sơ đồ
- entryFee: Chỉ với id bảng con, khi bảng còn mở đăng ký và chưa có ai đăng ký

Response 200 – giống GET /tournaments/{id} (xem 3.3).

### 2.4 Bốc thăm ghép đôi

POST /tournaments/{id}/execute-random-pairing · Quyền: BTC · {id} = bảng con RANDOM_DOUBLES

Không body. Cần số người chẵn, ≥ 2, bảng đang OPEN. Response 200: data = null, message "Bốc thăm ghép đôi ngẫu nhiên hoàn tất. Các đội thi đấu đã được tạo thành công."

### 2.5 Sinh sơ đồ thi đấu (chốt danh sách)

POST /tournaments/{id}/generate-bracket?format=KNOCKOUT · Quyền: BTC · {id} = bảng con

- Query format: KNOCKOUT | ROUND_ROBIN | GROUP_KNOCKOUT. Bỏ trống: dùng defaultBracketFormat của giải nếu có; nếu không, ≤ 8 đấu thủ → KNOCKOUT, từ 9 → GROUP_KNOCKOUT. Giải đã chốt defaultBracketFormat lúc tạo thì không đổi được sang thể thức khác (400)
- Ao làng bốc thăm ngẫu nhiên; bán chuyên / chuyên nghiệp xếp hạt giống theo Elo.
- Bảng chuyển IN_PROGRESS.

Response 200: data = null, message ví dụ "Chốt sổ và sinh nhánh đấu thành công (KNOCKOUT) với 7 trận đấu (8 đấu thủ/đội). Trạng thái giải đấu chuyển sang IN_PROGRESS."

### 2.6 Quyết định khi bảng thiếu người

POST /tournaments/{id}/registration-decision · Quyền: BTC · {id} = bảng con

Chỉ dùng khi bảng hết hạn đăng ký mà chưa đủ minParticipants. BTC có 24 giờ; quá hạn hệ thống tự hủy và hoàn 100%.
```json
{ "decision": "EXTEND", "newDeadline": "2026-12-19T23:59:00+07:00", "reason": null }
```
- CANCEL: Hủy bảng, hoàn 100% lệ phí (không tính vi phạm cho BTC). reason tùy chọn
- EXTEND: Gia hạn đăng ký tới newDeadline (sau hiện tại, không sau giờ bắt đầu)
- CONTINUE: Vẫn thi đấu với số người hiện có (cần ≥ 2)

Response 200: CANCEL trả như 2.8; EXTEND / CONTINUE trả data = null.

### 2.7 Xóa người tham gia

DELETE /tournaments/{id}/participants/{participantId} · Quyền: BTC · {id} = bảng con

Lý do bắt buộc (tối đa 500 ký tự), truyền qua body hoặc query:
```json
{ "reason": "Đăng ký sai hạng mục" }
```
hoặc DELETE /tournaments/{id}/participants/{participantId}?reason=Đăng%20ký%20sai%20hạng%20mục.

- Chỉ khi bảng còn OPEN.
- Luôn hoàn 100% lệ phí về đúng ví đã trả (kể cả sau hạn đăng ký); người bị xóa được báo kèm lý do.

Response 200: data = null, message "Đã xóa '{tên}' khỏi danh sách bảng đấu thành công."

### 2.8 Hủy giải

PATCH /tournaments/{id}/cancel-tournament · Quyền: Owner, Player, Admin · {id} = giải mẹ (hủy mọi bảng con chưa kết thúc) hoặc bảng con
```json
{ "reason": "Không thu xếp được trọng tài" }
```
reason bắt buộc, tối đa 500 ký tự.

Tác động: hoàn 100% lệ phí, trả quỹ thưởng chưa dùng, trả các ca sân đã giữ, thông báo người tham gia. Chế tài BTC xem mục 11.

Response 200
```json
{
  "cancelledTournaments": ["c7d2...90", "d8e3...01"],
  "refundedEntryFees": 1100000,
  "prizeFundReturned": 0,
  "notifiedUsers": 11,
  "releasedCourtSlots": 6,
  "fairPlayPenalty": -20,
  "organizerCancelCount": 1,
  "tournamentBannedUntil": null,
  "urgentNotified": false
}
```
- releasedCourtSlots: Số ca giữ sân (court-blocks) được mở lại
- fairPlayPenalty: Điểm Fair Play BTC bị trừ (0 nếu không bị phạt)
- organizerCancelCount: Tổng số lần BTC bị tính vi phạm hủy giải; null nếu lần này không bị tính
- tournamentBannedUntil: Có giá trị nếu lần hủy này khiến BTC bị cấm tạo giải 90 ngày
- urgentNotified: true nếu đã gửi thông báo khẩn cho chủ sân + Admin (BTC là người ngoài, hủy sát ngày)

Lỗi: 400 (thiếu lý do, đã hủy, đã kết thúc), 403 (không phải BTC), 404.

### 2.9 Xóa giải

DELETE /tournaments/{id} · Quyền: BTC · {id} = giải mẹ hoặc bảng con

Chỉ khi chưa có ai đăng ký còn hiệu lực, hoặc giải đã bị hủy. Giải đang / đã thi đấu phải dùng 2.8.

Response 200
```json
{ "deletedTournaments": ["c7d2...90", "d8e3...01"], "prizeFundReturned": 0 }
```

### 2.10 Điểm danh người tham gia

POST /tournaments/{id}/check-in · Quyền: BTC · {id} = bảng con
```json
{ "participantId": null, "qrCode": "TOUR|..." }
```
Truyền participantId hoặc qrCode (quét vé ở 3.6).

Response 200
```json
{
  "participantId": "e1f2...",
  "userId": "a9b8...",
  "fullName": "Trần Thị B",
  "phone": "0912345678",
  "teamId": null,
  "teamName": null,
  "tournamentId": "d8e3...01",
  "tournamentName": "Đơn nữ",
  "isCheckedIn": true,
  "checkedInAt": "2026-12-20T01:05:00Z"
}
```

### 2.11 Chủ sân báo "Tôi không có thỏa thuận này"

Chủ sân KHÔNG duyệt giải. Khi người ngoài tạo giải tại cơ sở, chủ sân chỉ nhận thông báo.

- Xem các giải người ngoài tạo tại cơ sở của mình: GET /tournaments/my-tournaments?scope=facility (giải chờ Admin có approvalStatus = PENDING_ADMIN); chi tiết (lịch sân yêu cầu, file bằng chứng ở rulesFileUrl...): GET /tournaments/{id}.
- Nếu không có thỏa thuận: chủ sân bấm nút "Tôi không có thỏa thuận này" để báo Admin. Admin sẽ thấy cảnh báo này trước khi duyệt (9.4).
- Endpoint cho nút này: CHƯA CHỐT, chờ BE bổ sung. Mobile dựng sẵn UI nút, gắn API khi BE có.
- API cũ PATCH /owner/tournaments/{id}/approve và PATCH /owner/tournaments/{id}/reject: không dùng trong luồng mới, mobile không gọi.

## 3. Công khai & người chơi

### 3.1 Danh sách giải công khai

GET /tournaments?facilityId=&categoryId=&status= · Quyền: Public
GET /facilities/{facilityId}/tournaments · Quyền: Public (lọc theo cơ sở)

Response 200 – mảng TournamentListResponse (chỉ giải mẹ, không gồm giải nội bộ / bị khóa)
```json
[
  {
    "id": "c7d2...90",
    "name": "Giải cầu lông mùa đông 2026",
    "status": "OPEN",
    "format": "Knockout",
    "tier": "AMATEUR",
    "purpose": "EXCHANGE",
    "minRating": null,
    "maxRating": null,
    "minRatedMatches": null,
    "facilityId": "4f1c...e2",
    "facilityName": "Sân cầu lông ABC",
    "facilityAddress": "12 Lê Lợi, Quận 1",
    "categoryId": "9a0b...11",
    "categoryName": "Cầu lông",
    "totalSubTournaments": 2,
    "startDate": "2026-12-20T01:00:00Z",
    "endDate": "2026-12-21T11:00:00Z",
    "registrationDeadline": "2026-12-18T16:59:00Z",
    "isRegistrationOpen": true,
    "imageUrl": "https://cdn.example.com/cover.jpg",
    "isPromoted": false
  }
]
```
isPromoted = true: giải đang chạy gói đẩy tin (hiện nhãn "Nổi bật").

### 3.2 Tìm giải (có phân trang)

GET /tournaments/search · Quyền: Public

Query:
- keyword: Tên giải / tên bảng
- facilityId, categoryId
- status: OPEN | IN_PROGRESS | FINISHED | CANCELLED
- registrationOpen: true = chỉ giải còn hạn đăng ký
- sortBy: upcoming (sắp diễn ra) | deadline (sắp hết hạn đăng ký) | newest (mặc định)
- page, pageSize: Mặc định 1, 10

Response 200 – PagedResponse<TournamentListResponse> (item giống 3.1).

### 3.3 Chi tiết giải / bảng đấu

GET /tournaments/{id} · Quyền: Public · {id} = giải mẹ hoặc bảng con

Response 200 – TournamentDetailResponse
```json
{
  "id": "c7d2...90",
  "name": "Giải cầu lông mùa đông 2026",
  "status": "OPEN",
  "format": "Knockout",
  "tier": "AMATEUR",
  "purpose": "EXCHANGE",
  "minRating": null,
  "maxRating": null,
  "minRatedMatches": null,
  "facilityId": "4f1c...e2",
  "facilityName": "Sân cầu lông ABC",
  "facilityAddress": "12 Lê Lợi, Quận 1",
  "categoryId": "9a0b...11",
  "categoryName": "Cầu lông",
  "sportRulesDescription": "Luật chung của môn...",
  "parentTournamentId": null,
  "parentTournamentName": null,
  "categoryType": "SINGLES",
  "categoryTypeName": "Đơn",
  "registrationGuide": "Đăng ký cá nhân",
  "maxParticipants": 16,
  "minTeamSize": null,
  "maxTeamSize": null,
  "currentParticipants": 7,
  "availableSlots": 9,
  "entryFee": 100000,
  "startDate": "2026-12-20T01:00:00Z",
  "endDate": "2026-12-21T11:00:00Z",
  "registrationDeadline": "2026-12-18T16:59:00Z",
  "isRegistrationOpen": true,
  "imageUrl": "https://cdn.example.com/cover.jpg",
  "rules": "Thi đấu theo luật BWF...",
  "rulesFileUrl": "https://res.cloudinary.com/.../dieu-le.pdf",
  "defaultBracketFormat": "Knockout",
  "organizerId": "a1b2...",
  "organizerName": "Nguyễn Văn A",
  "approvalStatus": "APPROVED",
  "approvalNote": null,
  "ownerApprovedAt": null,
  "ownerNote": null,
  "requestedSchedule": [
    { "date": "2026-12-20", "session": "FULL_DAY", "startTime": "06:00", "endTime": "22:00", "courtCount": 3 }
  ],
  "prizeNotice": "Giải thưởng do Ban tổ chức tự trao, SportNexus không giữ quỹ thưởng.",
  "prizes": [ { "id": "p1...", "position": "1", "rewardAmount": 1000000 } ],
  "children": [
    {
      "id": "d8e3...01",
      "name": "Đơn nam",
      "categoryType": "SINGLES",
      "categoryTypeName": "Đơn",
      "registrationGuide": "Đăng ký cá nhân",
      "format": "Knockout",
      "maxParticipants": 16,
      "minTeamSize": null,
      "maxTeamSize": null,
      "currentParticipants": 7,
      "availableSlots": 9,
      "entryFee": 100000,
      "status": "OPEN",
      "isRegistrationOpen": true,
      "prizes": [ { "id": "p1...", "position": "1", "rewardAmount": 1000000 } ]
    }
  ]
}
```
- Gọi với id giải mẹ: children chứa các bảng con.
- Gọi với id bảng con: parentTournamentId / parentTournamentName có giá trị, children rỗng; rulesFileUrl và requestedSchedule lấy theo giải mẹ.
- defaultBracketFormat trả theo tên nội bộ (Knockout / RoundRobin / GroupKnockout), null = BTC chọn khi sinh sơ đồ.
- requestedSchedule: lịch sân BTC yêu cầu (date dạng yyyy-MM-dd giờ VN, kèm khung giờ của buổi).
- ownerApprovedAt / ownerNote (ở đây và ở 9.1): thuộc luồng chủ sân duyệt cũ, luồng mới không dùng, mobile không cần hiển thị.

### 3.4 Danh sách người đã đăng ký

GET /tournaments/{id}/participants · Quyền: Public (SĐT chỉ hiện cho BTC / Admin / chính người đó) · {id} = bảng con

Response 200 – mảng TournamentParticipantResponse
```json
[
  {
    "participantId": "e1f2...",
    "tournamentId": "d8e3...01",
    "userId": "a9b8...",
    "fullName": "Trần Thị B",
    "username": "tranb",
    "phone": "0912345678",
    "avatarUrl": "https://...",
    "teamId": null,
    "teamName": null,
    "paymentStatus": "PAID",
    "qrCode": "TOUR|...",
    "isCheckedIn": false,
    "teamMembers": [
      { "accountId": "...", "fullName": "Lê C", "phone": "09...", "avatarUrl": null, "joinedAt": "2026-11-01T03:00:00Z" }
    ]
  }
]
```
teamMembers chỉ có ở bảng đội.

### 3.5 Đăng ký tham gia

POST /tournaments/{id}/join?teamId={teamId} · Quyền: Đăng nhập · {id} = bảng con

- Bảng cá nhân: không truyền teamId. Bảng đội: truyền teamId (đội trưởng đăng ký cho cả đội).
- Lệ phí bị trừ khỏi số dư và giữ tạm (đóng băng) tới khi giải quyết toán.
- Kiểm tra: còn hạn & còn chỗ, giải không khóa, Elo / số trận theo tier, kích thước đội, đã làm khảo sát môn (nếu chưa: 403 kèm errorCode).

Response 200
```json
{
  "participantId": "e1f2...",
  "tournamentId": "d8e3...01",
  "tournamentName": "Đơn nam",
  "entryFee": 100000,
  "qrCode": "TOUR|...",
  "paymentStatus": "PAID"
}
```

### 3.6 Vé QR tham dự

GET /tournaments/{id}/qr-ticket · Quyền: Đăng nhập (người đã đăng ký) · {id} = bảng con

Response 200 – TournamentQrTicketResponse
```json
{
  "tournamentId": "d8e3...01",
  "tournamentName": "Đơn nam",
  "categoryType": "SINGLES",
  "facilityId": "4f1c...e2",
  "facilityName": "Sân cầu lông ABC",
  "facilityAddress": "12 Lê Lợi, Quận 1",
  "participantId": "e1f2...",
  "userId": "a9b8...",
  "fullName": "Trần Thị B",
  "teamName": null,
  "qrCode": "TOUR|...",
  "paymentStatus": "PAID",
  "tournamentStatus": "OPEN"
}
```

### 3.7 Hủy đăng ký / rút lui

POST /tournaments/{id}/cancel · Quyền: Đăng nhập · {id} = bảng con

Chỉ khi bảng còn OPEN. Trước hạn đăng ký: hoàn 100% lệ phí. Sau hạn đăng ký: không hoàn lệ phí.

Response 200: data = null, message "Hủy đăng ký và hoàn lệ phí thành công." hoặc "Đã hủy đăng ký. Đã quá hạn đăng ký nên lệ phí không được hoàn."

### 3.8 Giải tôi đã đăng ký

GET /tournaments/my-registrations · Quyền: Đăng nhập

Response 200 – mảng MyTournamentRegistrationResponse
```json
[
  {
    "participantId": "e1f2...",
    "tournamentId": "d8e3...01",
    "tournamentName": "Đơn nam",
    "parentTournamentId": "c7d2...90",
    "parentTournamentName": "Giải cầu lông mùa đông 2026",
    "categoryType": "SINGLES",
    "facilityId": "4f1c...e2",
    "facilityName": "Sân cầu lông ABC",
    "entryFee": 100000,
    "paymentStatus": "PAID",
    "tournamentStatus": "OPEN",
    "qrCode": "TOUR|...",
    "teamId": null,
    "teamName": null,
    "startDate": "2026-12-20T01:00:00Z",
    "endDate": "2026-12-21T11:00:00Z",
    "registrationDeadline": "2026-12-18T16:59:00Z",
    "isRegistrationOpen": true,
    "imageUrl": "https://..."
  }
]
```

### 3.9 Lịch thi đấu của tôi

GET /tournaments/my-matches?from=2026-12-01&to=2026-12-31 · Quyền: Đăng nhập

Gồm trận cá nhân và trận của đội tôi, sắp theo giờ thi đấu.

Response 200 – mảng MyMatchResponse
```json
[
  {
    "matchId": "m1...",
    "tournamentId": "d8e3...01",
    "tournamentName": "Đơn nam",
    "parentTournamentId": "c7d2...90",
    "parentTournamentName": "Giải cầu lông mùa đông 2026",
    "roundName": "Tứ kết",
    "status": "PENDING",
    "startTime": "2026-12-20T02:00:00Z",
    "endTime": "2026-12-20T03:00:00Z",
    "courtName": "Sân 2",
    "facilityId": "4f1c...e2",
    "facilityName": "Sân cầu lông ABC",
    "facilityAddress": "12 Lê Lợi, Quận 1",
    "mySideName": "Trần Thị B",
    "opponentName": "Phạm D",
    "winnerName": null
  }
]
```

### 3.10 Sơ đồ thi đấu

GET /tournaments/{id}/bracket · Quyền: Public · {id} = bảng con

Response 200 – mảng trận
```json
[
  {
    "id": "m1...",
    "matchIndex": 1,
    "stage": "KNOCKOUT",
    "groupName": null,
    "resultType": null,
    "roundName": "Tứ kết",
    "status": "PENDING",
    "courtSlotId": "s1...",
    "startTime": "2026-12-20T02:00:00Z",
    "endTime": "2026-12-20T03:00:00Z",
    "courtId": "c1...",
    "courtName": "Sân 2",
    "p1": "Trần Thị B",
    "p2": "Phạm D",
    "winner": null,
    "scores": [ { "setNumber": 1, "scoreP1": 21, "scoreP2": 18, "isTiebreak": false } ]
  }
]
```
p1 / p2 = "TBD" khi chưa xác định đấu thủ. stage / groupName có ở thể thức vòng bảng.

### 3.11 Bảng xếp hạng vòng bảng / vòng tròn

GET /tournaments/{id}/standings · Quyền: Public · {id} = bảng con

Response 200 (message "Giải không có vòng bảng" nếu là knockout thuần)
```json
[
  {
    "group": "A",
    "rows": [
      { "rank": 1, "participantId": "e1f2...", "name": "Trần Thị B", "played": 3, "won": 3, "drawn": 0, "lost": 0, "points": 9, "diff": 25, "scored": 63 }
    ]
  }
]
```

## 4. Lời mời (giải nội bộ)

Áp dụng cho giải purpose = INTERNAL: không công khai, người chơi chỉ vào được qua lời mời của BTC.

### 4.1 Mời vào bảng đấu

POST /tournaments/{id}/invitations · Quyền: BTC (Owner, Player) · {id} = bảng con
POST /tournaments/{id}/participants – bí danh cũ, hành vi giống hệt.
```json
{ "userId": null, "phone": "0912345678", "teamId": null, "message": "Mời bạn tham gia giải nội bộ công ty" }
```
- Bảng cá nhân: userId hoặc phone.
- Bảng đội: teamId (đội trưởng nhận lời mời).
- message tối đa 500 ký tự.

Response 201 – TournamentInvitationResponse
```json
{
  "id": "inv1...",
  "tournamentId": "d8e3...01",
  "tournamentName": "Đơn nam",
  "parentTournamentId": "c7d2...90",
  "parentTournamentName": "Giải nội bộ 2026",
  "categoryType": "SINGLES",
  "entryFee": 0,
  "startDate": "2026-12-20T01:00:00Z",
  "registrationDeadline": "2026-12-18T16:59:00Z",
  "inviteeId": "a9b8...",
  "inviteeName": "Trần Thị B",
  "teamId": null,
  "teamName": null,
  "invitedById": "o1...",
  "invitedByName": "Nguyễn Văn A",
  "message": "Mời bạn tham gia giải nội bộ công ty",
  "status": "PENDING",
  "createdAt": "2026-11-23T03:00:00Z",
  "respondedAt": null
}
```

### 4.2 Lời mời của 1 bảng (BTC xem)

GET /tournaments/{id}/invitations · Quyền: BTC · Response 200: mảng TournamentInvitationResponse.

### 4.3 Thu hồi lời mời

DELETE /tournaments/invitations/{invitationId} · Quyền: BTC · Chỉ lời mời PENDING. Response 200: data = null, message "Đã thu hồi lời mời."

### 4.4 Lời mời tôi nhận được

GET /tournaments/my-invitations?status=PENDING · Quyền: Đăng nhập · Response 200: mảng TournamentInvitationResponse.

### 4.5 Trả lời lời mời

POST /tournaments/invitations/{invitationId}/respond · Quyền: Đăng nhập (người được mời)
```json
{ "accept": true }
```
- accept = true: đăng ký như tự đăng ký (kiểm tra điều kiện, giữ lệ phí). Response giống 3.5, message có tiền tố "Đã nhận lời mời. ". Nếu đăng ký lỗi thì lời mời vẫn PENDING để thử lại.
- accept = false: data = null, message "Đã từ chối lời mời."

## 5. Giữ sân & lịch sân

### 5.1 Giữ khung giờ sân cho giải (court-blocks)

POST /tournaments/{id}/court-blocks · Quyền: Owner (chủ cơ sở) hoặc Admin · {id} = giải mẹ hoặc bảng con

Các ca trong khung chuyển Reserved, khách không đặt được. Ca đã có khách đặt trả về trong conflicts.
```json
{
  "courtIds": ["c1...", "c2..."],
  "dateFrom": "2026-12-20",
  "dateTo": "2026-12-21",
  "startTime": "08:00:00",
  "endTime": "18:00:00"
}
```
- courtIds: Bắt buộc, sân con thuộc cơ sở tổ chức giải
- dateFrom: Bắt buộc, không phải ngày đã qua
- dateTo: Bỏ trống = bằng dateFrom; tối đa 14 ngày
- startTime, endTime: Giờ Việt Nam HH:mm:ss; bỏ trống cả hai = cả ngày (phải truyền đủ cả hai nếu dùng)

Response 200 – TournamentCourtBlockResultResponse
```json
{
  "matchedSlots": 20,
  "blockedSlots": 18,
  "alreadyBlockedSlots": 0,
  "conflicts": [
    {
      "slotId": "s9...",
      "courtId": "c1...",
      "courtName": "Sân 1",
      "startTime": "2026-12-20T03:00:00Z",
      "endTime": "2026-12-20T04:00:00Z",
      "reason": "Đã có khách đặt",
      "bookingId": "b7..."
    }
  ]
}
```

### 5.2 Bỏ giữ sân

POST /tournaments/{id}/court-blocks/release · Quyền: Owner hoặc Admin

Body giống 5.1 nhưng mọi trường tùy chọn; body rỗng {} = bỏ mọi ca chưa tới giờ đang giữ cho giải. Ca đã xếp cho trận chưa đá vẫn được giữ.

Response 200 – TournamentCourtBlockResultResponse (blockedSlots = số ca đã trả cho khách đặt; alreadyBlockedSlots = số ca vẫn giữ vì đã xếp trận).

### 5.3 Lịch sân của giải

GET /tournaments/{id}/court-schedule · Quyền: Public

Response 200 – TournamentCourtScheduleResponse
```json
{
  "tournamentId": "c7d2...90",
  "tournamentName": "Giải cầu lông mùa đông 2026",
  "blocks": [
    { "courtId": "c1...", "courtName": "Sân 1", "startTime": "2026-12-20T01:00:00Z", "endTime": "2026-12-20T11:00:00Z", "slotCount": 10 }
  ],
  "matches": [
    { "matchId": "m1...", "roundName": "Tứ kết", "status": "PENDING", "courtId": "c1...", "courtName": "Sân 1", "startTime": "2026-12-20T02:00:00Z", "endTime": "2026-12-20T03:00:00Z" }
  ]
}
```

### 5.4 Xếp lịch tự động

POST /tournaments/{id}/auto-schedule · Quyền: BTC · {id} = bảng con

Xếp các trận chưa có ca vào ca sân đã giữ cho giải và đề xuất trọng tài; BTC sửa lại được bằng 7.3 / 7.4.

Response 200
```json
{ "scheduled": 6, "unscheduled": 1, "refereesAssigned": 6, "missingReferee": 0 }
```

## 6. Nhân sự giải & trọng tài

Nhân sự gắn với giải mẹ (truyền id bảng con cũng được, hệ thống quy về giải mẹ). Nhân sự có accountId được nhập tỉ số các trận của giải tới khi giải kết thúc.

### 6.1 Thêm nhân sự

POST /tournaments/{id}/staff · Quyền: BTC
```json
{
  "fullName": "Lê Văn Trọng",
  "phone": "0987654321",
  "role": "REFEREE",
  "accountId": null,
  "usernameOrEmail": "trongtai01@gmail.com",
  "note": "Trọng tài chính sân 1"
}
```
- role: Bắt buộc: REFEREE | SCORER | OTHER
- accountId / usernameOrEmail: Tùy chọn: gắn tài khoản SportNexus (tìm theo id, hoặc theo username / email). Không tìm thấy → 404 (nhân sự cần tự tạo tài khoản trước)
- fullName, phone: Bắt buộc khi không gắn tài khoản; có tài khoản thì bỏ trống = lấy theo tài khoản

Response 201
```json
{ "id": "st1...", "fullName": "Lê Văn Trọng", "phone": "0987654321", "role": "REFEREE", "accountId": "u5...", "note": "Trọng tài chính sân 1" }
```

### 6.2 Danh sách nhân sự

GET /tournaments/{id}/staff · Quyền: BTC / Admin

Response 200
```json
[
  { "id": "st1...", "fullName": "Lê Văn Trọng", "phone": "0987654321", "role": "REFEREE", "accountId": "u5...", "note": null, "assignedMatches": 3 }
]
```
assignedMatches = số trận chưa xong đang được phân công.

### 6.3 Sửa nhân sự

PUT /tournaments/{id}/staff/{staffId} · Quyền: BTC · Body giống 6.1 (ghi đè toàn bộ) · Response 200: giống 6.1.

### 6.4 Xóa nhân sự

DELETE /tournaments/{id}/staff/{staffId} · Quyền: BTC · Response 200: data = null.

### 6.5 Trận tôi được nhập tỉ số (nhân sự)

GET /tournaments/my-staff-matches · Quyền: Đăng nhập

Các trận của những giải chưa kết thúc mà tôi là nhân sự có tài khoản (trọng tài / người nhập điểm). Dùng làm lối tắt vào trang nhập điểm.

Response 200 – mảng StaffMatchResponse
```json
[
  {
    "matchId": "m1...",
    "tournamentId": "d8e3...01",
    "tournamentName": "Đơn nam",
    "rootTournamentId": "c7d2...90",
    "rootTournamentName": "Giải cầu lông mùa đông 2026",
    "staffRole": "REFEREE",
    "isAssignedOfficial": true,
    "roundName": "Tứ kết",
    "status": "PENDING",
    "participant1Name": "Trần Thị B",
    "participant2Name": "Phạm D",
    "startTime": "2026-12-20T02:00:00Z",
    "endTime": "2026-12-20T03:00:00Z",
    "courtName": "Sân 1",
    "facilityName": "Sân cầu lông ABC"
  }
]
```
isAssignedOfficial = true: được phân công trọng tài của đúng trận đó (7.3). Message "Bạn chưa là trọng tài / người nhập điểm của giải nào" khi danh sách rỗng.

## 7. Trận đấu & tỉ số

### 7.1 Chi tiết trận

GET /matches/{matchId} · Quyền: Public (SĐT đấu thủ chỉ hiện cho BTC / Admin / người trong trận)

Response 200 – MatchDetailResponse
```json
{
  "id": "m1...",
  "tournamentId": "d8e3...01",
  "tournamentName": "Đơn nam",
  "sportName": "Cầu lông",
  "matchIndex": 1,
  "roundName": "Tứ kết",
  "status": "FINISHED",
  "courtSlotId": "s1...",
  "startTime": "2026-12-20T02:00:00Z",
  "endTime": "2026-12-20T03:00:00Z",
  "courtId": "c1...",
  "courtName": "Sân 1",
  "participant1Id": "e1f2...",
  "participant1Name": "Trần Thị B",
  "participant1Avatar": null,
  "participant1Phone": "0912345678",
  "participant2Id": "e3f4...",
  "participant2Name": "Phạm D",
  "participant2Avatar": null,
  "participant2Phone": null,
  "winnerId": "e1f2...",
  "winnerName": "Trần Thị B",
  "scores": [
    { "setNumber": 1, "scoreP1": 21, "scoreP2": 18, "isTiebreak": false },
    { "setNumber": 2, "scoreP1": 21, "scoreP2": 15, "isTiebreak": false }
  ]
}
```
isTiebreak = true (setNumber = 99): dòng loạt sút luân lưu, không phải một hiệp.

### 7.2 Nhập / sửa tỉ số

PUT /matches/{matchId}/score · Quyền: BTC, nhân sự giải có tài khoản, hoặc Admin

Nhập tỉ số và tự đưa bên thắng vào vòng sau. Áp dụng luật điểm theo môn (cầu lông tối đa 30/set theo BWF, tennis, pickleball, bóng bàn, bóng đá...).

Body (nhiều hiệp)
```json
{
  "sets": [
    { "setNumber": 1, "scoreP1": 21, "scoreP2": 18 },
    { "setNumber": 2, "scoreP1": 19, "scoreP2": 21 },
    { "setNumber": 3, "scoreP1": 21, "scoreP2": 17 }
  ],
  "winnerId": null,
  "tiebreakP1": null,
  "tiebreakP2": null,
  "resultType": "NORMAL"
}
```
Cách ngắn cho trận 1 hiệp: body { "scoreP1": 3, "scoreP2": 1 } hoặc query PUT /matches/{matchId}/score?scoreP1=3&scoreP2=1&winnerId=....

- sets: Danh sách hiệp (BO1 / BO3 / BO5)
- scoreP1, scoreP2: Dùng khi chỉ có 1 hiệp
- winnerId: Tùy chọn: bỏ trống thì hệ thống tự xác định theo tỉ số; nếu truyền phải khớp tỉ số
- tiebreakP1, tiebreakP2: Loạt sút luân lưu, chỉ môn bóng đá / futsal, chỉ khi tổng tỉ số hòa
- resultType: NORMAL (mặc định) | WALKOVER (không cần tỉ số) | RETIRED (tỉ số dở dang). WALKOVER / RETIRED bắt buộc winnerId

Response 200
```json
{
  "matchId": "m1...",
  "roundName": "Tứ kết",
  "status": "FINISHED",
  "resultType": "NORMAL",
  "winnerId": "e1f2...",
  "winnerName": "Trần Thị B",
  "scoreSummary": "Trần Thị B 2 - 1 Phạm D",
  "scoringMode": "SETS",
  "scoreP1": 2,
  "scoreP2": 1,
  "sets": [ { "setNumber": 1, "scoreP1": 21, "scoreP2": 18 } ],
  "tiebreak": null,
  "isTournamentFinished": false
}
```
- scoringMode: SETS (tính theo số hiệp thắng) hoặc TOTAL_SCORE (tổng điểm).
- Sửa tỉ số trận đã xong: hệ thống hoàn lần tính Elo cũ, đặt lại mốc khiếu nại và tính lại Elo sau.

### 7.3 Phân công trọng tài cho trận

PUT /matches/{matchId}/officials · Quyền: BTC
```json
{ "staffIds": ["st1...", "st2..."] }
```
Chỉ nhân sự vai trò REFEREE của giải; không trùng giờ với trận khác. Mảng rỗng = bỏ phân công.

Response 200
```json
{ "matchId": "m1...", "staffIds": ["st1...", "st2..."] }
```

### 7.4 Xếp sân cho trận

PUT /matches/{matchId}/assign-court · Quyền: BTC
```json
{ "courtSlotId": "s1..." }
```
Response 200
```json
{ "matchId": "m1...", "courtSlotId": "s1...", "courtName": "Sân 1", "startTime": "2026-12-20T02:00:00Z", "endTime": "2026-12-20T03:00:00Z" }
```

## 8. Khiếu nại kết quả trận

Quy trình: Đấu thủ khiếu nại → Trọng tài gửi biên bản → BTC chốt quyết định → Người khiếu nại chuyển Admin nếu không đồng ý → Admin đóng. Elo của trận chưa được tính khi khiếu nại đang mở hoặc đang chờ Admin. Luồng này tách biệt hoàn toàn với điểm Fair Play / đánh giá sao LFG.

### 8.1 Gửi khiếu nại

POST /reports · Quyền: Đăng nhập (chỉ người thi đấu trận đó: đấu thủ đơn hoặc thành viên đội)
```json
{
  "targetType": "MATCH",
  "targetObjectId": "m1...",
  "reason": "WRONG_MATCH_RESULT",
  "description": "BTC nhập ngược tỉ số set 2",
  "evidenceImageUrls": ["https://cdn.example.com/evidence1.jpg"]
}
```
- reason: WRONG_MATCH_RESULT (sai kết quả) | MATCH_MISCONDUCT (vi phạm trong trận). Danh sách đầy đủ: GET /reports/reasons.
- Chỉ trong matchComplaintMinutes phút sau khi trận kết thúc (mặc định 15 phút).
- BTC nhận thông báo.

Response 201 – ReportDetailResponse (xem 8.5).

### 8.2 Trọng tài gửi biên bản

POST /match-complaints/{id}/referee-note · Quyền: Đăng nhập – chỉ tài khoản được phân công làm REFEREE của đúng trận đó · {id} = id khiếu nại
```json
{ "note": "Đấu thủ 2 nhận thẻ vàng ở set 2; tỉ số 2-1 ghi nhận đúng." }
```
- note bắt buộc, tối đa 2000 ký tự.
- Gửi được khi khiếu nại đang mở hoặc đang chờ Admin; gửi lại = cập nhật biên bản.
- BTC và người khiếu nại được báo.

Response 200 – ReportDetailResponse (refereeNote, refereeSubmittedAt, refereeUserId có giá trị).

Lỗi:
- 403: Không phải trọng tài được phân công cho trận
- 400: Thiếu / quá dài nội dung; khiếu nại đã đóng
- 404: Không phải khiếu nại trận

### 8.3 BTC chốt quyết định

POST /match-complaints/{id}/decide · Quyền: Đăng nhập – chỉ BTC của giải
```json
{ "decision": "REJECT", "note": "Biên bản trọng tài xác nhận tỉ số đúng, giữ nguyên kết quả." }
```
- ACCEPT: Chấp nhận khiếu nại → trạng thái RESOLVED_NO_REFUND. BTC tự sửa tỉ số bằng 7.2 nếu cần (Elo được tính lại)
- REJECT: Bác khiếu nại, giữ nguyên kết quả → trạng thái REJECTED
- note bắt buộc, tối đa 2000 ký tự.
- Người khiếu nại được báo, kèm hạn được chuyển Admin (24 giờ).
- Không quyết định được khi khiếu nại đã chuyển Admin (400).

Response 200 – ReportDetailResponse (organizerDecisionNote, organizerDecidedAt có giá trị).

### 8.4 Chuyển Admin phân xử

POST /match-complaints/{id}/escalate · Quyền: Đăng nhập – chỉ người khiếu nại
```json
{ "reason": "Video cho thấy cầu rơi ngoài sân ở điểm quyết định." }
```
Được chuyển khi:
- BTC đã quyết định và chưa quá 24 giờ kể từ quyết định; hoặc
- BTC chưa xử lý và đã quá 24 giờ kể từ lúc gửi khiếu nại.

Mỗi khiếu nại chỉ chuyển được 1 lần. Sau khi chuyển:
- isEscalatedToAdmin = true; trạng thái mở lại: OWNER_RESPONDED (BTC đã quyết định) hoặc PENDING (BTC chưa xử lý).
- Mọi Admin và BTC được báo; BTC không đổi được quyết định nữa.
- Elo của trận chờ tới khi Admin đóng.

reason bắt buộc, tối đa 1000 ký tự.

Response 200 – ReportDetailResponse.

Lỗi:
- 403: Không phải người khiếu nại
- 400: Đã chuyển trước đó; quá 24 giờ sau quyết định; BTC còn trong hạn xử lý; khiếu nại đã đóng

### 8.5 Admin đóng khiếu nại

POST /reports/admin/{id}/resolve · Quyền: Admin
```json
{ "decision": "RESOLVE_NO_REFUND", "adminNote": "Chấp nhận khiếu nại, yêu cầu BTC sửa tỉ số set 2." }
```
Với khiếu nại trận dùng RESOLVE_NO_REFUND (khiếu nại đúng) hoặc REJECT (bác). Khi đóng, escalationClosedAt được ghi; lần chạy job sau mới tính Elo. Nếu cần đổi kết quả, Admin / BTC sửa tỉ số bằng 7.2.

ReportDetailResponse (các trường liên quan khiếu nại trận)
```json
{
  "id": "r1...",
  "reporterId": "a9b8...",
  "reporterName": "Phạm D",
  "reporterEmail": "d@example.com",
  "reporterPhone": "09...",
  "targetType": "MATCH",
  "targetObjectId": "m1...",
  "facilityId": "4f1c...e2",
  "facilityName": "Sân cầu lông ABC",
  "reason": "WRONG_MATCH_RESULT",
  "description": "BTC nhập ngược tỉ số set 2",
  "evidenceImageUrls": ["https://..."],
  "status": "OWNER_RESPONDED",
  "refereeNote": "Đấu thủ 2 nhận thẻ vàng ở set 2...",
  "refereeSubmittedAt": "2026-12-20T03:20:00Z",
  "refereeUserId": "u5...",
  "organizerDecisionNote": "Giữ nguyên kết quả.",
  "organizerDecidedAt": "2026-12-20T04:00:00Z",
  "isEscalatedToAdmin": true,
  "escalatedReason": "Video cho thấy cầu rơi ngoài sân...",
  "escalatedAt": "2026-12-20T06:00:00Z",
  "escalationClosedAt": null,
  "adminNote": null,
  "resolvedByAdminId": null,
  "resolvedByAdminName": null,
  "resolvedAt": null,
  "createdAt": "2026-12-20T03:10:00Z",
  "updatedAt": "2026-12-20T06:00:00Z"
}
```
(Các trường dành cho khiếu nại đặt sân như bookingId, requestedRefundPercentage, refundedAmount... là null với khiếu nại trận.)

### 8.6 Danh sách khiếu nại trận của giải

GET /tournaments/{id}/match-complaints?status=OPEN · Quyền: BTC / Admin (Owner, Player, Admin) · {id} = giải mẹ (gồm mọi bảng con) hoặc bảng con

- Query status: OPEN (mặc định: đang mở) | ALL

Response 200 – mảng MatchComplaintResponse (message "Không có khiếu nại" khi rỗng)
```json
[
  {
    "id": "r1...",
    "matchId": "m1...",
    "tournamentId": "d8e3...01",
    "tournamentName": "Đơn nam",
    "roundName": "Tứ kết",
    "participant1Name": "Trần Thị B",
    "participant2Name": "Phạm D",
    "winnerName": "Trần Thị B",
    "reporterId": "a9b8...",
    "reporterName": "Phạm D",
    "reason": "WRONG_MATCH_RESULT",
    "description": "BTC nhập ngược tỉ số set 2",
    "evidenceImageUrls": ["https://..."],
    "status": "PENDING",
    "resolutionNote": null,
    "createdAt": "2026-12-20T03:10:00Z",
    "resolvedAt": null
  }
]
```
resolutionNote / resolvedAt: kết luận của Admin nếu có, nếu không thì là quyết định của BTC (8.3 / 8.7).

### 8.7 BTC / Admin đóng khiếu nại kèm sửa tỉ số

POST /match-complaints/{complaintId}/resolve · Quyền: BTC / Admin (Owner, Player, Admin)

Đóng khiếu nại trong 1 bước, có thể sửa tỉ số luôn.
```json
{
  "action": "UPDATE_SCORE",
  "score": { "sets": [ { "setNumber": 1, "scoreP1": 21, "scoreP2": 18 }, { "setNumber": 2, "scoreP1": 21, "scoreP2": 19 } ] },
  "note": "Đã đối chiếu biên bản, sửa lại tỉ số set 2."
}
```
- action: KEEP_SCORE (giữ tỉ số, bác khiếu nại → REJECTED) | UPDATE_SCORE (sửa tỉ số → RESOLVED_NO_REFUND)
- score: Bắt buộc khi UPDATE_SCORE; cùng cấu trúc và luật kiểm tra như 7.2
- note: Tùy chọn, tối đa 2000 ký tự; bỏ trống = nội dung mặc định. Lưu vào adminNote / resolutionNote

Chỉ khi khiếu nại đang mở. Người khiếu nại được báo. Sửa tỉ số thì đặt lại mốc khiếu nại và Elo được tính lại sau.

Ý nghĩa theo người gọi:
- BTC gọi: Là quyết định của BTC (organizerDecisionNote, organizerDecidedAt), giống 8.3 nhưng sửa được tỉ số luôn. Sau đó người khiếu nại vẫn chuyển Admin được trong 24 giờ (8.4).
- Admin gọi (không phải BTC của giải): Là phán quyết cuối của Admin (adminNote, resolvedByAdminId, resolvedAt). Nếu khiếu nại đang chờ Admin: đóng yêu cầu phân xử (escalationClosedAt), Elo của trận được tính ở lần chạy job sau.

Khiếu nại đã chuyển Admin thì BTC không gọi được API này nữa (400); chỉ Admin đóng (bằng 8.7 hoặc 8.5).

Response 200
```json
{ "complaintId": "r1...", "matchId": "m1...", "status": "RESOLVED_NO_REFUND", "note": "Đã đối chiếu biên bản, sửa lại tỉ số set 2." }
```
Chọn API nào: BTC dùng decide (8.3) khi chỉ cần chấp nhận / bác, dùng resolve (8.7) khi muốn sửa tỉ số và đóng trong 1 bước. Cả hai đều là quyết định của BTC, người khiếu nại đều chuyển Admin được. Admin đóng khiếu nại đã chuyển lên bằng 8.7 (có thể sửa tỉ số) hoặc 8.5.

## 9. Admin quản lý giải

Quyền: Admin cho toàn bộ nhóm. Xem chi tiết / sơ đồ dùng API công khai (3.3, 3.10).

### 9.1 Danh sách giải

GET /admin/tournaments – gồm cả giải bị khóa / đã hủy

Query:
- keyword: Tên giải
- status: OPEN | IN_PROGRESS | FINISHED | CANCELLED
- facilityId, ownerId
- isLocked: true / false
- approvalStatus: APPROVED | PENDING_ADMIN | REJECTED | PENDING (= đang chờ Admin duyệt)
- page, pageSize: Mặc định 1, 20

Response 200 – PagedResponse<AdminTournamentItemResponse>
```json
{
  "page": 1, "pageSize": 20, "totalItems": 1, "totalPages": 1,
  "items": [
    {
      "id": "c7d2...90",
      "name": "Giải cầu lông mùa đông 2026",
      "status": "OPEN",
      "format": "Knockout",
      "categoryType": "SINGLES",
      "facilityId": "4f1c...e2",
      "facilityName": "Sân cầu lông ABC",
      "ownerId": "o1...",
      "ownerName": "Chủ sân ABC",
      "organizerId": "a1b2...",
      "organizerName": "Nguyễn Văn A",
      "approvalStatus": "PENDING_ADMIN",
      "approvalNote": null,
      "ownerApprovedAt": null,
      "ownerNote": null,
      "startDate": "2026-12-20T01:00:00Z",
      "endDate": "2026-12-21T11:00:00Z",
      "categoryId": "9a0b...11",
      "categoryName": "Cầu lông",
      "subTournamentCount": 2,
      "participantCount": 0,
      "prizeFundAmount": 0,
      "prizePaidAmount": 0,
      "isLocked": false,
      "lockReason": null,
      "cancelledAt": null,
      "cancelReason": null,
      "settledAt": null
    }
  ]
}
```

### 9.2 Thống kê

GET /admin/tournaments/statistics

Response 200 – AdminTournamentStatisticsResponse
```json
{
  "totalTournaments": 40,
  "open": 8,
  "inProgress": 3,
  "finished": 25,
  "cancelled": 4,
  "locked": 1,
  "subTournaments": 95,
  "totalParticipants": 620,
  "entryFeesToOwners": 45000000,
  "entryFeesRefunded": 2300000,
  "prizeFundsHeld": 0,
  "prizesPaid": 12000000,
  "topFacilities": [ { "facilityId": "4f1c...e2", "facilityName": "Sân cầu lông ABC", "tournamentCount": 9 } ]
}
```

### 9.3 Khóa / mở khóa giải

PATCH /admin/tournaments/{id}/lock – body { "reason": "Nội dung vi phạm" }
PATCH /admin/tournaments/{id}/unlock – không body

Khóa: ẩn khỏi danh sách công khai, ngừng nhận đăng ký, BTC không thao tác được. Response 200 – AdminTournamentItemResponse.

### 9.4 Duyệt / từ chối yêu cầu tổ chức (Admin là người duyệt duy nhất)

PATCH /admin/tournaments/{id}/approve – không body
PATCH /admin/tournaments/{id}/reject – body { "reason": "Thiếu thông tin điều lệ" } (bắt buộc)

- approve: chỉ khi giải đang PENDING_ADMIN → APPROVED, giải công khai và mở đăng ký.
- Admin kiểm tra nội dung bài đăng + bằng chứng thỏa thuận (rulesFileUrl). Nếu chủ sân đã báo "Tôi không có thỏa thuận này" (2.11), Admin thấy cảnh báo trước khi duyệt.
- Admin có thể yêu cầu giải đã có ca giữ sân (5.1) trước khi duyệt.
- reject: khi giải đang PENDING_ADMIN → REJECTED.
- Chủ sân của cơ sở và người tổ chức được báo.

Response 200 – AdminTournamentItemResponse.

### 9.5 Admin hủy giải

PATCH /admin/tournaments/{id}/cancel – body { "reason": "Vi phạm quy định" }

Giống 2.8 nhưng không tính vi phạm cho BTC; BTC được báo kèm số quỹ thưởng trả lại. Response 200: giống 2.8.

## 10. Elo / Bảng xếp hạng

Elo tính sau khi hết hạn khiếu nại của trận và không còn khiếu nại mở / đang chờ Admin. Giải đã hủy không tính Elo.

### 10.1 Elo của tôi

GET /ratings/me · Quyền: Đăng nhập

### 10.2 Bảng xếp hạng

GET /ratings/leaderboard?sportCategoryId={id}&ratingType=SINGLES&page=1&pageSize=20 · Quyền: Public

Response – 10.1: mảng RatingResponse; 10.2: PagedResponse<RatingResponse>
```json
{
  "ownerType": "USER",
  "ownerId": "a9b8...",
  "ownerName": "Trần Thị B",
  "sportCategoryId": "9a0b...11",
  "sportName": "Cầu lông",
  "ratingType": "SINGLES",
  "rating": 1265,
  "rank": "Bạc",
  "ratedMatches": 7,
  "isProvisional": true
}
```
- ownerType: USER | TEAM.
- rank: Đồng, Bạc, Vàng, Bạch kim, Kim cương.
- isProvisional = true khi dưới 10 trận giải (Elo tạm tính).

## 11. Luật nghiệp vụ quan trọng

Duyệt giải của người ngoài (1 cấp – chỉ Admin duyệt)
- Người ngoài tạo giải + đính kèm bằng chứng thỏa thuận → PENDING_ADMIN → Admin duyệt (9.4) → APPROVED.
- Chủ sân chỉ nhận thông báo, không duyệt; có nút "Tôi không có thỏa thuận này" để báo Admin (2.11). Admin thấy cảnh báo khi duyệt.
- Admin từ chối → REJECTED (bắt buộc lý do).
- Chủ sân tổ chức tại cơ sở của mình: APPROVED ngay.

Mốc thời gian
- Hạn đăng ký mặc định: 48 giờ trước startDate.
- Bảng hết hạn đăng ký mà thiếu người: BTC có 24 giờ để quyết định (2.6); quá hạn hệ thống tự hủy, hoàn 100%.
- Khiếu nại trận: trong 15 phút (cấu hình theo giải) sau khi trận kết thúc; chuyển Admin trong 24 giờ sau quyết định của BTC, hoặc khi BTC quá 24 giờ chưa xử lý.

Tiền
- Lệ phí đóng băng trong ví người chơi khi đăng ký; quyết toán cho BTC (trừ phí nền tảng, cùng % với đặt sân) khi giải kết thúc.
- Người chơi rút lui trước hạn đăng ký: hoàn 100%; sau hạn: không hoàn.
- Giải bị hủy (bởi BTC / Admin / hệ thống): luôn hoàn 100% lệ phí.

Chế tài BTC hủy giải
Áp dụng khi BTC tự hủy (2.8) một giải đã APPROVED và đã có ≥ 1 người / đội đăng ký còn hiệu lực:
- BTC bị trừ 20 điểm Fair Play và tăng OrganizerCancelCount.
- Bị tính vi phạm từ 2 lần trong 60 ngày → cấm tạo giải 90 ngày (POST /tournaments trả 403 kèm tournamentBannedUntil).
- Không áp dụng khi Admin hủy hộ, hệ thống tự hủy, hoặc BTC chọn CANCEL vì thiếu người (2.6).

Điều kiện tạo giải
- Điểm Fair Play của người tạo phải ≥ 80, nếu không POST /tournaments trả 403.
- Không đang trong thời gian bị cấm tạo giải.
- Admin không bị giới hạn.

BTC là người ngoài hủy sát ngày
- BTC không phải chủ sân tự hủy khi còn ≤ 7 ngày tới startDate → chủ sân và mọi Admin nhận thông báo [Khẩn].
- Các ca court-blocks luôn được giải phóng khi hủy giải.

## 12. Danh sách nhanh toàn bộ endpoint
(Định dạng: số. METHOD path — Quyền — Mục)

1. POST /tournaments — Owner, Player — 2.1
2. GET /tournaments/my-tournaments — Owner, Player — 2.2
3. PUT /tournaments/{id} — BTC / Admin — 2.3
4. POST /tournaments/{id}/execute-random-pairing — BTC — 2.4
5. POST /tournaments/{id}/generate-bracket — BTC — 2.5
6. POST /tournaments/{id}/registration-decision — BTC — 2.6
7. DELETE /tournaments/{id}/participants/{participantId} — BTC — 2.7
8. PATCH /tournaments/{id}/cancel-tournament — Owner, Player, Admin — 2.8
9. DELETE /tournaments/{id} — BTC — 2.9
10. POST /tournaments/{id}/check-in — BTC — 2.10
11. GET /tournaments — Public — 3.1
12. GET /facilities/{facilityId}/tournaments — Public — 3.1
13. GET /tournaments/search — Public — 3.2
14. GET /tournaments/{id} — Public — 3.3
15. GET /tournaments/{id}/participants — Public — 3.4
16. POST /tournaments/{id}/join — Đăng nhập — 3.5
17. GET /tournaments/{id}/qr-ticket — Đăng nhập — 3.6
18. POST /tournaments/{id}/cancel — Đăng nhập — 3.7
19. GET /tournaments/my-registrations — Đăng nhập — 3.8
20. GET /tournaments/my-matches — Đăng nhập — 3.9
21. GET /tournaments/{id}/bracket — Public — 3.10
22. GET /tournaments/{id}/standings — Public — 3.11
23. POST /tournaments/{id}/invitations — BTC — 4.1
24. POST /tournaments/{id}/participants — BTC — 4.1
25. GET /tournaments/{id}/invitations — BTC — 4.2
26. DELETE /tournaments/invitations/{invitationId} — BTC — 4.3
27. GET /tournaments/my-invitations — Đăng nhập — 4.4
28. POST /tournaments/invitations/{invitationId}/respond — Đăng nhập — 4.5
29. POST /tournaments/{id}/court-blocks — Owner — 5.1
30. POST /tournaments/{id}/court-blocks/release — Owner — 5.2
31. GET /tournaments/{id}/court-schedule — Public — 5.3
32. POST /tournaments/{id}/auto-schedule — BTC — 5.4
33. POST /tournaments/{id}/staff — BTC — 6.1
34. GET /tournaments/{id}/staff — BTC / Admin — 6.2
35. PUT /tournaments/{id}/staff/{staffId} — BTC — 6.3
36. DELETE /tournaments/{id}/staff/{staffId} — BTC — 6.4
37. GET /matches/{matchId} — Public — 7.1
38. PUT /matches/{matchId}/score — BTC / nhân sự / Admin — 7.2
39. PUT /matches/{matchId}/officials — BTC — 7.3
40. PUT /matches/{matchId}/assign-court — BTC — 7.4
41. POST /reports (targetType = MATCH) — Đăng nhập — 8.1
42. POST /match-complaints/{id}/referee-note — Trọng tài của trận — 8.2
43. POST /match-complaints/{id}/decide — BTC — 8.3
44. POST /match-complaints/{id}/escalate — Người khiếu nại — 8.4
45. POST /reports/admin/{id}/resolve — Admin — 8.5
46. GET /admin/tournaments — Admin — 9.1
47. GET /admin/tournaments/statistics — Admin — 9.2
48. PATCH /admin/tournaments/{id}/lock — Admin — 9.3
49. PATCH /admin/tournaments/{id}/unlock — Admin — 9.3
50. PATCH /admin/tournaments/{id}/approve — Admin — 9.4
51. PATCH /admin/tournaments/{id}/reject — Admin — 9.4
52. PATCH /admin/tournaments/{id}/cancel — Admin — 9.5
53. GET /ratings/me — Đăng nhập — 10.1
54. GET /ratings/leaderboard — Public — 10.2
55. PATCH /owner/tournaments/{id}/approve — Owner (chủ cơ sở) — 2.11 (KHÔNG DÙNG trong luồng mới)
56. PATCH /owner/tournaments/{id}/reject — Owner (chủ cơ sở) — 2.11 (KHÔNG DÙNG trong luồng mới)
57. GET /tournaments/my-staff-matches — Đăng nhập — 6.5
58. GET /tournaments/{id}/match-complaints — BTC / Admin — 8.6
59. POST /match-complaints/{complaintId}/resolve — BTC / Admin — 8.7
60. Chủ sân báo "Tôi không có thỏa thuận này" — path CHƯA CHỐT (chờ BE) — Owner (chủ cơ sở) — 2.11
