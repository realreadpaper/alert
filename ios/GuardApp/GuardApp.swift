import SwiftUI

#if !SELF_TEST
@main
struct GuardApp: App {
    @State private var mode: GuardMode = .outing
    @State private var isGuarding = true

    private let devices = [
        HomeDeviceRow(id: "iphone", name: "主力 iPhone", stateText: "在线", stateColor: GuardColor.safe),
        HomeDeviceRow(id: "android", name: "商务 Android", stateText: "在线", stateColor: GuardColor.safe),
        HomeDeviceRow(id: "backup", name: "备用机", stateText: "在线", stateColor: GuardColor.safe)
    ]

    var body: some Scene {
        WindowGroup {
            HomeView(
                mode: mode,
                deviceRows: devices,
                isGuarding: isGuarding,
                onToggleGuarding: { isGuarding.toggle() },
                onAddDevice: {},
                onSelectMode: { mode = $0 }
            )
        }
    }
}
#endif
