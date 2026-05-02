package com.deviceguard

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.deviceguard.features.home.HomeScreen
import com.deviceguard.features.pairing.AddDeviceScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var appState by remember { mutableStateOf(GuardAppState.initial(nowEpochSeconds = currentEpochSeconds())) }
            val homeState = appState.homeUiState

            when (appState.screen) {
                GuardAppScreen.Home -> HomeScreen(
                    mode = homeState.mode,
                    deviceRows = homeState.deviceRows,
                    isGuarding = homeState.isGuarding,
                    statusTitle = homeState.statusTitle,
                    statusDescription = homeState.statusDescription,
                    modeTitle = homeState.modeTitle,
                    modeHint = homeState.modeHint,
                    primaryActionTitle = homeState.primaryActionTitle,
                    onAddDevice = { appState = appState.startAddDevice(currentEpochSeconds()) },
                    onToggleGuarding = { appState = appState.toggleGuarding() },
                    onSelectMode = { selectedMode -> appState = appState.selectMode(selectedMode) }
                )
                GuardAppScreen.AddDevice -> AddDeviceScreen(
                    inviteDisplayCode = appState.activeInviteDisplayCode.orEmpty(),
                    inviteCode = appState.activeInviteCode.orEmpty(),
                    expiresInText = "5 分钟内有效",
                    pendingDeviceName = appState.pendingJoinRequest?.displayName,
                    onSimulateJoinRequest = {
                        appState = appState.simulateIncomingJoinRequest(currentEpochSeconds())
                    },
                    onApproveJoin = {
                        appState = appState.approvePendingJoin(currentEpochSeconds())
                    },
                    onRejectJoin = {
                        appState = appState.rejectPendingJoin()
                    },
                    onCancel = {
                        appState = appState.cancelAddDevice()
                    }
                )
            }
        }
    }

    private fun currentEpochSeconds(): Long = System.currentTimeMillis() / 1_000
}
