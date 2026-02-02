# Requirement Analysis: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 1 - Requirement Intake & Classification  
> **Date:** 2026-02-02  
> **Source:** [SRS v1.5](../../../srs_input_documents/srs-nhan-canh-bao_v1.5.md)

---

## 1. Feature Classification

| Attribute | Value |
|-----------|-------|
| **Name** | US 1.2 - Nhận Cảnh Báo Bất Thường |
| **Type** | New Feature |
| **Complexity** | Complex |
| **Epic** | KOLIA-1517 (Kết nối Người thân) |

---

## 2. User Story

**Là một Caregiver**, tôi muốn **nhận thông báo kịp thời khi Patient gặp tình huống sức khỏe bất thường**, để **có thể hỗ trợ và theo dõi sức khỏe Patient**.

---

## 3. Scope Summary

### ✅ In Scope

| Category | Items |
|----------|-------|
| **Cảnh báo HA** | Bất thường (delta >10mmHg so với TB 7 ngày) |
| **Cảnh báo SOS** | Khẩn cấp Priority 0 |
| **Cảnh báo Thuốc** | Sai liều, Bỏ lỡ 3 liều liên tiếp |
| **Cảnh báo Tuân thủ** | <70% thuốc, <70% đo HA, 3 lần đo liên tiếp |
| **UI Screens** | Alert Block, Lịch sử, Modal Popup, SOS Modal |
| **Push Notification** | FCM (iOS/Android) |

### ❌ Out of Scope

- Tùy chỉnh ngưỡng cảnh báo riêng cho Caregiver
- Gọi điện tự động khi có cảnh báo
- Cảnh báo âm thanh đặc biệt (ringtone custom)

---

## 4. Business Rules Extraction

| BR-ID | Category | Description | Priority |
|-------|----------|-------------|:--------:|
| BR-ALT-001 | Authorization | Permission #2 = ON | P0 |
| BR-ALT-002 | Threshold | Delta >10mmHg vs TB 7 ngày (Ref: BR-HA-017) | P1 |
| BR-ALT-004 | Priority | SOS bypass mọi settings | P0 |
| BR-ALT-005 | Rate Limit | Debounce 5 phút (trừ SOS) | P1 |
| BR-ALT-009 | Retention | 90 ngày | P2 |
| BR-ALT-013 | Security | Ẩn PII trên lock screen | P0 |
| BR-ALT-019 | Consolidation | GỘP medication notification | P1 |
| BR-ALT-SOS-001 | Display | Button vị trí conditional (GPS valid) | P1 |

**Total:** 18 BR-ALT rules

---

## 5. UI Screens Identified

| Screen ID | Name | Complexity |
|-----------|------|:----------:|
| SCR-ALT-01 | Alert Block (Dashboard) | Medium |
| SCR-ALT-02 | Lịch sử Cảnh báo | Medium |
| SCR-ALT-03 | Modal Popup | Low |
| SCR-ALT-04 | SOS Modal | Medium |

---

## 6. Dependencies

| Dependency | Status | Blocker? |
|------------|:------:|:--------:|
| US 1.1 Kết nối Người thân | ✅ Deployed | No |
| Đo Huyết áp | ✅ Deployed | No |
| Uống thuốc MVP0.3 | ✅ Deployed | No |
| SOS | ⏳ TODO | No |

---

## 7. Assumptions

1. Permission #2 tại Patient đã cấp cho Caregiver (Default: ON)
2. Caregiver có app đã cài đặt và đăng nhập
3. Patient đã thiết lập thông tin cá nhân (có SĐT)

---

## Next Phase

➡️ [context-mapping.md](./context-mapping.md)
