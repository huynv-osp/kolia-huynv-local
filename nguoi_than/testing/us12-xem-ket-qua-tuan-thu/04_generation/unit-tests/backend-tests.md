# Backend Unit Tests: US 1.2 - Xem Kết Quả Tuân Thủ

> **Service:** user-service  
> **Framework:** JUnit 5 + Mockito  
> **Date:** 2026-02-05

---

## Test Class: CaregiverComplianceServiceImplTest

### File Location
```
user-service/src/test/java/com/userservice/service/impl/CaregiverComplianceServiceImplTest.java
```

### Dependencies (Mock)

```java
@ExtendWith(MockitoExtension.class)
class CaregiverComplianceServiceImplTest {
    
    @Mock private ConnectionRepository connectionRepository;
    @Mock private PermissionService permissionService;
    @Mock private BloodPressureRepository bpRepository;
    @Mock private MedicationFeedbackRepository medicationRepository;
    @Mock private ReExaminationRepository checkupRepository;
    @Mock private AuditLogService auditLogService;
    
    @InjectMocks private CaregiverComplianceServiceImpl service;
}
```

---

## Test Cases

### TC-US-001: Happy Path - Daily Summary với Permission ON

```java
@Test
@DisplayName("Should return daily summary when permission is granted")
void shouldReturnDailySummary_WhenPermissionGranted() {
    // Given
    String caregiverId = "caregiver-001";
    String patientId = "patient-001";
    String date = "2026-02-05";
    
    Connection mockConnection = Connection.builder()
        .id("conn-001")
        .caregiverId(caregiverId)
        .patientId(patientId)
        .status(ConnectionStatus.ACTIVE)
        .relationship("Bố")
        .build();
    
    when(connectionRepository.findActiveConnection(caregiverId, patientId))
        .thenReturn(Future.succeededFuture(mockConnection));
    when(permissionService.hasPermission("conn-001", PermissionType.COMPLIANCE_TRACKING))
        .thenReturn(Future.succeededFuture(true));
    when(bpRepository.getTodaySummary(patientId, date))
        .thenReturn(Future.succeededFuture(mockBPSummary()));
    when(medicationRepository.getTodaySummary(patientId, date))
        .thenReturn(Future.succeededFuture(mockMedSummary()));
    when(checkupRepository.getUpcoming(patientId))
        .thenReturn(Future.succeededFuture(mockCheckupSummary()));
    
    // When
    Future<GetPatientDailySummaryResponse> result = 
        service.getPatientDailySummary(caregiverId, patientId, date);
    
    // Then
    assertThat(result.succeeded()).isTrue();
    GetPatientDailySummaryResponse response = result.result();
    assertThat(response.getHasPermission()).isTrue();
    assertThat(response.getPatientInfo().getRelationship()).isEqualTo("Bố");
    assertThat(response.getBpSummary()).isNotNull();
    assertThat(response.getMedSummary()).isNotNull();
    assertThat(response.getCheckupSummary()).isNotNull();
}
```

---

### TC-US-002: Security - Permission Denied

```java
@Test
@DisplayName("Should return permission denied when permission is OFF")
void shouldReturnPermissionDenied_WhenPermissionOff() {
    // Given
    String caregiverId = "caregiver-002";
    String patientId = "patient-001";
    
    Connection mockConnection = Connection.builder()
        .id("conn-002")
        .caregiverId(caregiverId)
        .patientId(patientId)
        .status(ConnectionStatus.ACTIVE)
        .build();
    
    when(connectionRepository.findActiveConnection(caregiverId, patientId))
        .thenReturn(Future.succeededFuture(mockConnection));
    when(permissionService.hasPermission("conn-002", PermissionType.COMPLIANCE_TRACKING))
        .thenReturn(Future.succeededFuture(false));  // Permission OFF
    
    // When
    Future<GetPatientDailySummaryResponse> result =
        service.getPatientDailySummary(caregiverId, patientId, null);
    
    // Then
    assertThat(result.succeeded()).isTrue();
    GetPatientDailySummaryResponse response = result.result();
    assertThat(response.getHasPermission()).isFalse();
    assertThat(response.getPermissionMessage()).contains("chưa cho phép");
    assertThat(response.getBpSummary()).isNull();  // No data leakage
    
    // Verify no data queries were made
    verify(bpRepository, never()).getTodaySummary(anyString(), anyString());
    verify(medicationRepository, never()).getTodaySummary(anyString(), anyString());
}
```

---

### TC-US-003: Edge Case - No Active Connection

```java
@Test
@DisplayName("Should throw error when no active connection exists")
void shouldThrowError_WhenNoActiveConnection() {
    // Given
    String caregiverId = "caregiver-003";
    String patientId = "patient-001";
    
    when(connectionRepository.findActiveConnection(caregiverId, patientId))
        .thenReturn(Future.succeededFuture(null));  // No connection
    
    // When
    Future<GetPatientDailySummaryResponse> result =
        service.getPatientDailySummary(caregiverId, patientId, null);
    
    // Then
    assertThat(result.failed()).isTrue();
    assertThat(result.cause().getMessage()).contains("Connection not found");
}
```

---

### TC-US-004: Empty State - No BP Records

```java
@Test
@DisplayName("Should return empty BP summary when no records today")
void shouldReturnEmptyBP_WhenNoRecordsToday() {
    // Given
    setupPermissionGranted("caregiver-001", "patient-002");
    when(bpRepository.getTodaySummary("patient-002", anyString()))
        .thenReturn(Future.succeededFuture(BloodPressureSummary.empty()));
    
    // When
    Future<GetPatientDailySummaryResponse> result =
        service.getPatientDailySummary("caregiver-001", "patient-002", null);
    
    // Then
    assertThat(result.succeeded()).isTrue();
    BloodPressureSummary bpSummary = result.result().getBpSummary();
    assertThat(bpSummary.getTotalMeasurements()).isZero();
    assertThat(bpSummary.isEmpty()).isTrue();
}
```

---

### TC-US-005: BP History với Permission

```java
@Test
@DisplayName("Should return BP history when permission granted")
void shouldReturnBPHistory_WhenPermissionGranted() {
    // Given
    setupPermissionGranted("caregiver-001", "patient-001");
    String date = "2026-02-05";
    List<BloodPressureRecord> mockRecords = List.of(
        mockBPRecord("08:00", 130, 85),
        mockBPRecord("14:00", 125, 82),
        mockBPRecord("20:00", 128, 80)
    );
    when(bpRepository.getByDate("patient-001", date))
        .thenReturn(Future.succeededFuture(mockRecords));
    
    // When
    Future<GetPatientBPHistoryResponse> result =
        service.getPatientBPHistory("caregiver-001", "patient-001", date);
    
    // Then
    assertThat(result.succeeded()).isTrue();
    assertThat(result.result().getRecordsCount()).isEqualTo(3);
}
```

---

### TC-US-006: Medications với Permission

```java
@Test
@DisplayName("Should return medications grouped by time when permission granted")
void shouldReturnMedications_WhenPermissionGranted() {
    // Given
    setupPermissionGranted("caregiver-001", "patient-001");
    String date = "2026-02-05";
    
    // When
    Future<GetPatientMedicationsResponse> result =
        service.getPatientMedications("caregiver-001", "patient-001", date);
    
    // Then
    assertThat(result.succeeded()).isTrue();
    assertThat(result.result().getHasPermission()).isTrue();
}
```

---

### TC-US-007: Checkups với Permission

```java
@Test
@DisplayName("Should return checkups when permission granted")
void shouldReturnCheckups_WhenPermissionGranted() {
    // Given
    setupPermissionGranted("caregiver-001", "patient-001");
    
    // When
    Future<GetPatientCheckupsResponse> result =
        service.getPatientCheckups("caregiver-001", "patient-001");
    
    // Then
    assertThat(result.succeeded()).isTrue();
    assertThat(result.result().getHasPermission()).isTrue();
}
```

---

### TC-US-010: BR-CG-014 - Relationship Override

```java
@Test
@DisplayName("Should return relationship not userTitle (BR-CG-014)")
void shouldReturnRelationship_InPatientInfo() {
    // Given
    Connection mockConnection = Connection.builder()
        .id("conn-001")
        .relationship("Bố")        // Mối quan hệ
        .patientName("Nguyễn A")
        .patientUserTitle("Ông")   // Danh xưng - should NOT be used
        .build();
    
    setupWithConnection(mockConnection);
    
    // When
    Future<GetPatientDailySummaryResponse> result =
        service.getPatientDailySummary("caregiver-001", "patient-001", null);
    
    // Then
    PatientInfo patientInfo = result.result().getPatientInfo();
    assertThat(patientInfo.getDisplayLabel()).isEqualTo("Bố");  // NOT "Ông"
    assertThat(patientInfo.getName()).isEqualTo("Nguyễn A");
}
```

---

### TC-US-011: BR-CG-013 - Audit Logging

```java
@Test
@DisplayName("Should audit log on data access (BR-CG-013)")
void shouldAuditLog_OnDataAccess() {
    // Given
    setupPermissionGranted("caregiver-001", "patient-001");
    
    // When
    service.getPatientDailySummary("caregiver-001", "patient-001", null).await();
    
    // Then
    verify(auditLogService).log(argThat(log -> 
        log.getCaregiverId().equals("caregiver-001") &&
        log.getPatientId().equals("patient-001") &&
        log.getAction().equals("VIEW_COMPLIANCE_DASHBOARD")
    ));
}
```

---

### TC-US-012: BR-CG-016 - Checkup Status

```java
@Test
@DisplayName("Should return correct checkup status per BR-CG-016")
void shouldReturnCheckupStatus_PerBR_CG_016() {
    // Given
    setupPermissionGranted("caregiver-001", "patient-001");
    LocalDate today = LocalDate.now();
    
    List<ReExaminationEvent> mockCheckups = List.of(
        mockCheckup(today.plusDays(5), null),         // Upcoming → 🟢
        mockCheckup(today.minusDays(1), "completed"), // Completed → 🟢
        mockCheckup(today.minusDays(2), null)         // Overdue → 🟠
    );
    when(checkupRepository.getAll("patient-001")).thenReturn(Future.succeededFuture(mockCheckups));
    
    // When
    Future<GetPatientCheckupsResponse> result =
        service.getPatientCheckups("caregiver-001", "patient-001");
    
    // Then
    List<CheckupItem> items = result.result().getItemsList();
    assertThat(items.get(0).getStatus()).isEqualTo("upcoming");  // 🟢
    assertThat(items.get(1).getStatus()).isEqualTo("completed"); // 🟢
    assertThat(items.get(2).getStatus()).isEqualTo("overdue");   // 🟠
}
```

---

## Test Utilities

```java
// Helper methods
private void setupPermissionGranted(String caregiverId, String patientId) {
    Connection mockConnection = Connection.builder()
        .id("conn-" + caregiverId)
        .caregiverId(caregiverId)
        .patientId(patientId)
        .status(ConnectionStatus.ACTIVE)
        .relationship("Bố")
        .build();
    
    when(connectionRepository.findActiveConnection(caregiverId, patientId))
        .thenReturn(Future.succeededFuture(mockConnection));
    when(permissionService.hasPermission(anyString(), eq(PermissionType.COMPLIANCE_TRACKING)))
        .thenReturn(Future.succeededFuture(true));
}

private BloodPressureRecord mockBPRecord(String time, int systolic, int diastolic) {
    return BloodPressureRecord.builder()
        .measurementTime(time)
        .systolic(systolic)
        .diastolic(diastolic)
        .build();
}
```

---

## Run Command

```bash
cd user-service
mvn test -Dtest=CaregiverComplianceServiceImplTest
```
