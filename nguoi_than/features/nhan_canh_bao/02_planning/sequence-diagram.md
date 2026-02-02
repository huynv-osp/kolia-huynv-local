# Sequence Diagram: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 6 - Dependency & Sequence Planning  
> **Date:** 2026-02-02

---

## 1. Real-time HA Alert Flow

```mermaid
sequenceDiagram
    participant P as Patient
    participant US as user-service
    participant K as Kafka
    participant SS as schedule-service
    participant FCM as FCM
    participant C as Caregiver App

    P->>US: Đo HA (145/95)
    US->>US: Save BP record
    US->>US: Calculate 7-day avg
    US->>US: Check delta >10mmHg
    US->>K: topic-alert-triggers
    K->>SS: Consume event
    SS->>SS: Check debounce (Redis)
    SS->>SS: Check Permission #2
    SS->>US: CreateAlert (gRPC)
    US->>US: Save alert record
    SS->>FCM: Send push
    FCM->>C: Deliver notification
    
    alt App Foreground
        C->>C: Show Modal Popup
    else App Background
        C->>C: Show System Notification
    end
```

---

## 2. SOS Alert Flow

```mermaid
sequenceDiagram
    participant P as Patient
    participant US as user-service
    participant K as Kafka
    participant SS as schedule-service
    participant FCM as FCM
    participant C as Caregiver App

    P->>US: Activate SOS
    US->>K: topic-alert-triggers (SOS)
    K->>SS: Consume (Priority 0)
    Note over SS: No debounce for SOS
    SS->>US: CreateAlert (gRPC)
    SS->>FCM: Send CRITICAL push
    FCM->>C: Deliver (bypass DND)
    C->>C: Show SOS Modal
```

---

## 3. Batch 21:00 Flow

```mermaid
sequenceDiagram
    participant CB as Celery Beat
    participant SS as schedule-service
    participant DB as Database
    participant US as user-service
    participant FCM as FCM

    CB->>SS: Trigger 21:00 batch
    SS->>DB: Query compliance data
    SS->>SS: Evaluate <70%
    SS->>SS: Detect 3 consecutive misses
    SS->>SS: Apply BR-ALT-019 (consolidate)
    SS->>US: CreateAlert (batch)
    SS->>FCM: Send push (batch)
```

---

## 4. Task Dependencies

```
DB-001 ──▶ PROTO-001 ──▶ USR-001 ──▶ USR-003 ──▶ USR-005 ──┐
                                                            │
                   USR-007 ──▶ USR-008 ──▶ SCH-001 ─────────┤
                                                            │
                         PROTO-001 ──▶ GW-002 ──────────────┤
                                                            ▼
                                                     USR-006 ──▶ GW-001
                                                            │
JOB-001 ──▶ SCH-001 ──▶ SCH-002 ──▶ SCH-007 ────────────────┘
                   │
                   └──▶ SCH-005 ──▶ SCH-007
```

---

## 5. Integration Dependencies

| Source | Target | Event/Method |
|--------|--------|--------------|
| user-service | Kafka | `topic-alert-triggers` (producer) |
| schedule-service | Kafka | Consumer |
| schedule-service | user-service | `CreateAlert` gRPC |
| schedule-service | FCM | Push HTTP |
| user-service | schedule-service | `topic-alert-dispatched` |

---

## Next Phase

➡️ [../03_review/review-checklist.md](../03_review/review-checklist.md)
