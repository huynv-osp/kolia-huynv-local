# Complete Analysis: KOLIA-1517 (v4.0)

> **SA Analysis Report**  
> **Date:** 2026-02-13  
> **Revision:** v4.0 - Family Group model + Admin-managed + slot-based connections

---

## 1. Executive Summary

| Metric | v2.23 | v4.0 |
|--------|:-----:|:----:|
| **Feasibility** | 88/100 | **82/100** ✅ |
| **Impact** | 🟢 LOW | **🟡 MEDIUM** |
| **Services** | 3 | **5** |
| **Tables** | 6 NEW + 1 ALTER | **2 NEW + 6 existing + 1 ALTER** |
| **BRs** | 41 | **60+** |
| **Effort** | 68h | **~80h** |

---

## 2. Model Evolution

### v2.0 (Bi-directional)
```
2 NEW tables + 1 extend:
- connection_invites  ← Bi-directional invite
- user_emergency_contacts ← EXTEND
- connection_permissions ← RBAC
- invite_notifications ← Delivery
- relationships       ← Lookup
```

### v4.0 (Family Group)
```
+2 NEW tables + updated:
- family_groups       ← NEW: Group lifecycle
- family_group_members← NEW: Slot-based membership
- connection_invites  ← invite_type: add_patient/add_caregiver
- user_emergency_contacts ← +permission_revoked, +family_group_id
- connection_permissions ← 5 types (from 6)
- invite_notifications ← Unchanged
- relationships       ← Unchanged
```

**Key Architecture Changes:**
- ✅ Admin-only invites (BR-041) — Member cannot invite
- ✅ Auto-connect CG→ALL Patients (BR-045)
- ✅ Soft disconnect via permission_revoked (BR-040)
- ✅ Exclusive group: 1 user = 1 group (BR-057)
- ✅ Slot-based via payment-service integration
- ✅ Leave group for Non-Admin (BR-061)

---

## 3. Gap Analysis Summary

### Core Connection Rules (60+ BRs)

| SRS Requirement | Implementation | ✅ |
|-----------------|----------------|:--:|
| Admin-only invites (BR-041) | Admin check + Family Group | ✅ |
| Simplified form: phone only (BR-055) | CreateInviteRequest | ✅ |
| Slot pre-check (BR-033, BR-059) | gRPC to payment-service | ✅ |
| Auto-connect on CG accept (BR-045) | Transactional fan-out | ✅ |
| Soft disconnect (BR-040) | permission_revoked flag | ✅ |
| Exclusive group (BR-057) | UNIQUE constraint + server check | ✅ |
| Admin self-add auto-accept (BR-049) | Skip invite flow | ✅ |
| Silent revoke/restore (BR-056) | No notification | ✅ |
| Leave group (BR-061) | Non-Admin self-remove | ✅ |
| Member broadcast (BR-052) | Kafka + push | ✅ |
| ZNS/SMS fallback (BR-004) | invite_notifications | ✅ |
| No self-invite (BR-006) | CHECK constraint | ✅ |
| No duplicate pending (BR-007) | UNIQUE partial index | ✅ |
| Accept → connection + 5 perms (BR-008, BR-009) | Trigger | ✅ |
| MQH optional on accept (BR-050) | Null fallback to {Tên} | ✅ |
| MQH update via SCR-06 (BR-054) | PUT relationship API | ✅ |
| Admin cannot self-remove (BR-058) | Server validation | ✅ |

### Dashboard Rules (11 BR-DB-*)

| Requirement | Implementation | ✅ |
|-------------|----------------|:--:|
| Line Chart 2 đường (BR-DB-001) | API + UI spec | ✅ |
| Toggle Tuần/Tháng auto-select (BR-DB-002) | API logic | ✅ |
| Permission #1 gate (BR-DB-008, BR-DB-011) | SEC-DB-001 | ✅ |
| Empty states (BR-DB-009, BR-DB-010) | UI spec | ✅ |
| Report list (BR-RPT-001, BR-RPT-002) | SCR-REPORT-LIST | ✅ |

### Security Requirements (3 SEC-DB-*)

| Requirement | Implementation | ✅ |
|-------------|----------------|:--:|
| API Authorization (SEC-DB-001) | Permission check at user-service | ✅ |
| Permission Revoke 403 (SEC-DB-002) | No-cache policy | ✅ |
| Deep Link Protection (SEC-DB-003) | Validation flow | ✅ |

**Coverage: 60+ total rules**

---

## 4. Table Summary

| Table | Status | Columns | Indexes |
|-------|:------:|:-------:|:-------:|
| **family_groups** | **NEW v4.0** | **7** | **2** |
| **family_group_members** | **NEW v4.0** | **7** | **2** |
| relationships | Existing | 6 | 0 |
| relationship_inverse_mapping | Existing | 3 | 1 |
| connection_invites | Updated | 12 | 5 |
| user_emergency_contacts | Extended | +3 (v4.0) | +1 |
| connection_permissions | Existing | 5 | 1 |
| invite_notifications | Existing | 13 | 5 |

---

## 5. Implementation Roadmap

| Phase | Duration | Focus |
|:-----:|----------|-------|
| 1 | Week 1-2 | Foundation: family_groups + entities + payment client |
| 2 | Week 2-3 | Invite flow: Admin-only + slot check + auto-connect |
| 3 | Week 3-4 | Permissions: revoke/restore + exclusive group + leave |
| 4 | Week 4-5 | Notifications: broadcast + ZNS + silent changes |
| 5 | Week 5-6 | Testing: cross-service + migration + UAT |

---

## 6. Documents Updated

| Document | Status |
|----------|:------:|
| 01_intake/document_classification.md | ✅ v4.0 |
| 01_intake/scope_summary.md | ✅ v4.0 |
| 02_context/architecture_snapshot.md | ✅ v4.0 |
| 02_context/database_entities.md | ✅ v4.0 |
| 03_extraction/functional_requirements.md | ✅ v4.0 |
| 03_extraction/non_functional_requirements.md | ✅ v4.0 |
| 04_mapping/api_mapping.md | ✅ v4.0 |
| 04_mapping/database_mapping.md | ✅ v4.0 |
| 04_mapping/service_mapping.md | ✅ v4.0 (NEW) |
| 05_feasibility/feasibility_report.md | ✅ v4.0 |
| 06_impact/impact_analysis.md | ✅ v4.0 (NEW) |
| 07_risks/technical_risks.md | ✅ v4.0 |
| 07_risks/implementation_recommendations.md | ✅ v4.0 |
| 08_report/executive_summary.md | ✅ v4.0 |
| 08_report/complete_analysis.md | ✅ v4.0 |

---

## 7. Approval

| Role | Status | Date |
|------|:------:|------|
| SA Lead | ✅ | 2026-02-13 |
| Tech Lead | ⏳ | - |
