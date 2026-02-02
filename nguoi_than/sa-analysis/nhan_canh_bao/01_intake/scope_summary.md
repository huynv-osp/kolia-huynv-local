# Scope Summary: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Analysis Name:** nhan_canh_bao  
> **Date:** 2026-02-02  
> **Parent Feature:** KOLIA-1517 (Kết nối Người thân)

---

## In Scope ✅

### Alert Types

| Alert Type | Trigger | Priority |
|------------|---------|:--------:|
| **HA Khẩn cấp** | Tâm thu <90/>180, Tâm trương <60/>120 | P0 |
| **HA Bất thường** | Chênh lệch >10mmHg so với TB 7 ngày | P1 |
| **SOS** | Patient nhấn nút SOS | P0 |
| **Sai liều** | Patient báo cáo "Sai liều" | P1 |
| **Bỏ lỡ thuốc** | 3 liều liên tiếp | P1 |
| **Bỏ lỡ đo HA** | 3 lần đo liên tiếp | P1 |
| **Tuân thủ kém** | <70% trong 24h | P1 |

### Delivery Channels

- ✅ Push Notification (FCM iOS/Android)
- ✅ In-App Modal Popup (Foreground)
- ✅ Silent Push (Badge Update)

### UI Components

- ✅ Alert Block trên Dashboard (max 5 cards, 24h)
- ✅ Lịch sử cảnh báo (filter, pagination)
- ✅ SOS Modal với nút "Gọi ngay"

### Features

- ✅ Debounce 5 phút cho cùng loại cảnh báo
- ✅ SOS bypass mọi settings (Priority 0)
- ✅ Mark all as read
- ✅ Deep link navigation

---

## Out of Scope ❌

- ❌ Tùy chỉnh ngưỡng cảnh báo riêng cho từng Caregiver
- ❌ Tính năng gọi điện tự động khi có cảnh báo
- ❌ Cảnh báo âm thanh đặc biệt (ringtone custom)
- ❌ Fallback ZNS → SMS (Phase 2)
- ❌ Heart Rate thresholds (Phase 2)

---

## Assumptions

1. Permission #2 tại Patient đã cấp cho Caregiver (Default: ON)
2. Caregiver có app đã cài đặt và đăng nhập
3. Patient đã thiết lập thông tin cá nhân (có SĐT)
4. Kết nối Người thân (US 1.1) đã được triển khai và hoạt động

---

## Constraints

1. Alert Delivery ≤ 5 giây từ khi event xảy ra
2. Badge Update ≤ 10 giây
3. History Load ≤ 1 giây cho 20 items
4. Lịch sử cảnh báo giữ 90 ngày
5. PII phải ẩn trên Lock Screen

---

## Initial Complexity Assessment

| Factor | Assessment | Notes |
|--------|:----------:|-------|
| **Services Affected** | 3-4 | user-service, api-gateway, schedule-service, Mobile App |
| **Database Changes** | Minor | 1-2 tables mới |
| **API Changes** | Extension | 4-6 endpoints mới |
| **UI Changes** | Major | 4 screens, complex navigation |
| **Integration Points** | 3-5 | FCM, Kafka, existing BP/Medication/SOS features |
| **Dependencies** | High | Phụ thuộc 3 SRS khác (BP, Medication, SOS) |

---

## Risk Highlights

| Risk | Impact | Probability |
|------|:------:|:-----------:|
| Real-time push delivery <5s | High | Medium |
| Complex trigger logic (multiple sources) | Medium | Medium |
| State sync across app states (foreground/background/killed) | Medium | Low |
| Permission #2 enforcement consistency | High | Low |

---

## Next Steps

➡️ Proceed to Phase 2: Context Loading

**Architecture Files to Load:**
- `ALIO_SERVICES_CATALOG.md`
- `Alio_database_create.sql`
- Existing `connection_service.proto`
- SRS dependencies (BP, Medication, SOS)
