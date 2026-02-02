# Non-Functional Requirements Extraction

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Source Document** | `docs/srs_input_documents/srs.md` Section 5 |
| **Extraction Date** | 2026-01-26 |

---

## 1. Performance Requirements (NFR-PERF)

| NFR ID | Requirement | Metric | Target | Priority |
|--------|-------------|--------|--------|:--------:|
| NFR-PERF-01 | SOS Entry → Main transition | Response time | < 500ms | 🔴 Critical |
| NFR-PERF-02 | Server-client countdown sync | Tolerance | ≤ 5 seconds | 🔴 Critical |
| NFR-PERF-03 | ZNS sending after countdown | Latency | < 3 seconds | 🔴 Critical |
| NFR-PERF-04 | First Aid content load | Load time (cached) | < 2 seconds | 🟡 High |
| NFR-PERF-05 | Hospital Map load | Load time | < 3 seconds | 🟡 High |

### Performance Notes
- **Countdown sync** is critical - server must be source of truth with max 5s deviation
- **ZNS sending** must be fast to ensure emergency response

---

## 2. Security Requirements (NFR-SEC)

| NFR ID | Requirement | Details | Priority |
|--------|-------------|---------|:--------:|
| NFR-SEC-01 | Location data protection | Share ONLY when SOS activated | 🔴 Critical |
| NFR-SEC-02 | ZNS encryption | Use HTTPS for all ZNS API calls | 🔴 Critical |
| NFR-SEC-03 | CSKH API authentication | Authenticated API calls only | 🔴 Critical |
| NFR-SEC-04 | User consent for location | Already granted via Location Permission | 🟡 High |
| NFR-SEC-05 | Privacy Policy | Display link in Settings | 🟡 High |
| NFR-SEC-06 | Data Retention | SOS events auto-delete after 90 days | 🟡 High |

### Security Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                       │
├─────────────────────────────────────────────────────────┤
│ 1. Transport: HTTPS/TLS for all external communications │
│ 2. Authentication: JWT verified for all SOS requests    │
│ 3. Authorization: User can only trigger own SOS         │
│ 4. Data: Location encrypted in transit and at rest      │
│ 5. Audit: All SOS events logged with timestamps         │
│ 6. Retention: Auto-purge after 90 days                  │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Availability Requirements (NFR-AVAIL)

| NFR ID | Requirement | Details | Priority |
|--------|-------------|---------|:--------:|
| NFR-AVAIL-01 | Offline First Aid | Content cached locally for offline access | 🟡 High |
| NFR-AVAIL-02 | Phone calls offline | Native phone (115, contacts) works without internet | 🔴 Critical |
| NFR-AVAIL-03 | Server countdown failover | Continue countdown if client disconnects | 🔴 Critical |
| NFR-AVAIL-04 | ZNS retry mechanism | Max 3 retries, 30s interval | 🔴 Critical |

### Offline Capability Matrix

| Feature | Offline Support | Notes |
|---------|:---------------:|-------|
| SOS Activation | ✅ Queue | Sync on reconnect |
| Call 115 | ✅ Works | Native phone |
| Call Contacts | ✅ Works | Native phone |
| ZNS Notifications | ❌ Queue | Sent on reconnect |
| Hospital Map | ❌ No | Requires internet |
| First Aid | ✅ Cached | Pre-downloaded |

---

## 4. Accessibility Requirements (NFR-ACC) - Elderly-Friendly

| NFR ID | Requirement | Specification | Priority |
|--------|-------------|---------------|:--------:|
| NFR-ACC-01 | Minimum font size | Body: 16sp, Headers: 20sp | 🔴 Critical |
| NFR-ACC-02 | Contrast ratio (text) | ≥ 4.5:1 | 🔴 Critical |
| NFR-ACC-03 | Contrast ratio (UI) | ≥ 3:1 for UI elements | 🟡 High |
| NFR-ACC-04 | Button touch target | Min 48x48dp | 🔴 Critical |
| NFR-ACC-05 | Emergency color | Red (#DC2626), high contrast | 🔴 Critical |
| NFR-ACC-06 | Sound/Haptic | Must bypass Do Not Disturb | 🔴 Critical |
| NFR-ACC-07 | Escalating feedback | Intensity increases 0-30s | 🟡 High |

### Elderly-Optimized Design Principles
1. **Large, Clear Text** - All text easily readable
2. **High Contrast** - Buttons clearly visible
3. **Simple Actions** - One-tap operations
4. **Auditory + Tactile** - Multi-sensory feedback
5. **Forgiving UI** - Cancel option always available

---

## 5. Reliability Requirements (NFR-REL)

| NFR ID | Requirement | Details | Priority |
|--------|-------------|---------|:--------:|
| NFR-REL-01 | SOS success rate | ≥ 99.9% for alert delivery | 🔴 Critical |
| NFR-REL-02 | Graceful degradation | Fallback hierarchy: ZNS → SMS → CSKH | 🔴 Critical |
| NFR-REL-03 | Error recovery | All errors logged, CSKH notified | 🔴 Critical |

### Fallback Hierarchy
```
┌─────────────────────────────────────────────────────┐
│              SOS DELIVERY FALLBACK                   │
├─────────────────────────────────────────────────────┤
│ Level 1: ZNS to ALL family contacts (parallel)       │
│    ↓ If FAIL after 3 retries                        │
│ Level 2: SMS fallback (if configured)               │
│    ↓ If FAIL                                        │
│ Level 3: CSKH API alert (manual intervention)       │
└─────────────────────────────────────────────────────┘
```

---

## 6. Compatibility Requirements (NFR-COMP)

| NFR ID | Requirement | Details | Priority |
|--------|-------------|---------|:--------:|
| NFR-COMP-01 | iOS support | iOS 13+ for DND bypass | 🟡 High |
| NFR-COMP-02 | Android support | Android 8+ for DND bypass | 🟡 High |
| NFR-COMP-03 | Zalo integration | Detect Zalo installation | 🟡 High |

---

## 7. Localization Requirements (NFR-L10N)

| NFR ID | Requirement | Details | Priority |
|--------|-------------|---------|:--------:|
| NFR-L10N-01 | Language | Vietnamese (vi-VN) primary | 🔴 Critical |
| NFR-L10N-02 | Timezone | Asia/Ho_Chi_Minh for timestamps | 🔴 Critical |
| NFR-L10N-03 | Phone format | Vietnamese format (10-11 digits) | 🟡 High |

---

## 8. NFR Summary

| Category | Count | Critical | High |
|----------|:-----:|:--------:|:----:|
| Performance | 5 | 3 | 2 |
| Security | 6 | 3 | 3 |
| Availability | 4 | 3 | 1 |
| Accessibility | 7 | 5 | 2 |
| Reliability | 3 | 3 | 0 |
| Compatibility | 3 | 0 | 3 |
| Localization | 3 | 2 | 1 |
| **TOTAL** | **31** | **19** | **12** |

---

## 9. Validation Matrix

| Requirement | Verification Method | Criteria |
|-------------|---------------------|----------|
| NFR-PERF-* | Load testing | Meet latency targets |
| NFR-SEC-* | Security audit | OWASP compliance |
| NFR-AVAIL-* | Offline testing | Feature works |
| NFR-ACC-* | Accessibility testing | WCAG 2.1 AA |
| NFR-REL-* | Chaos engineering | Graceful degradation |

---

## Next Phase

✅ **Phase 3: NFR Extraction** - COMPLETE

➡️ **Phase 4: Architecture Mapping**
