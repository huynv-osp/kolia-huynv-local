# ⭐ Implementation Tasks

## Feature Context

| Attribute | Value |
|-----------|-------|
| **Feature Name** | `sos_emergency` |
| **Total Tasks** | 32 |
| **Total Effort** | ~25 working days |
| **Sprint Recommendation** | 2-3 sprints (with overlap) |

---

## Task Summary by Service

| Service | Tasks | Effort (days) | Priority |
|---------|:-----:|:-------------:|:--------:|
| Database Migrations | 5 | 2 | 🔴 P0 |
| user-service | 4 | 3 | 🔴 P0 |
| api-gateway-service | 8 | 6 | 🔴 P0 |
| schedule-service | 8 | 6 | 🔴 P0 |
| Mobile App | 7 | 8 | 🟡 P1 |
| **TOTAL** | **32** | **~25 days** | - |

---

## Sprint Planning Recommendation

| Sprint | Focus | Tasks |
|--------|-------|-------|
| **Sprint 1** | Foundation | DB + user-service + api-gateway core |
| **Sprint 2** | Integration | schedule-service + ZNS + Mobile core |
| **Sprint 3** | Complete | Mobile remaining + E2E testing |

---

# 📦 DATABASE MIGRATIONS

---

## Task: DB-001 - Create user_emergency_contacts Table

### Service: database (user-service schema)
### Priority: 🔴 P0 (Critical Path)
### Estimated: 2h
### Dependencies: None

### Description
Tạo bảng lưu trữ emergency contacts cho mỗi user (max 5 contacts).

### Technical Scope
- [x] Migration script: `V{version}__create_user_emergency_contacts.sql`
- [x] Indexes: user_id + priority, unique (user_id, phone)
- [x] Constraints: priority 1-5, active status
- [x] Trigger: auto-update `updated_at`

### DDL
```sql
CREATE TABLE user_emergency_contacts (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relationship VARCHAR(50),
    priority SMALLINT NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    zalo_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_priority_range CHECK (priority BETWEEN 1 AND 5),
    UNIQUE (user_id, phone)
);

CREATE INDEX idx_emergency_contacts_user ON user_emergency_contacts (user_id, priority);
CREATE INDEX idx_emergency_contacts_active ON user_emergency_contacts (user_id) WHERE is_active = TRUE;
```

### Acceptance Criteria
- [x] Table created with all columns
- [x] Indexes created
- [x] Constraints enforced
- [x] Rollback script works

---

## Task: DB-002 - Create sos_events Table

### Service: database (schedule-service schema)
### Priority: 🔴 P0 (Critical Path)
### Estimated: 2h
### Dependencies: None

### Description
Tạo bảng tracking SOS events với partitioning monthly.

### Technical Scope
- [x] Migration script
- [x] Partitioning by `triggered_at`
- [x] Indexes: user + time, status, cooldown
- [x] Retention: 90 days (partition drop)

### Acceptance Criteria
- [x] Table created with partitioning
- [x] Default partition exists
- [x] Indexes optimized for queries

---

## Task: DB-003 - Create sos_notifications Table

### Service: database (schedule-service schema)
### Priority: 🔴 P0 (Critical Path)
### Estimated: 2h
### Dependencies: DB-002

### Description
Tạo bảng tracking notifications (ZNS/SMS) sent per SOS event.

### Technical Scope
- [x] Migration script
- [x] FK to sos_events
- [x] Partitioning by `created_at`
- [x] Indexes: event_id, status for retry

---

## Task: DB-004 - Create sos_escalation_calls Table

### Service: database (schedule-service schema)
### Priority: 🔴 P0 (Critical Path)
### Estimated: 1h
### Dependencies: DB-002

### Description
Tạo bảng tracking escalation calls per SOS event.

---

## Task: DB-005 - Create first_aid_content Table

### Service: database (schedule-service/CMS schema)
### Priority: 🟡 P1
### Estimated: 1h
### Dependencies: None

### Description
Tạo bảng CMS cho First Aid content (4 categories).

### Seed Data
```sql
INSERT INTO first_aid_content (category, title, icon_name, display_order) VALUES
('cpr', 'Hồi sinh tim phổi (CPR)', 'heart_plus', 1),
('stroke', 'Đột quỵ (F.A.S.T)', 'brain', 2),
('low_sugar', 'Hạ đường huyết', 'sugar', 3),
('fall', 'Té ngã', 'fall', 4);
```

---

# 📦 USER-SERVICE

---

## Task: US-001 - Create EmergencyContact Proto

### Service: user-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 2h
### Dependencies: DB-001

### Description
Định nghĩa proto file cho EmergencyContactService.

### Technical Scope
- [x] File: `emergency_contact_service.proto`
- [x] Service: `EmergencyContactService`
- [x] Messages: `EmergencyContact`, `GetEmergencyContactsRequest/Response`
- [x] RPCs: Get, Upsert, Delete

### Proto Definition
```protobuf
syntax = "proto3";
package user;

service EmergencyContactService {
  rpc GetEmergencyContacts(GetEmergencyContactsRequest) returns (GetEmergencyContactsResponse);
  rpc UpsertEmergencyContact(UpsertEmergencyContactRequest) returns (EmergencyContact);
  rpc DeleteEmergencyContact(DeleteEmergencyContactRequest) returns (google.protobuf.Empty);
}

message EmergencyContact {
  string contact_id = 1;
  string name = 2;
  string phone = 3;
  string relationship = 4;
  int32 priority = 5;
  bool is_active = 6;
  bool zalo_enabled = 7;
}

message GetEmergencyContactsRequest {
  string user_id = 1;
}

message GetEmergencyContactsResponse {
  repeated EmergencyContact contacts = 1;
}
```

### Acceptance Criteria
- [x] Proto compiles successfully
- [x] Java stubs generated
- [x] Consistent with existing proto style

---

## Task: US-002 - Implement EmergencyContactRepository

### Service: user-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 3h
### Dependencies: US-001, DB-001

### Description
Implement repository layer for emergency contacts.

### Technical Scope
- [x] Entity: `EmergencyContactEntity`
- [x] Repository: `EmergencyContactRepository`
- [x] Methods: findByUserId, findByUserIdAndPriority, save, delete
- [x] Vert.x async patterns

### Related Files
- `user-service/src/main/java/com/alio/user/entity/EmergencyContactEntity.java`
- `user-service/src/main/java/com/alio/user/repository/EmergencyContactRepository.java`

### Acceptance Criteria
- [x] CRUD operations work
- [x] Pagination support
- [x] Error handling

---

## Task: US-003 - Implement EmergencyContactService

### Service: user-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 4h
### Dependencies: US-002

### Description
Business logic layer for emergency contact management.

### Technical Scope
- [x] Validation: max 5 contacts, phone format, priority range
- [x] Duplicate phone check
- [x] Priority reordering on insert/delete
- [x] Cache integration (optional)

### Acceptance Criteria
- [x] Max 5 contacts per user enforced
- [x] Validation errors with clear messages
- [x] Priority order maintained

---

## Task: US-004 - Implement EmergencyContactGrpcService

### Service: user-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 3h
### Dependencies: US-003

### Description
gRPC service implementation exposing emergency contact operations.

### Technical Scope
- [x] Implement: `EmergencyContactServiceGrpc`
- [x] Integration with `EmergencyContactService`
- [x] Error mapping to gRPC status codes
- [x] Unit tests

### Acceptance Criteria
- [x] All RPCs working
- [x] Error codes correct
- [x] Integration test passes

---

# 📦 API-GATEWAY-SERVICE

---

## Task: GW-001 - Create SOS REST Endpoints

### Service: api-gateway-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 4h
### Dependencies: None

### Description
Implement SOS core REST endpoints.

### Endpoints
| POST | `/api/sos/activate` | Start SOS countdown |
| POST | `/api/sos/cancel` | Cancel SOS |
| GET | `/api/sos/status/{eventId}` | Get SOS status |

> **Note:** Bypass endpoint removed in SRS v1.8

### Technical Scope
- [x] Controller: `SOSController`
- [x] Handler: `SOSHandler` (Vert.x)
- [x] Request/Response DTOs
- [x] OpenAPI annotations

### Related Files
- `api-gateway-service/src/main/java/com/alio/gateway/controller/SOSController.java`
- `api-gateway-service/src/main/java/com/alio/gateway/handler/SOSHandler.java`
- `api-gateway-service/src/main/java/com/alio/gateway/dto/sos/*`

### API Contract
```json
// POST /api/sos/activate
{
  "request": {
    "latitude": 10.762622,
    "longitude": 106.660172,
    "battery_level_percent": 85,
    "is_offline_triggered": false
  },
  "response": {
    "event_id": "uuid",
    "countdown_seconds": 30,
    "countdown_started_at": "2026-01-26T10:00:00Z",
    "status": "PENDING"
  }
}
```

### Acceptance Criteria
- [x] All 4 endpoints working
- [x] JWT auth required
- [x] Validation errors handled
- [x] OpenAPI docs generated

---

## Task: GW-002 - Implement Cooldown Service

### Service: api-gateway-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 3h
### Dependencies: GW-001

### Description
Implement 30-minute cooldown tracking using Redis. NO bypass allowed per SRS v1.8.

### Technical Scope
- [x] Service: `CooldownService`
- [x] Redis key pattern: `sos:cooldown:{userId}`
- [x] TTL: 30 minutes (1800 seconds)
- [ ] ~~Bypass flag storage~~ (Removed in v1.8)

### Redis Operations
```java
// Check cooldown
GET sos:cooldown:{userId}  // Returns last SOS timestamp

// Set cooldown
SETEX sos:cooldown:{userId} 1800 {timestamp}  // 30 minutes TTL

// NO bypass per SRS v1.8 - user must wait full 30 minutes
```

### Acceptance Criteria
- [x] 30-min cooldown enforced correctly
- [ ] ~~Bypass works~~ (Removed)
- [x] Redirect to Dashboard if in cooldown
- [x] Redis errors handled gracefully

---

## Task: GW-003 - Create Emergency Contact REST Endpoints

### Service: api-gateway-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 3h
### Dependencies: US-004

### Description
REST endpoints for emergency contact management.

### Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/sos/contacts` | List contacts |
| POST | `/api/sos/contacts` | Add contact |
| PUT | `/api/sos/contacts/{id}` | Update contact |
| DELETE | `/api/sos/contacts/{id}` | Delete contact |

### Technical Scope
- [x] Controller: `EmergencyContactController`
- [x] gRPC client to user-service
- [x] Request validation

### Acceptance Criteria
- [x] All 4 CRUD endpoints working
- [x] gRPC integration tested

---

## Task: GW-004 - Implement gRPC Client for EmergencyContacts

### Service: api-gateway-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 2h
### Dependencies: US-004

### Description
gRPC client để gọi user-service cho emergency contacts.

### Technical Scope
- [x] Client: `EmergencyContactGrpcClient`
- [x] Channel configuration
- [x] Error handling + retry

---

## Task: GW-005 - Create First Aid REST Endpoint

### Service: api-gateway-service
### Priority: 🟡 P1
### Estimated: 2h
### Dependencies: DB-005

### Description
REST endpoint để get First Aid content cho mobile caching.

### Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/sos/first-aid` | Get all categories |
| GET | `/api/sos/first-aid?category={cat}` | Filter by category |

---

## Task: GW-006 - Implement SOS Event Kafka Producer

### Service: api-gateway-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 3h
### Dependencies: GW-001

### Description
Kafka producer để publish SOS events cho schedule-service.

### Technical Scope
- [x] Producer: `SOSEventProducer`
- [x] Topic: `sos-events`
- [x] Message schema: SOSEventMessage

### Message Schema
```json
{
  "event_id": "uuid",
  "user_id": "uuid",
  "event_type": "ACTIVATED",
  "latitude": 10.762622,
  "longitude": 106.660172,
  "battery_level": 85,
  "countdown_seconds": 30,
  "timestamp": "2026-01-26T10:00:00Z"
}
```

---

## Task: GW-007 - Implement CSKH API Client

### Service: api-gateway-service
### Priority: 🟡 P1
### Estimated: 3h
### Dependencies: GW-001

### Description
HTTP client để gửi alerts đến CSKH system.

### Technical Scope
- [x] Client: `CSKHApiClient`
- [x] Authentication: API Key
- [x] Retry logic
- [x] Circuit breaker

### API Contract
```json
// POST https://cskh.alio.vn/api/v1/alerts/sos
{
  "request": {
    "user_id": "uuid",
    "event_id": "uuid",
    "patient_name": "Nguyễn Văn A",
    "patient_phone": "0901234567",
    "location": {"lat": 10.762622, "lng": 106.660172},
    "triggered_at": "2026-01-26T10:00:00Z",
    "alert_type": "auto"
  }
}
```

---

## Task: GW-008 - Add Countdown Sync Endpoint

### Service: api-gateway-service
### Priority: 🟡 P1
### Estimated: 2h
### Dependencies: GW-001, GW-002

### Description
Endpoint for mobile to sync countdown with server.

### Technical Scope
- [x] Use Redis for server-side countdown tracking
- [x] Return remaining seconds
- [x] Handle clock drift

---

# 📦 SCHEDULE-SERVICE

---

## Task: SS-001 - Create SOS Celery Tasks Module

### Service: schedule-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 2h
### Dependencies: None

### Description
Setup module structure cho SOS tasks.

### Technical Scope
- [x] Module: `schedule_service/tasks/sos/`
- [x] Files: `__init__.py`, `send_alerts.py`, `escalation.py`
- [x] Celery queue: `sos_critical`, `sos_normal`

### File Structure
```
schedule_service/
└── tasks/
    └── sos/
        ├── __init__.py
        ├── send_alerts.py
        ├── escalation.py
        ├── offline_queue.py
        └── cleanup.py
```

---

## Task: SS-002 - Implement SOS Kafka Consumer

### Service: schedule-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 3h
### Dependencies: SS-001

### Description
Kafka consumer để nhận SOS events từ api-gateway.

### Technical Scope
- [x] Consumer: `SOSEventConsumer`
- [x] Topic: `sos-events`
- [x] Trigger Celery tasks on event

### Acceptance Criteria
- [x] Consume messages successfully
- [x] Handle malformed messages
- [x] Trigger correct task based on event_type

---

## Task: SS-003 - Implement send_sos_alerts Task

### Service: schedule-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 4h
### Dependencies: SS-001, SS-002

### Description
Celery task gửi ZNS đến tất cả emergency contacts.

### Technical Scope
- [x] Task: `send_sos_alerts`
- [x] Queue: `sos_critical`
- [x] Parallel ZNS sending
- [x] Track status in `sos_notifications`

### Pseudo Code
```python
@shared_task(bind=True, queue='sos_critical', max_retries=3)
def send_sos_alerts(self, event_id: str, user_id: str, location: dict):
    # 1. Get emergency contacts from user-service
    contacts = grpc_client.get_emergency_contacts(user_id)
    
    # 2. Send ZNS to ALL contacts in parallel
    for contact in contacts:
        notification = create_notification(event_id, contact)
        zns_result = zns_client.send(notification)
        save_notification_status(notification, zns_result)
    
    # 3. Alert CSKH
    cskh_client.send_alert(event_id, user_id, location)
    
    # 4. Trigger escalation if needed
    execute_escalation.delay(event_id, user_id, contacts)
```

### Acceptance Criteria
- [x] All contacts receive ZNS
- [x] Notifications tracked in DB
- [x] CSKH alerted
- [x] Retry on failure

---

## Task: SS-004 - Implement ZNS Client

### Service: schedule-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 4h
### Dependencies: None

### Description
HTTP client để gọi Zalo ZNS API.

### Technical Scope
- [x] Client: `ZNSClient`
- [x] OAuth2 authentication
- [x] Template sending
- [x] Rate limiting handling
- [x] Retry with backoff

### API Integration
```python
class ZNSClient:
    BASE_URL = "https://zns.zalo.me/api"
    
    async def send_template(
        self, 
        phone: str, 
        template_id: str, 
        variables: dict
    ) -> ZNSResult:
        # OAuth token refresh
        # Send template
        # Handle rate limits
        # Return result with message_id
```

### Templates
| Template ID | Name | Variables |
|-------------|------|-----------|
| `sos_alert_v1` | SOS Alert Primary | patient_name, timestamp, location_link, phone |
| `sos_escalation_v1` | SOS Escalation | patient_name, timestamp, location_link, phone |

---

## Task: SS-005 - Implement execute_escalation Task

### Service: schedule-service
### Priority: 🔴 P0 (Critical Path)
### Estimated: 5h
### Dependencies: SS-003

### Description
Celery task chain cho escalation flow (20s per contact).

### Technical Scope
- [x] Task: `execute_escalation`
- [x] Chained tasks với countdown
- [x] Track call status
- [x] Stop on success (contact answers)

### State Machine
```
PENDING → CALLING → CONNECTED (stop)
                  → NO_ANSWER → next contact
                  → BUSY → next contact
                  → REJECTED → next contact
```

### Acceptance Criteria
- [x] 20s timeout per contact
- [x] Sequential calling
- [x] Stop immediately on success
- [x] CSKH alert after all fail

---

## Task: SS-006 - Implement retry_failed_zns Task

### Service: schedule-service
### Priority: 🟡 P1
### Estimated: 2h
### Dependencies: SS-003, SS-004

### Description
Background task retry failed ZNS notifications.

### Technical Scope
- [x] Query `sos_notifications` with status=FAILED
- [x] Max 3 retries
- [x] 30s interval between retries
- [x] Alert CSKH after max retries

---

## Task: SS-007 - Implement process_offline_queue Task

### Service: schedule-service
### Priority: 🟡 P1
### Estimated: 3h
### Dependencies: SS-003

### Description
Process SOS events that were queued while offline.

### Technical Scope
- [x] Consume offline events from api-gateway
- [x] Process in order of original timestamp
- [x] Mark as synced after processing

---

## Task: SS-008 - Implement cleanup_sos_events Task

### Service: schedule-service
### Priority: 🟢 P2
### Estimated: 2h
### Dependencies: DB-002

### Description
Cleanup task để xóa SOS events older than 90 days.

### Technical Scope
- [x] Daily scheduled task
- [x] Drop old partitions
- [x] Archive if needed

---

# 📱 MOBILE APP

---

## Task: MOB-001 - Implement SOS Core Screens

### Service: mobile-app
### Priority: 🔴 P0 (Critical Path)
### Estimated: 8h
### Dependencies: GW-001

### Description
Implement 3 core SOS screens: Entry, Main (Countdown), Support Dashboard.

### Screens
| Screen | Components |
|--------|------------|
| SOS-00 Entry | Header, Description, Activate Button, Back Link |
| SOS-01 Main | Countdown Timer, Call 115, Cancel |
| SOS-02 Dashboard | Success Header, Action Buttons |

### Technical Scope
- [x] CountdownTimer component with animation
- [x] Sound/Haptic escalating feedback
- [x] DND bypass implementation
- [x] State management

### Acceptance Criteria
- [x] Countdown UI accurate
- [x] Sound plays (bypass DND if possible)
- [x] Transitions smooth
- [x] Works offline for native calls

---

## Task: MOB-002 - Implement Offline Queue Manager

### Service: mobile-app
### Priority: 🔴 P0 (Critical Path)
### Estimated: 6h
### Dependencies: MOB-001

### Description
SQLite-based offline queue for SOS events.

### Technical Scope
- [x] SQLite database on device
- [x] Queue SOS with timestamp + location
- [x] Auto-sync when online
- [x] Retry logic (3 times, 30s interval)

### Acceptance Criteria
- [x] SOS queued when offline
- [x] Auto-send on reconnect
- [x] Retry works correctly

---

## Task: MOB-003 - Implement Contact List Screen

### Service: mobile-app
### Priority: 🟡 P1
### Estimated: 4h
### Dependencies: GW-003

### Description
Display emergency contacts with call/Zalo actions.

### Screens
| Screen | Components |
|--------|------------|
| SOS-03 | Contact Cards, Phone Button, Zalo Button |

### Technical Scope
- [x] Fetch contacts from API
- [x] Native phone integration
- [x] Zalo deep link (detect installation)
- [x] Track manual calls for escalation skip

---

## Task: MOB-004 - Implement Hospital Map Screen

### Service: mobile-app
### Priority: 🟡 P1
### Estimated: 6h
### Dependencies: None

### Description
Google Maps integration showing nearby hospitals.

### Screens
| Screen | Components |
|--------|------------|
| SOS-04 | Map, Hospital Markers, Bottom Sheet |

### Technical Scope
- [x] Google Maps SDK
- [x] Places API for hospitals
- [x] Current location
- [x] Navigation deep link

### Acceptance Criteria
- [x] Map loads within 3s
- [x] Hospitals displayed
- [x] Navigation works
- [x] Empty state for no results

---

## Task: MOB-005 - Implement First Aid Screens

### Service: mobile-app
### Priority: 🟡 P1
### Estimated: 4h
### Dependencies: GW-005

### Description
First Aid categories and detail screens (offline-capable).

### Screens
| Screen | Description |
|--------|-------------|
| SOS-05 | Category list |
| SOS-05a-d | Detail screens |

### Technical Scope
- [x] Fetch and cache content
- [x] Markdown rendering
- [x] Offline support
- [x] Disclaimer display

---

## Task: MOB-006 - Implement Error State Screens

### Service: mobile-app
### Priority: 🟡 P1
### Estimated: 3h
### Dependencies: MOB-001

### Description
Error handling screens for various failure modes.

### Screens
| Screen | Trigger |
|--------|---------|
| ERR-01 | Offline |
| ERR-02 | Airplane mode |
| ERR-03 | Cooldown modal |
| ERR-04 | Loading state |
| ERR-05 | Hospital empty |
| ERR-06 | First aid empty |

---

## Task: MOB-007 - Implement SOS API Service

### Service: mobile-app
### Priority: 🔴 P0 (Critical Path)
### Estimated: 4h
### Dependencies: GW-001

### Description
API service layer for all SOS backend calls.

### Technical Scope
- [x] SOSApiService class
- [x] Token refresh handling
- [x] Error mapping
- [x] Offline detection

### Endpoints
```typescript
interface SOSApiService {
  activate(request: ActivateRequest): Promise<ActivateResponse>;
  cancel(eventId: string): Promise<void>;
  getStatus(eventId: string): Promise<SOSStatus>;
  bypassCooldown(request: ActivateRequest): Promise<ActivateResponse>;
  getContacts(): Promise<EmergencyContact[]>;
  getFirstAid(): Promise<FirstAidContent[]>;
}
```

---

# 📋 TASK SUMMARY

## All Tasks by Priority

### P0 - Critical Path (Must have for Phase 1)

| Task ID | Task | Service | Effort |
|---------|------|---------|:------:|
| DB-001 | user_emergency_contacts table | DB | 2h |
| DB-002 | sos_events table | DB | 2h |
| DB-003 | sos_notifications table | DB | 2h |
| DB-004 | sos_escalation_calls table | DB | 1h |
| US-001 | EmergencyContact Proto | user-service | 2h |
| US-002 | EmergencyContactRepository | user-service | 3h |
| US-003 | EmergencyContactService | user-service | 4h |
| US-004 | EmergencyContactGrpcService | user-service | 3h |
| GW-001 | SOS REST Endpoints | api-gateway | 4h |
| GW-002 | Cooldown Service | api-gateway | 3h |
| GW-003 | Contact REST Endpoints | api-gateway | 3h |
| GW-004 | gRPC Client | api-gateway | 2h |
| GW-006 | Kafka Producer | api-gateway | 3h |
| SS-001 | SOS Tasks Module | schedule | 2h |
| SS-002 | Kafka Consumer | schedule | 3h |
| SS-003 | send_sos_alerts Task | schedule | 4h |
| SS-004 | ZNS Client | schedule | 4h |
| SS-005 | execute_escalation Task | schedule | 5h |
| MOB-001 | SOS Core Screens | mobile | 8h |
| MOB-002 | Offline Queue Manager | mobile | 6h |
| MOB-007 | SOS API Service | mobile | 4h |

### P1 - High Priority (Phase 2)

| Task ID | Task | Service | Effort |
|---------|------|---------|:------:|
| DB-005 | first_aid_content table | DB | 1h |
| GW-005 | First Aid Endpoint | api-gateway | 2h |
| GW-007 | CSKH API Client | api-gateway | 3h |
| GW-008 | Countdown Sync | api-gateway | 2h |
| SS-006 | retry_failed_zns Task | schedule | 2h |
| SS-007 | process_offline_queue Task | schedule | 3h |
| MOB-003 | Contact List Screen | mobile | 4h |
| MOB-004 | Hospital Map Screen | mobile | 6h |
| MOB-005 | First Aid Screens | mobile | 4h |
| MOB-006 | Error State Screens | mobile | 3h |

### P2 - Nice to Have (Phase 3)

| Task ID | Task | Service | Effort |
|---------|------|---------|:------:|
| SS-008 | cleanup_sos_events Task | schedule | 2h |

---

## Next Phase

✅ **Phase 5: Implementation Tasks** - COMPLETE

➡️ **Phase 6: Dependency & Sequence Planning**
