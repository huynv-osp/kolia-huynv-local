# Complete Analysis: US 1.3 - Gửi Lời Động Viên

> **Phase:** 8 - Report Generation & Review  
> **Date:** 2026-02-04  
> **Version:** v1.0  
> **Status:** Ready for Review

---

## Document Overview

Tài liệu này tổng hợp toàn bộ phân tích SA cho tính năng "Gửi Lời Động Viên" (Encouragement Messages) - US 1.3 thuộc epic "Kết nối Người thân".

---

## Quick Navigation

| Phase | Document | Status |
|:-----:|----------|:------:|
| 1 | [Document Classification](../01_intake/document_classification.md) | ✅ |
| 1 | [Scope Summary](../01_intake/scope_summary.md) | ✅ |
| 2 | [Architecture Snapshot](../02_context/architecture_snapshot.md) | ✅ |
| 2 | [Database Entities](../02_context/database_entities.md) | ✅ |
| 3 | [Functional Requirements](../03_extraction/functional_requirements.md) | ✅ |
| 3 | [Non-Functional Requirements](../03_extraction/non_functional_requirements.md) | ✅ |
| 4 | [Service Mapping](../04_mapping/service_mapping.md) | ✅ |
| 4 | [API Mapping](../04_mapping/api_mapping.md) | ✅ |
| 4 | [Database Mapping](../04_mapping/database_mapping.md) | ✅ |
| 5 | [Feasibility Report](../05_feasibility/feasibility_report.md) | ✅ |
| 6 | [Impact Analysis](../06_impact/impact_analysis.md) | ✅ |
| 7 | [Technical Risks](../07_risks/technical_risks.md) | ✅ |
| 7 | [Implementation Recommendations](../07_risks/implementation_recommendations.md) | ✅ |
| 8 | [Executive Summary](executive_summary.md) | ✅ |

---

## Feature Description

### Purpose

Cho phép **Caregiver** gửi lời nhắn động viên đến **Patient** để khuyến khích họ tuân thủ lịch uống thuốc, đo huyết áp và duy trì tinh thần tích cực.

### Key Characteristics

- **One-way communication**: Caregiver → Patient (không reply)
- **Permission-based**: Cần Permission #6 (encouragement) = ON
- **Quota-limited**: Max 10 tin/ngày/Patient
- **Time-windowed**: Patient xem modal trong 24h
- **Push notification**: Real-time delivery

---

## API Endpoints (4 APIs)

### Caregiver APIs

| Method | Endpoint | Purpose |
|:------:|----------|---------|
| POST | `/api/v1/encouragements` | Gửi lời động viên |
| GET | `/api/v1/encouragements/quota` | Check quota còn lại |

### Patient APIs

| Method | Endpoint | Purpose |
|:------:|----------|---------|
| GET | `/api/v1/encouragements` | List lời động viên (24h) |
| POST | `/api/v1/encouragements/mark-read` | Batch mark as read |

---

## Database Schema

### New Table: `encouragement_messages`

```sql
CREATE TABLE encouragement_messages (
    encouragement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(user_id),
    patient_id UUID NOT NULL REFERENCES users(user_id),
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id),
    content VARCHAR(150) NOT NULL,
    sender_name VARCHAR(100),
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- FK: ensures valid code
    relationship_display VARCHAR(100),  -- Patient's perspective
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_content_length CHECK (char_length(content) <= 150),
    CONSTRAINT chk_different_users CHECK (sender_id != patient_id)
);
```

### Indexes

```sql
CREATE INDEX idx_enc_patient_unread ON encouragement_messages (patient_id, is_read, sent_at DESC) WHERE is_read = FALSE;
CREATE INDEX idx_enc_patient_recent ON encouragement_messages (patient_id, sent_at DESC);
-- Note: Use timestamp range query for quota check (IMMUTABLE requirement)
CREATE INDEX idx_enc_quota ON encouragement_messages (sender_id, patient_id, sent_at);
```

---

## Service Changes Summary

### user-service (24h)

- **Proto**: `encouragement_service.proto` (4 methods)
- **Entity**: `EncouragementMessage.java`
- **Repository**: `EncouragementRepository.java`
- **Service**: `EncouragementServiceImpl.java`
- **Handler**: `EncouragementServiceGrpcImpl.java`
- **Kafka**: `EncouragementKafkaProducer.java`

### api-gateway-service (10h)

- **Handler**: `EncouragementHandler.java`
- **Client**: `EncouragementServiceClient.java`
- **DTOs**: Request/Response classes
- **Config**: 4 new routes

### schedule-service (4h)

- **Consumer**: `encouragement_consumer.py`
- **Task**: `send_encouragement_notification.py`
- **Template**: Push notification template

### Mobile App (16h)

- **Widget**: `EncouragementWidget.tsx`
- **Modal**: `EncouragementModal.tsx`
- **Hook**: `useEncouragement.ts`
- **Store**: `encouragementStore.ts`

---

## Feasibility Assessment

| Criteria | Score | Notes |
|----------|:-----:|-------|
| Architecture Fit | 5/5 | Standard microservices pattern |
| Database Compatibility | 4/5 | 1 new table, reuses existing |
| API/gRPC Compatibility | 5/5 | Standard patterns |
| Service Boundary Clarity | 4/5 | Clear separation |
| Technology Stack Match | 5/5 | All existing tech |

**Final Score: 85/100 - FEASIBLE ✅**

---

## Impact Analysis

| Metric | Value |
|--------|:-----:|
| Services Affected | 4 |
| New Tables | 1 |
| Modified Tables | 0 |
| Breaking Changes | 0 |
| Data Migration | None |

**Impact Level: 🟡 MEDIUM**

---

## Risk Register

| Risk | Probability | Impact | Score |
|------|:-----------:|:------:|:-----:|
| Push Notification Failure | LOW | MEDIUM | 4/10 |
| Permission Race Condition | LOW | LOW | 2/10 |
| Quota Bypass Attempt | LOW | MEDIUM | 3/10 |
| Content Injection (XSS) | LOW | MEDIUM | 3/10 |
| Database Performance | LOW | LOW | 2/10 |

**Overall Risk: LOW-MEDIUM**

---

## Implementation Plan

### Phase 1: Database (2h)
```bash
# Create migration
V2026.02.04.1__create_encouragement_messages.sql
```

### Phase 2: user-service (24h)
- Proto definition
- Entity, Repository, Service
- gRPC Handler
- Kafka producer
- Unit tests

### Phase 3: api-gateway (10h)
- gRPC client
- REST handlers
- DTOs
- Route config

### Phase 4: schedule-service (4h)
- Kafka consumer
- Push notification task
- Templates

### Phase 5: Mobile App (16h)
- Widget component
- Modal component
- API integration
- State management

### Phase 6: Testing (8h)
- Integration tests
- E2E tests
- Performance tests

**Total: 64 hours** (including buffer)

---

## Monitoring & Observability

### Key Metrics

| Metric | Alert Threshold |
|--------|-----------------|
| Create Error Rate | > 1% |
| Push Failure Rate | > 5% |
| Create Latency P95 | > 1s |
| Quota Exhaustion Rate | > 50% users |

---

## Definition of Done

- [ ] Database migration applied
- [ ] Unit tests passing (>85% coverage)
- [ ] Integration tests passing
- [ ] Code review approved
- [ ] API documentation complete
- [ ] Monitoring dashboards configured
- [ ] Feature flag enabled in staging
- [ ] E2E tests passing
- [ ] Performance test passed
- [ ] Security review completed

---

## Appendix

### Related Documents

- [SRS v1.3](../../srs_input_documents/srs_gui_loi_dong_vien.md)
- [Prototype HTML](../../srs_input_documents/prototype/prototype_gui_loi_dong_vien.html)
- [Kết nối Người thân SA](../ket_noi_nguoi_than/)

### Change Log

| Version | Date | Author | Changes |
|:-------:|------|--------|---------|
| v1.0 | 2026-02-04 | SA Workflow | Initial analysis |

---

## Approval

| Reviewer | Status | Date | Comments |
|----------|:------:|------|----------|
| SA Lead | ⏳ | - | - |
| Tech Lead | ⏳ | - | - |
| Product Owner | ⏳ | - | - |
