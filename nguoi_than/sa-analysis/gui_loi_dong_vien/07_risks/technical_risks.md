# Technical Risks: US 1.3 - Gửi Lời Động Viên

> **Phase:** 7 - Technical Risks & Recommendations  
> **Date:** 2026-02-04

---

## Risk Register

### RISK-001: Push Notification Failure

| Attribute | Value |
|-----------|-------|
| **Category** | Infrastructure |
| **Probability** | 🟢 LOW (10%) |
| **Impact** | 🟡 MEDIUM |
| **Risk Score** | 4/10 |

**Description:**  
FCM/APNs delivery may fail due to network issues or invalid tokens.

**Mitigation:**
1. Implement retry queue (3 attempts, exponential backoff)
2. Track push_status in database
3. Log and alert on failure spikes
4. Graceful degradation: message saved even if push fails

**Contingency:**  
Patient can still view messages in-app via modal/list.

---

### RISK-002: Permission Race Condition

| Attribute | Value |
|-----------|-------|
| **Category** | Concurrency |
| **Probability** | 🟢 LOW (5%) |
| **Impact** | 🟢 LOW |
| **Risk Score** | 2/10 |

**Description:**  
Permission may be revoked between widget load and send action.

**Mitigation:**
1. Real-time permission check in CreateEncouragement
2. Return clear error message
3. Client-side refresh after error
4. Log permission denials for analysis

**Contingency:**  
User receives clear error; no data corruption.

---

### RISK-003: Quota Bypass Attempt

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Probability** | 🟢 LOW (5%) |
| **Impact** | 🟡 MEDIUM |
| **Risk Score** | 3/10 |

**Description:**  
Malicious user may attempt to bypass 10/day quota limit.

**Mitigation:**
1. Server-side quota enforcement (never trust client)
2. Use database COUNT with proper date filter
3. Consider Redis atomic counter for high-volume
4. Rate limit API (60 req/min per user)

**Contingency:**  
Database constraint prevents over-quota messages.

---

### RISK-004: Content Injection (XSS)

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Probability** | 🟢 LOW (5%) |
| **Impact** | 🟡 MEDIUM |
| **Risk Score** | 3/10 |

**Description:**  
User may attempt to inject malicious scripts in message content.

**Mitigation:**
1. Input sanitization on backend
2. Content encoding on frontend display
3. CSP headers on web views
4. No HTML rendering in content field

**Contingency:**  
Content stored as plain text only.

---

### RISK-005: Database Performance

| Attribute | Value |
|-----------|-------|
| **Category** | Performance |
| **Probability** | 🟢 LOW (10%) |
| **Impact** | 🟢 LOW |
| **Risk Score** | 2/10 |

**Description:**  
High message volume may impact query performance.

**Mitigation:**
1. Proper indexing (quota, unread, recent)
2. 90-day retention with scheduled cleanup
3. Partition by date if needed (future)
4. Monitor query execution time

**Contingency:**  
Add BRIN index on sent_at for range queries.

---

## Risk Summary Matrix

| Risk ID | Risk | Probability | Impact | Score | Status |
|:-------:|------|:-----------:|:------:|:-----:|:------:|
| RISK-001 | Push Failure | 🟢 | 🟡 | 4 | MITIGATED |
| RISK-002 | Permission Race | 🟢 | 🟢 | 2 | MITIGATED |
| RISK-003 | Quota Bypass | 🟢 | 🟡 | 3 | MITIGATED |
| RISK-004 | XSS Injection | 🟢 | 🟡 | 3 | MITIGATED |
| RISK-005 | DB Performance | 🟢 | 🟢 | 2 | MITIGATED |

**Overall Risk Level:** 🟢 LOW

---

## Risk Monitoring

| Risk | Monitoring Metric | Alert Threshold |
|------|-------------------|-----------------|
| Push Failure | `schedule.push.failure_rate` | > 5% |
| Permission Denial | `user.encouragement.permission_denied` | > 100/hour |
| Quota Exceeded | `user.encouragement.quota_exceeded_rate` | > 50% users |
| Create Latency | `user.encouragement.create_latency_p95` | > 1s |

---

## Next Steps

➡️ Proceed to Phase 8: Report Generation & Review
