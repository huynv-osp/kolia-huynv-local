# Architecture Snapshot: ALIO Services

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-02-13 (Updated from 2026-01-28)  
> **Reference:** ALIO_SERVICES_CATALOG.md  
> **Revision:** v4.0 — Added payment-service, auth-service impact

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT (Mobile App)                         │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTP/REST
┌───────────────────────────────▼─────────────────────────────────┐
│                      API GATEWAY                                 │
│  api-gateway-service (Java 17, Vert.x, port 8080)               │
│  [AFFECTED: 🔴 HIGH - 6 new + 4 updated REST endpoints]        │
└──────┬──────────────────────────────────────────────────────────┘
       │ gRPC
┌──────▼─────────┐  ┌─────────────────┐  ┌────────────────────────┐
│  user-service  │  │ payment-service │  │  Other Services        │
│  (Vert.x)      │  │ (Spring Boot)   │  │  (storage, gami)       │
│  [🔴 HIGH]     │  │ [🟡 MEDIUM]     │  │  [🟢 LOW - No Impact]  │
│  +FamilyGroup  │  │ GetSubscription │  │                        │
│  +AutoConnect  │  │ SyncMembers     │  │                        │
└────────────────┘  └─────────────────┘  └────────────────────────┘
       │ Kafka
┌──────▼─────────┐  ┌─────────────────┐
│schedule-service│  │  auth-service   │
│ (Celery)       │  │  (Vert.x)       │
│ [🟡 MEDIUM]    │  │  [🟢 LOW]       │
│ +MemberBcast   │  │  backfillInvite │
└────────────────┘  └─────────────────┘
```

---

## 2. Service Catalog (Affected)

| Service | Stack | Role | Impact | v4.0 Changes |
|---------|-------|------|:------:|--------------|
| **api-gateway-service** | Java 17, Vert.x | REST entry, gRPC client | 🔴 | +6 new endpoints, update 4 existing |
| **user-service** | Java 17, Vert.x | Business logic, data | 🔴 | +FamilyGroup entity/service, auto-connect, soft-disconnect |
| **payment-service** | Java 17, Spring Boot | Subscription, slots | 🟡 | Existing GetSubscription + SyncMembers RPCs |
| **schedule-service** | Python, Celery | Async notifications | 🟡 | +Member broadcast, update invite noti |
| **auth-service** | Java 17, Vert.x | OTP, JWT | 🟢 | Existing backfillPendingInviteReceiverIds (keep) |

---

## 3. Communication Patterns

| Pattern | Technologies | Usage |
|---------|--------------|-------|
| Sync Request-Response | gRPC | Gateway → user-service, payment-service |
| Async Events | Kafka | user-service → schedule-service |
| External Notifications | HTTP | schedule-service → ZNS/SMS/FCM |
| **Cross-service call** | gRPC | **user-service → payment-service** (GetSubscription/SyncMembers) |

---

## 4. Gateway Compliance (ARCH-001)

```
api-gateway-service:
  ✅ ALLOWED:
    - handler/     → REST endpoint handlers
    - dto/         → Request/Response DTOs
    - client/      → gRPC clients
    - config/      → Route configuration
    
  ❌ NOT ALLOWED:
    - service/     → Business logic (NOTE: ConnectionService.java exists but is thin proxy)
    - repository/  → Database access
    - entity/      → JPA entities
```

---

## 5. Technology Stack

| Layer | Technology |
|-------|------------|
| Runtime | Java 17, Python 3.11 |
| Frameworks | Vert.x, Spring Boot, Celery |
| Protocol | gRPC, REST, Kafka |
| Database | PostgreSQL 14 |
| Cache | Redis |
| Message Queue | Kafka |
