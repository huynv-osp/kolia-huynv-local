# Feature Specification: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Version:** v1.5  
> **Date:** 2026-02-02  
> **Status:** ✅ Ready for Implementation  
> **SRS Source:** [srs-nhan-canh-bao_v1.5.md](../../../srs_input_documents/srs-nhan-canh-bao_v1.5.md)  
> **SA Analysis:** [nhan_canh_bao/](../../../sa-analysis/nhan_canh_bao/)

---

## 1. Feature Overview

### 1.1 Mục đích

Cho phép **Caregiver** nhận thông báo kịp thời khi **Patient** gặp các tình huống sức khỏe bất thường, bao gồm:
- Cảnh báo khẩn cấp SOS
- Cảnh báo huyết áp bất thường (cao/thấp hơn bình thường)
- Cảnh báo thuốc (sai liều, bỏ lỡ)
- Cảnh báo tuân thủ kém

### 1.2 Scope

| Trong Scope ✅ | Ngoài Scope ❌ |
|----------------|----------------|
| 7 loại cảnh báo (SOS, HA, Thuốc, Tuân thủ) | Tùy chỉnh ngưỡng cảnh báo |
| Push notification + In-app modal | Gọi điện tự động |
| Lịch sử cảnh báo (90 ngày) | Ringtone tùy chỉnh |
| Filter theo loại, thời gian, Patient | |

---

## 2. Alert Types (7 Total)

| ID | Type | Category | Priority | Trigger | Mode |
|:--:|------|:--------:|:--------:|---------|:----:|
| 1 | 🚨 SOS | SOS | P0 | Patient kích hoạt SOS | ⚡ Real-time |
| 2 | 💛 HA Bất thường (Cao) | HA | P1 | Delta >10mmHg so với TB 7 ngày (cao hơn) | ⚡ Real-time |
| 3 | 💛 HA Bất thường (Thấp) | HA | P1 | Delta >10mmHg so với TB 7 ngày (thấp hơn) | ⚡ Real-time |
| 4 | 💊 Sai liều | MEDICATION | P1 | Patient confirm "Sai liều" | ⚡ Real-time |
| 5 | 💊 Bỏ lỡ thuốc | MEDICATION | P2 | 3 liều liên tiếp | 📅 Batch 21:00 |
| 6 | 📊 Bỏ lỡ đo HA | COMPLIANCE | P2 | 3 lần liên tiếp | 📅 Batch 21:00 |
| 7 | 📉 Tuân thủ kém | COMPLIANCE | P2 | <70% trong 24h | 📅 Batch 21:00 |

> **v1.5 Changes:** Loại bỏ ngưỡng cứng (hard thresholds). HA chỉ dùng delta so với TB 7 ngày.

---

## 3. Key Business Rules

| BR-ID | Rule | Priority |
|-------|------|:--------:|
| BR-ALT-001 | Chỉ gửi khi Permission #2 = ON | P0 |
| BR-ALT-002 | HA: Chênh lệch >10mmHg so với TB 7 ngày (Ref: BR-HA-017) | P1 |
| BR-ALT-004 | SOS bypass mọi settings | P0 |
| BR-ALT-005 | Debounce 5 phút (trừ SOS) | P1 |
| BR-ALT-009 | Retention 90 ngày | P2 |
| BR-ALT-013 | Ẩn PII trên lock screen | P0 |
| BR-ALT-019 | GỘP medication notification (nhiều thuốc → 1 notification) | P1 |
| BR-ALT-SOS-001 | Button "Xem vị trí" chỉ hiển thị khi có GPS hợp lệ | P1 |

---

## 4. UI Screens

| Screen ID | Name | Description |
|-----------|------|-------------|
| SCR-ALT-01 | Alert Block (Dashboard) | Max 5 alerts trong 24h, priority sort |
| SCR-ALT-02 | Lịch sử cảnh báo | Full list với filter, pagination |
| SCR-ALT-03 | Modal Popup | In-app alert khi foreground |
| SCR-ALT-04 | SOS Modal | Chi tiết SOS với Gọi ngay + Vị trí |

### 4.1 Alert Card Format

```
┌───────────────────────────────────────────────────────┐
│ [Icon] [Tên] - [Nội dung chính]              [HH:mm] │
└───────────────────────────────────────────────────────┘
```

**Examples:**
- `🚨 Mẹ cần hỗ trợ KHẨN CẤP!` `16:45`
- `💛 Mẹ - HA 145/95 (Cao hơn bình thường)` `16:45`
- `💊 Mẹ - Amlodipine uống sai liều` `16:45`

---

## 5. Processing Modes

### 5.1 Real-time (≤5s)

| Alert | Trigger Source | Flow |
|-------|----------------|------|
| SOS | user-service | SOS → Kafka → schedule-service → Push |
| HA Bất thường | user-service | BP save → delta calculation → Kafka → Push |
| Sai liều | user-service | Drug report confirm → Kafka → Push |

### 5.2 Batch (21:00 Daily)

| Alert | Evaluation |
|-------|------------|
| Bỏ lỡ 3 liều thuốc | Celery Beat query |
| Bỏ lỡ 3 lần đo HA | Celery Beat query |
| Tuân thủ <70% | 24h window calculation |

---

## 6. Technical Summary

| Metric | Value |
|--------|-------|
| **Services Affected** | 4 |
| **New Tables** | 2 (caregiver_alerts, caregiver_alert_types) |
| **Estimated Effort** | 132 hours |
| **Breaking Changes** | None |
| **Feature Flags** | Recommended per alert type |

---

## 7. Dependencies

| Feature | Status | Required For |
|---------|:------:|--------------|
| Kết nối Người thân | ✅ Deployed | Permission #2 |
| Đo Huyết áp | ✅ Deployed | BP triggers |
| Uống thuốc MVP0.3 | ✅ Deployed | Medication triggers |
| SOS | ⏳ TODO | SOS triggers |

---

## 8. References

- [SA Assessment Report](../../../sa-analysis/nhan_canh_bao/08_report/sa_assessment_report.md)
- [API Mapping](../../../sa-analysis/nhan_canh_bao/04_mapping/api_mapping.md)
- [Service Mapping](../../../sa-analysis/nhan_canh_bao/04_mapping/service_mapping.md)
- [Database Schema](../../../sa-analysis/nhan_canh_bao/04_mapping/database_mapping.md)
