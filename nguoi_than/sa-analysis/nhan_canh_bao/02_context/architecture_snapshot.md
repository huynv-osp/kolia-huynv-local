# Architecture Snapshot: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-02-02

---

## ALIO Services Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT (Mobile App)                         │
│     [AlertBlock, AlertHistoryScreen, AlertModal, SOSModal]      │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTP/REST + Push
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API GATEWAY SERVICE                         │
│  - New: AlertHandler (REST → gRPC)                              │
│  - Existing: ConnectionHandler                                   │
└──────┬──────────────────────────────────────────────────────────┘
       │ gRPC
       ▼
┌──────────────────────────────────────────────────────────────────┐
│                      USER-SERVICE                                 │
│  - New: AlertServiceGrpcImpl                                     │
│  - Existing: ConnectionServiceGrpcImpl                           │
│  - Tables: caregiver_alerts, caregiver_alert_types              │
└──────────────────────────────────────────────────────────────────┘
       │ Kafka (topic-alert-triggers)
       ▼
┌──────────────────────────────────────────────────────────────────┐
│                    SCHEDULE-SERVICE (Core)                       │
│  - New: AlertTriggerConsumer (Kafka)                            │
│  - New: AlertEvaluator (BP, Medication, Compliance)             │
│  - New: AlertDispatcher (Push via FCM)                          │
│  - Existing: Connection notification flow                        │
└──────────────────────────────────────────────────────────────────┘
       ▓                    │
       │ Kafka              ▼ FCM
┌──────┴──────────┐   ┌─────────────────┐
│topic-alert-    │   │  FCM (Push)     │
│  triggers      │   │  → Mobile App   │
└─────────────────┘   └─────────────────┘
```

---

## Services Involved

| Service | Role | Impact |
|---------|------|:------:|
| **schedule-service** | Alert trigger evaluation, push dispatch | 🔴 HIGH |
| **user-service** | Alert storage, history, CRUD, BP delta calculation, Kafka producer | 🟡 MEDIUM |
| **api-gateway-service** | REST API endpoints | 🟡 MEDIUM |
| **Mobile App** | UI components, push handling | 🔴 HIGH |

---

## Existing Infrastructure to Leverage

### From KOLIA-1517 (Kết nối Người thân)

| Component | Reuse For |
|-----------|-----------|
| `invite_notifications` table | Model for `caregiver_alerts` table |
| Kafka connection flow | Alert trigger events |
| FCM push infrastructure | Alert notifications |
| Permission #2 (nhận cảnh báo khẩn cấp) | Alert authorization |
| `caregiver_report_views` | Model for alert read tracking |

### From Existing Features

| Feature | Integration Point |
|---------|-------------------|
| **Đo Huyết áp** | BP thresholds, 7-day average |
| **Uống thuốc** | Missed doses, wrong dose events |
| **SOS** | Emergency alert trigger |

---

## Technology Stack

| Layer | Technology |
|-------|------------|
| API Gateway | Java 17, Vert.x, gRPC client |
| Backend | Java 17, Vert.x, gRPC server |
| Scheduler | Python, Celery, Redis |
| Message Queue | Apache Kafka |
| Push | Firebase Cloud Messaging (FCM) |
| Database | PostgreSQL 15+ |
| Cache | Redis |
| Mobile | React Native, FCM SDK |

---

## Communication Patterns

### Alert Flow (Real-time)

```
BP Measurement → user-service (save + đánh giá delta) → Kafka → schedule-service → FCM → Mobile
                                                                           ↓
                                                              user-service (store alert)
```

### Alert Flow (Batch)

```
Celery Beat (21:00) → schedule-service → Evaluate Compliance
                                      ↓
                               FCM → Mobile
                                      ↓
                            user-service (store alert)
```

---

## Key Constraints

| ID | Constraint | Source |
|----|------------|--------|
| ARCH-001 | Gateway: No business logic | ALIO Standards |
| ARCH-002 | Backend: gRPC + Repository pattern | ALIO Standards |
| PERF-001 | Push delivery ≤ 5 seconds | SRS NFR |
| SEC-001 | PII hidden on lock screen | SRS BR-ALT-013 |
