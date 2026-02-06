# API Integration Tests: US 1.2 - Xem Kết Quả Tuân Thủ

> **Service:** api-gateway-service  
> **Framework:** JUnit 5 + Vert.x WebClient  
> **Date:** 2026-02-05

---

## Test Class: CaregiverComplianceHandlerTest

### File Location
```
api-gateway-service/src/test/java/com/gateway/handler/CaregiverComplianceHandlerTest.java
```

---

## Unit Tests (Handler Layer)

### TC-GW-001: Call user-service with correct params

```java
@Test
@DisplayName("Should call user-service with correct params")
void shouldCallUserService_WithCorrectParams() {
    // Given
    String caregiverId = "caregiver-001";
    String patientId = "patient-001";
    String date = "2026-02-05";
    
    RoutingContext ctx = mockRoutingContext(caregiverId, patientId, date);
    
    when(grpcClient.getPatientDailySummary(caregiverId, patientId, date))
        .thenReturn(Future.succeededFuture(mockResponse()));
    
    // When
    handler.getPatientDailySummary(ctx);
    
    // Then
    verify(grpcClient).getPatientDailySummary(caregiverId, patientId, date);
    verify(ctx).json(any(PatientDailySummaryResponse.class));
}
```

---

### TC-GW-002: Extract caregiverId from JWT

```java
@Test
@DisplayName("Should extract caregiverId from JWT token")
void shouldExtractCaregiverId_FromJWT() {
    // Given
    String expectedCaregiverId = "caregiver-jwt-001";
    RoutingContext ctx = mockRoutingContextWithJWT(expectedCaregiverId);
    
    // When
    handler.getPatientDailySummary(ctx);
    
    // Then
    verify(grpcClient).getPatientDailySummary(
        eq(expectedCaregiverId), 
        anyString(), 
        anyString()
    );
}
```

---

### TC-GW-003: Validate patientId path param

```java
@Test
@DisplayName("Should validate patientId is UUID format")
void shouldValidatePatientId_PathParam() {
    // Given
    RoutingContext ctx = mockRoutingContextWithInvalidPatientId("invalid-id");
    
    // When
    handler.getPatientDailySummary(ctx);
    
    // Then
    verify(ctx).fail(argThat(e -> 
        e instanceof ValidationException &&
        e.getMessage().contains("patientId")
    ));
}
```

---

### TC-GW-004: Return 401 when no token

```java
@Test
@DisplayName("Should return 401 when no JWT token")
void shouldReturn401_WhenNoToken() {
    // Given
    RoutingContext ctx = mockRoutingContextWithoutJWT();
    
    // When
    handler.getPatientDailySummary(ctx);
    
    // Then
    verify(ctx).response();
    verify(response).setStatusCode(401);
}
```

---

### TC-GW-005: Return 200 with permission denied

```java
@Test
@DisplayName("Should return 200 with permission denied in body")
void shouldReturn200_WithPermissionDenied() {
    // Given
    RoutingContext ctx = mockRoutingContext("caregiver-002", "patient-001", null);
    
    GetPatientDailySummaryResponse grpcResponse = GetPatientDailySummaryResponse.newBuilder()
        .setHasPermission(false)
        .setPermissionMessage("Người thân chưa cho phép xem")
        .build();
    
    when(grpcClient.getPatientDailySummary(anyString(), anyString(), anyString()))
        .thenReturn(Future.succeededFuture(grpcResponse));
    
    // When
    handler.getPatientDailySummary(ctx);
    
    // Then
    verify(ctx).json(argThat(response -> {
        PatientDailySummaryResponse r = (PatientDailySummaryResponse) response;
        return !r.isHasPermission() && r.getPermissionMessage() != null;
    }));
}
```

---

## Integration Tests (API Layer)

### File Location
```
api-gateway-service/src/test/java/com/gateway/integration/CaregiverComplianceApiTest.java
```

---

### TC-API-001: GET Daily Summary - Success

```java
@Test
@DisplayName("GET /v1/patients/:id/daily-summary returns 200 with valid data")
void getDailySummary_Returns200_ValidData() {
    // Given
    String patientId = "550e8400-e29b-41d4-a716-446655440001";
    String token = getValidCaregiverToken();
    
    // When
    HttpResponse<Buffer> response = webClient
        .get(8080, "localhost", "/v1/patients/" + patientId + "/daily-summary")
        .putHeader("Authorization", "Bearer " + token)
        .send()
        .toCompletionStage()
        .toCompletableFuture()
        .get();
    
    // Then
    assertThat(response.statusCode()).isEqualTo(200);
    JsonObject body = response.bodyAsJsonObject();
    assertThat(body.getBoolean("hasPermission")).isTrue();
    assertThat(body.getJsonObject("bpSummary")).isNotNull();
    assertThat(body.getJsonObject("medSummary")).isNotNull();
    assertThat(body.getJsonObject("checkupSummary")).isNotNull();
}
```

---

### TC-API-002: GET Daily Summary - Permission Denied

```java
@Test
@DisplayName("GET /v1/patients/:id/daily-summary returns 200 with permission denied")
void getDailySummary_Returns200_PermissionDenied() {
    // Given
    String patientId = "550e8400-e29b-41d4-a716-446655440002"; // No permission
    String token = getValidCaregiverToken();
    
    // When
    HttpResponse<Buffer> response = webClient
        .get(8080, "localhost", "/v1/patients/" + patientId + "/daily-summary")
        .putHeader("Authorization", "Bearer " + token)
        .send()
        .toCompletionStage()
        .toCompletableFuture()
        .get();
    
    // Then
    assertThat(response.statusCode()).isEqualTo(200);
    JsonObject body = response.bodyAsJsonObject();
    assertThat(body.getBoolean("hasPermission")).isFalse();
    assertThat(body.getString("permissionMessage")).isNotEmpty();
    assertThat(body.getJsonObject("bpSummary")).isNull();
}
```

---

### TC-API-003: GET Daily Summary - No Token

```java
@Test
@DisplayName("GET /v1/patients/:id/daily-summary returns 401 without token")
void getDailySummary_Returns401_NoToken() {
    // Given
    String patientId = "550e8400-e29b-41d4-a716-446655440001";
    
    // When
    HttpResponse<Buffer> response = webClient
        .get(8080, "localhost", "/v1/patients/" + patientId + "/daily-summary")
        // No Authorization header
        .send()
        .toCompletionStage()
        .toCompletableFuture()
        .get();
    
    // Then
    assertThat(response.statusCode()).isEqualTo(401);
}
```

---

### TC-API-004: GET BP History - Success

```java
@Test
@DisplayName("GET /v1/patients/:id/blood-pressure returns BP records")
void getBPHistory_Returns200_ValidData() {
    // Given
    String patientId = "550e8400-e29b-41d4-a716-446655440001";
    String date = "2026-02-05";
    String token = getValidCaregiverToken();
    
    // When
    HttpResponse<Buffer> response = webClient
        .get(8080, "localhost", "/v1/patients/" + patientId + "/blood-pressure")
        .addQueryParam("date", date)
        .putHeader("Authorization", "Bearer " + token)
        .send()
        .toCompletionStage()
        .toCompletableFuture()
        .get();
    
    // Then
    assertThat(response.statusCode()).isEqualTo(200);
    JsonObject body = response.bodyAsJsonObject();
    assertThat(body.getBoolean("hasPermission")).isTrue();
    assertThat(body.getJsonArray("records")).isNotNull();
}
```

---

### TC-API-005: GET Medications - Grouped by Time

```java
@Test
@DisplayName("GET /v1/patients/:id/medications returns grouped medications")
void getMedications_ReturnsGroupedByTime() {
    // Given
    String patientId = "550e8400-e29b-41d4-a716-446655440001";
    String token = getValidCaregiverToken();
    
    // When
    HttpResponse<Buffer> response = webClient
        .get(8080, "localhost", "/v1/patients/" + patientId + "/medications")
        .putHeader("Authorization", "Bearer " + token)
        .send()
        .toCompletionStage()
        .toCompletableFuture()
        .get();
    
    // Then
    assertThat(response.statusCode()).isEqualTo(200);
    JsonObject body = response.bodyAsJsonObject();
    // Check time-based grouping
    assertThat(body.containsKey("morningMeds") || 
               body.containsKey("timeGroups")).isTrue();
}
```

---

### TC-API-006: GET Checkups - Success

```java
@Test
@DisplayName("GET /v1/patients/:id/checkups returns upcoming and past checkups")
void getCheckups_Returns200_ValidData() {
    // Given
    String patientId = "550e8400-e29b-41d4-a716-446655440001";
    String token = getValidCaregiverToken();
    
    // When
    HttpResponse<Buffer> response = webClient
        .get(8080, "localhost", "/v1/patients/" + patientId + "/checkups")
        .putHeader("Authorization", "Bearer " + token)
        .send()
        .toCompletionStage()
        .toCompletableFuture()
        .get();
    
    // Then
    assertThat(response.statusCode()).isEqualTo(200);
    JsonObject body = response.bodyAsJsonObject();
    assertThat(body.getBoolean("hasPermission")).isTrue();
    assertThat(body.getJsonArray("upcomingCheckups")).isNotNull();
    assertThat(body.getJsonArray("pastCheckups")).isNotNull();
}
```

---

### TC-API-007: GET Checkups - Status Tags per BR-CG-016

```java
@Test
@DisplayName("GET /v1/patients/:id/checkups returns correct status per BR-CG-016")
void getCheckups_ReturnsStatusTags() {
    // Given
    String patientId = "550e8400-e29b-41d4-a716-446655440001";
    String token = getValidCaregiverToken();
    
    // When
    HttpResponse<Buffer> response = webClient
        .get(8080, "localhost", "/v1/patients/" + patientId + "/checkups")
        .putHeader("Authorization", "Bearer " + token)
        .send()
        .toCompletionStage()
        .toCompletableFuture()
        .get();
    
    // Then
    JsonArray pastCheckups = response.bodyAsJsonObject().getJsonArray("pastCheckups");
    for (int i = 0; i < pastCheckups.size(); i++) {
        JsonObject checkup = pastCheckups.getJsonObject(i);
        String status = checkup.getString("status");
        // Must be one of: upcoming, completed, overdue, missed
        assertThat(status).isIn("upcoming", "completed", "overdue", "missed");
    }
}
```

---

## Run Commands

### Unit Tests
```bash
cd api-gateway-service
mvn test -Dtest=CaregiverComplianceHandlerTest
```

### Integration Tests
```bash
cd api-gateway-service
mvn test -Dtest=CaregiverComplianceApiTest
```

### All Tests
```bash
cd api-gateway-service
mvn test -Dtest="*CaregiverCompliance*"
```
