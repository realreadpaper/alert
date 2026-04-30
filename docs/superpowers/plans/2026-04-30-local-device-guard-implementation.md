# Local Device Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一款无账号、无云端、无位置记录的 Android + iOS 本地编组手机看护 App。

**Architecture:** 双端采用原生实现：iOS 使用 Swift/SwiftUI/CoreBluetooth，Android 使用 Kotlin/Jetpack Compose/Bluetooth LE/Foreground Service。两端共享协议文档、状态机、UI token 和验收标准，而不是强行共享底层代码。

**Tech Stack:** Swift, SwiftUI, CoreBluetooth, UserNotifications, Network.framework, Kotlin, Jetpack Compose, Android Bluetooth LE APIs, Foreground Service, Android Keystore, Keychain.

---

## File Structure

计划创建两个原生 App 工程和共享文档目录：

- `ios/GuardApp/`：iOS App。
- `android/`：Android App。
- `docs/technical/`：协议、平台能力和架构文档。
- `docs/ui/`：UI 规范、用户流程、文案规范。
- `docs/implementation/`：实现细节、测试矩阵、上架注意。

## Task 1: 技术原型验证

**Files:**

- Create: `ios/GuardApp/Core/Bluetooth/BlePrototype.swift`
- Create: `android/app/src/main/java/com/deviceguard/core/bluetooth/BlePrototype.kt`
- Create: `docs/implementation/prototype-test-report.md`

- [ ] **Step 1: 创建 iOS BLE 广播/扫描原型**

实现最小可运行原型，验证 CoreBluetooth 在前台和后台的广播/扫描行为。

- [ ] **Step 2: 创建 Android BLE 广播/扫描原型**

实现最小可运行原型，验证 Android 在前台服务下的广播/扫描行为。

- [ ] **Step 3: 记录测试结果**

在 `docs/implementation/prototype-test-report.md` 记录前台、锁屏、后台 5 分钟、后台 30 分钟的发现延迟。

- [ ] **Step 4: Commit**

```bash
git add ios android docs/implementation/prototype-test-report.md
git commit -m "prototype: validate local BLE guard behavior"
```

## Task 2: 本地身份与密钥存储

**Files:**

- Create: `ios/GuardApp/Core/Identity/LocalIdentityStore.swift`
- Create: `android/app/src/main/java/com/deviceguard/core/identity/LocalIdentityStore.kt`
- Test: iOS unit tests and Android unit tests for device ID persistence.

- [ ] **Step 1: 实现本机 deviceId 生成**

首次启动生成随机 UUID，后续从安全存储读取。

- [ ] **Step 2: 实现组密钥安全保存**

iOS 使用 Keychain，Android 使用 Keystore 保护的本地加密存储。

- [ ] **Step 3: 写持久化测试**

验证重启 App 后 `deviceId` 不变，清除本地数据后重新生成。

- [ ] **Step 4: Commit**

```bash
git add ios/GuardApp/Core/Identity android/app/src/main/java/com/deviceguard/core/identity
git commit -m "feat: add local identity storage"
```

## Task 3: 看护组创建与扫码加入

**Files:**

- Create: `ios/GuardApp/Features/Pairing/`
- Create: `android/app/src/main/java/com/deviceguard/features/pairing/`
- Create: shared pairing protocol tests per platform.

- [ ] **Step 1: 实现创建看护组**

创建 `groupId`、`groupSecret`、创建者设备记录和默认模式。

- [ ] **Step 2: 实现一次性邀请二维码**

二维码包含 `inviteId`、`expiresAt`、`groupId`、`ownerDeviceId`、`joinToken`、`protocolVersion`。

- [ ] **Step 3: 实现新设备扫码加入**

扫码成功后填写或确认设备名称，进入等待确认状态。

- [ ] **Step 4: 实现创建者确认**

创建者点击 `允许` 后，新设备进入设备列表，并完成本地密钥保存。

- [ ] **Step 5: Commit**

```bash
git add ios/GuardApp/Features/Pairing android/app/src/main/java/com/deviceguard/features/pairing
git commit -m "feat: add local guard group pairing"
```

## Task 4: GuardEngine 状态机

**Files:**

- Create: `ios/GuardApp/Core/GuardEngine/`
- Create: `android/app/src/main/java/com/deviceguard/core/guardengine/`

- [ ] **Step 1: 定义状态枚举**

状态包括 `online`、`unstable`、`preAlert`、`alarming`、`paused`、`permissionLimited`、`lowPowerRisk`。

- [ ] **Step 2: 实现模式阈值**

实现外出、室内、静音三套阈值配置。

- [ ] **Step 3: 实现状态转换**

根据 BLE/LAN 最近可靠发现时间输出设备状态和报警意图。

- [ ] **Step 4: 写状态机测试**

覆盖短暂丢包、持续失联、恢复连接、静音模式、暂停 10 分钟。

- [ ] **Step 5: Commit**

```bash
git add ios/GuardApp/Core/GuardEngine android/app/src/main/java/com/deviceguard/core/guardengine
git commit -m "feat: add guard state engine"
```

## Task 5: BLE 与局域网心跳

**Files:**

- Create: `ios/GuardApp/Core/Bluetooth/`
- Create: `ios/GuardApp/Core/LocalNetwork/`
- Create: `android/app/src/main/java/com/deviceguard/core/bluetooth/`
- Create: `android/app/src/main/java/com/deviceguard/core/localnetwork/`

- [ ] **Step 1: 实现 rollingId 生成**

使用 `HMAC_SHA256(groupSecret, deviceId + timeBucket)` 生成短期标识。

- [ ] **Step 2: 实现 BLE 广播与扫描**

广播本机 rollingId，扫描组内其他设备 rollingId。

- [ ] **Step 3: 实现局域网签名心跳**

发送带时间戳、nonce 和 HMAC 的本地心跳。

- [ ] **Step 4: 接入 GuardEngine**

将 BLE 与 LAN observation 汇入状态机。

- [ ] **Step 5: Commit**

```bash
git add ios/GuardApp/Core/Bluetooth ios/GuardApp/Core/LocalNetwork android/app/src/main/java/com/deviceguard/core/bluetooth android/app/src/main/java/com/deviceguard/core/localnetwork
git commit -m "feat: add local heartbeat transports"
```

## Task 6: 报警与通知

**Files:**

- Create: `ios/GuardApp/Core/AlarmEngine/`
- Create: `android/app/src/main/java/com/deviceguard/core/alarmengine/`
- Create: `android/app/src/main/java/com/deviceguard/core/service/GuardForegroundService.kt`

- [ ] **Step 1: 实现预警通知**

设备进入 `preAlert` 时发送通知和震动。

- [ ] **Step 2: 实现强提醒**

设备进入 `alarming` 时响铃、震动，并显示报警页。

- [ ] **Step 3: 实现停止与暂停**

处理 `我知道了` 和 `暂停 10 分钟`。

- [ ] **Step 4: Android 接入前台服务**

看护开启时显示常驻通知，提供停止看护和切换静音操作。

- [ ] **Step 5: Commit**

```bash
git add ios/GuardApp/Core/AlarmEngine android/app/src/main/java/com/deviceguard/core/alarmengine android/app/src/main/java/com/deviceguard/core/service
git commit -m "feat: add graded local alarms"
```

## Task 7: UI 与设计系统

**Files:**

- Create: `ios/GuardApp/DesignSystem/`
- Create: `android/app/src/main/java/com/deviceguard/design/`
- Create: Home, Pairing, Alarm, Settings screens per platform.

- [ ] **Step 1: 建立 UI token**

实现颜色、字号、圆角、间距、按钮样式。

- [ ] **Step 2: 实现首页**

包含状态卡片、模式切换、设备列表、主按钮。

- [ ] **Step 3: 实现添加设备和加入设备流程**

包含二维码、扫码、等待确认、创建者确认。

- [ ] **Step 4: 实现报警页**

包含预警态、强提醒态、暂停和确认操作。

- [ ] **Step 5: Commit**

```bash
git add ios/GuardApp/DesignSystem ios/GuardApp/Features android/app/src/main/java/com/deviceguard/design android/app/src/main/java/com/deviceguard/features
git commit -m "feat: add refined guard app UI"
```

## Task 8: 权限引导与降级

**Files:**

- Create: `ios/GuardApp/Core/Permissions/`
- Create: `android/app/src/main/java/com/deviceguard/core/permissions/`

- [ ] **Step 1: 实现权限检测**

检测蓝牙、通知、本地网络、后台相关限制。

- [ ] **Step 2: 实现权限修复页**

一次只展示当前最关键问题，并提供系统设置入口。

- [ ] **Step 3: 实现降级状态**

缺少本地网络时只用 BLE；缺少通知时继续看护但提示风险；蓝牙关闭时暂停核心看护。

- [ ] **Step 4: Commit**

```bash
git add ios/GuardApp/Core/Permissions android/app/src/main/java/com/deviceguard/core/permissions
git commit -m "feat: add permissions guidance"
```

## Task 9: 真机测试与阈值校准

**Files:**

- Create: `docs/implementation/device-test-matrix.md`
- Modify: mode threshold config files per platform.

- [ ] **Step 1: 建立测试矩阵**

覆盖 iPhone、Pixel、Samsung、小米、华为、OPPO 或 vivo。

- [ ] **Step 2: 执行场景测试**

测试前台、锁屏、后台、同 Wi-Fi、无 Wi-Fi、车内、会议室、酒店/餐厅。

- [ ] **Step 3: 校准模式阈值**

根据误报和报警延迟调整外出、室内、静音模式。

- [ ] **Step 4: Commit**

```bash
git add docs/implementation/device-test-matrix.md ios android
git commit -m "test: calibrate guard thresholds on real devices"
```

## Task 10: 隐私与上架准备

**Files:**

- Create: `docs/implementation/privacy-review.md`
- Create: `docs/implementation/store-review-notes.md`

- [ ] **Step 1: 验证无云端请求**

抓包确认 App 不上传位置、设备状态或身份信息。

- [ ] **Step 2: 完成隐私说明**

说明无账号、无云端、无位置记录、本地看护。

- [ ] **Step 3: 完成上架说明**

解释蓝牙、通知、本地网络和 Android 前台服务用途。

- [ ] **Step 4: Commit**

```bash
git add docs/implementation/privacy-review.md docs/implementation/store-review-notes.md
git commit -m "docs: add privacy and store review notes"
```

## Self-Review

- Spec coverage: 已覆盖本地编组、扫码加入、无云端、BLE + 局域网、场景模式、分级报警、商务优雅 UI、权限降级、真机测试。
- Placeholder scan: 本计划未发现未填写内容或占位项。
- Type consistency: 核心概念统一为 `GuardGroup`、`GuardDevice`、`GuardMode`、`DeviceState`、`AlarmEvent`。
