# Requirement Analysis: US 1.2 - Xem Kết Quả Tuân Thủ

> **Feature Analysis Phase 1: Intake**  
> **Date:** 2026-02-05  
> **Input:** SRS v2.5 + SA Analysis

---

## Feature Classification (FA-001)

| Attribute | Value |
|-----------|-------|
| **Name** | US 1.2 - Xem Kết Quả Tuân Thủ (Caregiver Compliance View) |
| **Type** | New Feature |
| **Complexity** | Complex (21+ score) |
| **Priority** | P0 (Core caregiver feature) |

---

## Architecture Decision Record (ADR)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary service | user-service | Owns patient health data (BP, meds, checkups) |
| API Gateway | api-gateway-service | REST endpoints → gRPC forwarding |
| Communication | gRPC | Consistent with existing Caregiver Alert pattern |
| Data storage | Existing tables | `blood_pressure_records`, `user_medication_feedback`, `re_examination_event` |
| Mobile strategy | Clone-based isolation | 0% impact on existing user flows |
| AI integration | agents-service reuse | Existing `/bp-summary` endpoint (no changes) |

---

## Scope Boundaries

### ✅ IN SCOPE

| Category | Items |
|----------|-------|
| **Screens** | SCR-CG-DASH, SCR-CG-HA-LIST, SCR-CG-HA-DETAIL, SCR-CG-MED-SCHEDULE, SCR-CG-CHECKUP-LIST, SCR-CG-CHECKUP-DETAIL |
| **Business Rules** | BR-CG-001 → BR-CG-020 (20 rules) |
| **Security** | SEC-CG-001 (Permission #4 check), SEC-CG-003 (Context isolation) |
| **APIs** | 4 new endpoints với patientId parameter |

### ❌ OUT OF SCOPE

| Category | Items | Reference |
|----------|-------|-----------|
| Task setup | Permission #3 | US 2.1 |
| Proxy execution | Caregiver thực hiện thay | US 2.2 |
| Long-term trends | BP chart (Permission #1) | US 1.1 (existing) |
| agents-service changes | No modifications needed | Reuse existing |

---

## Requirements Summary

### Functional Requirements (from SRS v2.5)

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-01 | Dashboard với 3 khối VIEW (HA, Thuốc, Tái khám) | P0 |
| FR-02 | Permission #4 check at server-side | P0 |
| FR-03 | Drill-down screens với Context Header | P0 |
| FR-04 | {Danh xưng} → {Mối quan hệ} override | P0 |
| FR-05 | Permission Denied Overlay khi #4 OFF | P0 |
| FR-06 | Checkup status logic (5-day retention) | P1 |
| FR-07 | CG VIEW header icons hidden | P1 |
| FR-08 | Audit log với caregiver_id | P2 |

### Non-Functional Requirements

| NFR | Requirement | Target |
|-----|-------------|--------|
| NFR-01 | Dashboard load time | < 1s (cached) |
| NFR-02 | Block data fetch | < 2s per block |
| NFR-03 | Navigation response | < 0.5s |
| NFR-04 | Permission check latency | < 100ms |

---

## Dependencies

| Dependency | Status | Impact |
|------------|:------:|--------|
| US 1.1 Nhận Cảnh Báo | ✅ Done | Permission service, CaregiverAlertHandler pattern |
| Kết nối Người thân | ✅ Done | `connections`, `connection_permissions` tables |
| Bản tin 24H | ✅ Done | BR-010/011/012 logic |
| Profile Selector | ✅ Done | Patient selection UI |

---

## Source Documents

| Document | Path | Version |
|----------|------|:-------:|
| SRS | `docs/nguoi_than/srs_input_documents/srs-xem-ket-qua-tuan-thu.md` | v2.5 |
| Prototype | `docs/nguoi_than/srs_input_documents/prototype/prototype-xem-ket-qua-tuan-thu.html` | v2.2 |
| SA Analysis | `docs/sa-analysis/us12-xem-ket-qua-tuan-thu/` | Complete |

---

## Phase 1 Checkpoint

✅ **PHASE 1 COMPLETE** → Proceed to Phase 2 (Context Mapping)
