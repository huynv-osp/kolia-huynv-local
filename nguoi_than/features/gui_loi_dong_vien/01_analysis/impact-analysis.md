# Impact Analysis: US 1.3 - Gửi Lời Động Viên

> **Phase:** 3 - Impact Analysis  
> **Date:** 2026-02-04  
> **SA Reference:** [impact_analysis.md](../../sa-analysis/gui_loi_dong_vien/06_impact/impact_analysis.md)

---

## 1. Impact Summary

| Metric | Value |
|--------|:-----:|
| **Services Affected** | 4 |
| **New Tables** | 1 |
| **Modified Tables** | 0 |
| **Breaking Changes** | 0 |
| **Data Migration** | None |
| **Impact Level** | 🟡 MEDIUM |

---

## 2. Service Impact Matrix

| Service | Impact | New Code | Modified Code | Effort |
|---------|:------:|:--------:|:-------------:|:------:|
| user-service | 🟡 | ~10 files | ~2 files | 24h |
| api-gateway | 🟡 | ~6 files | ~1 file | 10h |
| schedule-service | 🟢 | ~3 files | 0 | 4h |
| Mobile App | 🟡 | ~8 files | ~2 files | 16h |
| **Total** | | | | **54h** |

---

## 3. Impact by Service (FA-002)

### 3.1 user-service 🟡 MEDIUM

**New Files:**

| Layer | File | Purpose |
|-------|------|---------|
| Entity | `EncouragementMessage.java` | Domain object |
| Repository | `EncouragementRepository.java` | Data access |
| Service | `EncouragementService.java` | Interface |
| Service | `EncouragementServiceImpl.java` | Business logic |
| Handler | `EncouragementServiceGrpcImpl.java` | gRPC endpoint |
| Kafka | `EncouragementKafkaProducer.java` | Event publisher |
| DTO | `EncouragementMessageDto.java` | Transfer object |
| Proto | `encouragement_service.proto` | gRPC spec |

**Modified Files:**

| File | Change |
|------|--------|
| `GrpcServerConfig.java` | Register new service |
| `ErrorCodes.java` | Add QUOTA_EXCEEDED, PERMISSION_DENIED |

---

### 3.2 api-gateway-service 🟡 MEDIUM

**New Files:**

| Layer | File | Purpose |
|-------|------|---------|
| Handler | `EncouragementHandler.java` | REST endpoints |
| Client | `EncouragementServiceClient.java` | gRPC client |
| DTO | `CreateEncouragementRequest.java` | Request |
| DTO | `EncouragementResponse.java` | Response |
| DTO | `MarkAsReadRequest.java` | Batch read |
| DTO | `QuotaResponse.java` | Quota info |

**Modified Files:**

| File | Change |
|------|--------|
| `RouteConfig.java` | Add 4 routes |

---

### 3.3 schedule-service 🟢 LOW

**New Files:**

| File | Purpose |
|------|---------|
| `encouragement_consumer.py` | Kafka consumer |
| `send_encouragement_notification.py` | Push task |
| `encouragement_templates.py` | FCM templates |

---

### 3.4 Mobile App 🟡 MEDIUM

**New Files:**

| File | Purpose |
|------|---------|
| `EncouragementWidget.tsx` | Caregiver compose |
| `EncouragementModal.tsx` | Patient view |
| `useEncouragement.ts` | Hook |
| `encouragementStore.ts` | Zustand store |
| `encouragement.service.ts` | API client |
| `EncouragementCard.tsx` | List item |

**Modified Files:**

| File | Change |
|------|--------|
| `PatientDashboard.tsx` | Add widget |
| `DeepLinkHandler.ts` | Handle push deeplink |

---

## 4. Database Impact

### New Table

```sql
CREATE TABLE encouragement_messages (
    encouragement_id UUID PRIMARY KEY,
    sender_id UUID NOT NULL REFERENCES users(user_id),
    patient_id UUID NOT NULL REFERENCES users(user_id),
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id),
    content VARCHAR(150) NOT NULL,
    sender_name VARCHAR(100),                                           -- Caregiver's display name
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- FK: ensures valid code
    relationship_display VARCHAR(100),                                  -- Patient's perspective (Perspective Standard v2.23)
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

> ⚠️ **Note:** `relationship_display` = how **Patient calls Caregiver** (e.g., "Con gái")

### Indexes (4 total)

| Index | Purpose |
|-------|---------|
| `idx_enc_patient_unread` | Patient modal query |
| `idx_enc_patient_recent` | 24h window query |
| `idx_enc_quota` | Daily quota check |
| `idx_enc_sender` | Sender history |

---

## 5. Integration Impact

| Integration | Change | Risk |
|-------------|--------|:----:|
| Kafka | New topic `topic-encouragement-created` | 🟢 |
| FCM | New notification type | 🟢 |
| Permission #6 | New usage (already exists) | 🟢 |

---

## 6. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|:-----------:|:------:|------------|
| Push delivery delay | LOW | MEDIUM | Retry queue |
| Permission race | LOW | LOW | Real-time check |
| Quota bypass | LOW | LOW | Server enforcement |

---

## 7. Dependencies

| Feature | Status | Required For |
|---------|:------:|--------------|
| Kết nối Người thân | ✅ Deployed | Permission #6 |
| Permission Management | ✅ Deployed | Check permission |
| Push Infrastructure | ✅ Deployed | FCM delivery |

---

## Next Phase

➡️ Proceed to Phase 4: Service Decomposition
