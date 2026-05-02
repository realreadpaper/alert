# Cloud Assist Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增加一个可选云端辅助原型，用于在非同一局域网时模拟远程在线状态同步。

**Architecture:** 保持本地优先，新增云端心跳协议和内存云端仓库，不接真实服务器。Android UI 增加云端辅助开关，开启后组内非本机设备可显示 `远程在线` 或 `云端失联`。

**Tech Stack:** Kotlin, Jetpack Compose, JUnit/kotlin-test, HMAC-SHA256, in-memory repository.

---

### Task 1: 云端心跳协议

**Files:**
- Create: `android/app/src/main/java/com/deviceguard/core/cloud/CloudHeartbeatMessage.kt`
- Test: `android/app/src/test/java/com/deviceguard/core/cloud/CloudHeartbeatMessageTest.kt`

- [ ] **Step 1: Write failing tests**
  - Verify signed heartbeat creation.
  - Verify valid heartbeat passes signature and clock-skew checks.
  - Verify tampered heartbeat fails.

- [ ] **Step 2: Implement message and signer**
  - Define `CloudHeartbeatMessage`.
  - Define `CloudHeartbeatSigner.create`, `encode`, `decode`, `verify`.

- [ ] **Step 3: Run targeted test**
  - `./gradlew :android:app:testDebugUnitTest --tests com.deviceguard.core.cloud.CloudHeartbeatMessageTest`

### Task 2: 内存云端状态仓库

**Files:**
- Create: `android/app/src/main/java/com/deviceguard/core/cloud/CloudPresenceRepository.kt`
- Test: `android/app/src/test/java/com/deviceguard/core/cloud/InMemoryCloudPresenceRepositoryTest.kt`

- [ ] **Step 1: Write failing tests**
  - Upsert a valid heartbeat.
  - Read last seen for a device.
  - Reject invalid signatures.

- [ ] **Step 2: Implement repository**
  - Define `CloudPresenceRepository`.
  - Implement `InMemoryCloudPresenceRepository`.

- [ ] **Step 3: Run targeted test**
  - `./gradlew :android:app:testDebugUnitTest --tests com.deviceguard.core.cloud.InMemoryCloudPresenceRepositoryTest`

### Task 3: Android app-state and UI integration

**Files:**
- Modify: `android/app/src/main/java/com/deviceguard/GuardAppState.kt`
- Modify: `android/app/src/main/java/com/deviceguard/features/home/HomeScreen.kt`
- Test: `android/app/src/test/java/com/deviceguard/GuardAppStateTest.kt`

- [ ] **Step 1: Write failing tests**
  - Cloud assist is off by default.
  - Toggling cloud assist on records remote heartbeat for member devices.
  - Remote member row displays `远程在线`.
  - Expired cloud heartbeat displays `云端失联`.

- [ ] **Step 2: Implement app-state fields and actions**
  - Add `cloudAssistEnabled`.
  - Add `toggleCloudAssist(nowEpochSeconds)`.
  - Add cloud status mapping into `homeUiState`.

- [ ] **Step 3: Add UI control**
  - Add a `云端辅助` button in the home header.
  - Button text reflects `开` or `关`.

- [ ] **Step 4: Run full verification**
  - `./gradlew :android:app:testDebugUnitTest :android:app:assembleDebug`
  - Install and launch APK on emulator.
