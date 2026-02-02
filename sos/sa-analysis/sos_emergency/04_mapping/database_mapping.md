# Database Mapping

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Mapping Date** | 2026-01-26 |

---

## 1. Requirements to Database Mapping

### 1.1 Table Requirements by Feature

| FR ID | Requirement | Tables Required |
|-------|-------------|-----------------|
| FR-SOS-01 | SOS Entry | - |
| FR-SOS-02 | SOS Countdown | `sos_events` |
| FR-SOS-03 | Alert Sending | `sos_events`, `sos_notifications`, `notifications` |
| FR-SOS-04 | SOS Cancellation | `sos_events` |
| FR-SOS-05 | Call 115 | - (client-side) |
| FR-SOS-06 | Auto Escalation | `sos_escalation_calls`, `user_emergency_contacts` |
| FR-SOS-07 | Escalation Success | `sos_escalation_calls` |
| FR-SOS-08 | Escalation During 115 | `sos_escalation_calls` |
| FR-SOS-09 | Contact List | `user_emergency_contacts` |
| FR-SOS-10 | Hospital Map | - (Google API) |
| FR-SOS-11 | First Aid | `first_aid_content` |
| FR-SOS-12 | SOS Offline | `sos_events` (offline_queue fields) |
| FR-SOS-13 | Airplane Mode | - (client-side) |
| FR-SOS-14 | Low Battery | `sos_events.battery_level_percent` |
| FR-SOS-15 | Cooldown | `sos_events` (query for recent) |
| FR-SOS-16 | ZNS Retry | `sos_notifications` (retry fields) |
| FR-SOS-17 | GPS Timeout | `sos_events.location_source` |
| FR-SOS-18 | Server Timeout | `sos_events` (offline queue) |

---

## 2. New Table Specifications

### 2.1 `user_emergency_contacts`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `contact_id` | UUID | PK, DEFAULT gen_random_uuid() | Unique ID |
| `user_id` | UUID | FK → users, NOT NULL | Owner |
| `name` | VARCHAR(100) | NOT NULL | Contact name |
| `phone` | VARCHAR(20) | NOT NULL | Phone number |
| `relationship` | VARCHAR(50) | | Relationship type |
| `priority` | SMALLINT | NOT NULL, DEFAULT 1, CHECK 1-5 | Escalation order |
| `is_active` | BOOLEAN | DEFAULT TRUE | Active status |
| `zalo_enabled` | BOOLEAN | DEFAULT FALSE | Zalo availability |
| `created_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |
| `updated_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |

**Indexes:**
- `idx_emergency_contacts_user` ON (user_id, priority)
- `idx_emergency_contacts_active` ON (user_id) WHERE is_active = TRUE
- UNIQUE (user_id, phone)

**Estimated Size:** ~500KB per 10K users (5 contacts each)

### 2.2 `sos_events`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `event_id` | UUID | PK, DEFAULT gen_random_uuid() | Unique ID |
| `user_id` | UUID | FK → users, NOT NULL | Trigger user |
| `triggered_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW | Trigger time |
| `trigger_source` | VARCHAR(50) | DEFAULT 'manual' | manual, low_battery |
| `latitude` | DOUBLE PRECISION | | GPS lat |
| `longitude` | DOUBLE PRECISION | | GPS lng |
| `location_accuracy_m` | DOUBLE PRECISION | | GPS accuracy |
| `location_timestamp` | TIMESTAMPTZ | | GPS time |
| `location_source` | VARCHAR(50) | | gps, cell_tower, last_known |
| `countdown_seconds` | SMALLINT | NOT NULL, DEFAULT 30, CHECK 0-30 | Duration |
| `countdown_started_at` | TIMESTAMPTZ | NOT NULL | Start time |
| `countdown_completed_at` | TIMESTAMPTZ | | Completion time |
| `status` | SMALLINT | NOT NULL, DEFAULT 0, CHECK 0-3 | 0:PENDING, 1:COMPLETED, 2:CANCELLED, 3:FAILED |
| `cancelled_at` | TIMESTAMPTZ | | Cancellation time |
| `cancellation_reason` | VARCHAR(100) | | Cancel reason |
| `is_offline_triggered` | BOOLEAN | DEFAULT FALSE | Offline flag |
| `offline_queue_timestamp` | TIMESTAMPTZ | | Queue time |
| `sync_completed_at` | TIMESTAMPTZ | | Sync time |
| `cooldown_bypassed` | BOOLEAN | DEFAULT FALSE | Bypass flag |
| `battery_level_percent` | SMALLINT | CHECK 0-100 | Battery |
| `device_info` | JSONB | | Device metadata |
| `created_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |
| `updated_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |

**Indexes:**
- `idx_sos_events_user` ON (user_id, triggered_at DESC)
- `idx_sos_events_status` ON (status) WHERE status = 0
- `idx_sos_events_cooldown` ON (user_id, countdown_completed_at DESC) WHERE status = 1
- `idx_sos_events_location` ON (latitude, longitude) WHERE latitude IS NOT NULL

**Partitioning:** BY RANGE (triggered_at) - Monthly partitions
**Retention:** 90 days auto-delete

**Estimated Size:** ~100KB per 1K events

### 2.3 `sos_notifications`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `notification_id` | UUID | PK, DEFAULT gen_random_uuid() | Unique ID |
| `event_id` | UUID | FK → sos_events, NOT NULL | Parent event |
| `contact_id` | UUID | FK → user_emergency_contacts | Contact (nullable for CSKH) |
| `recipient_name` | VARCHAR(100) | NOT NULL | Denormalized name |
| `recipient_phone` | VARCHAR(20) | NOT NULL | Denormalized phone |
| `recipient_type` | VARCHAR(50) | NOT NULL | family, cskh |
| `channel` | VARCHAR(50) | NOT NULL | zns, sms, push, call, cskh_api |
| `template_id` | VARCHAR(100) | | ZNS template |
| `message_content` | TEXT | | Audit content |
| `status` | SMALLINT | NOT NULL, DEFAULT 0, CHECK 0-4 | 0:PENDING, 1:SENT, 2:DELIVERED, 3:FAILED, 4:RETRY_PENDING |
| `sent_at` | TIMESTAMPTZ | | Send time |
| `delivered_at` | TIMESTAMPTZ | | Delivery time |
| `retry_count` | SMALLINT | DEFAULT 0, CHECK 0-3 | Retry count |
| `last_retry_at` | TIMESTAMPTZ | | Last retry |
| `next_retry_at` | TIMESTAMPTZ | | Next retry |
| `error_code` | VARCHAR(50) | | Error code |
| `error_message` | TEXT | | Error details |
| `external_message_id` | VARCHAR(200) | | ZNS message ID |
| `created_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |
| `updated_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |

**Indexes:**
- `idx_sos_notifications_event` ON (event_id)
- `idx_sos_notifications_status` ON (status) WHERE status IN (0, 4)
- `idx_sos_notifications_retry` ON (next_retry_at) WHERE status = 4

**Partitioning:** BY RANGE (created_at) - Monthly partitions
**Retention:** 90 days auto-delete

**Estimated Size:** ~250KB per 1K events (5 notifications each)

### 2.4 `sos_escalation_calls`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `call_id` | UUID | PK, DEFAULT gen_random_uuid() | Unique ID |
| `event_id` | UUID | FK → sos_events, NOT NULL | Parent event |
| `contact_id` | UUID | FK → user_emergency_contacts | Contact |
| `contact_name` | VARCHAR(100) | NOT NULL | Denormalized name |
| `contact_phone` | VARCHAR(20) | NOT NULL | Denormalized phone |
| `escalation_order` | SMALLINT | NOT NULL, CHECK 1-5 | Order |
| `call_type` | VARCHAR(50) | NOT NULL | auto_call, manual_call, 115_call |
| `status` | SMALLINT | NOT NULL, DEFAULT 0, CHECK 0-7 | Call status |
| `initiated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW | Start |
| `connected_at` | TIMESTAMPTZ | | Connect time |
| `ended_at` | TIMESTAMPTZ | | End time |
| `duration_seconds` | INTEGER | | Duration |
| `timeout_seconds` | SMALLINT | DEFAULT 20 | Timeout |
| `created_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |
| `updated_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |

**Status Values:**
- 0: PENDING
- 1: CALLING (ringing)
- 2: CONNECTED
- 3: NO_ANSWER
- 4: BUSY
- 5: REJECTED
- 6: FAILED
- 7: SKIPPED

**Indexes:**
- `idx_sos_escalation_calls_event` ON (event_id, escalation_order)
- `idx_sos_escalation_calls_pending` ON (status) WHERE status IN (0, 1)

**Retention:** 90 days auto-delete

### 2.5 `first_aid_content`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `content_id` | UUID | PK, DEFAULT gen_random_uuid() | Unique ID |
| `category` | VARCHAR(100) | NOT NULL | cpr, stroke, low_sugar, fall |
| `title` | VARCHAR(200) | NOT NULL | Title |
| `content` | TEXT | NOT NULL | Markdown content |
| `display_order` | SMALLINT | DEFAULT 0 | Sort order |
| `icon_name` | VARCHAR(100) | | Icon identifier |
| `is_active` | BOOLEAN | DEFAULT TRUE | Active flag |
| `version` | INTEGER | DEFAULT 1 | Content version |
| `created_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |
| `updated_at` | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP | |

**Indexes:**
- `idx_first_aid_category` ON (category, display_order)
- `idx_first_aid_active` ON (is_active) WHERE is_active = TRUE

**Estimated Size:** <1MB (static content)

---

## 3. Existing Table Extensions

### 3.1 `notifications` Usage

No schema changes required. Use existing table with:

| Field | Value for SOS |
|-------|--------------|
| `notification_type` | 2 (push) or 3 (in_app) |
| `priority` | 5 (highest) |
| `schedule_type` | 'sos' |
| `action_data` | `{"event_id": "uuid", "action": "VIEW_SOS_DASHBOARD"}` |

### 3.2 `user_health_profiles` Consideration

Existing emergency contact fields can remain for backward compatibility:
- `emergency_contact_name`
- `emergency_contact_phone`
- `emergency_contact_relation`

**Migration:** Optional - Copy existing data to `user_emergency_contacts` with priority=1

---

## 4. Database Impact Summary

### 4.1 Storage Estimates (Year 1)

| Table | Rows Estimate | Size Estimate |
|-------|--------------|---------------|
| `user_emergency_contacts` | 500K | 50 MB |
| `sos_events` | 50K | 10 MB |
| `sos_notifications` | 250K | 50 MB |
| `sos_escalation_calls` | 100K | 15 MB |
| `first_aid_content` | 50 | <1 MB |
| **TOTAL** | **~900K** | **~126 MB** |

### 4.2 Query Performance Considerations

| Query Type | Expected Frequency | Index Support |
|------------|-------------------|---------------|
| Get user contacts | High (SOS activation) | ✅ Covered |
| Check cooldown | High (SOS button tap) | ✅ Partial index |
| List SOS events | Medium (admin/user) | ✅ User + time |
| Retry pending ZNS | Low (background job) | ✅ Status index |
| First Aid content | Medium (on-demand) | ✅ Category index |

### 4.3 Maintenance Tasks

| Task | Frequency | Method |
|------|-----------|--------|
| Partition creation | Monthly | pg_partman or manual |
| Old partition drop | Monthly | Auto (90 day retention) |
| VACUUM ANALYZE | Weekly | pg_cron |
| Index rebuild | As needed | REINDEX CONCURRENTLY |

---

## 5. Migration Plan

### 5.1 Migration Scripts Order

1. Create `user_emergency_contacts` table
2. Create `sos_events` table with partitions
3. Create `sos_notifications` table with partitions
4. Create `sos_escalation_calls` table
5. Create `first_aid_content` table
6. Create triggers for updated_at
7. (Optional) Migrate existing emergency contacts
8. Insert initial first_aid_content data

### 5.2 Rollback Scripts

Each migration script has corresponding rollback:
- DROP TABLE IF EXISTS {table_name} CASCADE

---

## Next Phase

✅ **Phase 4: Database Mapping** - COMPLETE

➡️ **Phase 5: Feasibility Assessment**
