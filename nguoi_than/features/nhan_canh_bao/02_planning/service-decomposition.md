# Service Decomposition: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 4 - Service Decomposition  
> **Date:** 2026-02-02  
> **Applies Rule:** FA-002 (Service-Specific Change Documentation)

---

## Service: user-service 🟡 MEDIUM

### Code Changes

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Proto | `proto/alert_service.proto` | NEW | 6 gRPC methods |
| Entity | `entity/CaregiverAlert.java` | NEW | Alert entity |
| Entity | `entity/AlertType.java` | NEW | Lookup entity |
| Repository | `repository/CaregiverAlertRepository.java` | NEW | Data access |
| Service | `service/AlertService.java` | NEW | Interface |
| Service | `service/impl/AlertServiceImpl.java` | NEW | Implementation |
| Service | `service/impl/BPDeltaEvaluator.java` | NEW | 7-day delta calculation |
| Handler | `handler/AlertServiceGrpcImpl.java` | NEW | gRPC handler |
| Producer | `kafka/AlertKafkaProducer.java` | NEW | Alert trigger events |

### Database Changes

| Table | Change |
|-------|:------:|
| caregiver_alerts | CREATE |
| caregiver_alert_types | CREATE |

**Effort:** 36h

---

## Service: api-gateway-service 🟡 MEDIUM

### Code Changes

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Handler | `handler/AlertHandler.java` | NEW | REST endpoints |
| Client | `client/AlertServiceClient.java` | NEW | gRPC client |
| DTO | `dto/response/AlertListResponse.java` | NEW | Response |
| Config | `RouteConfig.java` | MODIFY | Add routes |
| Swagger | `alert-management.yaml` | NEW | API docs |

### Gateway Compliance (ARCH-001) ✅

- ✅ Handler only (REST→gRPC)
- ✅ No service layer
- ✅ No repository

**Effort:** 12h

---

## Service: schedule-service 🔴 HIGH

### Code Changes

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Consumer | `consumers/alert_trigger_consumer.py` | NEW | Kafka consumer |
| Task | `tasks/alerts/bp_alert_evaluator.py` | NEW | HA delta check |
| Task | `tasks/alerts/medication_alert_evaluator.py` | NEW | Sai liều |
| Task | `tasks/alerts/compliance_batch_evaluator.py` | NEW | <70% batch |
| Task | `tasks/alerts/missed_streak_evaluator.py` | NEW | 3 consecutive |
| Task | `tasks/alerts/alert_dispatcher.py` | NEW | Push dispatch |
| Service | `services/debounce_service.py` | NEW | Redis TTL 5min |
| Constants | `constants/alert_templates.py` | NEW | Push templates |

### Integration

| Target | Protocol |
|--------|----------|
| Kafka (topic-alert-triggers) | Consumer |
| FCM | HTTP Producer |
| Redis | Debounce cache |

**Effort:** 40h

---

## Service: Mobile App 🔴 HIGH

### Code Changes

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Store | `stores/alertStore.ts` | NEW | Zustand |
| Service | `services/alert.service.ts` | NEW | API client |
| Component | `components/alerts/AlertBlock.tsx` | NEW | Dashboard block |
| Component | `components/alerts/AlertCard.tsx` | NEW | Card |
| Screen | `screens/alerts/AlertHistoryScreen.tsx` | NEW | History |
| Modal | `components/modals/AlertModal.tsx` | NEW | In-app |
| Modal | `components/modals/SOSModal.tsx` | NEW | SOS detail |
| Handler | `services/PushHandler.ts` | MODIFY | Alert payloads |

**Effort:** 48h

---

## Next Phase

➡️ [implementation-tasks.md](./implementation-tasks.md)
