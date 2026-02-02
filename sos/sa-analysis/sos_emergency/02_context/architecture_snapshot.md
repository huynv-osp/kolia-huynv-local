# ALIO Architecture Snapshot for SOS Emergency

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Reference Doc** | `Bmad/MY_workflows/artchitect/ALIO_SERVICES_CATALOG.md` |
| **Snapshot Date** | 2026-01-26 |

---

## 1. ALIO Services Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT (Kolia Mobile App)                   │
│              iOS/Android + Location + Native Phone               │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTP/REST
┌───────────────────────────────▼─────────────────────────────────┐
│                      API GATEWAY SERVICE                         │
│  api-gateway-service (Java 17, Vert.x, port 8080)               │
│  - gRPC client, Kafka producer, Redis client                    │
│  - 🎯 SOS: New REST endpoints for SOS activation                │
└──────┬──────────────────────────────────────────────────────────┘
       │ gRPC
       ├──────────────────────────────────────────────────────────┐
       │                                                          │
┌──────▼─────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────▼───────┐
│  auth-service  │  │ user-service │  │storage-service│  │  gami-service  │
│  (Vert.x)      │  │ (Vert.x)     │  │ (Vert.x)      │  │  (Vert.x)      │
│  - OTP/JWT     │  │ 🎯 SOS:      │  │ - MinIO       │  │  - Missions    │
│  - Admin Auth  │  │ - Family     │  │ - TTS         │  │  - Rewards     │
│                │  │ - Location   │  │ - Files       │  │                │
└────────────────┘  └──────────────┘  └──────────────┘  └────────────────┘
       │ Kafka + REST
       │
┌──────▼─────────┐  ┌────────────────┐  ┌────────────────┐
│ agents-service │  │schedule-service│  │kolia-assistant │
│ (FastAPI)      │  │ (Celery)       │  │ (ADK/FastAPI)  │
│ - BMI Agent    │  │ 🎯 SOS:        │  │ - LLM Chat     │
│ - BP Agent     │  │ - Reminders    │  │ - Sessions     │
│ - Drug Agent   │  │ - SOS Queue    │  │                │
└────────────────┘  └────────────────┘  └────────────────┘
```

### 1.2 Services Inventory

| Service | Tech Stack | Port | Relevance to SOS |
|---------|------------|------|------------------|
| **api-gateway-service** | Java 17, Vert.x | HTTP 8080 | 🔴 HIGH - Entry point, REST APIs |
| **auth-service** | Java 17, Vert.x | gRPC 9090, HTTP 8000 | 🟡 MEDIUM - JWT validation |
| **user-service** | Java 17, Vert.x | gRPC 9092, HTTP 8082 | 🔴 HIGH - Family contacts, location |
| **storage-service** | Java 17, Vert.x | gRPC 9094, HTTP 8004 | 🟢 LOW - File storage if needed |
| **gami-service** | Java 17, Vert.x | gRPC 9093, HTTP 8003 | 🟢 LOW - Optional gamification |
| **agents-service** | Python, FastAPI | Multiple ports | 🟢 LOW - No AI agent needed |
| **schedule-service** | Python, Celery | Flower 5555 | 🔴 HIGH - Escalation, retry, queue |
| **kolia-assistant** | Python, FastAPI | HTTP 6666 | 🟢 LOW - Not involved |

---

## 2. Relevant Services Deep Dive

### 2.1 api-gateway-service (🔴 HIGH)

**Current Capabilities:**
- REST endpoint routing
- gRPC client to business services
- Kafka producer for async tasks
- Redis for caching and session

**SOS Requirements:**
- ✅ REST endpoint creation - Supported
- ✅ gRPC calls to user-service - Supported
- ✅ Kafka publish for async tasks - Supported
- ⚠️ ZNS integration - **NEW** (requires new client)
- ⚠️ External API calls (CSKH) - **NEW** (requires new client)

### 2.2 user-service (🔴 HIGH)

**Current Capabilities:**
- User profile management
- Location management (`user_locations` table candidate)
- Family relationships (`family_group_members`, `family_groups`)
- Friend management (`friends`, `friend_requests`)
- Notifications (`notifications` table)

**gRPC Services (from proto files):**
- `UserService` - Profile, location, config
- `FamilyRelationshipService` - Family members management
- `FriendService` - Friend list

**SOS Requirements:**
- ✅ Family contact retrieval - Available via `FamilyRelationshipService`
- ✅ Notification sending - Available via `notifications` table
- ✅ Location storage/retrieval - Available via existing patterns
- ⚠️ Emergency contact priority - **EXTENSION** needed

### 2.3 schedule-service (🔴 HIGH)

**Current Capabilities:**
- Celery beat scheduler
- Celery worker for background tasks
- Redis broker
- Kafka consumer (optional)
- Reminder & notification tasks

**SOS Requirements:**
- ✅ Scheduled task execution - Supported
- ✅ Retry logic - Celery built-in
- ⚠️ Escalation flow automation - **NEW** task type
- ⚠️ Offline queue processing - **NEW** task type
- ⚠️ Real-time countdown sync - **COMPLEX** (may need WebSocket)

### 2.4 auth-service (🟡 MEDIUM)

**Current Capabilities:**
- OTP/SMS verification
- JWT token management
- Admin authentication

**SOS Requirements:**
- ✅ JWT validation for SOS requests - Available
- ⚠️ SMS/OTP integration - Can be reused for ZNS fallback

---

## 3. Communication Patterns

### 3.1 Synchronous (gRPC)

```
api-gateway → user-service: Get family contacts
api-gateway → user-service: Get user location
api-gateway → user-service: Create notification
```

### 3.2 Asynchronous (Kafka)

```
api-gateway → Kafka → schedule-service: Queue SOS event
schedule-service → Kafka → notification-worker: Send ZNS
```

### 3.3 External Integrations (NEW for SOS)

```
schedule-service → ZNS API: Send notifications (HTTP)
api-gateway → CSKH API: Send alerts (HTTP)
Mobile App → Google Maps API: Hospital search (Client-side)
Mobile App → Native Phone: Call 115 (Client-side)
```

---

## 4. Key Infrastructure

### 4.1 Data Stores

| Store | Service | Purpose for SOS |
|-------|---------|-----------------|
| **PostgreSQL** | All Java services | SOS events, contacts, notifications |
| **Redis** | api-gateway, schedule | Session, countdown sync, queue |
| **Kafka** | api-gateway, schedule | Async task dispatch |
| **MinIO** | storage-service | Not directly needed |

### 4.2 External Services

| Service | Current Status | Needed for SOS |
|---------|---------------|----------------|
| **ZNS API** | 🟡 Not configured | ✅ Required |
| **Google Maps API** | ✅ Available | ✅ Required (client-side) |
| **SMS Provider** | ✅ Available (auth) | ⚠️ Fallback for ZNS |
| **CSKH API** | 🔴 Not exists | ✅ Required (new integration) |

---

## 5. Architecture Fit Assessment

### 5.1 Strong Fits ✅

| Capability | Architecture Support | Notes |
|------------|---------------------|-------|
| REST API endpoints | ✅ Excellent | api-gateway standard |
| Family contact management | ✅ Good | Existing FamilyRelationshipService |
| Notification sending | ✅ Good | notifications table + infrastructure |
| Background task execution | ✅ Excellent | Celery in schedule-service |
| Location management | ✅ Good | Existing patterns |
| Retry logic | ✅ Built-in | Celery retry mechanism |

### 5.2 Gaps / Extensions Needed 🟡

| Requirement | Gap | Proposed Solution |
|-------------|-----|-------------------|
| ZNS Integration | No client exists | Add ZNS client to schedule-service |
| CSKH API | No integration | Add HTTP client to api-gateway |
| Escalation automation | New workflow | Create Celery task chain |
| Real-time countdown sync | No WebSocket | Use Redis pub/sub or polling |
| SOS event tracking | No table | Create new `sos_events` table |
| Offline queue | App-side | Mobile queue + backend sync |

### 5.3 Architecture Risks 🔴

| Risk | Severity | Mitigation |
|------|----------|------------|
| ZNS rate limits | 🟡 Medium | Implement rate limiting + retry |
| Server-client sync (5s tolerance) | 🟡 Medium | Server as source of truth |
| Escalation call automation | 🔴 High | May require native mobile integration |
| DND bypass for sound/haptic | 🔴 High | OS-level permissions (mobile app) |

---

## 6. Recommended Service Responsibilities

| Service | SOS Responsibility |
|---------|-------------------|
| **Mobile App** | UI, countdown display, native phone calls, GPS, sound/haptic |
| **api-gateway** | REST endpoints, orchestration, initial validation |
| **user-service** | Family contacts, location storage, user config |
| **schedule-service** | Escalation flow, ZNS sending, offline queue processing |
| **Redis** | Countdown sync, session state, cooldown tracking |
| **PostgreSQL** | SOS events, audit logs |

---

## Next Phase

✅ **Phase 2: Context** - COMPLETE

➡️ **Phase 3: Requirements Extraction**
