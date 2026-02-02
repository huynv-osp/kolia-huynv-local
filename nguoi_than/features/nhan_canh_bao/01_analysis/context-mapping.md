# Context Mapping: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 2 - System Context Mapping  
> **Date:** 2026-02-02  
> **Source:** [SA Analysis](../../../sa-analysis/nhan_canh_bao/)

---

## 1. ALIO Services Mapping

| Service | Role | Impact |
|---------|------|:------:|
| **user-service** | Alert entity, gRPC service, BP delta calculation, Kafka producer | 🟡 MEDIUM |
| **api-gateway** | REST endpoints | 🟡 MEDIUM |
| **schedule-service** | Trigger consumer, evaluators, push | 🔴 HIGH |
| **Mobile App** | UI screens, push handling | 🔴 HIGH |

---

## 2. Data Flow Architecture

```
┌─────────────────┐       ┌────────────────┐       ┌─────────────────┐
│   Mobile App    │◄─────►│  API Gateway   │◄─────►│  user-service   │
│  (Alert UI)     │ REST  │  (Endpoints)   │ gRPC  │(Alert + Delta)  │
└────────┬────────┘       └────────────────┘       └────────┬────────┘
         │                                                   │
         │ FCM Push                                         │ Kafka
         │                                                   │
┌────────▼────────┐       ┌────────────────┐       ┌────────▼────────┐
│   FCM Service   │◄──────│schedule-service│◄──────│topic-alert-     │
│                 │       │ (Trigger/Push) │       │    triggers     │
└─────────────────┘       └────────────────┘       └─────────────────┘
```

---

## 3. Database Entities

### Existing (Reuse)

| Table | Purpose |
|-------|---------|
| `user_emergency_contacts` | Active caregivers for patient |
| `connection_permissions` | Permission #2 check |
| `user_blood_pressure` | BP threshold evaluation |
| `medication_schedules` | Missed medication tracking |

### New (Create)

| Table | Purpose |
|-------|---------|
| `caregiver_alerts` | Main alerts table (14 columns) |
| `caregiver_alert_types` | Lookup table (4 categories) |

---

## 4. Integration Points

| From | To | Protocol | Topic/Method |
|------|-----|----------|--------------|
| user-service | schedule-service | Kafka | `topic-alert-triggers` |
| schedule-service | user-service | gRPC | `CreateAlert` |
| schedule-service | FCM | HTTP | Push notification |
| user-service | schedule-service | Kafka | `topic-alert-dispatched` |

---

## 5. Processing Modes

### ⚡ Real-time (≤5s SLA)

| Alert | Source |
|-------|--------|
| SOS | user-service |
| HA Bất thường | user-service (BP delta calculation) |
| Sai liều | user-service |

### 📅 Batch (21:00 Daily)

| Alert | Source |
|-------|--------|
| Tuân thủ <70% | schedule-service |
| Bỏ lỡ 3 liên tiếp | schedule-service |

---

## Next Phase

➡️ [impact-analysis.md](./impact-analysis.md)
