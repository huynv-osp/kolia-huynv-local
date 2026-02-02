# Implementation Tasks: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 5 - Task Generation  
> **Date:** 2026-02-02  
> **Total:** 35 tasks / 132h

---

## Phase 1: Foundation (12h)

| ID | Task | Service | Est. |
|----|------|---------|:----:|
| DB-001 | Create migration SQL | user-service | 4h |
| PROTO-001 | Create alert_service.proto | user-service | 4h |
| JOB-001 | Register Celery batch job | schedule-service | 4h |

---

## Phase 2: Backend Core (40h)

| ID | Task | Service | Est. |
|----|------|---------|:----:|
| USR-001 | CaregiverAlert entity | user-service | 2h |
| USR-002 | AlertType entity | user-service | 1h |
| USR-003 | CaregiverAlertRepository | user-service | 4h |
| USR-004 | AlertService interface | user-service | 2h |
| USR-005 | AlertServiceImpl | user-service | 8h |
| USR-006 | AlertServiceGrpcImpl | user-service | 6h |
| USR-007 | BPDeltaEvaluator | user-service | 4h |
| USR-008 | AlertKafkaProducer | user-service | 4h |
| GW-001 | AlertHandler | api-gateway | 4h |
| GW-002 | AlertServiceClient | api-gateway | 3h |
| GW-003 | Add routes | api-gateway | 1h |
| GW-004 | Swagger spec | api-gateway | 2h |
| GW-005 | DTOs | api-gateway | 2h |

---

## Phase 3: Schedule Service (40h)

| ID | Task | Service | Est. |
|----|------|---------|:----:|
| SCH-001 | alert_trigger_consumer | schedule-service | 8h |
| SCH-002 | bp_alert_evaluator | schedule-service | 6h |
| SCH-003 | medication_alert_evaluator | schedule-service | 6h |
| SCH-004 | debounce_service | schedule-service | 4h |
| SCH-005 | compliance_batch_evaluator | schedule-service | 6h |
| SCH-006 | missed_streak_evaluator | schedule-service | 4h |
| SCH-007 | alert_dispatcher | schedule-service | 4h |
| SCH-008 | alert_templates | schedule-service | 2h |

---

## Phase 4: Mobile (48h)

| ID | Task | Service | Est. |
|----|------|---------|:----:|
| MOB-001 | alertStore | Mobile | 4h |
| MOB-002 | alert.service | Mobile | 4h |
| MOB-003 | AlertBlock | Mobile | 6h |
| MOB-004 | AlertCard | Mobile | 4h |
| MOB-005 | AlertHistoryScreen | Mobile | 8h |
| MOB-006 | useAlertFilters hook | Mobile | 4h |
| MOB-007 | AlertModal | Mobile | 4h |
| MOB-008 | SOSModal | Mobile | 4h |
| MOB-009 | PushHandler update | Mobile | 4h |
| MOB-010 | DeepLinkHandler update | Mobile | 4h |
| MOB-011 | Navigation routes | Mobile | 2h |

---

## Next Phase

➡️ [sequence-diagram.md](./sequence-diagram.md)
