# Task Breakdown: KOLIA-1517 - Kết nối Người thân

> **Date:** 2026-01-30  
> **Total Tasks:** 29 (+1 for v2.14 Mark Report Read)  
> **Total Effort:** 60.5 hours (v2.14: +4.5h)  
> **Revision:** v2.14 - Added Mark Report Read API tasks

---

## Execution Order

```
Phase 1 (Week 1-2)
├── DB-001 ─▶ ENTITY-001~004 ─▶ REPO-001~003 ─▶ SVC-001~003 ─▶ HANDLER-001
├── PROTO-001 ─▶ PROTO-002 ─▶ CLIENT-001 ─┘
└── GW-HANDLER-001~002

Phase 2 (Week 3)
├── KAFKA-001
└── SCHED-001~002

Phase 3 (Week 4)
└── TEST-001~004
```

---

## Tasks by Service

### 📦 Database (1 task, 2h)

| ID | Task | Priority | Effort | Dependencies |
|----|------|:--------:|:------:|--------------|
| DB-001 | Migration script | P0 | 2h | None |

---

### 📦 user-service (16 tasks, 32h)

| ID | Task | Priority | Effort | Dependencies |
|----|------|:--------:|:------:|--------------|
| ENTITY-001 | ConnectionInvite entity | P0 | 1h | DB-001 |
| ENTITY-002 | UserConnection entity | P0 | 1h | DB-001 |
| ENTITY-003 | ConnectionPermission entity | P0 | 1h | DB-001, ENTITY-002 |
| ENTITY-004 | InviteNotification entity | P1 | 1h | DB-001, ENTITY-001 |
| REPO-001 | ConnectionInviteRepository | P0 | 2h | ENTITY-001 |
| REPO-002 | UserConnectionRepository | P0 | 2h | ENTITY-002 |
| REPO-003 | ConnectionPermissionRepository | P0 | 1h | ENTITY-003 |
| PROTO-001 | Proto definition | P0 | 2h | None |
| PROTO-002 | Proto compilation | P0 | 1h | PROTO-001 |
| SVC-001 | InviteService | P0 | 4h | REPO-001 |
| SVC-002 | ConnectionService | P0 | 4h | REPO-002, SVC-001, SVC-003 |
| SVC-003 | PermissionService | P0 | 3h | REPO-003 |
| HANDLER-001 | ConnectionHandler (gRPC) | P0 | 3h | SVC-001~003 |
| KAFKA-001 | Kafka producer | P1 | 2h | SVC-001~003 |
| CONST-001 | Enums (4 files) | P0 | 1h | None |
| DTO-001 | DTOs (8 files) | P0 | 2h | None |

---

### 📦 api-gateway-service (5 tasks, 11h)

| ID | Task | Priority | Effort | Dependencies |
|----|------|:--------:|:------:|--------------|
| CLIENT-001 | ConnectionServiceClient | P0 | 2h | PROTO-002 |
| GW-HANDLER-001 | InviteHandler (REST) | P0 | 3h | CLIENT-001 |
| GW-HANDLER-002 | ConnectionHandler (REST) | P0 | 3h | CLIENT-001 |
| GW-DTO-001 | Request DTOs | P0 | 1.5h | None |
| GW-DTO-002 | Response DTOs | P0 | 1.5h | None |

---

### 📦 schedule-service (2 tasks, 7h)

| ID | Task | Priority | Effort | Dependencies |
|----|------|:--------:|:------:|--------------|
| SCHED-001 | invite_notification task | P1 | 4h | KAFKA-001 |
| SCHED-002 | connection_notification task | P1 | 3h | KAFKA-001 |

---

### 📦 Testing (5 tasks, 15h)

| ID | Task | Priority | Effort | Dependencies |
|----|------|:--------:|:------:|--------------|
| TEST-001 | InviteService tests | P1 | 3h | SVC-001 |
| TEST-002 | ConnectionService tests | P1 | 3h | SVC-002 |
| TEST-002B | PermissionService tests | P1 | 3h | SVC-003 |
| TEST-003 | Gateway handler tests | P1 | 2h | GW-HANDLER-001~002 |
| TEST-004 | Integration tests | P2 | 4h | All |

---

## Test Commands

```bash
# user-service
cd user-service && mvn test -Dtest=*ConnectionTest

# api-gateway-service
cd api-gateway-service && mvn test -Dtest=*ConnectionTest

# schedule-service
cd schedule-service && pytest tests/tasks/connection/

# Integration
mvn verify -Pintegration-test
```
