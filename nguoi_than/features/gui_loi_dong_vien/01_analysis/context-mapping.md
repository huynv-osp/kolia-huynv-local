# Context Mapping: US 1.3 - Gửi Lời Động Viên

> **Phase:** 2 - System Context Mapping  
> **Date:** 2026-02-04  
> **Reference:** [ALIO_SERVICES_CATALOG.md](../../../.agent/workflows/KOLIA_workflows/artchitect/ALIO_SERVICES_CATALOG.md)

---

## 1. Services Involved

| Service | Tech Stack | Role in Feature |
|---------|------------|-----------------|
| **user-service** | Java 17, Vert.x | Primary - Business logic, DB access |
| **api-gateway-service** | Java 17, Vert.x | REST→gRPC forwarding |
| **schedule-service** | Python/Celery | Push notification dispatch |
| **Mobile App** | React Native/Expo | UI cho Caregiver & Patient |

### ⏸️ DEFERRED Services

| Service | Status | Notes |
|---------|:------:|-------|
| agents-service | ⏸️ DEFERRED | AI Suggestions cho future release |

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        MOBILE APP (React Native)                         │
│  ┌───────────────────────────┐     ┌───────────────────────────────┐    │
│  │      CAREGIVER VIEW       │     │        PATIENT VIEW           │    │
│  │  - EncouragementWidget    │     │  - EncouragementModal (24h)   │    │
│  │  - Send message (POST)    │     │  - Mark as read (POST)        │    │
│  │  - Check quota (GET)      │     │  - List messages (GET)        │    │
│  └─────────────┬─────────────┘     └──────────────┬────────────────┘    │
└────────────────┼───────────────────────────────────┼────────────────────┘
                 │ REST (HTTPS)                      │
                 ▼                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      api-gateway-service (Vert.x)                        │
│                                                                          │
│  POST /api/v1/encouragements                                             │
│  GET  /api/v1/encouragements                                             │
│  POST /api/v1/encouragements/mark-read                                   │
│  GET  /api/v1/encouragements/quota                                       │
│                                                                          │
│  EncouragementHandler.java → EncouragementServiceClient.java             │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │ gRPC
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       user-service (Vert.x)                              │
│                                                                          │
│  EncouragementServiceGrpcImpl.java                                       │
│    ├── createEncouragement()                                             │
│    ├── getEncouragementList()                                            │
│    ├── markAsRead()                                                      │
│    └── getQuota()                                                        │
│                                                                          │
│  EncouragementService.java → EncouragementRepository.java                │
│                                   │                                      │
│               ┌───────────────────┼───────────────────┐                  │
│               ▼                   ▼                   ▼                  │
│  ┌───────────────────┐ ┌──────────────────┐ ┌────────────────────┐       │
│  │   PostgreSQL      │ │  Kafka Producer  │ │ Permission Check   │       │
│  │ encouragement_msgs│ │ topic-enc-created│ │ connection_perms   │       │
│  └───────────────────┘ └────────┬─────────┘ └────────────────────┘       │
└─────────────────────────────────┼───────────────────────────────────────┘
                                  │ Kafka
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     schedule-service (Python/Celery)                     │
│                                                                          │
│  EncouragementKafkaConsumer                                              │
│    └── send_encouragement_push_notification.py                           │
│                                                                          │
│  Push Notification to FCM/APNs                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Database Entities

### New Table: `encouragement_messages`

| Column | Type | Purpose |
|--------|------|---------|
| encouragement_id | UUID | PK |
| sender_id | UUID | FK → users |
| patient_id | UUID | FK → users |
| contact_id | UUID | FK → user_emergency_contacts |
| content | VARCHAR(150) | Message (BR-002) |
| sender_name | VARCHAR(100) | Caregiver's display name |
| relationship_code | VARCHAR(30) | FK → relationships (e.g., "daughter") |
| relationship_display | VARCHAR(100) | **Patient's perspective** - how Patient calls Caregiver |
| is_read | BOOLEAN | Read status |
| sent_at | TIMESTAMPTZ | Timestamp |

> ⚠️ **Perspective Standard v2.23:** `relationship_display` là danh xưng mà **Patient gọi Caregiver**.
> Ví dụ: Patient = Bà Lan (Mẹ), Caregiver = Cô Huy (Con gái) → `relationship_display = "Con gái"`

### Referenced Tables (No Changes)

- `users` - Sender/Patient information
- `user_emergency_contacts` - Connection info, relationship
- `connection_permissions` - Permission #6 check

---

## 4. Communication Patterns

| From | To | Protocol | Purpose |
|------|-----|:--------:|---------|
| Mobile | api-gateway | REST | CRUD operations |
| api-gateway | user-service | gRPC | Business logic |
| user-service | PostgreSQL | SQL | Data persistence |
| user-service | Kafka | Event | Trigger notification |
| schedule-service | Kafka | Consume | Receive event |
| schedule-service | FCM | HTTP | Push notification |

---

## 5. Data Flow: Send Encouragement

```
1. Caregiver taps "Gửi"
   │
2. Mobile POST /api/v1/encouragements
   │
3. api-gateway validates JWT, forwards gRPC
   │
4. user-service:
   ├── Check Permission #6 = ON
   ├── Check Quota < 10/day
   ├── Validate content length ≤150
   ├── Get relationship metadata
   ├── Insert encouragement_messages
   └── Publish Kafka event
   │
5. schedule-service consumes event
   │
6. Push notification to Patient device
   │
7. Patient opens app → Modal displays
```

---

## Next Phase

➡️ Proceed to Phase 3: Impact Analysis
