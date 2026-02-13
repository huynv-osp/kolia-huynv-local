# Non-Functional Requirements: KOLIA-1517 - Kết nối Người thân

> **Phase:** 3 - Requirements Extraction  
> **Date:** 2026-02-13  
> **Revision:** v4.0 - Family Group model, slot-based connections, cross-service dependencies

---

## 1. Performance Requirements

| Requirement | Target | Notes |
|-------------|--------|-------|
| API Response Time | < 200ms (p95) | For all REST endpoints |
| Database Query | < 50ms | With proper indexes |
| Notification Delivery | < 5s | ZNS/Push |
| Concurrent Users | 10,000+ | Active connections |
| **Slot Check Latency** | < 100ms | **v4.0:** gRPC call to payment-service |
| **Auto-connect Processing** | < 500ms | **v4.0:** Creating N connections on CG accept |
| **Family Group Query** | < 100ms | **v4.0:** Group + members + slot info |

---

## 2. Availability Requirements

| Requirement | Target | Notes |
|-------------|--------|-------|
| user-service Uptime | 99.9% | Core service |
| Database Availability | 99.95% | PostgreSQL |
| Notification SLA | 99% delivery rate | ZNS/Push |
| **payment-service** | 99.9% | **v4.0:** Required for invite flow (slot check) |
| **Graceful Degradation** | Required | **v4.0:** If payment-service down → block invite with clear UX message |

---

## 3. Security Requirements

| Category | Requirement | Notes |
|----------|-------------|-------|
| Authentication | JWT token validation | All endpoints |
| Authorization | User can only modify own data | |
| **Admin Authorization** | **Only Admin can send invites** | **v4.0 BR-041** |
| Data Privacy | Permissions control visibility | 5-category RBAC |
| **Silent Revoke** | **No notification on permission changes** | **v4.0 BR-056** |
| Audit Trail | Track all permission changes | |
| **Exclusive Group** | **Server-side enforcement** | **v4.0 BR-057:** 1 user = 1 group |

---

## 4. Scalability Requirements

| Dimension | Requirement | Notes |
|-----------|-------------|-------|
| **Connections per Group** | **Slot-based per package** | **v4.0 BR-033, BR-059:** Determined by payment subscription |
| Concurrent invites | 1000/minute | |
| **Slot Race Condition** | **Pessimistic locking** | **v4.0:** Prevent double-consume at payment-service |
| **Auto-connect Fan-out** | Up to N patients per accept | **v4.0 BR-045:** CG connects to ALL patients in group |
| **Member Broadcast** | Up to M members per event | **v4.0 BR-052:** Push to all members on new join |

---

## 5. Notification Requirements

| Channel | Requirement |
|---------|-------------|
| ZNS | Primary channel, approved templates |
| SMS | Fallback when ZNS fails |
| Push | In-app notifications |
| Retry | 3x with 30s interval (BR-004) |
| **Member Broadcast** | **v4.0 BR-052:** Push to ALL existing members on new join |
| **Silent Changes** | **v4.0 BR-056:** NO notification for permission on/off |

---

## 6. UI/UX Requirements

| Requirement | Target |
|-------------|--------|
| Touch Target | 44x44 dp minimum |
| Accessibility | WCAG 2.1 AA |
| Language | Vietnamese only |
| Confirmation | Required for destructive actions (TẮT permission, Tắt quyền theo dõi, Xoá thành viên, Rời nhóm) |

---

## 7. Data Retention

| Data Type | Retention |
|-----------|-----------|
| Active Connections | Indefinite |
| Rejected Invites | 30 days |
| Notification Logs | 90 days |
| **Revoked Connections** | **Indefinite** (v4.0: soft disconnect, permission_revoked flag) |
| **Family Group History** | **Indefinite** (status tracking) |

---

## 8. Cross-Service Dependencies (v4.0)

| Dependency | Protocol | Required For | Failure Mode |
|------------|----------|-------------|--------------|
| user-service → payment-service | gRPC | Slot check, Admin validation | Block invite, show error |
| user-service → payment-service | gRPC | GetSubscription (group info) | Degrade gracefully |
| api-gateway → user-service | gRPC | All KCNT operations | Standard error handling |
| schedule-service → Kafka | Event | Member broadcast notifications | Retry with dead-letter |
| auth-service → user-service | gRPC | Backfill receiver_id | Fire-and-forget with logging |
