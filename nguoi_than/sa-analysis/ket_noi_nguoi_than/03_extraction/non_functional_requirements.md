# Non-Functional Requirements: KOLIA-1517 - Kết nối Người thân

> **Phase:** 3 - Requirements Extraction  
> **Date:** 2026-01-28

---

## 1. Performance Requirements

| Requirement | Target | Notes |
|-------------|--------|-------|
| API Response Time | < 200ms (p95) | For all REST endpoints |
| Database Query | < 50ms | With proper indexes |
| Notification Delivery | < 5s | ZNS/Push |
| Concurrent Users | 10,000+ | Active connections |

---

## 2. Availability Requirements

| Requirement | Target |
|-------------|--------|
| Service Uptime | 99.9% |
| Database Availability | 99.95% |
| Notification SLA | 99% delivery rate |

---

## 3. Security Requirements

| Category | Requirement |
|----------|-------------|
| Authentication | JWT token validation |
| Authorization | User can only modify own data |
| Data Privacy | Permissions control visibility |
| Audit Trail | Track all permission changes |

---

## 4. Scalability Requirements

| Dimension | Requirement |
|-----------|-------------|
| Connections per Patient | Unlimited (Phase 1) |
| Connections per Caregiver | Unlimited |
| Concurrent invites | 1000/minute |

---

## 5. Notification Requirements

| Channel | Requirement |
|---------|-------------|
| ZNS | Primary channel, approved templates |
| SMS | Fallback when ZNS fails |
| Push | In-app notifications |
| Retry | 3x with 30s interval (BR-004) |

---

## 6. UI/UX Requirements

| Requirement | Target |
|-------------|--------|
| Touch Target | 44x44 dp minimum |
| Accessibility | WCAG 2.1 AA |
| Language | Vietnamese only |
| Confirmation | Required for destructive actions |

---

## 7. Data Retention

| Data Type | Retention |
|-----------|-----------|
| Active Connections | Indefinite |
| Rejected Invites | 30 days |
| Notification Logs | 90 days |
