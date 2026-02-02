# 📋 Feature Specification

## SOS Emergency - Technical Specification

---

## Executive Summary

| Attribute | Value |
|-----------|-------|
| **Feature Name** | SOS - Chức năng hỗ trợ khẩn cấp |
| **Version** | 1.0 |
| **Status** | Ready for Development |
| **Complexity** | 🔴 Complex (21-30 points) |
| **Total Tasks** | 32 |
| **Estimated Effort** | ~25 working days |
| **Sprints** | 3 sprints |

---

## 1. Scope

### 1.1 In Scope
- ✅ SOS activation with 30s countdown
- ✅ ZNS notifications to emergency contacts
- ✅ CSKH API integration
- ✅ Auto-escalation flow (20s per contact)
- ✅ Call 115 (native phone)
- ✅ Emergency contact management
- ✅ Hospital map (Google Maps)
- ✅ First aid guide (offline-capable)
- ✅ Offline queue & retry
- ✅ Low battery handling (10s countdown)
- ✅ Cooldown management (30 min, no bypass per v1.8)
- ✅ SOS without contacts (CSKH only, per BR-SOS-024)

### 1.2 Out of Scope
- ❌ External hospital system integration
- ❌ IoT medical device integration
- ❌ SOS History/Log screen
- ❌ Zalo Video Call (không có public API/deep link)

---

## 2. Architecture Summary

### 2.1 Services

| Service | Responsibility |
|---------|----------------|
| **api-gateway-service** | REST APIs, orchestration |
| **user-service** | Emergency contacts gRPC |
| **schedule-service** | ZNS, escalation, background tasks |
| **Mobile App** | 16 screens, offline queue |

### 2.2 New Database Tables

| Table | Purpose |
|-------|---------|
| `user_emergency_contacts` | Emergency contact list (max 5) |
| `sos_events` | SOS event tracking |
| `sos_notifications` | ZNS/SMS notification log |
| `sos_escalation_calls` | Escalation call tracking |
| `first_aid_content` | First aid CMS content |

### 2.3 New API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/sos/activate` | Start SOS |
| POST | `/api/sos/cancel` | Cancel SOS |
| GET | `/api/sos/status/{id}` | Get status |
| GET | `/api/sos/contacts` | List contacts |
| POST | `/api/sos/contacts` | Add contact |
| PUT | `/api/sos/contacts/{id}` | Update contact |
| DELETE | `/api/sos/contacts/{id}` | Delete contact |
| GET | `/api/sos/first-aid` | Get first aid content |
| POST | `/api/sos/escalation/confirm` | Confirm contact answered |

> **Note:** `/api/sos/activate/bypass` removed in SRS v1.8 - no bypass allowed

---

## 3. Sprint Plan

### Sprint 1: Foundation (Week 1-2)
| Deliverable | Tasks |
|-------------|-------|
| Database migrations | DB-001..005 |
| user-service gRPC | US-001..004 |
| api-gateway core | GW-001..004, GW-006 |

### Sprint 2: Integration (Week 3-4)
| Deliverable | Tasks |
|-------------|-------|
| schedule-service core | SS-001..005 |
| api-gateway integration | GW-005, GW-007, GW-008 |
| Mobile core | MOB-001, MOB-002, MOB-007 |

### Sprint 3: Complete (Week 5-6)
| Deliverable | Tasks |
|-------------|-------|
| schedule-service background | SS-006..008 |
| Mobile remaining | MOB-003..006 |
| E2E testing | All |

---

## 4. Dependencies & Blockers

### 4.1 Blockers
| Blocker | Status | Mitigation |
|---------|:------:|------------|
| Kết nối người thân | 🔴 Not started | Mock contacts for testing |
| ZNS OA | 🟡 Pending | SMS fallback |

### 4.2 External Dependencies
| Dependency | Status |
|------------|:------:|
| Google Maps API | ✅ Available |
| SMS Provider | ✅ Available |
| Location Permission | ✅ Handled |

---

## 5. Risks Summary

| Risk | Severity | Mitigation |
|------|:--------:|------------|
| Auto-escalation complexity | 🔴 | Push notification approach |
| Countdown sync | 🔴 | Server as source of truth |
| ZNS rate limits | 🔴 | SMS fallback |
| DND bypass | 🟡 | iOS Critical Alerts |

---

## 6. Success Criteria

| Metric | Target |
|--------|--------|
| SOS completion rate | ≥99% |
| Alert delivery rate | ≥95% |
| Response time (activate) | <500ms |
| ZNS sending | <3s after countdown |

---

## 7. Documents Index

| Document | Path |
|----------|------|
| SRS | `docs/srs_input_documents/srs_sos.md` |
| SA Analysis | `docs/sa-analysis/sos_emergency/` |
| Requirement Analysis | `docs/features/sos_emergency/01_analysis/` |
| Planning | `docs/features/sos_emergency/02_planning/` |
| Review | `docs/features/sos_emergency/03_review/` |
| Output | `docs/features/sos_emergency/04_output/` |

---

## Sign-off

| Role | Status |
|------|:------:|
| Solution Architect | ✅ Approved |
| Tech Lead | ⏳ Pending |
| Product Owner | ⏳ Pending |
