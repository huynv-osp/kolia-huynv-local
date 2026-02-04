# Feature Specification: US 1.3 - Gửi Lời Động Viên

> **Version:** v1.0  
> **Date:** 2026-02-04  
> **Status:** ✅ Ready for Implementation  
> **SRS Source:** [srs_gui_loi_dong_vien.md](../../srs_input_documents/srs_gui_loi_dong_vien.md)  
> **SA Analysis:** [gui_loi_dong_vien/](../../sa-analysis/gui_loi_dong_vien/)

---

## 1. Feature Overview

### 1.1 Mục đích

Cho phép **Caregiver** gửi lời nhắn động viên một chiều đến **Patient** để:
- Khích lệ tinh thần và duy trì động lực tuân thủ điều trị
- Nhắc nhở nhẹ nhàng về lịch uống thuốc, đo huyết áp
- Tạo kết nối tình cảm gia đình qua ứng dụng

### 1.2 Scope

| Trong Scope ✅ | Ngoài Scope ❌ |
|----------------|----------------|
| Gửi tin nhắn (Caregiver → Patient) | AI Suggestions (⏸️ DEFERRED) |
| Nhận tin nhắn qua modal 24h | Patient reply |
| Push notification real-time | Message edit/delete |
| Quota 10 tin/ngày/Patient | Full chat history |
| Permission #6 check | Voice message |

---

## 2. API Endpoints (4 APIs)

| Method | Endpoint | Actor | Purpose |
|:------:|----------|:-----:|---------|
| POST | `/api/v1/encouragements` | Caregiver | Gửi lời động viên |
| GET | `/api/v1/encouragements` | Patient | Lấy list 24h |
| POST | `/api/v1/encouragements/mark-read` | Patient | Batch đánh dấu đọc |
| GET | `/api/v1/encouragements/quota` | Caregiver | Check quota còn lại |

---

## 3. Business Rules

| BR-ID | Rule | Priority | Enforcement |
|:-----:|------|:--------:|-------------|
| BR-001 | Max 10 tin/ngày/Patient | HIGH | Server-side quota |
| BR-002 | Max 150 Unicode chars | HIGH | DB constraint |
| BR-003 | Permission #6 = ON | CRITICAL | Real-time check |
| BR-004 | Không kiểm duyệt nội dung | HIGH | Caregiver chịu TN |

---

## 4. Database

### New Table: `encouragement_messages`

| Column | Type | Purpose |
|--------|------|---------|
| encouragement_id | UUID | PK |
| sender_id, patient_id | UUID | FK → users |
| contact_id | UUID | FK → user_emergency_contacts |
| content | VARCHAR(150) | Message (BR-002) |
| sender_name | VARCHAR(100) | Caregiver's display name |
| relationship_code | VARCHAR(30) | FK → relationships (e.g., "daughter") |
| relationship_display | VARCHAR(100) | **Patient's perspective** - how Patient calls Caregiver |
| is_read | BOOLEAN | Read status |
| sent_at | TIMESTAMPTZ | Timestamp |

> ⚠️ **Perspective Standard v2.23:** `relationship_display` là danh xưng mà **Patient gọi Caregiver**.
> Ví dụ: Patient = Mẹ, Caregiver = Con gái → `relationship_display = "Con gái"`

---

## 5. UI Screens

| Screen ID | Name | Actor | Description |
|-----------|------|:-----:|-------------|
| SCR-ENG-01 | EncouragementWidget | Caregiver | Compose & send |
| SCR-ENG-02 | EncouragementModal | Patient | View 24h messages |

### Component Specs

| ID | Component | Constraints |
|:--:|-----------|-------------|
| ENG-02 | TextInput | Min 3 lines, max 150 chars |
| ENG-03 | CharCounter | Red (#FF4D4F) when ≥140 |
| ENG-04 | SendButton | Disabled if empty |

---

## 6. Technical Summary

| Metric | Value |
|--------|:-----:|
| **Services Affected** | 4 |
| **New Tables** | 1 |
| **Estimated Effort** | 54 hours |
| **Breaking Changes** | None |
| **Feature Flags** | Recommended |

---

## 7. Dependencies

| Feature | Status | Required For |
|---------|:------:|--------------|
| Kết nối Người thân | ✅ Deployed | Permission #6 |
| Push Infrastructure | ✅ Deployed | FCM delivery |

---

## 8. References

- [SA Executive Summary](../../sa-analysis/gui_loi_dong_vien/08_report/executive_summary.md)
- [API Mapping](../../sa-analysis/gui_loi_dong_vien/04_mapping/api_mapping.md)
- [Service Mapping](../../sa-analysis/gui_loi_dong_vien/04_mapping/service_mapping.md)
- [Database Mapping](../../sa-analysis/gui_loi_dong_vien/04_mapping/database_mapping.md)
