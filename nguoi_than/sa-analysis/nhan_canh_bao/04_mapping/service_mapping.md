# Service Mapping: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-02  
> **Revision:** v1.5  
> **Source:** SRS-Nhận-Cảnh-Báo_v1.5  
> **Applies Rule:** SA-002 (Service-Level Impact Detailing)

---

## Service: user-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Proto | `proto/alert_service.proto` | NEW | 6 gRPC methods |
| Entity | `entity/CaregiverAlert.java` | NEW | Alert entity |
| Entity | `entity/AlertType.java` | NEW | Alert type lookup |
| Repository | `repository/CaregiverAlertRepository.java` | NEW | Alert data access |
| Service | `service/AlertService.java` | NEW | Alert CRUD logic |
| Service | `service/impl/AlertServiceImpl.java` | NEW | Implementation |
| Service | `service/impl/BPDeltaEvaluator.java` | NEW | 7-day avg delta calculation |
| Handler | `handler/AlertServiceGrpcImpl.java` | NEW | gRPC handler |
| Producer | `kafka/AlertKafkaProducer.java` | NEW | Alert trigger Kafka events |
| DTO | `dto/request/CreateAlertRequest.java` | NEW | Create alert |
| DTO | `dto/response/AlertInfo.java` | NEW | Alert info |
| Constants | `constants/AlertPriority.java` | NEW | P0-P2 enum |
| Constants | `constants/AlertCategory.java` | NEW | Alert categories |
| Event | `event/AlertCreatedEvent.java` | NEW | Kafka payload |

### gRPC Methods (alert_service.proto)

| RPC | Request | Response | Description |
|-----|---------|----------|-------------|
| CreateAlert | CreateAlertRequest | AlertResponse | Tạo alert mới |
| GetAlertHistory | GetAlertHistoryRequest | AlertHistoryResponse | Lấy lịch sử (pagination) |
| GetAlertDetail | GetAlertDetailRequest | AlertDetailResponse | Chi tiết alert |
| MarkAlertAsRead | MarkAlertAsReadRequest | Empty | Mark single as read |
| MarkAllAlertsAsRead | MarkAllAlertsAsReadRequest | Empty | Mark all as read |
| GetUnreadCount | GetUnreadCountRequest | UnreadCountResponse | Get badge count |

### Database Changes

| Table | Change | Details |
|-------|:------:|---------|
| caregiver_alerts | CREATE | 14 columns, 3 indexes |
| caregiver_alert_types | CREATE | Lookup table, 4 types |

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| schedule-service | Kafka | Alert trigger events |

### Estimated Effort: 36 hours

---

## Service: api-gateway-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Handler | `handler/AlertHandler.java` | NEW | REST endpoints |
| Client | `client/AlertServiceClient.java` | NEW | gRPC client |
| DTO | `dto/response/AlertListResponse.java` | NEW | Alert list |
| DTO | `dto/response/AlertDetailResponse.java` | NEW | Alert detail |
| DTO | `dto/request/MarkAlertsReadRequest.java` | NEW | Mark read |
| Config | `RouteConfig.java` | MODIFY | Add 6 routes |
| Swagger | `alert-management.yaml` | NEW | API documentation |

### REST Endpoints

| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/connections/alerts/types` | Alert type lookup (4 categories) |
| GET | `/api/v1/connections/alerts` | All alerts (filterable by patientId) |
| GET | `/api/v1/connections/alerts/{alertId}` | Alert detail |
| POST | `/api/v1/connections/alerts/mark-read` | Mark selected as read |
| POST | `/api/v1/connections/alerts/mark-all-read` | Mark all as read |
| GET | `/api/v1/connections/alerts/unread-count` | Badge count |

### Gateway Compliance (ARCH-001)

```
✅ COMPLIANT - No business logic in gateway
   - handler/    ✅ REST forwarding
   - dto/        ✅ Request/Response mapping
   - client/     ✅ gRPC client
   
❌ NOT PRESENT (as expected):
   - service/    ✅ Not added
   - repository/ ✅ Not added
   - entity/     ✅ Not added
```

### Estimated Effort: 12 hours

---

## Service: schedule-service

### Impact Level: 🔴 HIGH

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Task | `tasks/alerts/bp_alert_evaluator.py` | NEW | BP threshold evaluation |
| Task | `tasks/alerts/alert_dispatcher.py` | NEW | Push dispatch |
| Task | `tasks/alerts/compliance_batch_evaluator.py` | NEW | 21:00 batch |
| Task | `tasks/alerts/missed_streak_evaluator.py` | NEW | 3 consecutive misses |
| Consumer | `consumers/alert_trigger_consumer.py` | NEW | Kafka consumer |
| Service | `services/debounce_service.py` | NEW | 5-min debounce |
| Service | `services/push_notification_service.py` | MODIFY | Alert templates |
| Config | `config.py` | MODIFY | Add topics, templates |
| Constants | `constants/alert_templates.py` | NEW | Push templates |
| Celery | `celery_config.py` | MODIFY | Add 21:00 schedule |

### Kafka Topics

| Topic | Direction | Purpose |
|-------|:---------:|---------|
| topic-alert-triggers | IN | Receive trigger events |
| topic-alert-dispatched | OUT | Confirm delivery |

### Complex Business Logic

1. **BP Abnormal Evaluation (BR-ALT-002 + BR-HA-017):**
   - Calculate 7-day rolling average
   - Check delta >10mmHg (CAO hoặc THẤP)
   - Trigger alert khi chênh lệch > 10mmHg (Tâm thu HOẶC Tâm trương)
   - **v1.5 Update:** Loại bỏ hoàn toàn ngưỡng cứng (hard thresholds)
   - **Display:** 2 variants - "HA Cao bất thường" / "HA Thấp bất thường"

2. **Debounce (BR-ALT-005):**
   - Redis: `debounce:{caregiver}:{patient}:{type}` TTL 5min
   - SOS exempt

3. **Batch 21:00:**
   - Medication compliance <70%
   - BP measurement compliance <70%
   - 3 consecutive missed medication (**GỘP** - BR-ALT-019)
   - 3 consecutive missed BP

4. **Medication Notification Consolidation (BR-ALT-019):**
   - Nhiều thuốc sai liều → GỘP thành 1 notification
   - Nhiều thuốc bỏ lỡ → GỘP thành 1 notification
   - Format thống nhất, không phân biệt 1/nhiều thuốc

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| FCM | HTTP | Push delivery |
| Redis | - | Debounce cache |
| user-service | gRPC | Get caregivers, permission check, create alerts, BP delta calculation |

### Estimated Effort: 40 hours

---

## ⭐ Alert Processing Modes (SRS v1.5)

> Phân loại rõ **Real-time** và **Batch Job** processing modes.

### 🔴 REAL-TIME Alerts (Immediate Processing)

| Alert Type | Trigger Source | Flow | SLA |
|------------|----------------|------|:---:|
| **SOS** 🚧 | `user-service` *(⏳ TODO: Pending SOS branch merge)* | -- | -- |
| **HA Bất thường** | `user-service` (khi lưu BP record, tính delta so với TB 7 ngày) | BP Saved → user-service tính delta → Kafka trigger → schedule-service → Push | ≤5s |
| **Sai liều thuốc** | `user-service` (khi Patient confirm "Hoàn tất" + "Sai liều") | Drug Report → user-service → Kafka trigger → schedule-service → Push | ≤5s |

**Real-time Flow Diagram:**
```
Patient Action → Backend Processing → Kafka (topic-alert-triggers) → schedule-service → Push FCM/APNs
     ↓                    ↓                       ↓                         ↓
  - Đo HA        - user-service (tính     Consumer receives          Debounce check
  - Nhấn SOS       delta vs 7-day avg)    event immediately          → Create alert record
  - Report thuốc - user-service (Drug)                               → Send push
```

---

### 🔵 BATCH Alerts (21:00 Daily Job)

| Alert Type | Trigger Source | Evaluation Logic | BR Reference |
|------------|----------------|------------------|--------------|
| **Tuân thủ thuốc kém** | `schedule-service` (Celery Beat) | Compliance <70% trong 24h | BR-ALT-006 |
| **Tuân thủ đo HA kém** | `schedule-service` (Celery Beat) | Compliance <70% trong 24h | BR-ALT-006b |
| **Bỏ lỡ 3 liều thuốc** | `schedule-service` (Celery Beat) | 3 consecutive misses (**GỘP** - BR-ALT-019) | BR-ALT-007 |
| **Bỏ lỡ 3 lần đo HA** | `schedule-service` (Celery Beat) | 3 consecutive misses | BR-ALT-015 |

**Batch Job Specification:**
```yaml
job_key: caregiver_alerts_batch_21h
schedule: cron(0 21 * * *)  # 21:00 daily
timezone: Asia/Ho_Chi_Minh
task: schedule_service.tasks.alerts.run_batch_alerts

processing_order:
  1. Query all active caregivers
  2. For each caregiver-patient pair:
     - Eval medication compliance (24h)
     - Eval BP compliance (24h)
     - Detect 3 consecutive missed medications
     - Detect 3 consecutive missed BP measurements
  3. Apply BR-ALT-019: GỘP multiple medications → 1 notification
  4. Create caregiver_alerts records
  5. Send push notifications (batch)
```

---

### Summary Table

| Alert | Mode | Time | Debounce | BR |
|-------|:----:|:----:|:--------:|:--:|
| SOS 🚧 | ⏳ TODO | *(Pending SOS branch merge)* | -- | BR-ALT-004 |
| HA Bất thường | ⚡ Real-time | ≤5s | ✅ 5min | BR-ALT-002, BR-HA-017 |
| Sai liều | ⚡ Real-time | ≤5s | ✅ 5min | BR-ALT-008 |
| Tuân thủ thuốc kém | 📅 Batch | 21:00 | N/A | BR-ALT-006 |
| Tuân thủ đo HA kém | 📅 Batch | 21:00 | N/A | BR-ALT-006b |
| Bỏ lỡ 3 liều thuốc | 📅 Batch | 21:00 | N/A | BR-ALT-007, BR-ALT-019 |
| Bỏ lỡ 3 lần đo HA | 📅 Batch | 21:00 | N/A | BR-ALT-015 |

---

## Service: Mobile App (React Native)

### Impact Level: 🔴 HIGH

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Screen | `AlertHistoryScreen.tsx` | NEW | SCR-ALT-02 |
| Component | `AlertBlock.tsx` | NEW | Dashboard block |
| Component | `AlertCard.tsx` | NEW | Card component |
| Component | `AlertModal.tsx` | NEW | In-app popup |
| Component | `SOSModal.tsx` | NEW | SOS popup |
| Service | `alert.service.ts` | NEW | API client |
| Store | `alertStore.ts` | NEW | State management |
| Hook | `useAlertFilters.ts` | NEW | Filter state |
| Navigation | `DeepLinkHandler.ts` | MODIFY | Alert deeplinks |
| Notification | `PushHandler.ts` | MODIFY | Alert payloads |

### UI Components

| Screen | Complexity | New Components |
|--------|:----------:|----------------|
| SCR-ALT-01 (Alert Block) | Medium | AlertBlock, AlertCard |
| SCR-ALT-02 (History) | Medium | FilterBar, AlertList |
| SCR-ALT-03 (Modal) | Low | AlertModal |
| SCR-ALT-04 (SOS Modal) | Medium | SOSModal with Dialer |

### Estimated Effort: 48 hours

---

## Summary

| Service | Impact | Files | Effort |
|---------|:------:|:-----:|:------:|
| user-service | 🟡 MEDIUM | ~14 | 36h |
| api-gateway-service | 🟡 MEDIUM | ~8 | 12h |
| schedule-service | 🔴 HIGH | ~12 | 40h |
| Mobile App | 🔴 HIGH | ~15 | 48h |
| **Total** | | **~49** | **132h** |

---

## Cross-Feature Dependencies

| Feature | Dependency Type | Data/Events |
|---------|----------------|-------------|
| SRS Đo Huyết áp | Read BP data | Threshold triggers |
| SRS Uống thuốc | Read medication events | Missed, wrong dose |
| SRS SOS | Read SOS events | Emergency alerts |
| Kết nối Người thân | Read connections | Permission #2, caregivers |
