# 🔧 Service Decomposition

## Feature Context

| Attribute | Value |
|-----------|-------|
| **Feature Name** | `sos_emergency` |
| **Services Affected** | 4 |
| **Decomposition Date** | 2026-01-26 |

---

## 1. Service Responsibility Matrix

### Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SOS FEATURE - SERVICE DECOMPOSITION                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    MOBILE APP (Kolia)                            │    │
│  │  • 16 screens (SOS-00 to SOS-05d, ERR-01 to ERR-06)             │    │
│  │  • Offline queue manager                                         │    │
│  │  • Sound/Haptic manager                                          │    │
│  │  • Native phone/Zalo integration                                 │    │
│  └─────────────────────────┬───────────────────────────────────────┘    │
│                            │ REST API                                    │
│  ┌─────────────────────────▼───────────────────────────────────────┐    │
│  │                  API-GATEWAY-SERVICE                              │    │
│  │  • 10 REST endpoints                                              │    │
│  │  • Cooldown tracking (Redis)                                      │    │
│  │  • CSKH API integration                                           │    │
│  │  • Kafka producer (SOS events)                                    │    │
│  └───────┬───────────────────────────────────────┬─────────────────┘    │
│          │ gRPC                                   │ Kafka                │
│  ┌───────▼───────────────┐              ┌────────▼────────────────┐    │
│  │    USER-SERVICE       │              │   SCHEDULE-SERVICE      │    │
│  │  • Emergency contacts │              │  • SOS alert sending    │    │
│  │  • Location storage   │              │  • ZNS integration      │    │
│  │  • Notifications      │              │  • Escalation flow      │    │
│  └───────────────────────┘              │  • Offline queue proc   │    │
│                                         └─────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mobile App Decomposition

### 2.1 Screens (16 total)

| Module | Screen ID | Screen Name | Complexity |
|--------|-----------|-------------|:----------:|
| **SOS Core** | SOS-00 | SOS Entry | 🟢 Low |
| **SOS Core** | SOS-01 | SOS Main (Countdown) | 🔴 High |
| **SOS Core** | SOS-02 | SOS Support Dashboard | 🟡 Medium |
| **Contacts** | SOS-03 | Contact List | 🟡 Medium |
| **Hospital** | SOS-04 | Hospital Map | 🟡 Medium |
| **First Aid** | SOS-05 | First Aid Categories | 🟡 Medium |
| **First Aid** | SOS-05a | First Aid - CPR | 🟢 Low |
| **First Aid** | SOS-05b | First Aid - Stroke | 🟢 Low |
| **First Aid** | SOS-05c | First Aid - Low Sugar | 🟢 Low |
| **First Aid** | SOS-05d | First Aid - Fall | 🟢 Low |
| **Errors** | ERR-01 | Offline State | 🟡 Medium |
| **Errors** | ERR-02 | Airplane Mode | 🟢 Low |
| **Errors** | ERR-03 | Cooldown Modal | 🟢 Low |
| **Errors** | ERR-04 | Loading State | 🟢 Low |
| **Errors** | ERR-05 | Hospital Empty | 🟢 Low |
| **Errors** | ERR-06 | First Aid Empty | 🟢 Low |

### 2.2 Components & Utilities

| Type | Name | Description |
|------|------|-------------|
| Component | `CountdownTimer` | Circular countdown with animation |
| Component | `SOSButton` | Floating action button |
| Component | `ContactCard` | Emergency contact display |
| Component | `HospitalMarker` | Map marker with bottom sheet |
| Component | `FirstAidCard` | Category card with icon |
| Utility | `SoundManager` | DND bypass, escalating feedback |
| Utility | `HapticManager` | Vibration patterns |
| Utility | `OfflineQueueManager` | SQLite queue + retry |
| Utility | `BatteryMonitor` | Battery level detection |
| Service | `SOSApiService` | API calls to backend |
| Service | `LocationService` | GPS + cell tower |

---

## 3. API-Gateway-Service Decomposition

### 3.1 Controllers/Handlers

| Controller | Endpoints | Responsibility |
|------------|:---------:|----------------|
| `SOSController` | 4 | Activate, cancel, status, confirm |
| `EmergencyContactController` | 4 | CRUD contacts |
| `FirstAidController` | 2 | Get content, sync |

### 3.2 Services

| Service | Responsibility |
|---------|----------------|
| `SOSService` | SOS lifecycle management |
| `CooldownService` | 30-min cooldown tracking (no bypass per v1.8) |
| `SOSEventPublisher` | Kafka producer |
| `CSKHClient` | External CSKH API calls |

### 3.3 Integrations

| Integration | Type | Target |
|-------------|:----:|--------|
| EmergencyContactGrpcClient | gRPC | user-service |
| SOSEventProducer | Kafka | schedule-service |
| RedisClient | Cache | Cooldown, countdown sync |
| CSKHHttpClient | HTTP | CSKH API |

---

## 4. User-Service Decomposition

### 4.1 gRPC Services

| Service | RPCs | Responsibility |
|---------|:----:|----------------|
| `EmergencyContactService` | 4 | CRUD emergency contacts |

**RPC Methods:**
- `GetEmergencyContacts` - List user's contacts
- `UpsertEmergencyContact` - Create/update contact
- `DeleteEmergencyContact` - Remove contact
- `GetContactByPhone` - Lookup by phone

### 4.2 Domain Layer

| Component | Type | Responsibility |
|-----------|------|----------------|
| `EmergencyContact` | Entity | Contact data model |
| `EmergencyContactRepository` | Repository | Database access |
| `EmergencyContactService` | Service | Business logic |

### 4.3 Database

| Table | Operation |
|-------|-----------|
| `user_emergency_contacts` | NEW table |

---

## 5. Schedule-Service Decomposition

### 5.1 Celery Tasks

| Task | Queue | Priority | Retry |
|------|-------|:--------:|:-----:|
| `send_sos_alerts` | sos_critical | 🔴 P1 | 3x |
| `execute_escalation` | sos_critical | 🔴 P1 | 3x |
| `process_escalation_step` | sos_normal | 🟡 P2 | 2x |
| `retry_failed_zns` | sos_retry | 🟡 P2 | 3x |
| `process_offline_queue` | sos_normal | 🟡 P2 | 3x |
| `cleanup_sos_events` | sos_cleanup | 🟢 P3 | 1x |

### 5.2 Kafka Consumers

| Consumer | Topic | Purpose |
|----------|-------|---------|
| `SOSEventConsumer` | sos-events | Receive activation events |
| `SOSNotificationConsumer` | sos-notifications | Track delivery status |

### 5.3 External Clients

| Client | Protocol | Target |
|--------|:--------:|--------|
| `ZNSClient` | HTTPS | Zalo ZNS API |
| `SMSClient` | HTTPS | SMS fallback provider |

### 5.4 Database

| Table | Operation |
|-------|-----------|
| `sos_events` | NEW table |
| `sos_notifications` | NEW table |
| `sos_escalation_calls` | NEW table |
| `first_aid_content` | NEW table |

---

## 6. Database Decomposition Summary

### 6.1 Table Ownership

| Service | Tables |
|---------|--------|
| user-service | `user_emergency_contacts` |
| schedule-service | `sos_events`, `sos_notifications`, `sos_escalation_calls`, `first_aid_content` |

### 6.2 Schema Overview

```sql
-- user-service DB
user_emergency_contacts (
  contact_id, user_id, name, phone, relationship, priority, 
  is_active, zalo_enabled, created_at, updated_at
)

-- schedule-service DB (or shared)
sos_events (
  event_id, user_id, triggered_at, trigger_source,
  latitude, longitude, location_accuracy_m, location_source,
  countdown_seconds, countdown_started_at, countdown_completed_at,
  status, cancelled_at, is_offline_triggered, battery_level_percent,
  device_info, created_at, updated_at
)

sos_notifications (
  notification_id, event_id, contact_id,
  recipient_name, recipient_phone, recipient_type, channel,
  template_id, message_content, status,
  sent_at, delivered_at, retry_count, error_code,
  created_at, updated_at
)

sos_escalation_calls (
  call_id, event_id, contact_id,
  contact_name, contact_phone, escalation_order, call_type,
  status, initiated_at, connected_at, ended_at, duration_seconds,
  created_at, updated_at
)

first_aid_content (
  content_id, category, title, content, display_order,
  icon_name, is_active, version, created_at, updated_at
)
```

---

## 7. Effort Estimation by Service

| Service | Components | Effort (days) | Confidence |
|---------|:----------:|:-------------:|:----------:|
| Mobile App | 16 screens, 5 utilities | 10-12 | 🟡 70% |
| api-gateway | 10 endpoints, 4 services | 5-6 | 🟢 80% |
| user-service | 4 RPCs, 1 table | 2-3 | 🟢 85% |
| schedule-service | 6 tasks, 2 clients, 4 tables | 5-6 | 🟡 75% |
| **TOTAL** | - | **22-27 days** | 🟡 75% |

---

## Next Phase

✅ **Phase 4: Service Decomposition** - COMPLETE

➡️ **Phase 5: Task Generation (Per Service)** ⭐
