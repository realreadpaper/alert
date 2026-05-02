# Cross Platform Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打通 iOS 与 Android 的本地优先联调能力，让两端可以使用同一套配对二维码、BLE 发现格式、局域网心跳协议和看护状态模型。

**Architecture:** 先定义跨平台 wire contract，再让 iOS 和 Android 分别适配该 contract。协议层使用稳定的小写字符串、epoch seconds、HMAC-SHA256 和固定 JSON 字段名；UI 层只消费本地状态，不直接拼协议。云端辅助暂不进入本阶段，避免偏离“隐私、不做云端”的产品约束。

**Tech Stack:** SwiftUI, CoreBluetooth, CryptoKit, UserNotifications, Jetpack Compose, Android BLE APIs, Kotlin/JVM tests, Swift self-test runner.

---

## 审核重点

本计划优先解决当前审查发现的三个跨平台阻塞点：

- 配对二维码 payload 不兼容。
- 局域网心跳 HMAC payload 不兼容。
- BLE 广播/发现模型不兼容。

本计划不做：

- 不接入云端辅助。
- 不做 App Store 级别的 Critical Alerts 权限申请。
- 不承诺后台蓝牙在所有系统状态下 100% 保活，先做真机可验证的前台/锁屏基础路径。

## 关键设计决策

### 1. Wire enum 统一使用小写字符串

跨平台协议中的枚举统一为：

```text
mode: "outing" | "indoor" | "silent"
platform: "ios" | "android"
role: "owner" | "member"
deviceState: "online" | "unstable" | "pre_alert" | "alarming" | "paused" | "permission_limited" | "low_power_risk"
```

原因：

- JSON payload 中小写字符串更稳定，不绑定 Swift enum case 或 Kotlin enum name。
- iOS 当前 `GuardMode.rawValue` 已经是小写。
- Android 后续增加 `wireValue` 和 `fromWireValue()`，避免直接使用 `enum.name`。

### 2. 时间字段统一使用 epoch seconds

跨平台 JSON 字段统一使用 `createdAtEpochSeconds`、`joinedAtEpochSeconds`、`expiresAtEpochSeconds`、`requestedAtEpochSeconds`。

原因：

- Android 当前已经使用 epoch seconds。
- iOS `JSONEncoder.dateEncodingStrategy = .secondsSince1970` 虽然值一致，但字段名仍不一致，显式字段更适合跨平台协议。

### 3. QR payload 使用版本化 envelope

邀请二维码 payload 统一为：

```json
{
  "type": "device_guard_pairing_invite",
  "protocolVersion": 1,
  "inviteId": "invite-1",
  "groupId": "group-1",
  "ownerDeviceId": "owner-1",
  "joinToken": "token-1",
  "expiresAtEpochSeconds": 1710000300
}
```

加入请求 payload 统一为：

```json
{
  "type": "device_guard_join_request",
  "protocolVersion": 1,
  "inviteId": "invite-1",
  "groupId": "group-1",
  "deviceId": "ios-2",
  "displayName": "iPhone 备用机",
  "platform": "ios",
  "requestedAtEpochSeconds": 1710000010
}
```

批准加入 payload 统一为：

```json
{
  "type": "device_guard_join_approval",
  "protocolVersion": 1,
  "group": {
    "groupId": "group-1",
    "displayName": "看护组",
    "keyVersion": 1,
    "createdAtEpochSeconds": 1710000000,
    "currentMode": "outing",
    "devices": [
      {
        "deviceId": "owner-1",
        "displayName": "主力 iPhone",
        "platform": "ios",
        "role": "owner",
        "joinedAtEpochSeconds": 1710000000
      }
    ]
  },
  "groupSecretBase64": "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="
}
```

### 4. BLE 使用“两阶段发现”

iOS 官方 `CBPeripheralManager.startAdvertising` 只支持 `CBAdvertisementDataLocalNameKey` 和 `CBAdvertisementDataServiceUUIDsKey`，因此不能要求 iOS 像 Android 一样广播 service data。

统一方案：

- 广播阶段：两端都广播同一个 Device Guard service UUID。
- 读取阶段：扫描到 service UUID 后，连接对端 GATT service，读取 `rollingId` characteristic。
- Android 仍可保留 service data 快速路径，但不能依赖它作为唯一互通路径。

固定 UUID：

```text
serviceUuid: 75B9D2B7-7D40-4B10-9F4B-9D3592D4E101
rollingIdCharacteristicUuid: 75B9D2B8-7D40-4B10-9F4B-9D3592D4E101
```

### 5. 局域网心跳统一签名 payload

JSON payload：

```json
{
  "protocolVersion": 1,
  "groupHash": "abcd1234abcd1234",
  "deviceId": "ios-1",
  "deviceNameHash": "ef567890ef567890",
  "timestamp": 1710000000,
  "nonce": "nonce-1",
  "mode": "outing",
  "signature": "hex-hmac"
}
```

签名字符串：

```text
1|abcd1234abcd1234|ios-1|ef567890ef567890|1710000000|nonce-1|outing
```

HMAC:

```text
HMAC-SHA256(secret, signingPayload) -> lowercase hex
```

---

## File Structure

### Protocol contract

- Modify: `docs/technical/architecture.md`
  - 增加跨平台 wire contract 章节。
- Modify: `docs/implementation/implementation-details.md`
  - 增加协议字段、签名 payload、错误处理和真机联调流程。

### iOS

- Modify: `ios/GuardApp/Features/Pairing/GuardPairingModels.swift`
  - 将跨平台字段从 `Date` 模型迁移到 epoch seconds DTO，保留 UI/domain 层可读模型。
- Modify: `ios/GuardApp/Features/Pairing/GuardPairingService.swift`
  - 使用 envelope 编解码 QR payload。
- Modify: `ios/GuardApp/Core/LocalNetwork/LanHeartbeatMessage.swift`
  - 固定使用小写 wire enum。
- Modify: `ios/GuardApp/Core/Bluetooth/BlePrototype.swift`
  - 扫描到 service 后连接 peripheral，发现 service/characteristic，读取 rollingId。
- Modify: `ios/GuardApp/GuardApp.swift`
  - 接入真实 `GuardPairingService` 状态，让添加设备按钮进入 `AddDeviceView`。
- Modify: `ios/GuardApp/Features/Pairing/AddDeviceView.swift`
  - 显示真实 invite payload 和审核请求状态。
- Test: `ios/GuardApp/Features/Pairing/GuardPairingServiceTests.swift`
- Test: `ios/GuardApp/Core/LocalNetwork/LanHeartbeatMessageTests.swift`
- Test: `ios/GuardApp/Core/Bluetooth/RollingIdentifier.swift` 的对应测试如需补充，放在 `ios/GuardApp/Core/Bluetooth/RollingIdentifierTests.swift`

### Android

- Modify: `android/app/src/main/java/com/deviceguard/features/pairing/GuardPairingModels.kt`
  - 增加 wire enum 映射，避免使用 `enum.name`。
- Modify: `android/app/src/main/java/com/deviceguard/features/pairing/GuardPairingService.kt`
  - 使用 envelope 编解码 QR payload。
- Modify: `android/app/src/main/java/com/deviceguard/core/localnetwork/LanHeartbeatMessage.kt`
  - 使用 `mode.wireValue` 而不是 `mode.name`。
- Modify: `android/app/src/main/java/com/deviceguard/core/bluetooth/BlePrototype.kt`
  - 增加 GATT server 暴露 rollingId characteristic；扫描后连接并读取 characteristic。
- Modify: `android/app/src/main/java/com/deviceguard/MainActivity.kt`
  - 暂时隐藏或移除云端辅助入口。
- Modify: `android/app/src/main/java/com/deviceguard/features/home/HomeScreen.kt`
  - 不在主界面显示云端辅助开关。
- Test: `android/app/src/test/java/com/deviceguard/features/pairing/GuardPairingServiceTest.kt`
- Test: `android/app/src/test/java/com/deviceguard/core/localnetwork/LanHeartbeatMessageTest.kt`
- Test: `android/app/src/test/java/com/deviceguard/core/bluetooth/RollingIdentifierTest.kt`

---

## Task 1: 固化跨平台协议文档

**Files:**
- Modify: `docs/technical/architecture.md`
- Modify: `docs/implementation/implementation-details.md`

- [ ] **Step 1: 写入 wire contract**

增加 QR、join request、join approval、LAN heartbeat、BLE service/characteristic 的固定字段和示例 JSON。

- [ ] **Step 2: 明确兼容策略**

写明 `protocolVersion = 1`，未知 `type` 直接拒绝，未知 enum 直接拒绝，过期 invite 直接拒绝。

- [ ] **Step 3: 运行文档检查**

Run:

```bash
rg "expiresAt|expiresAtEpochSeconds|mode.name|rawValue|protocolVersion" docs
```

Expected:

```text
docs 中只把旧格式作为历史问题描述，正式 contract 使用 expiresAtEpochSeconds 和小写 wire enum。
```

- [ ] **Step 4: Commit**

```bash
git add docs/technical/architecture.md docs/implementation/implementation-details.md
git commit -m "docs: define cross-platform local guard protocol"
```

## Task 2: 统一 iOS 配对 QR 协议

**Files:**
- Modify: `ios/GuardApp/Features/Pairing/GuardPairingModels.swift`
- Modify: `ios/GuardApp/Features/Pairing/GuardPairingService.swift`
- Test: `ios/GuardApp/Features/Pairing/GuardPairingServiceTests.swift`

- [ ] **Step 1: 添加失败测试**

测试 iOS 能解析标准 envelope invite：

```swift
func testDecodesCanonicalInviteEnvelope() throws {
    let service = GuardPairingService()
    let payload = """
    {"type":"device_guard_pairing_invite","protocolVersion":1,"inviteId":"invite-1","groupId":"group-1","ownerDeviceId":"owner-1","joinToken":"token-1","expiresAtEpochSeconds":1710000300}
    """

    let invite = try service.decodeInviteFromQRCode(payload, nowEpochSeconds: 1710000000)

    assertEqual(invite.inviteId, "invite-1", "invite id")
    assertEqual(invite.expiresAtEpochSeconds, 1710000300, "expires at")
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```bash
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest && /tmp/deviceguard-ios-selftest
```

Expected:

```text
测试因 decodeInviteFromQRCode 签名或字段不存在失败。
```

- [ ] **Step 3: 实现 epoch seconds DTO**

将 `PairingInvite.expiresAt: Date` 改为 `expiresAtEpochSeconds: Int64`，`JoinRequest.requestedAt: Date` 改为 `requestedAtEpochSeconds: Int64`，`GuardDevice.joinedAt` 和 `GuardGroup.createdAt` 对应增加 epoch seconds wire 字段。

- [ ] **Step 4: 运行 iOS 自测**

Run:

```bash
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest && /tmp/deviceguard-ios-selftest
```

Expected:

```text
退出码 0。
```

- [ ] **Step 5: Commit**

```bash
git add ios/GuardApp/Features/Pairing/GuardPairingModels.swift ios/GuardApp/Features/Pairing/GuardPairingService.swift ios/GuardApp/Features/Pairing/GuardPairingServiceTests.swift
git commit -m "feat: align iOS pairing wire format"
```

## Task 3: 统一 Android 配对 QR 协议

**Files:**
- Modify: `android/app/src/main/java/com/deviceguard/features/pairing/GuardPairingModels.kt`
- Modify: `android/app/src/main/java/com/deviceguard/features/pairing/GuardPairingService.kt`
- Test: `android/app/src/test/java/com/deviceguard/features/pairing/GuardPairingServiceTest.kt`

- [ ] **Step 1: 添加失败测试**

测试 Android 编码出来的 invite 和 iOS 标准 envelope 一致：

```kotlin
@Test
fun encodeInviteForQrCode_usesCanonicalEnvelope() {
    val service = GuardPairingService(
        idFactory = { "invite-1" },
        tokenFactory = { "token-1" },
        secretFactory = { "0123456789abcdef0123456789abcdef".toByteArray() }
    )
    val group = GuardGroup(
        groupId = "group-1",
        displayName = "看护组",
        keyVersion = 1,
        createdAtEpochSeconds = 1710000000,
        devices = listOf(
            GuardDevice("owner-1", "主力 Android", GuardPlatform.ANDROID, GuardDeviceRole.OWNER, 1710000000)
        ),
        currentMode = GuardMode.OUTING
    )

    val invite = service.createInvite(group, "owner-1", 1710000000)
    val payload = JSONObject(service.encodeInviteForQrCode(invite))

    assertEquals("device_guard_pairing_invite", payload.getString("type"))
    assertEquals(1710000300, payload.getLong("expiresAtEpochSeconds"))
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```bash
gradle :android:app:testDebugUnitTest --tests com.deviceguard.features.pairing.GuardPairingServiceTest --no-daemon
```

Expected:

```text
测试因缺少 type 或字段格式不一致失败。
```

- [ ] **Step 3: 实现 canonical envelope**

`encodeInviteForQrCode()` 写入 `type = device_guard_pairing_invite`，`decodeInviteFromQrCode()` 验证 `type`、`protocolVersion`、过期时间。

- [ ] **Step 4: 运行 Android 测试**

Run:

```bash
gradle :android:app:testDebugUnitTest --no-daemon
```

Expected:

```text
BUILD SUCCESSFUL。
```

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/deviceguard/features/pairing/GuardPairingModels.kt android/app/src/main/java/com/deviceguard/features/pairing/GuardPairingService.kt android/app/src/test/java/com/deviceguard/features/pairing/GuardPairingServiceTest.kt
git commit -m "feat: align Android pairing wire format"
```

## Task 4: 统一局域网心跳签名

**Files:**
- Modify: `ios/GuardApp/Core/LocalNetwork/LanHeartbeatMessage.swift`
- Modify: `android/app/src/main/java/com/deviceguard/core/localnetwork/LanHeartbeatMessage.kt`
- Test: `ios/GuardApp/Core/LocalNetwork/LanHeartbeatMessageTests.swift`
- Test: `android/app/src/test/java/com/deviceguard/core/localnetwork/LanHeartbeatMessageTest.kt`

- [ ] **Step 1: 加 golden vector 测试**

两端使用同一组输入：

```text
groupId: group-1
groupSecret: 0123456789abcdef0123456789abcdef
deviceId: ios-1
deviceName: 主力 iPhone
mode: outing
timestamp: 1710000000
nonce: nonce-1
```

两端断言：

```text
签名 payload 必须是 1|<groupHash>|ios-1|<deviceNameHash>|1710000000|nonce-1|outing
mode JSON 必须是 "outing"
```

- [ ] **Step 2: 运行两端测试确认至少 Android 失败**

Run:

```bash
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest && /tmp/deviceguard-ios-selftest
gradle :android:app:testDebugUnitTest --tests com.deviceguard.core.localnetwork.LanHeartbeatMessageTest --no-daemon
```

Expected:

```text
Android 当前使用 OUTING，golden vector 应失败。
```

- [ ] **Step 3: Android 增加 wire enum**

为 `GuardMode` 增加 `wireValue` 和 `fromWireValue(value: String)`，`LanHeartbeatSigner` 全部改用 wire value。

- [ ] **Step 4: iOS 保持小写并补充拒绝未知值测试**

iOS `GuardMode` 继续使用小写 raw value，decode 时未知值应抛错。

- [ ] **Step 5: 运行全量测试**

Run:

```bash
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest && /tmp/deviceguard-ios-selftest
gradle :android:app:testDebugUnitTest --no-daemon
```

Expected:

```text
两条命令退出码 0。
```

- [ ] **Step 6: Commit**

```bash
git add ios/GuardApp/Core/LocalNetwork/LanHeartbeatMessage.swift ios/GuardApp/Core/LocalNetwork/LanHeartbeatMessageTests.swift android/app/src/main/java/com/deviceguard/core/localnetwork/LanHeartbeatMessage.kt android/app/src/test/java/com/deviceguard/core/localnetwork/LanHeartbeatMessageTest.kt
git commit -m "feat: align local heartbeat signing format"
```

## Task 5: 统一 BLE 发现流程

**Files:**
- Modify: `ios/GuardApp/Core/Bluetooth/BlePrototype.swift`
- Modify: `android/app/src/main/java/com/deviceguard/core/bluetooth/BlePrototype.kt`
- Test: `ios/GuardApp/Core/Bluetooth/RollingIdentifierTests.swift`
- Test: `android/app/src/test/java/com/deviceguard/core/bluetooth/RollingIdentifierTest.kt`

- [ ] **Step 1: 明确事件模型**

统一事件含义：

```text
bluetoothUnavailable
missingPermission
advertisingStarted
advertisingFailed
scanningStarted
peerDiscovered(rollingId, rssi, timestamp)
scanFailed
```

- [ ] **Step 2: iOS 实现连接读取 characteristic**

扫描到 service UUID 后：

```text
connect peripheral -> discover service -> discover rollingId characteristic -> read value -> emit peerDiscovered
```

- [ ] **Step 3: Android 实现 GATT server**

Android 在广播 service UUID 的同时开放 GATT server，包含 `rollingIdCharacteristicUuid` 的 readable characteristic。

- [ ] **Step 4: Android 保留 service data 快速路径**

如果扫描结果包含 service data，直接读取；如果没有，连接 GATT characteristic。

- [ ] **Step 5: 真机验证**

Run iOS:

```bash
DEVELOPMENT_TEAM=F4657JWDQ6 BUNDLE_ID=com.jianglong.deviceguard ios/scripts/run-device.sh
```

Run Android:

```bash
gradle :android:app:installDebug
```

Expected:

```text
iPhone 和 Android 在前台打开 App 后，日志中能互相看到同一个 rollingId 格式的 peerDiscovered 事件。
```

- [ ] **Step 6: Commit**

```bash
git add ios/GuardApp/Core/Bluetooth/BlePrototype.swift android/app/src/main/java/com/deviceguard/core/bluetooth/BlePrototype.kt ios/GuardApp/Core/Bluetooth/RollingIdentifierTests.swift android/app/src/test/java/com/deviceguard/core/bluetooth/RollingIdentifierTest.kt
git commit -m "feat: align BLE discovery across iOS and Android"
```

## Task 6: iOS 接入真实看护组状态

**Files:**
- Modify: `ios/GuardApp/GuardApp.swift`
- Modify: `ios/GuardApp/Features/Home/HomeView.swift`
- Modify: `ios/GuardApp/Features/Pairing/AddDeviceView.swift`
- Create: `ios/GuardApp/GuardAppState.swift`
- Test: `ios/GuardApp/GuardAppStateTests.swift`

- [ ] **Step 1: 添加 GuardAppState 测试**

覆盖：

```text
initial state creates owner group
startAddDevice creates invite
approveJoin appends member
rejectJoin keeps group unchanged
toggleGuarding changes isGuarding
selectMode changes mode
```

- [ ] **Step 2: 实现 iOS GuardAppState**

按 Android 当前 `GuardAppState` 的结构移植，但不包含 cloud assist 字段。

- [ ] **Step 3: 接入 UI 导航**

`GuardApp.swift` 根据 `screen` 显示 `HomeView` 或 `AddDeviceView`，`onAddDevice` 不再为空。

- [ ] **Step 4: 运行 iOS 自测**

Run:

```bash
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest && /tmp/deviceguard-ios-selftest
```

Expected:

```text
退出码 0。
```

- [ ] **Step 5: Commit**

```bash
git add ios/GuardApp/GuardApp.swift ios/GuardApp/GuardAppState.swift ios/GuardApp/GuardAppStateTests.swift ios/GuardApp/Features/Home/HomeView.swift ios/GuardApp/Features/Pairing/AddDeviceView.swift
git commit -m "feat: wire iOS app state to pairing flow"
```

## Task 7: 收敛 Android UI，移除默认云端入口

**Files:**
- Modify: `android/app/src/main/java/com/deviceguard/MainActivity.kt`
- Modify: `android/app/src/main/java/com/deviceguard/GuardAppState.kt`
- Modify: `android/app/src/main/java/com/deviceguard/features/home/HomeScreen.kt`
- Test: `android/app/src/test/java/com/deviceguard/GuardAppStateTest.kt`
- Test: `android/app/src/test/java/com/deviceguard/features/home/HomeUiStateTest.kt`

- [ ] **Step 1: 添加 UI 状态测试**

断言默认首页不暴露云端辅助：

```kotlin
@Test
fun initialState_doesNotExposeCloudAssistInPrimaryHomeUi() {
    val state = GuardAppState.initial(nowEpochSeconds = 1710000000)

    assertFalse(state.homeUiState.statusDescription.contains("云端"))
}
```

- [ ] **Step 2: 从 HomeScreen 参数移除 cloudAssistEnabled**

主界面不显示云端辅助开关。保留 cloud 包源码可以后续单独分支处理，但不进入本地版 UI。

- [ ] **Step 3: 运行 Android 测试**

Run:

```bash
gradle :android:app:testDebugUnitTest --no-daemon
```

Expected:

```text
BUILD SUCCESSFUL。
```

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/java/com/deviceguard/MainActivity.kt android/app/src/main/java/com/deviceguard/GuardAppState.kt android/app/src/main/java/com/deviceguard/features/home/HomeScreen.kt android/app/src/test/java/com/deviceguard/GuardAppStateTest.kt android/app/src/test/java/com/deviceguard/features/home/HomeUiStateTest.kt
git commit -m "refactor: keep Android home local-first by default"
```

## Task 8: 真机联调验收

**Files:**
- Modify: `docs/implementation/implementation-details.md`

- [ ] **Step 1: iOS 真机安装**

Run:

```bash
DEVELOPMENT_TEAM=F4657JWDQ6 BUNDLE_ID=com.jianglong.deviceguard ios/scripts/run-device.sh
```

Expected:

```text
Xcode build succeeded，iPhone 上 Device Guard 可启动。
```

- [ ] **Step 2: Android 真机或模拟器安装**

Run:

```bash
gradle :android:app:installDebug
```

Expected:

```text
APK 安装成功，Android 上 Device Guard 可启动。
```

- [ ] **Step 3: 配对互通验收**

验收路径：

```text
Android 创建邀请 -> iOS 解析 invite payload -> iOS 创建 join request -> Android approve -> Android 设备列表新增 iOS
iOS 创建邀请 -> Android 解析 invite payload -> Android 创建 join request -> iOS approve -> iOS 设备列表新增 Android
```

- [ ] **Step 4: 本地发现验收**

验收路径：

```text
iOS 和 Android 同时开启看护 -> 两端日志出现 peerDiscovered -> rollingId 可解析 -> 最近在线时间更新
```

- [ ] **Step 5: 心跳验收**

验收路径：

```text
iOS 生成 LAN heartbeat -> Android decode + verify 成功
Android 生成 LAN heartbeat -> iOS decode + verify 成功
```

- [ ] **Step 6: 文档记录**

把真机型号、系统版本、测试时间、通过/失败点写入 `docs/implementation/implementation-details.md`。

- [ ] **Step 7: Commit**

```bash
git add docs/implementation/implementation-details.md
git commit -m "docs: record cross-platform device validation"
```

---

## 最终验收标准

- iOS 和 Android 使用同一份 QR invite JSON schema。
- iOS 和 Android 的 LAN heartbeat 可以互相 decode 和 verify。
- iOS 和 Android 的 BLE 发现不依赖 Android-only service data。
- iOS 添加设备按钮进入真实添加流程，不再是空操作。
- Android 默认 UI 不显示云端辅助入口。
- 两端测试命令通过：

```bash
swiftc -typecheck $(find ios -name '*.swift' | sort)
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest && /tmp/deviceguard-ios-selftest
gradle :android:app:testDebugUnitTest --no-daemon
```

## 风险与降级策略

- iOS 后台 BLE 广播受系统限制：先验收前台和锁屏基础路径，再单独做后台稳定性测试。
- Android 厂商后台限制差异大：需要至少一台常见品牌真机验证前台服务。
- QR 扫码依赖暂未选型：第一阶段可以先用 payload 文本/手动复制验证协议，第二阶段再接入相机扫码和二维码渲染。
- 云端辅助代码当前存在于 Android worktree：本计划只隐藏默认入口，不删除代码，避免误删前面未提交工作。

