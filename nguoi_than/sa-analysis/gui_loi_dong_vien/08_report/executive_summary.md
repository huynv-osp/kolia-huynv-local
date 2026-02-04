# Executive Summary: US 1.3 - Gửi Lời Động Viên

> **Phase:** 8 - Report Generation & Review  
> **Date:** 2026-02-04  
> **Author:** SA Workflow Automated

---

## Overview

Feature "Gửi Lời Động Viên" cho phép Caregiver gửi tin nhắn động viên một chiều đến Patient thông qua ứng dụng Kolia. Đây là User Story 1.3 thuộc epic "Kết nối Người thân".

---

## Key Metrics

| Metric | Value |
|--------|:-----:|
| **Feasibility Score** | 85/100 ✅ |
| **Impact Level** | 🟡 MEDIUM |
| **Risk Level** | 🟢 LOW-MEDIUM |
| **Estimated Effort** | 54 hours |
| **Services Affected** | 4 |
| **New Tables** | 1 |
| **New API Endpoints** | 4 |

---

## Scope Summary

### In Scope (4 APIs)

| API | Actor | Purpose |
|-----|-------|---------|
| **POST** `/api/v1/encouragements` | Caregiver | Gửi lời động viên |
| **GET** `/api/v1/encouragements` | Patient | Lấy list 24h, mới→cũ |
| **POST** `/api/v1/encouragements/mark-read` | Patient | Batch đánh dấu đọc |
| **GET** `/api/v1/encouragements/quota` | Caregiver | Check quota còn lại |

### Out of Scope

- ~~AI Suggestions API~~ (Deferred)
- Patient response/reply
- Message edit/delete
- Full chat history

---

## Architecture Fit

```
Mobile App (Caregiver/Patient)
        │ REST
        ▼
api-gateway-service ── 4 endpoints
        │ gRPC
        ▼
user-service ── EncouragementService
        │
        ├── PostgreSQL (encouragement_messages)
        │
        └── Kafka → schedule-service → Push FCM
```

---

## Business Rules Summary

| BR | Rule | Enforcement |
|:--:|------|-------------|
| BR-001 | Max 10 tin/ngày/Patient | Server-side quota |
| BR-002 | Max 150 Unicode chars | DB constraint |
| BR-003 | Permission #6 = ON | Real-time check |

---

## Database Changes

### New Table: `encouragement_messages`

| Key Columns | Purpose |
|-------------|---------|
| sender_id, patient_id | Relationship |
| content (max 150) | Message |
| sender_name, relationship_display | Denormalized for display |
| is_read, sent_at | Status tracking |

---

## Service Impact

| Service | Impact | Effort |
|---------|:------:|:------:|
| user-service | 🟡 | 24h |
| api-gateway-service | 🟡 | 10h |
| schedule-service | 🟢 | 4h |
| Mobile App | 🟡 | 16h |
| **Total** | | **54h** |

---

## Risk Summary

| Risk | Level | Mitigation |
|------|:-----:|------------|
| Push Failure | LOW | Retry queue |
| Permission Race | LOW | Real-time check |
| Quota Bypass | LOW | Server-side enforcement |

---

## Recommendations

1. ✅ **PROCEED** with implementation
2. Implement database first, then user-service
3. Mobile development can parallel with api-gateway
4. Use feature flag for staged rollout

---

## Approval Status

| Role | Status | Date |
|------|:------:|------|
| SA Lead | ⏳ Pending | - |
| Tech Lead | ⏳ Pending | - |
| Product Owner | ⏳ Pending | - |

---

## Next Steps

1. Review and approve this SA analysis
2. Create database migration script
3. Begin implementation per Phase ordering
4. Set up monitoring dashboards
