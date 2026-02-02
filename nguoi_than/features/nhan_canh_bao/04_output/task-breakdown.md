# Task Breakdown: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Version:** v1.5  
> **Date:** 2026-02-02  
> **Total:** 132 hours

---

## Service: user-service (36h)

| Task ID | Task | Layer | File | Est. |
|---------|------|-------|------|:----:|
| USR-001 | Create migration SQL | DB | `V2026.02.02.1__create_caregiver_alerts.sql` | 4h |
| USR-002 | Create alert_service.proto | Proto | `proto/alert_service.proto` | 4h |
| USR-003 | Create CaregiverAlert entity | Entity | `entity/CaregiverAlert.java` | 2h |
| USR-004 | Create AlertType entity | Entity | `entity/AlertType.java` | 1h |
| USR-005 | Create CaregiverAlertRepository | Repo | `repository/CaregiverAlertRepository.java` | 4h |
| USR-006 | Create AlertService interface | Service | `service/AlertService.java` | 2h |
| USR-007 | Create AlertServiceImpl | Service | `service/impl/AlertServiceImpl.java` | 8h |
| USR-008 | Create BPDeltaEvaluator | Service | `service/impl/BPDeltaEvaluator.java` | 4h |
| USR-009 | Create AlertKafkaProducer | Kafka | `kafka/AlertKafkaProducer.java` | 4h |
| USR-010 | Create AlertServiceGrpcImpl | Handler | `handler/AlertServiceGrpcImpl.java` | 6h |
| USR-011 | Unit tests | Test | `service/AlertServiceTest.java` | 1h |

---

## Service: api-gateway-service (12h)

| Task ID | Task | Layer | File | Est. |
|---------|------|-------|------|:----:|
| GW-001 | Create AlertHandler | Handler | `handler/AlertHandler.java` | 4h |
| GW-002 | Create AlertServiceClient | Client | `client/AlertServiceClient.java` | 3h |
| GW-003 | Add routes | Config | `RouteConfig.java` | 1h |
| GW-004 | Create Swagger spec | Doc | `alert-management.yaml` | 2h |
| GW-005 | Create DTOs | DTO | `dto/response/AlertListResponse.java` | 2h |

---

## Service: schedule-service (40h)

| Task ID | Task | Layer | File | Est. |
|---------|------|-------|------|:----:|
| SCH-001 | Create alert_trigger_consumer | Consumer | `consumers/alert_trigger_consumer.py` | 8h |
| SCH-002 | Create bp_alert_evaluator | Task | `tasks/alerts/bp_alert_evaluator.py` | 6h |
| SCH-003 | Create medication_alert_evaluator | Task | `tasks/alerts/medication_alert_evaluator.py` | 6h |
| SCH-004 | Create debounce_service | Service | `services/debounce_service.py` | 4h |
| SCH-005 | Create compliance_batch_evaluator | Task | `tasks/alerts/compliance_batch_evaluator.py` | 6h |
| SCH-006 | Create missed_streak_evaluator | Task | `tasks/alerts/missed_streak_evaluator.py` | 4h |
| SCH-007 | Create alert_dispatcher | Task | `tasks/alerts/alert_dispatcher.py` | 4h |
| SCH-008 | Create alert_templates | Const | `constants/alert_templates.py` | 2h |

---

## Service: Mobile App (48h)

| Task ID | Task | Layer | File | Est. |
|---------|------|-------|------|:----:|
| MOB-001 | Create alertStore | Store | `stores/alertStore.ts` | 4h |
| MOB-002 | Create alert.service | Service | `services/alert.service.ts` | 4h |
| MOB-003 | Create AlertBlock | Component | `components/alerts/AlertBlock.tsx` | 6h |
| MOB-004 | Create AlertCard | Component | `components/alerts/AlertCard.tsx` | 4h |
| MOB-005 | Create AlertHistoryScreen | Screen | `screens/alerts/AlertHistoryScreen.tsx` | 8h |
| MOB-006 | Create useAlertFilters hook | Hook | `hooks/useAlertFilters.ts` | 4h |
| MOB-007 | Create AlertModal | Modal | `components/modals/AlertModal.tsx` | 4h |
| MOB-008 | Create SOSModal | Modal | `components/modals/SOSModal.tsx` | 4h |
| MOB-009 | Modify PushHandler | Handler | `services/PushHandler.ts` | 4h |
| MOB-010 | Modify DeepLinkHandler | Nav | `navigation/DeepLinkHandler.ts` | 4h |
| MOB-011 | Add navigation routes | Nav | `navigation/index.ts` | 2h |

---

## Summary by Service

| Service | Tasks | Hours |
|---------|:-----:|:-----:|
| user-service | 11 | 36h |
| api-gateway-service | 5 | 12h |
| schedule-service | 8 | 40h |
| Mobile App | 11 | 48h |
| **Total** | **35** | **132h** |
