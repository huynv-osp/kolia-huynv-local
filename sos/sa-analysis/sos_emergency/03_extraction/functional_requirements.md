# Functional Requirements Extraction

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Source Document** | `docs/srs_input_documents/srs.md` |
| **Extraction Date** | 2026-01-26 |

---

## 1. Feature Categories

### Feature Map

| Category | Feature Count | Priority |
|----------|:-------------:|:--------:|
| SOS Activation | 4 scenarios | 🔴 Critical |
| Escalation Flow | 3 scenarios | 🔴 Critical |
| Post-SOS Support | 3 scenarios | 🟡 High |
| Offline Handling | 2 scenarios | 🔴 Critical |
| Low Battery | 1 scenario | 🟡 High |
| Error Handling | 4 scenarios | 🔴 Critical |

---

## 2. Functional Requirements by Feature

### 2.1 SOS Activation (FR-SOS-01 to FR-SOS-04)

#### FR-SOS-01: SOS Entry Screen
| ID | FR-SOS-01 |
|------|-----------|
| **Description** | Display SOS Entry confirmation screen before activation |
| **Trigger** | User taps SOS floating button on Home Screen |
| **Input** | None |
| **Output** | SOS Entry screen with header "🚨 Bạn cần giúp đỡ?" |
| **Actors** | Patient (End User) |
| **Pre-conditions** | User is authenticated, on Home Screen |
| **Post-conditions** | Entry screen displayed |
| **BR References** | - |
| **Priority** | 🔴 Critical |

#### FR-SOS-02: SOS Countdown Activation
| ID | FR-SOS-02 |
|------|-----------|
| **Description** | Start 30-second countdown with escalating feedback |
| **Trigger** | User taps "KÍCH HOẠT SOS" button |
| **Input** | None |
| **Output** | SOS Main screen with countdown, Sound/Haptic feedback |
| **Actors** | Patient, System |
| **Pre-conditions** | User on SOS Entry screen |
| **Post-conditions** | Countdown running, server notified |
| **BR References** | BR-SOS-001, BR-SOS-002 |
| **Priority** | 🔴 Critical |

**Countdown Feedback Specification:**
| Time | Sound | Haptic |
|------|-------|--------|
| 0-20s | Beep every 5s | Light vibration every 5s |
| 20-25s | Beep every 2s | Faster vibration |
| 25-30s | Continuous beep | Continuous vibration |

#### FR-SOS-03: Alert Sending on Countdown Complete
| ID | FR-SOS-03 |
|------|-----------|
| **Description** | Send ZNS to ALL family contacts simultaneously + CSKH alert |
| **Trigger** | Countdown reaches 0 |
| **Input** | User ID, GPS location |
| **Output** | ZNS messages sent, CSKH alerted, GPS shared |
| **Actors** | System |
| **Pre-conditions** | Countdown completed, not cancelled |
| **Post-conditions** | Alerts sent, SOS Support Dashboard displayed |
| **BR References** | BR-SOS-003, BR-SOS-004 |
| **Priority** | 🔴 Critical |

#### FR-SOS-04: SOS Cancellation
| ID | FR-SOS-04 |
|------|-----------|
| **Description** | Allow user to cancel SOS during countdown |
| **Trigger** | User taps "❌ HỦY" button |
| **Input** | None |
| **Output** | Countdown stopped, return to Home |
| **Actors** | Patient |
| **Pre-conditions** | Countdown is running |
| **Post-conditions** | No alerts sent, NO cooldown applied |
| **BR References** | BR-SOS-005 |
| **Priority** | 🔴 Critical |

#### FR-SOS-05: Send Alert Now (Skip Countdown)
| ID | FR-SOS-05 |
|------|-----------|
| **Description** | Skip countdown and send alert immediately |
| **Trigger** | User taps "🆘 GỬI CẢNH BÁO NGAY" button |
| **Input** | None |
| **Output** | Countdown stopped, ZNS sent immediately, CSKH alerted |
| **Actors** | Patient, System |
| **Pre-conditions** | Countdown is running |
| **Post-conditions** | All alerts sent, SOS Support Dashboard displayed |
| **BR References** | BR-SOS-006 |
| **Priority** | 🔴 Critical |

---

### 2.2 Escalation Flow (FR-SOS-06 to FR-SOS-08)

#### FR-SOS-06: Automatic Escalation
| ID | FR-SOS-06 |
|------|-----------|
| **Description** | Auto-call family contacts in sequence (20s per contact) |
| **Trigger** | SOS activated, user NOT on 115 call |
| **Input** | Ordered contact list (1-5) |
| **Output** | Sequential calls, each with 20s timeout |
| **Actors** | System |
| **Pre-conditions** | SOS completed, contacts available |
| **Post-conditions** | Contact answered OR all failed |
| **BR References** | BR-SOS-007, BR-SOS-008 |
| **Priority** | 🔴 Critical |

**Escalation Logic:**
```
FOR each contact #X (1 to 5):
  IF contact #X NO_ANSWER/BUSY/REJECT in 20s:
    CONTINUE to contact #(X+1)
  ELSE IF contact #X CONNECTED:
    STOP escalation
    
IF all 5 contacts failed:
  ALERT CSKH (second time)
  SHOW "Gọi 115" prompt
```

#### FR-SOS-07: Escalation Success
| ID | FR-SOS-07 |
|------|-----------|
| **Description** | Stop escalation when contact answers |
| **Trigger** | Contact answers call (Call Connected) |
| **Input** | Call status from platform |
| **Output** | Escalation stopped |
| **Actors** | System, Family Contact |
| **Pre-conditions** | Escalation call in progress |
| **Post-conditions** | No further contacts called |
| **BR References** | BR-SOS-009 |
| **Priority** | 🔴 Critical |

#### FR-SOS-08: Escalation During 115 Call
| ID | FR-SOS-08 |
|------|-----------|
| **Description** | Only send ZNS (no auto-call) if user on 115 |
| **Trigger** | Escalation starts while user on 115 |
| **Input** | User call state |
| **Output** | ZNS/Push only, resume after 115 ends |
| **Actors** | System |
| **Pre-conditions** | User actively on 115 call |
| **Post-conditions** | Auto-call waits for 115 call end |
| **BR References** | BR-SOS-010 |
| **Priority** | 🔴 Critical |

---

### 2.3 Post-SOS Support (FR-SOS-09 to FR-SOS-11)

#### FR-SOS-09: Contact List & Manual Call
| ID | FR-SOS-09 |
|------|-----------|
| **Description** | View contact list and manually call |
| **Trigger** | User taps "Gọi người thân" on Dashboard |
| **Input** | None |
| **Output** | Contact List screen with call buttons |
| **Actors** | Patient |
| **Pre-conditions** | On SOS Support Dashboard |
| **Post-conditions** | Contact called, escalation skips this contact |
| **BR References** | BR-SOS-011 |
| **Priority** | 🟡 High |

#### FR-SOS-10: Hospital Map
| ID | FR-SOS-10 |
|------|-----------|
| **Description** | Show nearby hospitals on Google Maps |
| **Trigger** | User taps "Bệnh viện gần đây" |
| **Input** | GPS location |
| **Output** | Map with hospital markers, directions link |
| **Actors** | Patient, Google Maps API |
| **Pre-conditions** | GPS available |
| **Post-conditions** | Hospital details viewable |
| **BR References** | BR-SOS-012 |
| **Priority** | 🟡 High |

**Hospital Info Display:**
| Element | Content |
|---------|---------|
| Hospital Name | {Name} |
| Address | {Full address} |
| Distance | {X.X km} |
| Action | "📍 Chỉ đường" → Google Maps navigation |

**Empty State:** "Không tìm thấy bệnh viện gần bạn. Vui lòng gọi 115." (radius 10km)

#### FR-SOS-11: First Aid Guide
| ID | FR-SOS-11 |
|------|-----------|
| **Description** | Show offline-cached first aid instructions |
| **Trigger** | User taps "Hướng dẫn sơ cứu" |
| **Input** | None |
| **Output** | Categories: CPR, Stroke (F.A.S.T), Low Sugar, Fall |
| **Actors** | Patient |
| **Pre-conditions** | Content synced (or show empty state) |
| **Post-conditions** | Content displayed with disclaimer |
| **BR References** | BR-SOS-013, BR-SOS-014 |
| **Priority** | 🟡 High |

---

### 2.4 Offline Handling (FR-SOS-12 to FR-SOS-13)

#### FR-SOS-12: SOS Offline Mode
| ID | FR-SOS-12 |
|------|-----------|
| **Description** | Queue SOS when offline, auto-send on reconnect |
| **Trigger** | SOS activated without internet |
| **Input** | SOS data + timestamp + location |
| **Output** | Queue stored, retry on reconnect |
| **Actors** | Patient, Mobile App |
| **Pre-conditions** | No internet, mobile signal available |
| **Post-conditions** | SOS queued, "Gọi 115" still works |
| **BR References** | BR-SOS-015, BR-SOS-016 |
| **Priority** | 🔴 Critical |

**Retry Logic:**
- Max 3 retries
- 30 seconds between retries

#### ~~FR-SOS-13: Airplane Mode Detection~~ (REMOVED in SRS v2.1)

> **📝 Note:** Airplane Mode detection đã bị loại bỏ trong SRS v2.1. iOS không cho phép app detect trực tiếp trạng thái Airplane Mode. Thay vào đó, hệ thống chỉ kiểm tra có kết nối internet (Online/Offline) hay không. Xem FR-SOS-12 cho logic đơn giản hóa.

---

### 2.5 Low Battery (FR-SOS-14)

#### FR-SOS-14: Low Battery Countdown
| ID | FR-SOS-14 |
|------|-----------|
| **Description** | Shorten countdown to 10s when battery <10% |
| **Trigger** | SOS activated with battery <10% |
| **Input** | Battery level |
| **Output** | 10s countdown instead of 30s |
| **Actors** | System |
| **Pre-conditions** | Battery <10% |
| **Post-conditions** | Faster alert sending |
| **BR References** | BR-SOS-018 |
| **Priority** | 🟡 High |

---

### 2.6 Error Handling (FR-SOS-15 to FR-SOS-23)

#### FR-SOS-15: Cooldown Management
| ID | FR-SOS-15 |
|------|-----------|
| **Description** | Apply 30-minute cooldown after successful SOS |
| **Trigger** | SOS sent <30 minutes ago |
| **Input** | Last SOS timestamp |
| **Output** | Redirect to Dashboard (NO modal, NO bypass) |
| **Actors** | Patient |
| **Pre-conditions** | Previous SOS <30 min ago |
| **Post-conditions** | Dashboard shown with timestamp, user can still call 115/contacts |
| **BR References** | BR-SOS-019 |
| **Priority** | 🔴 Critical |

#### FR-SOS-16: ZNS Failure Retry
| ID | FR-SOS-16 |
|------|-----------|
| **Description** | Retry ZNS 3 times, then alert CSKH |
| **Trigger** | ZNS API error (timeout, 5xx, rate limit) |
| **Input** | ZNS response |
| **Output** | Retry attempts, CSKH fallback |
| **Actors** | System |
| **Pre-conditions** | ZNS send failed |
| **Post-conditions** | CSKH alerted for manual follow-up |
| **BR References** | BR-SOS-021 |
| **Priority** | 🔴 Critical |

#### FR-SOS-17: GPS Timeout Handling
| ID | FR-SOS-17 |
|------|-----------|
| **Description** | Use last known location if GPS timeout (10s) |
| **Trigger** | GPS not responding in 10s |
| **Input** | Last known location |
| **Output** | ZNS with warning about accuracy |
| **Actors** | System |
| **Pre-conditions** | GPS request pending |
| **Post-conditions** | Location included with caveat |
| **BR References** | BR-SOS-022 |
| **Priority** | 🟡 High |

#### FR-SOS-18: Server Timeout Handling
| ID | FR-SOS-18 |
|------|-----------|
| **Description** | Queue locally if server timeout (5s) |
| **Trigger** | Server not responding in 5s |
| **Input** | SOS data |
| **Output** | Local queue, retry every 30s |
| **Actors** | Mobile App |
| **Pre-conditions** | Server unreachable |
| **Post-conditions** | SOS will be sent when server available |
| **BR References** | BR-SOS-023 |
| **Priority** | 🔴 Critical |

#### FR-SOS-19: Escalation Call Drop Handling (NEW v1.8)
| ID | FR-SOS-19 |
|------|-----------|
| **Description** | Call connected < 10s then dropped = not answered |
| **Trigger** | Escalation call connects then drops within 10s |
| **Input** | Call duration |
| **Output** | Continue escalation to next contact |
| **Actors** | System |
| **Pre-conditions** | Escalation call in progress |
| **Post-conditions** | Contact NOT marked as answered, next contact called |
| **BR References** | BR-SOS-009, BR-SOS-028 |
| **Priority** | 🔴 Critical |

#### FR-SOS-20: Resume Escalation After 115 Call (NEW v1.8)
| ID | FR-SOS-20 |
|------|-----------|
| **Description** | Resume escalation from contact #1 after 115 call ends |
| **Trigger** | User ends 115 call, escalation was PAUSED |
| **Input** | Call end event |
| **Output** | Resume escalation from first contact |
| **Actors** | System |
| **Pre-conditions** | Escalation PAUSED due to 115 call |
| **Post-conditions** | Escalation resumes, no contacts skipped |
| **BR References** | BR-SOS-010, BR-SOS-027 |
| **Priority** | 🔴 Critical |

#### FR-SOS-21: Location Permission Flow (NEW v1.8)
| ID | FR-SOS-21 |
|------|-----------|
| **Description** | Hospital Map location permission popup flow |
| **Trigger** | User opens Hospital Map without location permission |
| **Input** | Permission state |
| **Output** | OS popup (first time) or Settings guide (previously denied) |
| **Actors** | Patient, Mobile App |
| **Pre-conditions** | Location permission not granted |
| **Post-conditions** | User guided to enable permission |
| **BR References** | BR-SOS-031 |
| **Priority** | 🟡 High |

#### FR-SOS-22: SOS Without Contacts (NEW v1.8)
| ID | FR-SOS-22 |
|------|-----------|
| **Description** | Allow SOS without contacts, send to CSKH only |
| **Trigger** | SOS activated with 0 emergency contacts |
| **Input** | Contact count = 0 |
| **Output** | Warning shown, SOS proceeds, CSKH alerted only |
| **Actors** | Patient, System |
| **Pre-conditions** | No contacts configured |
| **Post-conditions** | CSKH receives alert, Dashboard shows "Đã gửi đến bộ phận hỗ trợ" |
| **BR References** | BR-SOS-024 |
| **Priority** | 🔴 Critical |

#### FR-SOS-23: Contact Add In Session (NEW v1.8)
| ID | FR-SOS-23 |
|------|-----------|
| **Description** | New contact added during SOS session won't receive current ZNS |
| **Trigger** | User adds contact while SOS Dashboard active |
| **Input** | New contact data |
| **Output** | Contact saved, toast confirmation |
| **Actors** | Patient |
| **Pre-conditions** | SOS session active |
| **Post-conditions** | Contact NOT notified this session, can be called directly |
| **BR References** | BR-SOS-030 |
| **Priority** | 🟡 High |

---


## 3. Requirements Traceability Matrix

| FR ID | Scenarios | BR References | UI Screen | Priority |
|-------|-----------|---------------|-----------|:--------:|
| FR-SOS-01 | KC1 | - | SOS-00 | 🔴 |
| FR-SOS-02 | KC1 | BR-001, BR-002 | SOS-01 | 🔴 |
| FR-SOS-03 | KC2 | BR-003, BR-004 | SOS-02 | 🔴 |
| FR-SOS-04 | KC3 | BR-005 | SOS-01 | 🔴 |
| FR-SOS-05 | KC4 | BR-006 | SOS-01 | 🔴 |
| FR-SOS-06 | KC5 | BR-007, BR-008 | - | 🔴 |
| FR-SOS-07 | KC6 | BR-009 | - | 🔴 |
| FR-SOS-08 | KC7 | BR-010 | - | 🔴 |
| FR-SOS-09 | KC8 | BR-011 | SOS-03 | 🟡 |
| FR-SOS-10 | KC9 | BR-012 | SOS-04 | 🟡 |
| FR-SOS-11 | KC10 | BR-013, BR-014 | SOS-05 | 🟡 |
| FR-SOS-12 | KC11 | BR-015, BR-016 | ERR-01 | 🔴 |
| ~~FR-SOS-13~~ | ~~KC12~~ | ~~BR-017~~ | ~~ERR-02~~ | ❌ REMOVED |
| FR-SOS-14 | KC13 | BR-018 | SOS-01 | 🟡 |
| FR-SOS-15 | KC14 | BR-019 | ERR-03 | 🔴 |
| FR-SOS-16 | KC15 | BR-021, BR-026 | ERR-07 | 🔴 |
| FR-SOS-17 | KC16 | BR-022, BR-029 | - | 🟡 |
| FR-SOS-18 | KC17 | BR-023 | ERR-04 | 🔴 |
| FR-SOS-19 | KC6a | BR-009, BR-028 | - | 🔴 |
| FR-SOS-20 | KC7a | BR-010, BR-027 | - | 🔴 |
| FR-SOS-21 | KC9a | BR-031 | SOS-04 | 🟡 |
| FR-SOS-22 | KC18 | BR-024 | SOS-02 | 🔴 |
| FR-SOS-23 | KC18a | BR-030 | SOS-03 | 🟡 |

---

## 4. Summary Statistics

| Metric | Value |
|--------|-------|
| Total Functional Requirements | 23 |
| Critical Priority (🔴) | 16 |
| High Priority (🟡) | 7 |
| Business Rules Referenced | 31 |
| UI Screens Involved | 10 + 7 error states |

---

## Next Phase

✅ **Phase 3: Requirements Extraction** - COMPLETE

➡️ **Phase 4: Architecture Mapping**
