# Functional Requirements Extraction: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 3 - Functional Requirements Extraction  
> **Date:** 2026-02-02  
> **Source:** SRS-Nhận-Cảnh-Báo_v1.5  
> **Revision:** v1.5  
> **Applies Rule:** SA-002 (Service-Level Impact Detailing)

---

## Summary

| Category | Count |
|----------|:-----:|
| User Stories | 6 |
| Gherkin Scenarios | 17 |
| Business Rules | 18 |
| UI Screens | 4 |

---

## FR-001: Nhận cảnh báo HA Bất thường

### User Story
> Là một **Caregiver**, tôi muốn **nhận cảnh báo khi Patient có chỉ số HA thay đổi bất thường**, để **theo dõi và hỗ trợ kịp thời**.

### Trigger Logic (BR-HA-017 từ SRS Đo HA)
- So sánh chỉ số đo hiện tại với TB 7 ngày gần nhất
- Chênh lệch (cao hơn HOẶC thấp hơn) **>10mmHg** (Tâm thu hoặc Tâm trương)
- → Trigger alert

### Acceptance Criteria

| ID | Scenario | Trigger | Action |
|----|----------|---------|--------|
| 2.1.1 | HA Bất thường - Push | \|systolic_new - avg_7d\| > 10mmHg | Push notification + Badge +1 + Save history |
| 2.1.2 | HA Bất thường - In-App | App foreground + alert | Modal popup blocking |

### Technical Requirements
- Push gửi trong ≤5 giây
- Badge update bằng Silent Push
- Deeplink: ⏳ Pending US 1.1 (navigate to Dashboard hiện tại)

---

## FR-002: Nhận cảnh báo SOS 🚧

> **⏳ TODO:** Phần SOS đang phát triển trên nhánh riêng. Sẽ update sau khi merge.

### User Story
> Là một **Caregiver**, tôi muốn **nhận cảnh báo ngay lập tức khi Patient nhấn SOS**, để **có thể liên hệ hoặc hỗ trợ khẩn cấp**.

### Acceptance Criteria

| ID | Scenario | Trigger | Action |
|----|----------|---------|--------|
| 2.2.1 | SOS - Push | SOS event | Push to ALL caregivers, bypass DND |
| 2.2.2 | SOS - Popup Chi Tiết | SOS event HOẶC tap card | SOS Modal = màn chi tiết |
| 2.2.3 | Gọi ngay | Tap button | Open native dialer with patient phone |

### SOS Modal Elements (= Chi tiết SOS)
- 🚨 Icon + Title "⚠️ SOS - TÌNH HUỐNG KHẨN CẤP"
- Content: "[Danh xưng] vừa kích hoạt SOS!"
- Time: "Lúc: {HH:mm}"
- **📍 Xem vị trí**: Conditional (BR-ALT-SOS-001)
- Button Primary: "📞 Gọi ngay"
- Button Text: "Đóng"

### Technical Requirements
- Priority: Critical (bypass DND)
- NO debounce
- NOT affected by "Tạm dừng thông báo" toggle
- Deeplink: `kolia://dashboard?patient_id={id}&show_sos_popup=true`

---

## FR-003: Nhận cảnh báo Thuốc

### User Story
> Là một **Caregiver**, tôi muốn **biết khi Patient uống thuốc không đúng cách**, để **nhắc nhở hoặc hỗ trợ**.

### Acceptance Criteria

| ID | Scenario | Trigger | Action |
|----|----------|---------|--------|
| 2.3.1 | Sai liều | Patient confirms "Sai liều" | Alert immediately |
| 2.3.2 | Bỏ lỡ thuốc liên tiếp | Consecutive misses detected | Alert in 21:00 batch |

### Technical Requirements (BR-ALT-019)
- **GỘP notification thuốc**: Nhiều thuốc → 1 notification duy nhất
- Format thống nhất, không phân biệt 1/nhiều thuốc
- Deeplink: `kolia://patient/{patient_id}/medication-report`

---

## FR-004: Nhận cảnh báo Tuân thủ kém

### User Story
> Là một **Caregiver**, tôi muốn **biết khi Patient có tỷ lệ tuân thủ thấp**, để **động viên và hỗ trợ**.

### Acceptance Criteria

| ID | Scenario | Trigger | Action |
|----|----------|---------|--------|
| 2.4.1 | Tuân thủ thuốc <70% | 24h evaluation | 1 alert/day at 21:00 |
| 2.4.2 | Bỏ lỡ 3 lần đo HA | 3 consecutive misses | Alert in 21:00 batch |

### Technical Requirements
- Batch processing at 21:00
- Window: 24h rolling
- Max 1 alert per type per day

---

## FR-005: Lịch sử Cảnh báo

### User Story
> Là một **Caregiver**, tôi muốn **xem lại các cảnh báo đã nhận**, để **theo dõi tình trạng sức khỏe Patient theo thời gian**.

### Acceptance Criteria

| ID | Scenario | Action |
|----|----------|--------|
| 2.5.1 | Mở màn hình | Navigate to SCR-ALT-02 |
| 2.5.2 | Filter theo loại | Realtime filter (no Apply button) |
| 2.5.3 | Mark all as read | Reset badge to 0 |
| 2.5.4 | Pull-to-refresh offline | Toast "Không thể làm mới" |
| 2.5.5 | Alert từ unfollowed patient | Display with "[Đã ngắt kết nối]" badge, no navigation |
| 2.5.6 | Empty state | Show Kolia mascot + message |

### Technical Requirements
- Pagination: 20 items/page
- Retention: 90 days
- Sort: Priority DESC → Time DESC

---

## Business Rules Summary

| BR-ID | Category | Rule | Priority |
|-------|----------|------|:--------:|
| BR-ALT-001 | Auth | Permission #2 = ON required | P0 |
| BR-ALT-002 | Threshold | HA bất thường: >10mmHg (CAO/THẤP) so với TB 7 ngày. Display: \"HA Cao/Thấp bất thường\" (Ref: BR-HA-017) | P1 |
| BR-ALT-004 | Priority | SOS = Priority 0, bypass all | P0 |
| BR-ALT-005 | Rate Limit | 5-min debounce (except SOS) | P1 |
| BR-ALT-006 | Schedule | Medication compliance at 21:00 if <70% | P1 |
| BR-ALT-006b | Schedule | BP compliance at 21:00 if <70% | P1 |
| BR-ALT-007 | Pattern | 3 consecutive missed medications - **GỘP** (BR-ALT-019) | P1 |
| BR-ALT-008 | Trigger | Wrong dose on "Hoàn tất" | P1 |
| BR-ALT-009 | Retention | 90-day history | P2 |
| BR-ALT-010 | Settings | "Tạm dừng" toggle, SOS exempt | P1 |
| BR-ALT-011 | Timezone | Notifications in patient timezone | P1 |
| BR-ALT-013 | Security | PII hidden on lock screen | P0 |
| BR-ALT-014 | Calc | Compliance window: 24h | P1 |
| BR-ALT-015 | Pattern | 3 consecutive missed BP | P1 |
| BR-ALT-016 | Technical | Badge via Silent Push | P2 |
| BR-ALT-017 | Prerequisite | Only alert if patient has BP mission | P0 |
| BR-ALT-018 | Multiple | Multiple wrong dose → **GỘP** (BR-ALT-019) | P1 |
| BR-ALT-019 | Consolidation | **GỘP notification thuốc**: 1 notification duy nhất | P1 |
| BR-ALT-SOS-001 | Display | "📍 Xem vị trí" chỉ khi GPS valid (Ref: SRS SOS) | P1 |

---

## UI Screens

| Screen ID | Name | Complexity |
|-----------|------|:----------:|
| SCR-ALT-01 | Alert Block (Dashboard) | Medium |
| SCR-ALT-02 | Lịch sử cảnh báo | Medium |
| SCR-ALT-03 | Modal Popup (Foreground) | Low |
| SCR-ALT-04 | SOS Modal (= Chi tiết SOS) | Medium |

---

## Edge Cases

| EC-ID | Situation | Decision |
|-------|-----------|----------|
| EC-01 | Different timezone | Send per patient timezone |
| EC-07 | Popup during interaction | Show immediately (health priority) |
| EC-08 | Multiple alerts same time | Priority queue, 1 popup + badge |
| ~~EC-11~~ | ~~2 BP rules trigger~~ | ~~Không còn áp dụng - chỉ còn 1 rule BR-ALT-002~~ |
| EC-15 | Alert from unfollowed | Show + "[Đã ngắt kết nối]" |
| EC-18 | Mark all as read | Header button |
