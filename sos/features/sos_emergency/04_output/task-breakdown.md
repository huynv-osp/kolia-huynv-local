# 📋 Task Breakdown by Service

## SOS Emergency - Implementation Tasks

---

## Summary

| Service | Tasks | Effort | Priority |
|---------|:-----:|:------:|:--------:|
| Database | 5 | 8h | P0 |
| user-service | 4 | 12h | P0 |
| api-gateway-service | 12 | 32h | P0/P1 |
| schedule-service | 8 | 25h | P0/P1/P2 |
| Mobile App | 7 | 35h | P0/P1 |
| **TOTAL** | **36** | **~112h (14 days)** | - |

---

# 🗄️ DATABASE TASKS

| ID | Task | Effort | Priority | Dependencies |
|----|------|:------:|:--------:|--------------|
| **DB-001** | Create `user_emergency_contacts` table | 2h | P0 | - |
| **DB-002** | Create `sos_events` table (partitioned) | 2h | P0 | - |
| **DB-003** | Create `sos_notifications` table | 2h | P0 | DB-002 |
| **DB-004** | Create `sos_escalation_calls` table | 1h | P0 | DB-002 |
| **DB-005** | Create `first_aid_content` table + seed data | 1h | P1 | - |

---

# 👤 USER-SERVICE TASKS

| ID | Task | Effort | Priority | Dependencies |
|----|------|:------:|:--------:|--------------|
| **US-001** | Create EmergencyContact Proto | 2h | P0 | DB-001 |
| **US-002** | Implement EmergencyContactRepository | 3h | P0 | US-001 |
| **US-003** | Implement EmergencyContactService | 4h | P0 | US-002 |
| **US-004** | Implement EmergencyContactGrpcService | 3h | P0 | US-003 |

**Deliverable:** gRPC service for emergency contact CRUD

---

# 🌐 API-GATEWAY-SERVICE TASKS

| ID | Task | Effort | Priority | Dependencies |
|----|------|:------:|:--------:|--------------|
| **GW-001** | Create SOS REST Endpoints (4 endpoints) | 4h | P0 | - |
| **GW-002** | Implement Cooldown Service (Redis) | 3h | P0 | GW-001 |
| **GW-003** | Create Emergency Contact REST Endpoints (4 endpoints) | 3h | P0 | US-004 |
| **GW-004** | Implement gRPC Client for EmergencyContacts | 2h | P0 | US-004 |
| **GW-005** | Create First Aid REST Endpoint | 2h | P1 | DB-005 |
| **GW-006** | Implement SOS Event Kafka Producer | 3h | P0 | GW-001 |
| **GW-007** | Implement CSKH API Client | 3h | P1 | GW-001 |
| **GW-008** | Add Countdown Sync Endpoint | 2h | P1 | GW-001, GW-002 |
| **GW-009** | Create Hospital Nearby API (GAP-API-001) | 3h | P1 | - |
| **GW-010** | Implement Location Update API (GAP-API-003) | 2h | P1 | GW-001 |
| **GW-011** | Implement Manual Call API (GAP-API-005) | 2h | P0 | GW-001 |
| **GW-012** | Implement CSKH Alert Internal API (GAP-API-004) | 3h | P0 | GW-007 |

**Deliverable:** 14 REST endpoints + integrations

---

# ⚙️ SCHEDULE-SERVICE TASKS

| ID | Task | Effort | Priority | Dependencies |
|----|------|:------:|:--------:|--------------|
| **SS-001** | Create SOS Celery Tasks Module | 2h | P0 | - |
| **SS-002** | Implement SOS Kafka Consumer | 3h | P0 | SS-001 |
| **SS-003** | Implement `send_sos_alerts` Task | 4h | P0 | SS-002 |
| **SS-004** | Implement ZNS Client | 4h | P0 | - |
| **SS-005** | Implement `execute_escalation` Task | 5h | P0 | SS-003 |
| **SS-006** | Implement `retry_failed_zns` Task | 2h | P1 | SS-003, SS-004 |
| **SS-007** | Implement `process_offline_queue` Task | 3h | P1 | SS-003 |
| **SS-008** | Implement `cleanup_sos_events` Task | 2h | P2 | DB-002 |

**Deliverable:** 6 Celery tasks + ZNS integration

---

# 📱 MOBILE APP TASKS

| ID | Task | Effort | Priority | Dependencies |
|----|------|:------:|:--------:|--------------|
| **MOB-001** | Implement SOS Core Screens (SOS-00, 01, 02) | 8h | P0 | GW-001 |
| **MOB-002** | Implement Offline Queue Manager | 6h | P0 | MOB-001 |
| **MOB-003** | Implement Contact List Screen (SOS-03) | 4h | P1 | GW-003 |
| **MOB-004** | Implement Hospital Map Screen (SOS-04) | 6h | P1 | - |
| **MOB-005** | Implement First Aid Screens (SOS-05, 05a-d) | 4h | P1 | GW-005 |
| **MOB-006** | Implement Error State Screens (ERR-01..06) | 3h | P1 | MOB-001 |
| **MOB-007** | Implement SOS API Service | 4h | P0 | GW-001 |

**Deliverable:** 16 screens + offline capability

---

# ⏱️ GANTT CHART (Simplified)

```
Week 1:  |=== DB-* ===|=== US-* ===|
Week 2:  |=== GW-001..006 ===|
Week 3:  |=== SS-001..005 ===|=== GW-007,008 ===|
Week 4:  |=== MOB-001,002,007 ===|=== SS-006,007 ===|
Week 5:  |=== MOB-003..006 ===|
Week 6:  |=== Testing + Polish ===|=== SS-008 ===|
```

---

# 🎯 MILESTONES

| Milestone | Week | Deliverables |
|-----------|:----:|--------------|
| **M1: Backend Foundation** | 2 | DB + gRPC services ready |
| **M2: API Complete** | 3 | All REST endpoints working |
| **M3: Integration** | 4 | ZNS + Mobile core working |
| **M4: Feature Complete** | 5 | All screens implemented |
| **M5: Release Ready** | 6 | E2E tested, ready for QA |

---

# 📎 QUICK REFERENCE

## Critical Path Tasks (Must complete in order)
```
DB-001 → US-001 → US-002 → US-003 → US-004 → GW-003 → MOB-003
DB-002 → SS-001 → SS-002 → SS-003 → SS-005
GW-001 → GW-006 → MOB-001 → MOB-002
```

## Parallel Tracks
```
Track A: Database (Day 1)
Track B: user-service (Day 1-2)
Track C: api-gateway (Day 2-3)
Track D: schedule-service (Day 2-4)
Track E: mobile (Day 3+)
```

---

**Generated:** 2026-01-26T10:25:00+07:00
