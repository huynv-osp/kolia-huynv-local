# Architecture Snapshot: US 1.3 - Gửi Lời Động Viên

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-02-04  
> **Source:** ALIO_SERVICES_CATALOG.md

---

## System Context

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MOBILE APP (CAREGIVER VIEW)                        │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Kết nối Người thân Section (Below Tổng quan sức khỏe)                  │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │   Widget: Gửi Lời Động Viên (SCR-ENG-01)                         │  │ │
│  │  │   - ENG-01: Suggested Chips (3 câu gợi ý)                        │  │ │
│  │  │   - ENG-02: Text Input (max 150 chars)                           │  │ │
│  │  │   - ENG-04: Send Button                                          │  │ │
│  │  │   - ENG-05: Refresh AI Button                                    │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼ REST API
┌─────────────────────────────────────────────────────────────────────────────┐
│                            API GATEWAY SERVICE                               │
│  Port: 8080 | Java 17, Vert.x                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  NEW Endpoints (4 APIs):                                                  │  │
│  │  POST /api/v1/encouragements                 → Create                 │  │
│  │  GET  /api/v1/encouragements                 → List (patient view)    │  │
│  │  POST /api/v1/encouragements/mark-read       → Batch mark as read     │  │
│  │  GET  /api/v1/encouragements/quota           → Check quota remaining  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└──────────────┬──────────────────────────────────────────────────────────────┘
               │ gRPC + Kafka
               ▼
┌────────────────────────┐    ┌─────────────────┐
│     USER-SERVICE       │    │ SCHEDULE-SERVICE│
│ Port: gRPC 9092        │    │  Celery Workers │
│ ─────────────────────  │    │ ─────────────── │
│ • EncouragementHandler │    │ • Push Notif    │
│ • EncouragementService │    │                 │
│ • EncouragementRepo    │    │                 │
│ • Permission Check     │    │                 │
└────────────────────────┘    └─────────────────┘
               │
               ▼ PostgreSQL
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATABASE                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  NEW: encouragement_messages                                          │  │
│  │  EXISTING: user_emergency_contacts, connection_permissions            │  │
│  │            connection_permission_types                                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Relevant Services

### 1. api-gateway-service

| Attribute | Value |
|-----------|-------|
| **Stack** | Java 17, Vert.x |
| **Port** | HTTP 8080 |
| **Health** | GET /health |
| **Role** | REST → gRPC routing |

**Allowed Patterns:**
- ✅ `handler/` - REST endpoints
- ✅ `dto/` - Request/Response
- ✅ `client/` - gRPC clients
- ❌ `service/`, `repository/`, `entity/` - NOT allowed (ARCH-001)

### 2. user-service

| Attribute | Value |
|-----------|-------|
| **Stack** | Java 17, Vert.x |
| **Port** | gRPC 9092, HTTP health 8082 |
| **Health** | GET http://:8082/health |
| **Role** | Business logic, CRUD operations |

**Proto Files:**
- `user_service.proto` - User operations
- `connection_service.proto` - Connection management
- **NEW:** `encouragement_service.proto` - Encouragement operations

### 3. agents-service [⏸️ DEFERRED]

> **Status:** AI Suggestions deferred to future release

### 4. schedule-service

| Attribute | Value |
|-----------|-------|
| **Stack** | Python, Celery |
| **Port** | Flower 5555 |
| **Role** | Background tasks, notifications |

**Relevant Tasks:**
- `send_push_notification` - Push delivery
- **NEW:** `send_encouragement_notification` - Encouragement push

---

## Communication Patterns

### Create Encouragement Flow

```
Mobile App
    │ POST /api/v1/encouragements
    ▼
API Gateway
    │ gRPC: CreateEncouragement()
    ▼
user-service
    │ 1. Check permission (encouragement)
    │ 2. Check quota (10/day)
    │ 3. Validate content (150 chars)
    │ 4. Save to DB
    │ 5. Publish Kafka event
    ▼
schedule-service (Kafka consumer)
    │ Send push notification
    ▼
Patient Device
```

---

## Existing Components to Reuse

| Component | Location | Purpose |
|-----------|----------|---------|
| `PermissionType.ENCOURAGEMENT` | user-service/enums | Permission #6 |
| `ConnectionPermission` | user-service/entity | Permission check |
| `connection_permission_types` | Database | Permission lookup |
| `PushNotificationService` | schedule-service | Push delivery |

---

## Next Steps

➡️ Proceed to Phase 3: Functional Requirements Extraction
