import Foundation

enum GuardPermissionKind: String, Equatable, CaseIterable {
    case bluetooth
    case notification
    case localNetwork
    case backgroundRefresh
}

enum GuardPermissionStatus: String, Equatable {
    case granted
    case denied
    case notDetermined
    case restricted
}

struct GuardPermissionSnapshot: Equatable {
    var bluetooth: GuardPermissionStatus
    var notification: GuardPermissionStatus
    var localNetwork: GuardPermissionStatus
    var backgroundRefresh: GuardPermissionStatus
}

struct PermissionIssue: Equatable {
    let kind: GuardPermissionKind
    let title: String
    let message: String
    let primaryActionTitle: String
    let degradedState: DeviceState?
}

final class PermissionGuide {
    func mostImportantIssue(from snapshot: GuardPermissionSnapshot) -> PermissionIssue? {
        if snapshot.bluetooth != .granted {
            return PermissionIssue(
                kind: .bluetooth,
                title: "需要开启蓝牙",
                message: "用于发现看护组内手机是否仍在身边。",
                primaryActionTitle: "去开启",
                degradedState: .permissionLimited
            )
        }

        if snapshot.notification != .granted {
            return PermissionIssue(
                kind: .notification,
                title: "需要开启通知",
                message: "设备可能离开时，通知用于及时提醒你。",
                primaryActionTitle: "去开启",
                degradedState: nil
            )
        }

        if snapshot.localNetwork != .granted {
            return PermissionIssue(
                kind: .localNetwork,
                title: "建议开启本地网络",
                message: "同一 Wi-Fi 下可减少室内误报；不开启时仍可使用蓝牙看护。",
                primaryActionTitle: "去开启",
                degradedState: nil
            )
        }

        if snapshot.backgroundRefresh != .granted {
            return PermissionIssue(
                kind: .backgroundRefresh,
                title: "后台看护可能受限",
                message: "系统限制后台刷新时，回到 App 后会立即更新状态。",
                primaryActionTitle: "查看设置",
                degradedState: nil
            )
        }

        return nil
    }

    func canStartCoreGuarding(snapshot: GuardPermissionSnapshot) -> Bool {
        snapshot.bluetooth == .granted
    }
}
