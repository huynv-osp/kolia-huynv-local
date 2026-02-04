# [Kolia] SRS - Gửi lời động viên (Encouragement Messages)

## 1. Giới thiệu
### 1.1 Mục đích
Tài liệu này đặc tả tính năng "Gửi lời động viên", cho phép người thân (Caregiver) gửi những lời nhắn nhủ, động viên ngắn gọn đến người bệnh (Patient) để hỗ trợ tinh thần và nhắc nhở lối sống khỏe mạnh thông qua trợ lý ảo Kolia.

### 1.2 Phạm vi (In/Out)
**Trong phạm vi:**
- Giao diện soạn thảo tin nhắn (Compose Screen) dành cho Caregiver.
- Logic kiểm soát hạn ngạch (Quota) và giới hạn ký tự.
- Tích hợp gửi thông báo (Push Notification Trigger).
- [Tham khảo CR_002] Tác động hiển thị và điều hướng trên Dashboard/Action Feed của Patient.

**Ngoài phạm vi:**
- Phản hồi từ phía Patient (Giao tiếp một chiều).
- Cuộc trò chuyện tự do (Chat free-style) giữa người thân và người bệnh.

### 1.3 Thuật ngữ (Glossary)
| Thuật ngữ | Định nghĩa |
|-----------|------------|
| **Permission #6** | Quyền cho phép người thân gửi lời nhắn động viên. |
| **Quota** | Hạn ngạch số lượng tin nhắn được gửi trong ngày. |

### 1.4 Dependencies & Assumptions
- Phụ thuộc vào phân hệ **Kết nối người thân** để xác định quan hệ và quyền hạn.
- Giả định: Người thân và người bệnh đều đã có tài khoản và được kết nối với nhau.

---

## 2. Yêu cầu chức năng (Gherkin BDD)

### US-001: Caregiver gửi lời nhắn cho Patient
**User Story**: Là một **Caregiver**, tôi muốn **soạn và gửi lời nhắn động viên cho Patient**, để **khích lệ tinh thần và nhắc nhở họ chăm sóc sức khỏe**.

**Tiêu chí chấp nhận:**

- **Kịch bản 1: Gửi lời nhắn từ gợi ý AI (Happy Path)**
  - **Given** Caregiver đang ở Widget/Màn hình "Gửi lời động viên".
  - **And** Quyền số 6 (Permission #6) đang ở trạng thái **Bật (ON)**.
  - **And** Caregiver chưa dùng hết hạn ngạch 10 tin/ngày cho Patient này.
  - **When** Caregiver **chọn một Lời nhắn gợi ý (Chip)**.
  - **Then** Nội dung của Chip đó được **ghi đè (overwrite)** hoàn toàn vào ô nhập liệu (ENG-02).
  - **And** Caregiver có thể chỉnh sửa nội dung hoặc giữ nguyên.
  - **And** Nhấn nút **Gửi (Icon Mũi tên)**.
  - **Then** Hệ thống thực hiện kiểm tra quyền (real-time check).
  - **And** Nếu hợp lệ -> Gửi tin nhắn thành công lên server.
  - **And** Hiển thị toast: "Đã gửi lời động viên thành công".
  - **And** Reset nội dung trong ô nhập liệu về trống.
  - *Ref: BR-002, BR-003, BR-004, BR-005*

- **Kịch bản 1b: Xử lý Timeout khi AI đang gen gợi ý**
  - **Given** Caregiver vừa truy cập màn hình soạn thảo.
  - **When** API AI gọi quá 3 giây (Timeout) mà chưa có kết quả.
  - **Then** Hệ thống tự động hiển thị 03 câu gợi ý mặc định (Fallback Mechanism) tại ENG-01.
  - **And** Ẩn trạng thái Loading/Skeleton.
  - *Ref: Section 4.4, NFR-001*

- **Kịch bản 2: Không có quyền gửi lời nhắn (Authorization)**
  - **Given** Caregiver đang ở màn hình Chi tiết Patient.
  - **And** Quyền số 6 (Permission #6) đang ở trạng thái **Tắt (OFF)**.
  - **When** Màn hình được khởi tạo.
  - **Then** Icon/Nút "Gửi lời động viên" bị **ẨN** hoàn toàn.
  - **And** Caregiver không thể truy cập vào màn hình soạn thảo.
  - *Ref: BR-003*

- **Kịch bản 3: Chạm mốc hạn ngạch gửi trong ngày (Limit Quota)**
  - **Given** Caregiver đã gửi thành công 10 tin nhắn cho Patient X trong hôm nay.
  - **Then** Hệ thống hiển thị trạng thái Empty/Warning tại Widget: "Bạn đã đạt giới hạn 10 tin nhắn động viên cho ngày hôm nay."
  - **And** Vô hiệu hóa (Disable) ô nhập liệu và các chip gợi ý.
  - *Ref: BR-001*

- **Kịch bản 4: Kiểm soát độ dài nội dung (Length Constraint)**
  - **Given** Caregiver đang ở màn hình soạn thảo SCR-ENG-01.
  - **When** Caregiver nhập nội dung đến ký tự thứ 150.
  - **Then** Hệ thống chặn không cho nhập thêm ký tự thứ 151.
  - **And** Bộ đếm (Char Counter) hiển thị "150/150" với màu cảnh báo (Đỏ).
  - *Ref: BR-002*

- **Kịch bản 5: Chặn gửi nội dung trống (Input Validation)**
  - **Given** Caregiver đang ở màn hình soạn thảo.
  - **When** Ô nhập liệu trống HOẶC chỉ chứa khoảng trắng/xuống dòng.
  - **Then** Nút "Gửi" ở trạng thái **Disabled** (Mờ/Không thể nhấn).
  - *Ref: Component Spec ENG-04*

- **Kịch bản 6: Mất kết nối internet (Internet Offline)**
  - **Given** Caregiver đã soạn xong tin nhắn hợp lệ.
  - **When** Caregiver nhấn "Gửi" nhưng thiết bị không có kết nối internet.
  - **Then** Hệ thống hiển thị Popup "Mất kết nối mạng":
    - **Tiêu đề:** "Mất kết nối mạng"
    - **Nội dung:** "Vui lòng kiểm tra kết nối mạng Wi-fi hoặc 3G/4G để tiếp tục"
    - **Nút:** "Đóng"
  - **And** Giữ nguyên nội dung đã soạn trong ô nhập liệu.

- **Kịch bản 7: Lỗi hệ thống từ Server (Server Error 5xx)**
  - **Given** Caregiver đã soạn xong tin nhắn hợp lệ.
  - **When** Caregiver nhấn "Gửi" nhưng Server phản hồi lỗi (5xx) hoặc Timeout.
  - **Then** Hệ thống hiển thị thông báo (**Toast**): "Hệ thống đang gặp sự cố. Vui lòng thử lại sau ít phút."
  - **And** Giữ nguyên nội dung đã soạn để Caregiver không phải nhập lại.

- **Kịch bản 8: Permission bị thu hồi tại thời điểm gửi (Edge Case)**
  - **Given** Caregiver đang soạn tin nhắn hợp lệ.
  - **When** Caregiver nhấn "Gửi" nhưng ngay lúc đó Patient đã tắt Quyền #6.
  - **Then** Hệ thống hiển thị Toast lỗi: "Bạn không còn quyền gửi lời nhắn cho người này."
  - **And** Tự động đóng màn hình soạn thảo và quay về Dashboard.

---

## 3. Business Rules (BẮT BUỘC)
| BR-ID | Category | Mô tả Rule | Trigger | Exception | Priority |
|-------|----------|------------|---------|-----------|----------|
| **BR-001** | Limit | Mỗi Caregiver chỉ được gửi tối đa 10 tin nhắn/ngày cho một Patient. | Truy cập/Nhấn "Gửi" | N/A | High |
| **BR-002** | Limit | Độ dài tin nhắn tối đa 150 ký tự Unicode (Kể cả Emoji). | User nhập liệu | N/A | High |
| **BR-003** | Auth | Chỉ hiển thị tính năng và cho phép gửi nếu Permission #6 ("Gửi lời nhắn động viên") đang ở trạng thái phối (ON). | Init API & Nhấn "Gửi" | N/A | Critical |
| **BR-004** | Responsibility | Nội dung không qua kiểm soát AI. Người thân tự chịu trách nhiệm về nội dung gửi đi. | Nhấn "Gửi" | N/A | High |
| **BR-005** | Intelligence | Hệ thống gợi ý 03 lời nhắn: 02 câu nhắc nhiệm vụ ưu tiên + 01 câu tình cảm (Có xét tới Mood). | Khởi tạo Widget/Refresh | Fallback mẫu cố định | Medium |

---

## 4. Đặc tả Logic AI gợi ý (AI Suggested Messages)

Hệ thống sử dụng LLM để tạo ra 03 lời nhắn gợi ý dựa trên trạng thái thực tế của Patient.

### 4.1 Input Data cho AI
| Trường dữ liệu | Mô tả |
|----------------|-------|
| `Unfinished_Tasks`| Danh sách nhiệm vụ **Tuân thủ** chưa hoàn thành và được đánh dấu là **Ưu tiên**. |
| `Patient_Mood` | Tâm trạng của Patient ghi nhận trong 24h qua (Vd: Mệt, Vui, Buồn). |
| `Relationship` | Mối quan hệ giữa Caregiver và Patient. |
| `Appellation`  | Danh xưng tương ứng (Bố, Mẹ, Ông, Bà...). |
| `Tone`         | 02 phong cách: **Tình cảm** và **Nhắc nhở**, điều chỉnh theo Mood. |

### 4.2 Cấu trúc gợi ý (3 câu)
- **02 câu nhắc nhở:** Tập trung vào các nhiệm vụ ưu tiên từ `Unfinished_Tasks`.
    - *Vd: "Bố đừng quên đo huyết áp chiều nay nhé!"*
- **01 câu tình cảm:** Quan tâm, khích lệ tinh thần.
    - *Vd: "Con yêu Bố rất nhiều, Bố cố gắng lên ạ!"*

### 4.3 Ràng buộc (Prompting Constraints)
- **Độ dài gợi ý:** Tối đa **15 từ** mỗi câu (để vừa vặn trên Chip).
- **Medical Guardrails:**
    - KHÔNG đưa ra nhận định y khoa (Vd: "Chỉ số này ổn").
    - KHÔNG khuyên về sử dụng thuốc.
    - Chỉ dùng các động từ khích lệ: *"nhắc"*, *"đừng quên"*, *"duy trì"*, *"gắng lên"*.
- **Ngôn ngữ:** Tiếng Việt ấm áp, phù hợp văn hóa gia đình.

### 4.4 Fallback Mechanism
Trường hợp AI lỗi hoặc không có `Unfinished_Tasks`, hiển thị 3 câu mặc định:
1. "[Danh xưng] giữ gìn sức khỏe nhé!" (Tình cảm)
2. "[Danh xưng] đừng quên thực hiện các nhiệm vụ quan trọng hôm nay nha!" (Nhắc nhở)
3. "Mọi người luôn ở bên cạnh [Danh xưng], cố gắng lên ạ!" (Tình cảm)

### 4.5 Cơ chế kích hoạt (Trigger Mechanism)
- **Thời điểm:** Hệ thống gọi API gen lời nhắn ngay khi Caregiver vào màn hình soạn thảo SCR-ENG-01. 
- **Làm mới (Refresh):** Có nút bấm để Caregiver chủ động yêu cầu AI gen lại 03 câu khác nếu chưa ưng ý.
- **Caching:** Lời nhắn gợi ý cho cùng một Patient sẽ được Cache trong 1 phiên làm việc cho đến khi User nhấn Refresh hoặc thoát ứng dụng.

---

## 5. UI Specifications

### 5.1 Screen Inventory
| Screen ID | Screen Name | Description | Entry Points | Exit Points |
|-----------|-------------|-------------|--------------|-------------|
| **SCR-ENG-01** | Soạn lời động viên | Màn hình cho phép Caregiver nhập nội dung tin nhắn. | Dashboard Caregiver / Patient Details | Dashboard Caregiver |

### 5.2 Screen Components Specification (SCR-ENG-01)
| Component ID | Component Name | Type | Required | Constraints | Default Value |
|--------------|----------------|------|----------|-------------|---------------|
| **ENG-01** | Suggested Chips| Button | No | Hiển thị 3 câu gợi ý từ AI. Nhấn để **Ghi đè** nội dung vào ENG-02. **Trạng thái Loading:** Hiển thị Skeleton Chips. | N/A |
| **ENG-02** | Text Input | **Textarea** | Yes | Phải hiển thị ít nhất 3 dòng. Max 150 Unicode chars. Cho phép sửa nội dung. | "Nhập tin nhắn..." |
| **ENG-03** | Char Counter | Text | Yes | Định dạng: x/150. Đổi màu đỏ (**#FF4D4F**) khi >= 140 ký tự. | 0/150 |
| **ENG-04** | Gửi | Icon Button| Yes | Disabled nếu input chỉ có khoảng trắng hoặc trống. | Disabled |
| **ENG-05** | Refresh AI | Icon Button| No | Biểu tượng xoay vòng cạnh ENG-01. Nhấn để gọi lại API gen Chips mới. | Enabled |
| **ENG-06** | Mic Input | Icon Button| No | Nhấn giữ để dùng Voice-to-Text đổ nội dung vào ENG-02 (Overwrite). | N/A |

---

## 6. Đặc tả nội dung & UX Writing

### 6.1 Error Messages
| Case | Message Content | Type |
|------|-----------------|------|
| Hết hạn ngạch | "Bạn đã đạt giới hạn 10 tin nhắn động viên cho ngày hôm nay." | Toast/Inline |
| Mất mạng | "Vui lòng kiểm tra kết nối mạng Wi-fi hoặc 3G/4G để tiếp tục" | Popup |
| Lỗi Server | "Hệ thống đang gặp sự cố. Vui lòng thử lại sau ít phút." | Toast |

---

## 7. Yêu cầu phi chức năng (NFRs)
| ID | Category | Requirement | Target |
|----|----------|-------------|--------|
| **NFR-001** | Performance | Thời gian AI tạo lời nhắn gợi ý (AI Latency). | < 3 giây (95th percentile) |
| **NFR-002** | Security | Tin nhắn phải được mã hóa khi truyền tải giữa Client và Server. | AES-256 / TLS 1.3 |
| **NFR-003** | Availability | Tính năng "Gửi lời động viên" phải khả dụng 99.9% thời gian. | High Availability |

---

## Appendix
### A.1 Revision History
| Version | Date | Description | Author |
|---------|------|-------------|--------|
| v1.0 | 2026-02-03 | Initial Draft for Encouragement Feature. | Analyst |
| v1.1 | 2026-02-03 | Resolve Step 08 Audit: Added Loading states, NFRs, and Hex colors. | Mary (Analyst) |
| v1.2 | 2026-02-03 | Resolve QA Manager Review: Added Textarea, Overwrite logic, Refresh AI, Voice Input, Mood data, and Real-time Auth. | Mary (Analyst) |
| v1.3 | 2026-02-03 | Final Approved version - Ready for Development (Widget Style Prototype approved). | Mary (Analyst) |

### A.2 Cross-Feature Dependencies
| Feature bị ảnh hưởng | Loại thay đổi | CR ID | Priority | Status | Ref |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Kết nối người thân | Soft-activation Quyền #6 | CR_002 | High | Pending (Reverted) | Permission #6 (ON) |
| Bản tin hành động | Thêm Widget hiển thị lời nhắn | CR_002 | High | Pending (Reverted) | Comp 1.7 |
| Màn hình chính | Thêm Widget Dashboard | CR_002 | Medium | Pending (Reverted) | Comp 4.21, BR-033 |
| Notification | Thêm kịch bản tin nhắn mới | CR_002 | High | Pending (Reverted) | Scenario #7 |
