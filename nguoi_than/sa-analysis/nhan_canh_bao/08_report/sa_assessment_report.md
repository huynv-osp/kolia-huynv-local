# SA Assessment Report: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 8 - Documentation & Report  
> **Version:** 1.0  
> **Date:** 2026-02-02  
> **Author:** Solution Architect  
> **Status:** ✅ ANALYSIS COMPLETE

---

## Executive Summary

US 1.2 "Nhận Cảnh Báo Bất Thường" enables caregivers to receive real-time health alerts about their connected patients. This feature is **FEASIBLE** and can be implemented within the existing ALIO architecture with moderate complexity.

| Metric | Value |
|--------|-------|
| **Feasibility Score** | 82/100 ✅ FEASIBLE |
| **Impact Level** | 🟡 MEDIUM-HIGH |
| **Effort Estimate** | 136 hours (~17 man-days) |
| **Services Affected** | 5 |
| **New Tables** | 2 |
| **Breaking Changes** | None |

---

## Quick Reference

| Document | Path |
|----------|------|
| SRS Input | [srs-nhan-canh-bao_v1.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs-nhan-canh-bao_v1.md) |
| Scope Summary | [scope_summary.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/nhan_canh_bao/01_intake/scope_summary.md) |
| Architecture | [architecture_snapshot.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/nhan_canh_bao/02_context/architecture_snapshot.md) |
| Database Schema | [database_mapping.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/nhan_canh_bao/04_mapping/database_mapping.md) |
| API Spec | [api_mapping.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/nhan_canh_bao/04_mapping/api_mapping.md) |
| Feasibility | [feasibility_report.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/nhan_canh_bao/05_feasibility/feasibility_report.md) |
| Impact | [impact_analysis.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/nhan_canh_bao/06_impact/impact_analysis.md) |
| Risks | [risk_register.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/nhan_canh_bao/07_risks/risk_register.md) |

---

## Feature Overview

### Alert Types (8 total)

| ID | Type | Priority | Trigger |
|:--:|------|:--------:|---------|
| 1 | 🚨 SOS Emergency | 0 (Critical) | Patient activates SOS |
| 2 | ⚠️ BP Critical | 1 (High) | Systolic <90/>180, Diastolic <60/>120 |
| 3 | 💛 BP Abnormal | 2 (Medium) | >10mmHg from 7-day average |
| 4 | 💊 Wrong Dose | 2 (Medium) | Patient confirms wrong dose |
| 5 | 💊 Missed Medication | 3 (Low) | 3 consecutive missed doses |
| 6 | 📊 Missed BP | 3 (Low) | 3 consecutive missed measurements |
| 7 | 📉 Low Med Compliance | 3 (Low) | <70% in 24h window |
| 8 | 📊 Low BP Compliance | 3 (Low) | <70% in 24h window |

### Key Business Rules

- **BR-ALT-001:** Permission #2 must be enabled
- **BR-ALT-004:** SOS bypasses all settings (DND, "Tạm dừng")
- **BR-ALT-005:** 5-minute debounce (except SOS)
- **BR-ALT-009:** 90-day retention
- **BR-ALT-013:** PII hidden on lock screen

---

## Architecture

```
┌─────────────────┐       ┌────────────────┐       ┌─────────────────┐
│   Mobile App    │◄─────►│  API Gateway   │◄─────►│  user-service   │
│  (Alert UI)     │ REST  │  (Endpoints)   │ gRPC  │ (Alert + Delta) │
└────────┬────────┘       └────────────────┘       └────────┬────────┘
         │                                                   │
         │ FCM Push                                         │ Kafka
         │                                                   │
┌────────▼────────┐       ┌────────────────┐       ┌────────▼────────┐
│   FCM Service   │◄──────│schedule-service│◄──────│  topic-alert-   │
│                 │       │ (Trigger/Push) │       │    triggers     │
└─────────────────┘       └────────────────┘       └─────────────────┘
```

### Data Flow

1. **Trigger:** Event source (BP, Medication, SOS) → Kafka
2. **Evaluate:** schedule-service evaluates thresholds + debounce
3. **Dispatch:** FCM push to all eligible caregivers
4. **Store:** user-service persists alert record
5. **Display:** Mobile shows modal (foreground) or updates badge

---

## Service Mapping & Effort

| Service | Impact | Effort (h) | Key Deliverables |
|---------|:------:|:----------:|------------------|
| schedule-service | 🔴 HIGH | 40 | Trigger consumer, evaluator, push dispatcher |
| Mobile App | 🔴 HIGH | 48 | 4 screens, push handling, navigation |
| user-service | 🟡 MEDIUM | 36 | Alert entities, gRPC service, BP delta calculation, Kafka producer |
| api-gateway | 🟡 MEDIUM | 12 | REST endpoints, gRPC client |
| **TOTAL** | | **132** | |

---

## Database Changes

### New Tables

```sql
-- 1. Alert types lookup
CREATE TABLE caregiver_alert_types (
    type_id SMALLINT PRIMARY KEY,
    type_code VARCHAR(30) UNIQUE,
    name_vi VARCHAR(100),
    default_priority SMALLINT
);

-- 2. Main alerts table
CREATE TABLE caregiver_alerts (
    alert_id UUID PRIMARY KEY,
    caregiver_id UUID REFERENCES users,
    patient_id UUID REFERENCES users,
    alert_type_id SMALLINT REFERENCES caregiver_alert_types,
    priority SMALLINT,  -- 0=SOS, 1=Critical, 2=High, 3=Medium
    title VARCHAR(150),
    body TEXT,
    status SMALLINT DEFAULT 0,  -- 0=unread, 1=read
    push_status SMALLINT DEFAULT 0,
    source_type VARCHAR(30),
    source_id BIGINT,
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ  -- 90 days
);
```

### Key Indexes

- Unread alerts by caregiver (for badge)
- Priority + time (for history sort)
- Debounce (prevent duplicates)
- Push pending (for retry)

---

## Risk Summary

| Risk ID | Description | Level | Mitigation |
|---------|-------------|:-----:|------------|
| RISK-001 | Push SLA ≤5s breach | 🔴 HIGH | High-priority FCM, latency monitoring |
| RISK-002 | Debounce state loss | 🔴 HIGH | Redis persistence, DB constraint backup |
| RISK-003 | 7-day avg performance | 🟡 MEDIUM | Redis cache, incremental update |
| RISK-004 | Event ordering | 🟡 MEDIUM | Include all data in event payload |
| RISK-005 | Permission race | 🟡 MEDIUM | Re-check at dispatch time |
| RISK-006 | Badge desync | 🟡 MEDIUM | Sync on app launch |

---

## Dependencies

### Prerequisite Features

| Feature | Status | Blocker? |
|---------|:------:|:--------:|
| US 1.1 Kết nối Người thân | 🟡 In Progress | Yes (Permission #2) |
| Đo Huyết áp | ✅ Deployed | No |
| Uống thuốc MVP0.3 | ✅ Deployed | No |
| SOS | ✅ Deployed | No |

### Infrastructure

| Component | Status | Notes |
|-----------|:------:|-------|
| FCM | ✅ Ready | Medication reminders use it |
| Kafka | ✅ Ready | Connection feature uses it |
| Redis | ✅ Ready | Debounce cache |

---

## Recommendations

### Phased Implementation

**Phase 1 (MVP - Sprint 1-2):**
- ✅ SOS alerts (critical)
- ✅ BP Critical alerts
- ✅ Basic push notification
- ✅ Alert history screen
- ✅ Mark as read

**Phase 2 (Sprint 3-4):**
- ⬜ BP Abnormal alerts
- ⬜ Wrong Dose alerts
- ⬜ Missed Medication alerts
- ⬜ In-app modal popups
- ⬜ Filter by type

**Phase 3 (Future):**
- ⬜ Compliance alerts (batch)
- ⬜ ZNS/SMS fallback
- ⬜ Custom thresholds

### Technical Recommendations

1. **schedule-service as Core:** All trigger logic centralized here
2. **Event-Sourcing:** Include full data in Kafka events
3. **Feature Flags:** Enable gradual rollout per alert type
4. **Monitoring:** Track push latency P50/P95/P99

---

## Decision Matrix

| Question | Decision |
|----------|----------|
| Which service owns trigger logic? | schedule-service |
| Which service stores alerts? | user-service |
| Use existing notification table? | No, create specific `caregiver_alerts` |
| Support offline? | Read: Yes (cache). Write: No |
| Debounce mechanism? | Redis TTL + DB unique index |
| Badge sync method? | Silent push + API fallback |

---

## Sign-off

| Role | Name | Date |
|------|------|------|
| Solution Architect | (Pending) | |
| Tech Lead - Backend | (Pending) | |
| Tech Lead - Mobile | (Pending) | |
| Product Owner | (Pending) | |

---

## Appendix: Document Index

```
docs/nguoi_than/sa-analysis/nhan_canh_bao/
├── 01_intake/
│   ├── document_classification.md
│   └── scope_summary.md
├── 02_context/
│   ├── architecture_snapshot.md
│   └── database_entities.md
├── 03_extraction/
│   ├── functional_requirements.md
│   └── non_functional_requirements.md
├── 04_mapping/
│   ├── service_mapping.md
│   ├── api_mapping.md
│   └── database_mapping.md
├── 05_feasibility/
│   └── feasibility_report.md
├── 06_impact/
│   └── impact_analysis.md
├── 07_risks/
│   └── risk_register.md
└── 08_report/
    └── sa_assessment_report.md  ← YOU ARE HERE
```
