import SwiftUI

#if !SELF_TEST
@main
struct GuardApp: App {
    @StateObject private var appState = GuardAppState.live()

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.screen {
                case .home:
                    HomeView(
                        mode: appState.mode,
                        deviceRows: appState.deviceRows,
                        isGuarding: appState.isGuarding,
                        homeStatus: appState.homeStatus,
                        localNetworkStatus: appState.localNetworkStatus,
                        onToggleGuarding: appState.toggleGuarding,
                        onAddDevice: appState.startAddDevice,
                        onSelectMode: appState.selectMode
                    )
                case .addDevice:
                    AddDeviceView(
                        inviteCode: appState.activeInviteCode,
                        expiresInText: "邀请 5 分钟内有效，仅通过本地二维码交换",
                        onCancel: appState.cancelAddDevice
                    )
                }
            }
            .onAppear {
                appState.start()
            }
        }
    }
}
#endif
