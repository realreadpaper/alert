# BLE 原型验证报告

## 目标

验证 iOS 与 Android 在前台、锁屏、后台条件下能否通过 BLE 完成本地看护原型所需的广播和扫描。

## 原型文件

- iOS: `ios/GuardApp/Core/Bluetooth/BlePrototype.swift`
- Android: `android/app/src/main/java/com/deviceguard/core/bluetooth/BlePrototype.kt`

## 当前环境

本轮实现创建了 BLE 原型源文件，但尚未创建完整 Xcode/Gradle 工程，也没有连接两台以上真机执行无线测试。因此本报告只记录测试方案和待采集指标，不填写真机结果。

## 测试设备矩阵

| 组合 | 设备 A | 设备 B | 目标 |
| --- | --- | --- | --- |
| iOS + iOS | iPhone 近两代系统 | iPhone 近两代系统 | 验证 CoreBluetooth 广播/扫描 |
| Android + Android | Pixel 或 Samsung | 小米、OPPO、vivo 或华为 | 验证 Android 厂商后台差异 |
| iOS + Android | iPhone | Android 主流机型 | 验证跨平台发现延迟 |

## 测试场景

| 场景 | 操作 | 采集指标 | 通过标准 |
| --- | --- | --- | --- |
| 前台 | 两台手机都打开 App | 首次发现时间、RSSI 波动 | 30 秒内稳定发现 |
| 锁屏 | 两台手机锁屏后保持看护 | 发现间隔、断连次数 | 不应频繁误判离组 |
| 后台 5 分钟 | App 进入后台 5 分钟 | 后台发现延迟 | 能恢复或保持发现 |
| 后台 30 分钟 | App 进入后台 30 分钟 | 系统限制、恢复时间 | 回到前台能立即刷新 |
| 同 Wi-Fi | 两台手机同网 | BLE 与局域网互补情况 | 局域网可降低误报 |
| 无 Wi-Fi | 仅 BLE | 丢失触发时间 | 外出模式可进入预警 |

## 记录模板

| 日期 | 平台组合 | 系统版本 | 场景 | 首次发现 | 最大中断 | 是否误报 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |

## 结论

当前阶段只能确认原型代码已覆盖 BLE 广播、扫描、发现事件和权限缺失事件。真实可靠性必须在完整 App 工程和真机环境中验证，不能用模拟器结果替代。
