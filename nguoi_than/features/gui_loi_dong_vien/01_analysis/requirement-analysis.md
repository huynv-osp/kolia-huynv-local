# Requirement Analysis: US 1.3 - Gửi Lời Động Viên

> **Phase:** 1 - Requirement Intake & Classification  
> **Date:** 2026-02-04  
> **Source:** [SRS v1.3](../../srs_input_documents/srs_gui_loi_dong_vien.md)

---

## 1. Feature Classification (FA-001)

| Attribute | Value |
|-----------|-------|
| **Name** | Gửi Lời Động Viên (Encouragement Messages) |
| **Type** | ✨ New Feature |
| **Complexity** | 🟡 Medium |
| **User Story** | US 1.3 |
| **Epic** | Kết nối Người thân |

---

## 2. Scope Boundaries

### ✅ IN SCOPE

| Item | Description |
|------|-------------|
| Create Encouragement | Caregiver gửi tin nhắn đến Patient |
| Receive Encouragement | Patient xem lời động viên qua modal 24h |
| Quota Management | Max 10 tin/ngày/Patient |
| Mark as Read | Batch mark read cho Patient |
| Push Notification | Real-time notification khi có tin mới |

### ❌ OUT OF SCOPE (DEFERRED)

| Item | Reason |
|------|--------|
| AI Suggestions | Deferred to future release |
| Patient Reply | Giao tiếp một chiều |
| Message Edit/Delete | Không có trong SRS |
| Full Chat History | Chỉ hiển thị 24h window |

---

## 3. Actors & Permissions

| Actor | Role | Permission Required |
|-------|------|---------------------|
| **Caregiver** | Sender | Permission #6 = ON |
| **Patient** | Receiver | N/A (only receives) |

---

## 4. Business Rules Summary

| BR-ID | Rule | Priority | Enforcement |
|:-----:|------|:--------:|-------------|
| BR-001 | Max 10 tin/ngày/Patient | HIGH | Server-side quota |
| BR-002 | Max 150 Unicode chars | HIGH | DB constraint |
| BR-003 | Permission #6 = ON | CRITICAL | Real-time check |
| BR-004 | Nội dung không kiểm duyệt AI | HIGH | Caregiver chịu TN |
| BR-005 | AI gợi ý 3 lời nhắn | ⏸️ DEFERRED | N/A |

---

## 5. Functional Scenarios

### US-001: Caregiver Gửi Lời Động Viên

| Scenario | Type | Priority |
|----------|:----:|:--------:|
| SC-1: Gửi tin nhắn thành công (Happy Path) | Success | P0 |
| SC-2: Permission #6 = OFF | Authorization | P0 |
| SC-3: Quota exhausted (10/day) | Limit | P1 |
| SC-4: Content > 150 chars | Validation | P1 |
| SC-5: Empty content | Validation | P1 |
| SC-6: Network offline | Error | P2 |
| SC-7: Server error 5xx | Error | P2 |
| SC-8: Permission revoked mid-send | Edge Case | P2 |

---

## 6. NFR Summary

| ID | Category | Requirement | Target |
|:--:|----------|-------------|--------|
| NFR-001 | ~~Performance~~ | ~~AI Latency~~ | ⏸️ DEFERRED |
| NFR-002 | Security | TLS 1.3 encryption | Required |
| NFR-003 | Availability | 99.9% uptime | High |

---

## 7. ADR (Architecture Decision Record)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary Service | user-service | Manages user relationships & permissions |
| Communication | gRPC | Standard ALIO pattern |
| Data Storage | `encouragement_messages` | New table in user-service DB |
| Notification | Kafka → schedule-service | Async push delivery |

---

## 8. Complexity Score

| Factor | Weight | Score | Weighted |
|--------|:------:|:-----:|:--------:|
| Services affected (4) | 25% | 3 | 0.75 |
| Database changes (1 table) | 20% | 2 | 0.40 |
| New API endpoints (4) | 15% | 3 | 0.45 |
| Business logic complexity | 20% | 2 | 0.40 |
| Integration requirements | 10% | 2 | 0.20 |
| Testing requirements | 10% | 2 | 0.20 |

**Total Score: 24/50 → 🟡 MEDIUM Complexity**

---

## Next Phase

➡️ Proceed to Phase 2: System Context Mapping
