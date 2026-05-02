# Device Guard

Device Guard 是一款本地优先的多手机看护 App 原型。它面向拥有多台手机的用户：当其中一台手机离开看护范围时，其他已加入看护组的手机应能尽早提醒。

首版目标不是“云端找回手机”，而是“离开时及时发现”。当前实现坚持无账号、无云端、无定位记录的产品边界。

## 核心原则

- **本地优先**：看护组、设备状态、密钥和报警判断默认只在本机与组内设备之间处理。
- **无云端依赖**：当前 App 不包含账号、服务端请求、远程推送或云端状态同步。
- **不做定位**：不请求定位权限，不上传位置，不保存轨迹。
- **面对面加入**：新设备通过本地邀请流程加入，已有设备确认后才进入看护组。
- **分级提醒**：先判断连接不稳定，再进入预警，最后才强提醒，减少误报。
- **商务优雅 UI**：界面克制、清晰、可信赖，避免廉价警报器或老人机风格。

## 当前状态

当前仓库包含 iOS 与 Android 原生原型：

- Android：Kotlin + Jetpack Compose。
- iOS：Swift + SwiftUI。
- 双端均包含核心看护算法、报警模型、配对模型、滚动标识、局域网心跳签名模型和权限引导模型。
- Android 已接入较完整的本地 App 状态，可演示添加设备、模拟加入请求、确认加入和首页状态变化。
- iOS 当前主要是 UI shell + 核心模块 + 真机可运行工程；添加设备和局域网传输尚未接入端到端状态流。

### 已实现能力

- 看护模式：
  - 外出模式
  - 室内模式
  - 静音模式
- GuardEngine 状态判断：
  - `online`
  - `unstable`
  - `preAlert`
  - `alarming`
  - `paused`
  - `permissionLimited`
  - `lowPowerRisk`
- AlarmEngine：
  - 预警通知
  - 强提醒动作
  - 暂停提醒
  - 确认停止
- Pairing：
  - 创建看护组
  - 创建邀请
  - 创建加入请求
  - 审批加入
  - 跨平台 QR invite envelope
- LocalNetwork：
  - HMAC-SHA256 局域网心跳消息模型
  - 跨平台小写 `mode` wire value：`outing`、`indoor`、`silent`
- Bluetooth：
  - BLE rolling identifier 生成与候选匹配
  - iOS/Android BLE 原型类
- 本地身份：
  - iOS Keychain 存储实现
  - Android 安全存储抽象和内存实现

## 重要限制

当前版本仍是工程原型，不是完整可上架产品。

- iOS 尚未实现真实局域网传输层。`LanHeartbeatMessage` 只负责签名、编码、解码和验签；还没有 Bonjour、UDP/TCP listener 或 connection。
- iOS 首页仍是静态设备列表，`onAddDevice` 还没有接入真实状态流。
- iOS BLE 原型未接入 UI，也未完成连接后读取 rolling ID characteristic 的互通路径。
- Android BLE 与局域网也仍属于原型层，尚未作为后台稳定看护服务完整接入。
- 当前没有真实二维码渲染/扫码能力，QR payload 主要用于协议验证。
- 云端辅助相关文档仅作为后续扩展资料保留；当前 App 主线不包含云端逻辑。

## 仓库结构

```text
.
├── android/                      Android App
│   └── app/src/main/java/com/deviceguard/
│       ├── core/                 核心算法、BLE、身份、局域网、权限、服务
│       ├── design/               Compose 设计 token 和组件
│       └── features/             首页、配对、报警、设置
├── ios/                          iOS App
│   ├── DeviceGuard.xcodeproj
│   ├── GuardApp/
│   │   ├── Core/                 核心算法、BLE、身份、局域网、权限
│   │   ├── DesignSystem/         SwiftUI 设计系统
│   │   └── Features/             首页、配对、报警、设置
│   └── scripts/                  iOS 构建和真机运行脚本
├── docs/
│   ├── technical/                技术架构与平台实现
│   ├── implementation/           实现细节、隐私审查、测试矩阵
│   ├── ui/                       UI 设计与用户流程
│   └── superpowers/              规格与实施计划
├── gradle/                       Gradle wrapper
├── build.gradle.kts
└── settings.gradle.kts
```

## 环境要求

### Android

- Android Studio
- JDK 17 或 Android Studio bundled JBR
- Android SDK
- Android Emulator 或真机

### iOS

- macOS
- Xcode 15.4
- iOS 17.5 SDK
- Apple Developer 账号或本机 Apple Development 签名
- 可选：已信任开发者的 iPhone 真机

当前真机调试脚本默认使用：

```text
DEVICE_ID=00008101-000575411430001E
DEVICECTL_ID=67C1404D-0644-489C-9014-879E44FFFBEA
```

如果你的设备不同，可以通过环境变量覆盖。

## 构建与测试

### Android 单元测试

```bash
./gradlew :android:app:testDebugUnitTest --no-daemon
```

如果本机没有配置 wrapper 执行权限，可先运行：

```bash
chmod +x ./gradlew
```

### Android Debug APK

```bash
./gradlew :android:app:assembleDebug --no-daemon
```

### Android 安装到设备

```bash
./gradlew :android:app:installDebug --no-daemon
```

### iOS Swift 类型检查

```bash
swiftc -typecheck $(find ios -name '*.swift' | sort)
```

### iOS 自测

```bash
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest
/tmp/deviceguard-ios-selftest
```

### iOS Simulator 编译

```bash
xcodebuild \
  -project ios/DeviceGuard.xcodeproj \
  -scheme DeviceGuard \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### iOS 真机编译、安装、启动

先确认 Team ID 和 Bundle ID。示例：

```bash
DEVELOPMENT_TEAM=F4657JWDQ6 \
BUNDLE_ID=com.jianglong.deviceguard \
ios/scripts/run-device.sh
```

如果设备 ID 不同：

```bash
DEVELOPMENT_TEAM=F4657JWDQ6 \
BUNDLE_ID=com.jianglong.deviceguard \
DEVICE_ID=<xcode-device-id> \
DEVICECTL_ID=<devicectl-device-id> \
ios/scripts/run-device.sh
```

查看已连接设备：

```bash
xcrun devicectl list devices
```

## 无云端检查

当前 App 主线不应包含云端运行时代码或 Android `INTERNET` 权限。可用以下命令做源码级检查：

```bash
if rg -n "com\\.deviceguard\\.core\\.cloud|cloudAssist|CloudHeartbeat|CloudPresence|云端失联|远程在线|android\\.permission\\.INTERNET" android/app/src/main android/app/src/test; then
  exit 1
fi
```

该命令没有输出且退出码为 0，表示 Android App 源码与测试中没有云端运行时残留。

## 跨平台协议

### Pairing Invite

QR invite 使用版本化 JSON envelope：

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

要求：

- `type` 必须是 `device_guard_pairing_invite`。
- `protocolVersion` 必须是 `1`。
- `expiresAtEpochSeconds` 必须晚于当前时间。
- 未知字段可以忽略，缺失必需字段必须拒绝。

### LAN Heartbeat

局域网心跳使用 HMAC-SHA256 签名：

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

签名 payload 固定为：

```text
protocolVersion|groupHash|deviceId|deviceNameHash|timestamp|nonce|mode
```

`mode` 必须使用小写 wire value：

```text
outing
indoor
silent
```

## iOS 双机局域网验证说明

当前 iOS 工程可以安装到真机并启动，但还不能完成两个 iPhone 的局域网互通验证。原因是缺少 LAN transport：

- 没有 Bonjour service discovery。
- 没有 UDP/TCP 心跳发送。
- 没有心跳接收 listener。
- 没有把收到的心跳接入 `GuardEngine` 和首页状态。

在实现这些能力之前，两台 iPhone 同 Wi-Fi 只能验证 App 启动和 UI，不能验证真实“在线/失联”状态变化。

建议后续新增：

```text
ios/GuardApp/Core/LocalNetwork/LanHeartbeatTransport.swift
ios/GuardApp/Core/LocalNetwork/LanHeartbeatTransportTests.swift
ios/GuardApp/GuardAppState.swift
```

目标路径：

```text
create signed heartbeat -> advertise/discover peer -> send heartbeat -> receive heartbeat -> verify HMAC -> update device observation -> GuardEngine evaluates state -> HomeView refreshes
```

## 常用命令

```bash
# 查看仓库状态
git status --short --branch

# Android 全量验证
./gradlew :android:app:testDebugUnitTest --no-daemon
./gradlew :android:app:assembleDebug --no-daemon

# iOS 全量验证
swiftc -typecheck $(find ios -name '*.swift' | sort)
swiftc -D SELF_TEST $(find ios -name '*.swift' | sort) -o /tmp/deviceguard-ios-selftest && /tmp/deviceguard-ios-selftest
xcodebuild -project ios/DeviceGuard.xcodeproj -scheme DeviceGuard -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

## 文档索引

- [产品与技术架构](docs/technical/architecture.md)
- [平台实现细节](docs/technical/platform-implementation.md)
- [实现细节说明](docs/implementation/implementation-details.md)
- [隐私审查](docs/implementation/privacy-review.md)
- [商店审核说明](docs/implementation/store-review-notes.md)
- [设备测试矩阵](docs/implementation/device-test-matrix.md)
- [UI 设计规范](docs/ui/ui-design-spec.md)
- [用户流程](docs/ui/user-flows.md)
- [本地看护设计规格](docs/superpowers/specs/2026-04-30-local-device-guard-design.md)
- [本地看护实施计划](docs/superpowers/plans/2026-04-30-local-device-guard-implementation.md)

## 后续路线

建议按以下顺序推进：

1. iOS 接入真实 `GuardAppState`，让添加设备流程不再是空操作。
2. iOS 实现 `LanHeartbeatTransport`，支持两台 iPhone 同局域网心跳互通。
3. Android/iOS 统一 BLE GATT characteristic 读取路径。
4. 接入真实二维码渲染和扫码。
5. 把 BLE/LAN observation 接入 `GuardEngine`，刷新首页状态。
6. 做双 iPhone、双 Android、iPhone + Android 的真机矩阵测试。
7. 在独立分支重新评估云端辅助，不影响默认本地无云端主线。

## License

当前仓库未声明开源许可证。对外发布前需要补充明确的 License。

