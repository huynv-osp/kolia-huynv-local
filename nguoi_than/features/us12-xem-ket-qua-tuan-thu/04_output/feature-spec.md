# Feature Specification: US 1.2 - Xem Kết Quả Tuân Thủ

> **Feature Analysis Phase 8: Final Output**  
> **Version:** 1.0  
> **Date:** 2026-02-05

---

## Executive Summary

| Attribute | Value |
|-----------|-------|
| **Feature** | Caregiver Compliance Tracking View |
| **Type** | New Feature |
| **Priority** | P0 (Core caregiver feature) |
| **Complexity** | Complex (26.5/50) |
| **Effort** | 76 hours (~2 weeks) |
| **Impact** | 🟢 LOW (Clone-based isolation) |

---

## Feature Description

**Người thân (Caregiver)** xem kết quả tuân thủ của **Người bệnh (Patient)** bao gồm:

1. **Dashboard** với 3 khối VIEW:
   - **Huyết áp (HA):** Tóm tắt 24h + AI insight
   - **Thuốc:** Tình hình uống thuốc hôm nay
   - **Tái khám:** Lịch khám sắp tới

2. **Drill-down screens** với Context Header hiển thị thông tin Patient

3. **Permission #4 check:** Server-side enforcement

---

## Functional Requirements

### FR-01: Dashboard 3 Blocks

```
┌─────────────────────────────────────┐
│  SCR-CG-DASH (Dashboard)            │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 🫀 HUYẾT ÁP                  [>]││
│  │ 145/95 mmHg - Cao             ││
│  │ "Nghỉ ngơi, đo lại sau 15p"   ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ 💊 THUỐC                     [>]││
│  │ 4/6 đã uống                    ││
│  │ Còn 2 thuốc chưa uống          ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ 🏥 TÁI KHÁM                  [>]││
│  │ Tim mạch - Dr. Nguyễn          ││
│  │ 10/02/2026, 09:00              ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

### FR-02: Permission #4 Check

```
Permission OFF → PermissionDeniedOverlay
Permission ON  → Show Dashboard data
```

### FR-03: Context Header

```
┌─────────────────────────────────────┐
│ [<] LỊCH SỬ HUYẾT ÁP               │
├─────────────────────────────────────┤
│ [Avatar] Bố - Nguyễn Văn A          │
│          {Mối quan hệ} - {Họ tên}   │
└─────────────────────────────────────┘
```

---

## Security Requirements

| ID | Requirement | Implementation |
|----|-------------|----------------|
| SEC-CG-001 | Permission #4 server check | `PermissionService.hasPermission()` |
| SEC-CG-003 | Context isolation | `patientId` filter in all queries |
| BR-CG-013 | Audit logging | Log với `caregiver_id` |

---

## API Endpoints

| # | Method | Endpoint | Purpose |
|:-:|--------|----------|---------|
| 1 | GET | `/v1/patients/:id/daily-summary` | Dashboard data |
| 2 | GET | `/v1/patients/:id/blood-pressure` | BP history |
| 3 | GET | `/v1/patients/:id/medications` | Med schedule |
| 4 | GET | `/v1/patients/:id/checkups` | Checkup list |

---

## Mobile Screens

| Screen | Clone From | Key Modifications |
|--------|------------|-------------------|
| CaregiverComplianceDashboardScreen | HeartbeatBulletinScreen | Remove actions, add Permission check |
| CaregiverBPHistoryScreen | BloodPressureMissionScreen | View-only, add Context Header |
| CaregiverMedicationScheduleScreen | MedicationMissionScreen | View-only, add Context Header |
| CaregiverCheckupListScreen | ReExamScheduleScreen | View-only, add Context Header |

---

## Implementation Timeline

| Week | Phase | Deliverables |
|:----:|-------|--------------|
| 1 | Backend | Proto, Service, Handler, DTOs, Routes |
| 2 | Frontend | 4 Screens, Components, Navigation, Testing |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Dashboard load time | < 1s |
| Permission check | < 100ms |
| Unit test coverage | > 80% |
| Zero breaking changes | ✅ |

---

## References

- [SRS v2.5](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs-xem-ket-qua-tuan-thu.md)
- [Prototype v2.2](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/prototype/prototype-xem-ket-qua-tuan-thu.html)
- [SA Analysis](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/sa-analysis/us12-xem-ket-qua-tuan-thu/)
