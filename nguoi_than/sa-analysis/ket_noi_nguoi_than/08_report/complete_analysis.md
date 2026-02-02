# Complete Analysis: KOLIA-1517 (REVISED v2.15)

> **SA Analysis Report**  
> **Date:** 2026-02-02  
> **Revision:** v2.15 - Added Default View State (UX-DVS-*) from SRS v3, synced version numbers

---

## 1. Executive Summary

| Metric | Value |
|--------|-------|
| **Feasibility** | 88/100 ✅ (improved) |
| **Impact** | 🟢 LOW (reduced from MEDIUM) |
| **Tables** | 5 NEW + 1 ALTER |
| **Effort** | 68 hours (updated) |

---

## 2. Schema Optimization

### Before (v1.0)
```
4 new tables:
- connection_invites
- user_connections     ← Duplicate data
- connection_permissions
- invite_notifications
```

### After (v2.0)
```
4 new + 1 extend:
- relationships       ← NEW lookup
- connection_invites  ← Invite lifecycle
- user_emergency_contacts ← EXTEND (reuse!)
- connection_permissions ← RBAC
- invite_notifications ← Delivery
```

**Benefits:**
- ✅ Reuse `user_emergency_contacts`
- ✅ `relationships` lookup shared
- ✅ SOS backward compatible
- ✅ Less code duplication

---

## 3. Gap Analysis Summary

### Core Connection Rules (25 BRs)

| SRS Requirement | Implementation | ✅ |
|-----------------|----------------|:--:|
| Bi-directional invites (BR-001) | connection_invites.invite_type | ✅ |
| ZNS/SMS fallback (BR-004) | invite_notifications | ✅ |
| No self-invite (BR-006) | CHECK constraint | ✅ |
| No duplicate pending (BR-007) | UNIQUE partial index | ✅ |
| Accept → connection + 6 perms (BR-008) | user_emergency_contacts + trigger | ✅ |
| 6 permissions default ON (BR-009) | Trigger auto-create | ✅ |
| Notify sender on accept/reject (BR-010/011) | Kafka + notification payload | ✅ |
| Relationship stored (BR-028) | relationships lookup | ✅ |

### Dashboard Rules (11 BR-DB-*)

| Requirement | Implementation | ✅ |
|-------------|----------------|:--:|
| Line Chart 2 đường (BR-DB-001) | API + UI spec | ✅ |
| Toggle Tuần/Tháng auto-select (BR-DB-002) | API logic | ✅ |
| Permission #1 gate (BR-DB-008, BR-DB-011) | SEC-DB-001 | ✅ |
| Empty states (BR-DB-009, BR-DB-010) | UI spec | ✅ |

### Security Requirements (3 SEC-DB-*)

| Requirement | Implementation | ✅ |
|-------------|----------------|:--:|
| API Authorization (SEC-DB-001) | Permission check at user-service | ✅ |
| Permission Revoke 403 (SEC-DB-002) | No-cache policy | ✅ |
| Deep Link Protection (SEC-DB-003) | Validation flow | ✅ |

**Coverage: 41 total rules (25 Core + 11 Dashboard + 2 Report + 3 Security)**

---

## 4. Table Summary

| Table | Status | Columns | Indexes |
|-------|:------:|:-------:|:-------:|
| relationships | NEW | 6 | 0 |
| connection_invites | NEW | 11 | 5 |
| user_emergency_contacts | EXTEND | +4 | +2 |
| connection_permissions | NEW | 5 | 1 |
| invite_notifications | NEW | 10 | 3 |

---

## 5. Implementation Roadmap

| Phase | Duration | Focus |
|:-----:|----------|-------|
| 1 | Week 1 | Migrations + Entities |
| 2 | Week 2 | Services + gRPC |
| 3 | Week 3 | REST + Notifications |
| 4 | Week 4 | Testing |

---

## 6. Documents Updated

| Document | Status |
|----------|:------:|
| 02_context/database_entities.md | ✅ v2.0 |
| 03_extraction/functional_requirements.md | ✅ v2.11 (UX-DVS-*) |
| 04_mapping/database_mapping.md | ✅ v2.7 |
| 04_mapping/api_mapping.md | ✅ v2.13 |
| 06_impact/impact_analysis.md | ✅ v2.13 |
| v2.14_mark_report_read_api.md | ✅ v2.14 |
| v2.15_default_view_state.md | ✅ v2.15 (NEW) |
| 08_report/complete_analysis.md | ✅ v2.15 |
| features/.../database-changes.sql | ✅ v2.0 |

---

## 7. Approval

| Role | Status | Date |
|------|:------:|------|
| SA Lead | ✅ | 2026-01-28 |
| Tech Lead | ⏳ | - |
