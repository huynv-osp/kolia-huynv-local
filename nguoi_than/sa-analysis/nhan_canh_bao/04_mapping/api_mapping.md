# API Mapping: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-02  
> **Revision:** v1.5  
> **Source:** SRS-Nhận-Cảnh-Báo_v1.5

---

## REST API Endpoints (api-gateway-service)

### Alert Types Lookup

| Method | Path | Description | Auth | Note |
|:------:|------|-------------|:----:|------|
| GET | `/api/v1/connections/alerts/types` | List all alert types (4 categories) | ✅ | For FE filter dropdown |

> ℹ️ `caregiver_alert_types` là lookup table với 4 loại cố định (SOS, HA, MEDICATION, COMPLIANCE). Admin CRUD không cần thiết - data được seed qua migration.

### Alert Types Response

```json
GET /api/v1/connections/alerts/types

{
  "types": [
    {"type_id": 1, "type_code": "SOS", "name_vi": "Khẩn cấp", "name_en": "Emergency", "icon": "🚨", "display_order": 1},
    {"type_id": 2, "type_code": "HA", "name_vi": "Huyết áp", "name_en": "Blood Pressure", "icon": "❤️", "display_order": 2},
    {"type_id": 3, "type_code": "MEDICATION", "name_vi": "Thuốc", "name_en": "Medication", "icon": "💊", "display_order": 3},
    {"type_id": 4, "type_code": "COMPLIANCE", "name_vi": "Tuân thủ", "name_en": "Compliance", "icon": "📊", "display_order": 4}
  ]
}
```

---

### Alert Management

| Method | Path | Description | Auth | BR Reference |
|:------:|------|-------------|:----:|--------------:|
| GET | `/api/v1/connections/alerts` | List alerts (paginated, filterable by patientId) | ✅ | - |
| GET | `/api/v1/connections/alerts/{alertId}` | Alert detail | ✅ | - |
| POST | `/api/v1/connections/alerts/mark-read` | Mark selected as read | ✅ | - |
| POST | `/api/v1/connections/alerts/mark-all-read` | Mark all as read | ✅ | EC-18 |
| GET | `/api/v1/connections/alerts/unread-count` | Get badge count | ✅ | - |

### Query Parameters (GET /connections/alerts) ⭐ ENHANCED

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| patientId | UUID | - | Filter by patient (optional) |
| typeId | Int | - | Filter by alert_type_id (1=SOS, 2=HA, 3=MEDICATION, 4=COMPLIANCE) |
| periodDays | Int | `7` | Số ngày gần nhất: 0 (today), 7, 30, 90 |
| page | Int | 0 | Page number (0-indexed) |
| size | Int | 20 | Items per page (max 50) |
| status | Int | - | 0=unread, 1=read, null=all |

### Example Requests

```
# Get all alerts (default: 7 days, page 0, size 20)
GET /api/v1/connections/alerts

# Filter by HA category, last 30 days
GET /api/v1/connections/alerts?typeId=2&periodDays=30

# Filter by patient, today only, page 1
GET /api/v1/connections/alerts?patientId=abc123&periodDays=0&page=1

# Filter unread COMPLIANCE alerts
GET /api/v1/connections/alerts?typeId=4&status=0&page=2&size=20
```

### Paginated Response

```json
{
  "alerts": [
    {
      "alert_id": "uuid",
      "patient_id": "uuid",
      "patient_name": "Mẹ",
      "alert_type_id": 2,
      "alert_type_code": "HA",
      "priority": 1,
      "title": "Mẹ - HA 185/125 (THA khẩn cấp)",
      "body": null,
      "icon": "⚠️",
      "color": "red",
      "deeplink": "kolia://patient/{patient_id}/health-overview",
      "status": 0,
      "created_at": "2026-02-02T16:45:00+07:00",
      "payload": {"systolic": 185, "diastolic": 125, "note": "Đau đầu nhẹ"}
    }
  ],
  "pagination": {
    "page": 0,
    "size": 20,
    "total_items": 45,
    "total_pages": 3,
    "has_more": true
  },
  "summary": {
    "unread_count": 5,
    "total_count": 45
  }
}
```

---

## gRPC Methods (alert_service.proto)

### user-service → AlertService

```protobuf
service AlertService {
  // Create alert (internal, from schedule-service via Kafka callback)
  rpc CreateAlert(CreateAlertRequest) returns (AlertResponse);
  
  // Get alert history with pagination
  rpc GetAlertHistory(GetAlertHistoryRequest) returns (AlertHistoryResponse);
  
  // Get single alert detail
  rpc GetAlertDetail(GetAlertDetailRequest) returns (AlertDetailResponse);
  
  // Mark single alert as read
  rpc MarkAlertAsRead(MarkAlertAsReadRequest) returns (google.protobuf.Empty);
  
  // Mark all alerts as read
  rpc MarkAllAlertsAsRead(MarkAllAlertsAsReadRequest) returns (google.protobuf.Empty);
  
  // Get unread count for badge
  rpc GetUnreadCount(GetUnreadCountRequest) returns (UnreadCountResponse);
}
```

### Messages

```protobuf
message CreateAlertRequest {
  string caregiver_id = 1;
  string patient_id = 2;
  int32 alert_type_id = 3;
  int32 priority = 4;
  string title = 5;
  string body = 6;
  string icon = 7;
  string color = 8;
  string deeplink = 9;
  string payload_json = 10;  // JSON string
  string source_type = 11;
  int64 source_id = 12;
}

message AlertInfo {
  string alert_id = 1;
  string caregiver_id = 2;
  string patient_id = 3;
  string patient_name = 4;
  int32 alert_type_id = 5;
  string alert_type_code = 6;
  int32 priority = 7;
  string title = 8;
  string body = 9;
  string icon = 10;
  string color = 11;
  string deeplink = 12;
  string payload_json = 13;
  int32 status = 14;  // 0=unread, 1=read
  int64 created_at = 15;
  int64 read_at = 16;
}

message GetAlertHistoryRequest {
  string caregiver_id = 1;
  string patient_id = 2;  // optional
  string filter_type = 3;  // optional: HA, SOS, MEDICATION, COMPLIANCE
  string period = 4;  // 7d, 30d, 90d
  int32 page = 5;
  int32 size = 6;
}

message AlertHistoryResponse {
  repeated AlertInfo alerts = 1;
  int32 total_count = 2;
  int32 unread_count = 3;
  int32 page = 4;
  int32 size = 5;
  bool has_more = 6;
}

message UnreadCountResponse {
  int32 count = 1;
}
```

---

## Kafka Topics

### Alert Trigger Topic

**Topic:** `topic-alert-triggers`

**Producer:** user-service (BP, Drug), schedule-service (batch)  
**Consumer:** schedule-service

**Payload:**

```json
{
  "event_type": "BP_ABNORMAL | SOS | WRONG_DOSE | MISSED_MEDICATION | MISSED_BP | LOW_MED_COMPLIANCE | LOW_BP_COMPLIANCE",
  "patient_id": "uuid",
  "source_type": "blood_pressure | medication | sos | compliance",
  "source_id": 123,
  "timestamp": "2026-02-02T16:45:00+07:00",
  "data": {
    "systolic": 145,
    "diastolic": 95,
    "avg_7d_systolic": 130,
    "avg_7d_diastolic": 85,
    "delta_systolic": 15,
    "delta_diastolic": 10,
    "medication_count": 2,
    "compliance_rate": 60
  },
  "consolidation": {
    "is_consolidated": true,
    "consolidated_count": 2,
    "note": "BR-ALT-019: Nhiều thuốc → GỘP 1 notification"
  }
}
```

### Alert Dispatched Topic

**Topic:** `topic-alert-dispatched`

**Producer:** schedule-service  
**Consumer:** user-service (to update push_status)

**Payload:**

```json
{
  "alert_id": "uuid",
  "caregiver_id": "uuid",
  "push_status": 1,
  "sent_at": "2026-02-02T16:45:05+07:00",
  "error": null
}
```

---

## Push Notification Payloads

### Standard Alert

```json
{
  "notification": {
    "title": "⚠️ Mẹ - Huyết áp bất thường!",
    "body": "Chỉ số 185/125 mmHg lúc 16:45. Nhấn để xem chi tiết."
  },
  "data": {
    "type": "CAREGIVER_ALERT",
    "alert_id": "uuid",
    "patient_id": "uuid",
    "alert_type": "BP_ABNORMAL",
    "priority": 1,
    "deeplink": "kolia://dashboard?patient_id={patient_id}"
  },
  "android": {
    "priority": "high"
  },
  "apns": {
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "badge": 5,
        "content-available": 1
      }
    }
  }
}
```

### SOS Alert (Critical)

```json
{
  "notification": {
    "title": "🆘 KHẨN CẤP - Mẹ",
    "body": "Mẹ vừa kích hoạt SOS lúc 16:45! Nhấn để xem vị trí."
  },
  "data": {
    "type": "SOS_ALERT",
    "alert_id": "uuid",
    "patient_id": "uuid",
    "patient_phone": "0901234567",
    "location_available": true,
    "priority": 0,
    "deeplink": "kolia://dashboard?patient_id={patient_id}&show_sos_popup=true"
  },
  "android": {
    "priority": "high",
    "notification": {
      "sound": "sos_sound",
      "channel_id": "sos_alerts"
    }
  },
  "apns": {
    "headers": {
      "apns-priority": "10",
      "apns-push-type": "alert"
    },
    "payload": {
      "aps": {
        "sound": "sos_sound.caf",
        "interruption-level": "critical"
      }
    }
  }
}
```

### Silent Push (Badge Update)

```json
{
  "data": {
    "type": "BADGE_UPDATE",
    "badge_count": 5
  },
  "android": {
    "priority": "high"
  },
  "apns": {
    "headers": {
      "apns-push-type": "background",
      "apns-priority": "5"
    },
    "payload": {
      "aps": {
        "content-available": 1,
        "badge": 5
      }
    }
  }
}
```

---

## Deep Links

| Alert Type | Deep Link | Target Screen | Note |
|------------|-----------|---------------|------|
| BP_ABNORMAL | `kolia://dashboard?patient_id={id}` | Dashboard | ⏳ SCR-HEALTH-OVERVIEW pending US 1.1 |
| SOS | `kolia://dashboard?patient_id={id}&show_sos_popup=true` | Dashboard + SOS Popup | Popup = chi tiết SOS |
| WRONG_DOSE | `kolia://patient/{id}/medication-report` | SCR-MED-REPORT | - |
| MISSED_MEDICATION | `kolia://patient/{id}/medication-report` | SCR-MED-REPORT | - |
| MISSED_BP | `kolia://dashboard?patient_id={id}` | Dashboard | ⏳ SCR-HEALTH-OVERVIEW pending US 1.1 |
| LOW_COMPLIANCE | `kolia://patient/{id}/compliance` | SCR-COMPLIANCE | - |

---

## SRS v1.5 Changes Summary

| Item | v1.0 | v1.5 |
|------|------|------|
| HA Alert | BP_CRITICAL + BP_ABNORMAL | **BP_ABNORMAL only** (BR-ALT-002 + BR-HA-017) |
| HA Display | 1 variant | **2 variants:** "HA Cao bất thường" / "HA Thấp bất thường" |
| Hard Thresholds | <90/>180, <60/>120 | **Removed** - chỉ dùng delta >10mmHg |
| Medication Notification | N alerts cho N thuốc | **GỘP 1** notification (BR-ALT-019) |
| SOS Deeplink | `/sos-alert` | `/dashboard?show_sos_popup=true` |
| "Xem vị trí" button | Always shown | **Conditional** (BR-ALT-SOS-001) |
