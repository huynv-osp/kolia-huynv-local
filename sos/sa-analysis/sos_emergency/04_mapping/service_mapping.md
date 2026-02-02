# Service Mapping

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Mapping Date** | 2026-01-26 |

---

## 1. Requirements to Services Mapping

### 1.1 Primary Service Ownership

| FR ID | Requirement | Primary Service | Secondary Services |
|-------|-------------|-----------------|-------------------|
| FR-SOS-01 | SOS Entry Screen | **Mobile App** | - |
| FR-SOS-02 | SOS Countdown | **Mobile App** | api-gateway, Redis |
| FR-SOS-03 | Alert Sending | **schedule-service** | api-gateway, user-service |
| FR-SOS-04 | SOS Cancellation | **Mobile App** | api-gateway |
| FR-SOS-05 | Call 115 | **Mobile App** (Native) | - |
| FR-SOS-06 | Auto Escalation | **schedule-service** | Mobile App |
| FR-SOS-07 | Escalation Success | **schedule-service** | - |
| FR-SOS-08 | Escalation During 115 | **schedule-service** | Mobile App |
| FR-SOS-09 | Contact List | **Mobile App** | user-service |
| FR-SOS-10 | Hospital Map | **Mobile App** | Google Maps API |
| FR-SOS-11 | First Aid | **Mobile App** | api-gateway (CMS) |
| FR-SOS-12 | SOS Offline | **Mobile App** | schedule-service |
| FR-SOS-13 | Airplane Mode | **Mobile App** | - |
| FR-SOS-14 | Low Battery | **Mobile App** | schedule-service |
| FR-SOS-15 | Cooldown | **api-gateway** | Redis |
| FR-SOS-16 | ZNS Retry | **schedule-service** | - |
| FR-SOS-17 | GPS Timeout | **Mobile App** | - |
| FR-SOS-18 | Server Timeout | **Mobile App** | schedule-service |

---

## 2. Service Responsibility Matrix

### 2.1 api-gateway-service

| Responsibility | Type | New/Existing |
|----------------|------|:------------:|
| REST endpoint: `POST /api/sos/activate` | Endpoint | 🆕 NEW |
| REST endpoint: `POST /api/sos/cancel` | Endpoint | 🆕 NEW |
| REST endpoint: `GET /api/sos/status/{eventId}` | Endpoint | 🆕 NEW |
| REST endpoint: `POST /api/sos/confirm-received` | Endpoint | 🆕 NEW |
| REST endpoint: `GET /api/sos/contacts` | Endpoint | 🆕 NEW |
| REST endpoint: `GET /api/sos/first-aid` | Endpoint | 🆕 NEW |
| gRPC call to user-service for contacts | Integration | 🆕 NEW |
| Kafka publish for SOS events | Integration | ✅ Existing pattern |
| Redis cooldown tracking | Integration | 🆕 NEW |
| CSKH API integration | Integration | 🆕 NEW |

**Estimated Changes:** ~8 new controllers/handlers, ~5 new service classes

### 2.2 user-service

| Responsibility | Type | New/Existing |
|----------------|------|:------------:|
| Get emergency contacts list | gRPC RPC | 🆕 NEW |
| Store user location on SOS | gRPC RPC | 🔄 EXTEND |
| Create SOS notification | gRPC RPC | 🔄 EXTEND |
| Family relationship query | gRPC RPC | ✅ Existing |

**Estimated Changes:** ~3 new gRPC methods, ~2 new repository methods

### 2.3 schedule-service

| Responsibility | Type | New/Existing |
|----------------|------|:------------:|
| Celery task: `send_sos_alerts` | Task | 🆕 NEW |
| Celery task: `execute_escalation` | Task | 🆕 NEW |
| Celery task: `retry_failed_zns` | Task | 🆕 NEW |
| Celery task: `process_offline_queue` | Task | 🆕 NEW |
| ZNS API client | Integration | 🆕 NEW |
| Kafka consumer for SOS events | Consumer | 🆕 NEW |

**Estimated Changes:** ~6 new Celery tasks, ~2 new clients

### 2.4 Mobile App (Kolia)

| Responsibility | Type | New/Existing |
|----------------|------|:------------:|
| SOS Entry Screen (SOS-00) | Screen | 🆕 NEW |
| SOS Main Screen (SOS-01) | Screen | 🆕 NEW |
| SOS Support Dashboard (SOS-02) | Screen | 🆕 NEW |
| Contact List Screen (SOS-03) | Screen | 🆕 NEW |
| Hospital Map Screen (SOS-04) | Screen | 🆕 NEW |
| First Aid Screen (SOS-05) | Screen | 🆕 NEW |
| First Aid Detail Screens (SOS-05a-d) | Screen | 🆕 NEW |
| Error State Screens (ERR-01 to ERR-06) | Screen | 🆕 NEW |
| Countdown UI component | Component | 🆕 NEW |
| Sound/Haptic manager | Utility | 🆕 NEW |
| Offline queue manager | Utility | 🆕 NEW |
| Native phone call integration | Integration | 🆕 NEW |
| Zalo deep link integration | Integration | 🆕 NEW |
| Google Maps SDK | Integration | ✅ Existing |

**Estimated Changes:** ~10 new screens, ~5 new components, ~3 utilities

---

## 3. API Endpoint Mapping

### 3.1 New REST Endpoints (api-gateway)

#### POST /api/v1/sos/trigger
```yaml
Request:
  headers:
    Authorization: Bearer {jwt}
  body:
    latitude: number (optional)
    longitude: number (optional)
    location_accuracy_m: number (optional)
    battery_level_percent: number (optional)
    is_offline_triggered: boolean (default: false)
    device_info: object (optional)

Response:
  success:
    event_id: uuid
    countdown_seconds: number (30 or 10)
    countdown_started_at: timestamp
    status: "PENDING"
    contacts_count: number  # 0 = CSKH only per BR-SOS-024
  error:
    code: "COOLDOWN_ACTIVE" | "SERVER_ERROR"
    message: string
    retry_after_seconds: number (max 1800 for 30-min cooldown)
  # NOTE: CONTACTS_REQUIRED removed per SRS v1.8 BR-SOS-024 - SOS allowed with 0 contacts
```

#### POST /api/v1/sos/cancel
```yaml
Request:
  headers:
    Authorization: Bearer {jwt}
  body:
    event_id: uuid
    cancellation_reason: string (optional)

Response:
  success:
    event_id: uuid
    status: "CANCELLED"
  error:
    code: "EVENT_NOT_FOUND" | "ALREADY_COMPLETED" | "SERVER_ERROR"
```

#### GET /api/v1/sos/status/{eventId}
```yaml
Request:
  headers:
    Authorization: Bearer {jwt}
  params:
    eventId: uuid

Response:
  success:
    event_id: uuid
    status: "PENDING" | "COMPLETED" | "CANCELLED" | "FAILED"
    countdown_remaining_seconds: number (if PENDING)
    notifications_sent: number
    escalation_status: object (if started)
```

#### POST /api/v1/sos/confirm-received
```yaml
Request:
  headers:
    Authorization: Bearer {jwt}
  body:
    event_id: uuid
    contact_id: uuid
    confirmation_type: "ANSWERED_CALL" | "ACKNOWLEDGED"

Response:
  success:
    escalation_stopped: boolean
```

#### GET /api/v1/sos/contacts
```yaml
Request:
  headers:
    Authorization: Bearer {jwt}

Response:
  success:
    contacts:
      - contact_id: uuid
        name: string
        phone: string
        relationship: string
        priority: number
        zalo_enabled: boolean
    count: number
```

#### GET /api/v1/sos/first-aid
```yaml
Request:
  headers:
    Authorization: Bearer {jwt}
  query:
    category: string (optional, specific category)
    version_after: number (optional, for sync)

Response:
  success:
    categories:
      - category: "cpr" | "stroke" | "low_sugar" | "fall"
        title: string
        content: markdown
        icon_name: string
    version: number
```

---

## 4. gRPC Mapping

### 4.1 New RPC Methods (user-service)

```protobuf
// user_service.proto additions

service EmergencyContactService {
  // Get user's emergency contacts for SOS
  rpc GetEmergencyContacts(GetEmergencyContactsRequest) returns (GetEmergencyContactsResponse);
  
  // Add/Update emergency contact
  rpc UpsertEmergencyContact(UpsertEmergencyContactRequest) returns (EmergencyContact);
  
  // Delete emergency contact
  rpc DeleteEmergencyContact(DeleteEmergencyContactRequest) returns (google.protobuf.Empty);
}

message GetEmergencyContactsRequest {
  string user_id = 1;
}

message GetEmergencyContactsResponse {
  repeated EmergencyContact contacts = 1;
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
```

### 4.2 Existing RPC Extensions

```protobuf
// Extend UserService for location storage
rpc StoreSOSLocation(StoreSOSLocationRequest) returns (google.protobuf.Empty);

message StoreSOSLocationRequest {
  string user_id = 1;
  string event_id = 2;
  double latitude = 3;
  double longitude = 4;
  double accuracy_m = 5;
  google.protobuf.Timestamp location_time = 6;
  string source = 7; // gps, cell_tower, last_known
}
```

---

## 5. Kafka Topics

### 5.1 New Topics Required

| Topic | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `sos-events` | api-gateway | schedule-service | SOS activation events |
| `sos-notifications` | schedule-service | notification-worker | ZNS/SMS dispatch |
| `sos-escalation` | schedule-service | schedule-service | Escalation coordination |

### 5.2 Message Schemas

```json
// sos-events topic
{
  "event_id": "uuid",
  "user_id": "uuid",
  "event_type": "ACTIVATED" | "CANCELLED" | "COUNTDOWN_COMPLETE",
  "latitude": 10.762622,
  "longitude": 106.660172,
  "battery_level": 85,
  "countdown_seconds": 30,
  "timestamp": "2026-01-26T10:00:00Z"
}

// sos-notifications topic
{
  "notification_id": "uuid",
  "event_id": "uuid",
  "recipient_phone": "0901234567",
  "recipient_name": "Nguyễn Văn A",
  "channel": "ZNS" | "SMS" | "PUSH",
  "template_id": "sos_alert_v1",
  "variables": {
    "patient_name": "Trần Thị B",
    "timestamp": "10:30 26/01/2026",
    "location_link": "https://maps.google.com/..."
  },
  "retry_count": 0
}
```

---

## 6. Integration Points

### 6.1 External APIs

| Integration | Service | Protocol | New/Existing |
|-------------|---------|----------|:------------:|
| **ZNS API** | schedule-service | HTTPS | 🆕 NEW |
| **CSKH API** | api-gateway | HTTPS | 🆕 NEW |
| **Google Maps Places** | Mobile App | SDK | ✅ Existing |
| **SMS Provider** | schedule-service | HTTPS | ✅ Existing (fallback) |

### 6.2 ZNS Integration Details

```yaml
ZNS_API:
  base_url: https://zns.zalo.me/api
  authentication: OAuth2 Bearer Token
  rate_limit: 500 msg/hour (Business account)
  
  templates:
    - id: sos_alert_v1
      name: "SOS Alert Primary"
      variables: [patient_name, timestamp, location_link, phone]
    
    - id: sos_escalation_v1
      name: "SOS Escalation"
      variables: [patient_name, timestamp, location_link, phone]
```

### 6.3 CSKH API Details

```yaml
CSKH_API:
  base_url: https://cskh.alio.vn/api/v1
  authentication: API Key
  
  endpoints:
    - POST /alerts/sos
      body:
        user_id: uuid
        event_id: uuid
        patient_name: string
        patient_phone: string
        location: { lat, lng }
        triggered_at: timestamp
        alert_type: "auto" | "escalation_failed"
```

---

## 7. Mapping Summary

| Component | New Items | Modified Items | Total Changes |
|-----------|:---------:|:--------------:|:-------------:|
| api-gateway endpoints | 6 | 0 | 6 |
| user-service gRPC | 4 | 1 | 5 |
| schedule-service tasks | 6 | 0 | 6 |
| Kafka topics | 3 | 0 | 3 |
| External integrations | 2 | 0 | 2 |
| Mobile screens | 16 | 0 | 16 |

---

## Next Phase

✅ **Phase 4: Service Mapping** - COMPLETE

➡️ **Phase 5: Feasibility Assessment**
