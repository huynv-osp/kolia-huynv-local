# Database Entities for SOS Emergency

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Reference Doc** | `Bmad/MY_workflows/database/Alio_database_create.sql` |
| **Database Version** | 3.12 |
| **Snapshot Date** | 2026-01-26 |

---

## 1. Existing Relevant Tables

### 1.1 User Management (PHÂN HỆ 1)

#### `users`
Primary user table - central to SOS operations.

| Column | Type | SOS Relevance |
|--------|------|---------------|
| `user_id` | UUID PK | ✅ SOS event owner |
| `full_name` | VARCHAR(100) | ✅ ZNS template variable |
| `is_active` | BOOLEAN | ✅ Check before SOS |
| `created_at` | TIMESTAMPTZ | - |

#### `user_configurations`
User settings including notification preferences.

| Column | Type | SOS Relevance |
|--------|------|---------------|
| `user_id` | UUID PK FK | ✅ Link to user |
| `notification_preferences` | JSONB | ✅ Check push/SMS enabled |
| `fcm_token` | TEXT | ✅ Push notification target |
| `timezone` | VARCHAR(50) | ✅ Format ZNS timestamp |

#### `notifications`
Notification storage.

| Column | Type | SOS Relevance |
|--------|------|---------------|
| `notification_id` | UUID PK | ✅ Track SOS notification |
| `user_id` | UUID FK | ✅ Recipient |
| `notification_type` | SMALLINT | ✅ 0:email, 1:sms, 2:push, 3:in_app |
| `title` | VARCHAR(100) | ✅ SOS alert title |
| `message` | TEXT | ✅ SOS alert body |
| `priority` | SMALLINT | ✅ HIGH priority for SOS |
| `schedule_type` | VARCHAR(50) | ✅ 'sos' type |
| `action_data` | JSONB | ✅ SOS action data |
| `created_at` | TIMESTAMPTZ | ✅ Timestamp |

### 1.2 Family & Friends (PHÂN HỆ 1)

#### `family_groups`
```sql
-- NOT SHOWN in provided SQL - but referenced in triggers
-- Likely exists with structure:
CREATE TABLE family_groups (
    group_id UUID PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMPTZ,
    ...
);
```

#### `family_group_members`
```sql
-- Referenced in trigger comments
-- Key fields for SOS:
-- - user_id: Family member
-- - status: 1 = active
-- - Note: Check is_supervisor for escalation
```

#### `friends`
| Column | Type | SOS Relevance |
|--------|------|---------------|
| `friendship_id` | UUID PK | - |
| `user_id` | UUID FK | ✅ SOS sender |
| `friend_id` | UUID FK | ⚠️ Could be emergency contact |
| `status` | SMALLINT | ✅ 1 = active |

### 1.3 User Health (PHÂN HỆ 3)

#### `user_health_profiles`
| Column | Type | SOS Relevance |
|--------|------|---------------|
| `user_id` | UUID PK FK | ✅ Link |
| `emergency_contact_name` | VARCHAR(100) | ✅ **PRIMARY SOS contact** |
| `emergency_contact_phone` | VARCHAR(15) | ✅ **PRIMARY SOS phone** |
| `emergency_contact_relation` | VARCHAR(50) | ✅ Relationship info |
| `medical_conditions` | JSONB | ✅ Include in CSKH alert |

> 📌 **KEY FINDING**: `user_health_profiles` already has emergency contact fields!

---

## 2. Tables Needing EXTENSION

### 2.1 Emergency Contacts Table (NEW or EXTEND)

**Option A: Use existing `user_health_profiles`**
- ✅ Already has 1 emergency contact
- ❌ SRS requires up to 5 contacts with priority

**Option B: Create new `user_emergency_contacts` table** (RECOMMENDED)
```sql
CREATE TABLE user_emergency_contacts (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relationship VARCHAR(50),
    priority SMALLINT NOT NULL DEFAULT 1, -- 1-5 for escalation order
    is_active BOOLEAN DEFAULT TRUE,
    zalo_enabled BOOLEAN DEFAULT FALSE, -- Can receive Zalo calls
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_priority_range CHECK (priority BETWEEN 1 AND 5),
    UNIQUE (user_id, phone)
);
CREATE INDEX idx_emergency_contacts_user ON user_emergency_contacts (user_id, priority);
CREATE INDEX idx_emergency_contacts_active ON user_emergency_contacts (user_id) WHERE is_active = TRUE;
```

---

## 3. NEW Tables Required

### 3.1 `sos_events` - SOS Event Tracking

```sql
CREATE TABLE sos_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Trigger info
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trigger_source VARCHAR(50) NOT NULL DEFAULT 'manual', -- manual, low_battery, etc.
    
    -- Location at trigger time
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_accuracy_m DOUBLE PRECISION,
    location_timestamp TIMESTAMPTZ,
    location_source VARCHAR(50), -- gps, cell_tower, last_known
    
    -- Countdown & Status
    countdown_seconds SMALLINT NOT NULL DEFAULT 30,
    countdown_started_at TIMESTAMPTZ NOT NULL,
    countdown_completed_at TIMESTAMPTZ, -- NULL if cancelled
    
    -- Final status
    status SMALLINT NOT NULL DEFAULT 0,
    -- 0: PENDING (countdown running)
    -- 1: COMPLETED (alerts sent)
    -- 2: CANCELLED (user cancelled)
    -- 3: FAILED (send failed)
    
    -- Cancellation details
    cancelled_at TIMESTAMPTZ,
    cancellation_reason VARCHAR(100),
    
    -- Offline handling
    is_offline_triggered BOOLEAN DEFAULT FALSE,
    offline_queue_timestamp TIMESTAMPTZ,
    sync_completed_at TIMESTAMPTZ,
    
    -- Cooldown tracking
    cooldown_bypassed BOOLEAN DEFAULT FALSE,
    
    -- Battery info at trigger
    battery_level_percent SMALLINT,
    
    -- Metadata
    device_info JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_countdown_range CHECK (countdown_seconds BETWEEN 0 AND 30),
    CONSTRAINT chk_status_values CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_battery_range CHECK (battery_level_percent IS NULL OR battery_level_percent BETWEEN 0 AND 100)
);

-- Indexes
CREATE INDEX idx_sos_events_user ON sos_events (user_id, triggered_at DESC);
CREATE INDEX idx_sos_events_status ON sos_events (status) WHERE status = 0;
CREATE INDEX idx_sos_events_cooldown ON sos_events (user_id, countdown_completed_at DESC) WHERE status = 1;
CREATE INDEX idx_sos_events_location ON sos_events (latitude, longitude) WHERE latitude IS NOT NULL;
```

### 3.2 `sos_notifications` - SOS Notification Log

```sql
CREATE TABLE sos_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES sos_events(event_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Recipient info (denormalized for history)
    recipient_name VARCHAR(100) NOT NULL,
    recipient_phone VARCHAR(20) NOT NULL,
    recipient_type VARCHAR(50) NOT NULL, -- family, cskh
    
    -- Notification type
    channel VARCHAR(50) NOT NULL, -- zns, sms, push, call, cskh_api
    template_id VARCHAR(100), -- ZNS template ID
    
    -- Content (for audit)
    message_content TEXT,
    
    -- Status
    status SMALLINT NOT NULL DEFAULT 0,
    -- 0: PENDING
    -- 1: SENT
    -- 2: DELIVERED
    -- 3: FAILED
    -- 4: RETRY_PENDING
    
    -- Timing
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    
    -- Retry info
    retry_count SMALLINT DEFAULT 0,
    last_retry_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    
    -- Error handling
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- External IDs
    external_message_id VARCHAR(200), -- ZNS message ID
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_notification_status CHECK (status IN (0, 1, 2, 3, 4)),
    CONSTRAINT chk_retry_count CHECK (retry_count BETWEEN 0 AND 3)
);

-- Indexes
CREATE INDEX idx_sos_notifications_event ON sos_notifications (event_id);
CREATE INDEX idx_sos_notifications_status ON sos_notifications (status) WHERE status IN (0, 4);
CREATE INDEX idx_sos_notifications_retry ON sos_notifications (next_retry_at) WHERE status = 4;
```

### 3.3 `sos_escalation_calls` - Escalation Call Tracking

```sql
CREATE TABLE sos_escalation_calls (
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES sos_events(event_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Contact info (denormalized)
    contact_name VARCHAR(100) NOT NULL,
    contact_phone VARCHAR(20) NOT NULL,
    escalation_order SMALLINT NOT NULL, -- 1-5
    
    -- Call type
    call_type VARCHAR(50) NOT NULL, -- auto_call, manual_call, 115_call
    
    -- Status
    status SMALLINT NOT NULL DEFAULT 0,
    -- 0: PENDING
    -- 1: CALLING (ringing)
    -- 2: CONNECTED
    -- 3: NO_ANSWER
    -- 4: BUSY
    -- 5: REJECTED
    -- 6: FAILED
    -- 7: SKIPPED (user manually called)
    
    -- Timing
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connected_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Timeout tracking
    timeout_seconds SMALLINT DEFAULT 20,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_call_status CHECK (status IN (0, 1, 2, 3, 4, 5, 6, 7)),
    CONSTRAINT chk_escalation_order CHECK (escalation_order BETWEEN 1 AND 5)
);

-- Indexes
CREATE INDEX idx_sos_escalation_calls_event ON sos_escalation_calls (event_id, escalation_order);
CREATE INDEX idx_sos_escalation_calls_pending ON sos_escalation_calls (status) WHERE status IN (0, 1);
```

### 3.4 `first_aid_content` - First Aid Content (CMS)

```sql
CREATE TABLE first_aid_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(100) NOT NULL, -- cpr, stroke, low_sugar, fall
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL, -- Markdown content
    display_order SMALLINT DEFAULT 0,
    icon_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_first_aid_category ON first_aid_content (category, display_order);
CREATE INDEX idx_first_aid_active ON first_aid_content (is_active) WHERE is_active = TRUE;
```

---

## 4. Database Impact Summary

### 4.1 New Tables Required

| Table | Rows Est (Year 1) | Partition Strategy |
|-------|------------------|-------------------|
| `user_emergency_contacts` | 500K (5 per user) | None needed |
| `sos_events` | 50K | By `triggered_at` |
| `sos_notifications` | 250K (5 per event) | By `created_at` |
| `sos_escalation_calls` | 100K | By `created_at` |
| `first_aid_content` | <100 | None needed |

### 4.2 Existing Tables Modified

| Table | Modification | Impact |
|-------|--------------|--------|
| None required | - | ✅ No breaking changes |

### 4.3 Data Retention Policy (from SRS)

| Table | Retention | Auto-delete |
|-------|-----------|-------------|
| `sos_events` | 90 days | ✅ Required |
| `sos_notifications` | 90 days | ✅ Required |
| `sos_escalation_calls` | 90 days | ✅ Required |

---

## 5. Migration Considerations

### 5.1 Data Migration

- **user_health_profiles.emergency_contact_* → user_emergency_contacts**: Optional migration for existing emergency contacts (priority = 1)

### 5.2 Indexes

- All tables have appropriate indexes for common queries
- Partial indexes for status-based queries

### 5.3 Triggers

```sql
-- Auto-update updated_at
CREATE TRIGGER trigger_sos_events_updated_at
    BEFORE UPDATE ON sos_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_sos_notifications_updated_at
    BEFORE UPDATE ON sos_notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## Next Phase

✅ **Phase 2: Context (Database)** - COMPLETE

➡️ **Phase 3: Requirements Extraction**
