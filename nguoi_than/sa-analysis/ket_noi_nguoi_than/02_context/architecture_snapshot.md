# Architecture Snapshot: ALIO Services

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-01-28  
> **Reference:** ALIO_SERVICES_CATALOG.md

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT (Web/Mobile)                         │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTP/REST
┌───────────────────────────────▼─────────────────────────────────┐
│                      API GATEWAY                                 │
│  api-gateway-service (Java 17, Vert.x, port 8080)               │
│  [AFFECTED: 🟡 MEDIUM - 8 new REST endpoints]                   │
└──────┬──────────────────────────────────────────────────────────┘
       │ gRPC
┌──────▼─────────┐  ┌─────────────────┐  ┌────────────────────────┐
│  user-service  │  │ schedule-service│  │  Other Services        │
│  (Vert.x)      │  │ (Celery)        │  │  (auth, storage, gami) │
│  [🔴 HIGH]     │  │ [🟡 MEDIUM]     │  │  [🟢 LOW - No Impact]  │
└────────────────┘  └─────────────────┘  └────────────────────────┘
```

---

## 2. Service Catalog (Affected)

| Service | Stack | Role | Impact |
|---------|-------|------|:------:|
| **api-gateway-service** | Java 17, Vert.x | REST entry, gRPC client | 🟡 |
| **user-service** | Java 17, Vert.x | Business logic, data | 🔴 |
| **schedule-service** | Python, Celery | Async notifications | 🟡 |

---

## 3. Communication Patterns

| Pattern | Technologies | Usage |
|---------|--------------|-------|
| Sync Request-Response | gRPC | Gateway → Backend |
| Async Events | Kafka | Backend → Schedule |
| External Notifications | HTTP | Schedule → ZNS/SMS/FCM |

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
    - service/     → Business logic
    - repository/  → Database access
    - entity/      → JPA entities
```

---

## 5. Technology Stack

| Layer | Technology |
|-------|------------|
| Runtime | Java 17, Python 3.11 |
| Frameworks | Vert.x, Celery |
| Protocol | gRPC, REST, Kafka |
| Database | PostgreSQL 14 |
| Cache | Redis |
| Message Queue | Kafka |
