package com.deviceguard

import com.deviceguard.core.guardengine.GuardMode
import com.deviceguard.features.home.HomeDevice
import com.deviceguard.features.home.HomeUiState
import com.deviceguard.features.pairing.GuardDevice
import com.deviceguard.features.pairing.GuardGroup
import com.deviceguard.features.pairing.GuardPairingService
import com.deviceguard.features.pairing.GuardPlatform
import com.deviceguard.features.pairing.JoinRequest
import com.deviceguard.features.pairing.PairingInvite

enum class GuardAppScreen {
    Home,
    AddDevice
}

data class GuardAppState(
    val screen: GuardAppScreen,
    val group: GuardGroup,
    private val groupSecret: ByteArray,
    val mode: GuardMode,
    val isGuarding: Boolean,
    val activeInvite: PairingInvite?,
    val activeInviteDisplayCode: String?,
    val activeInviteCode: String?,
    val pendingJoinRequest: JoinRequest?,
    private val pairingService: GuardPairingService
) {
    val homeUiState: HomeUiState
        get() = HomeUiState.fromDevices(
            mode = mode,
            isGuarding = isGuarding,
            devices = group.devices.map { device ->
                HomeDevice(
                    id = device.deviceId,
                    name = device.displayName,
                    guardingStateText = "在线"
                )
            }
        )

    fun toggleGuarding(): GuardAppState = copy(isGuarding = !isGuarding)

    fun selectMode(mode: GuardMode): GuardAppState = copy(mode = mode)

    fun startAddDevice(nowEpochSeconds: Long): GuardAppState {
        val ownerDeviceId = group.devices.first().deviceId
        val invite = pairingService.createInvite(
            group = group,
            ownerDeviceId = ownerDeviceId,
            nowEpochSeconds = nowEpochSeconds
        )
        return copy(
            screen = GuardAppScreen.AddDevice,
            activeInvite = invite,
            activeInviteDisplayCode = invite.toDisplayCode(),
            activeInviteCode = pairingService.encodeInviteForQrCode(invite),
            pendingJoinRequest = null
        )
    }

    fun cancelAddDevice(): GuardAppState = copy(
        screen = GuardAppScreen.Home,
        activeInvite = null,
        activeInviteDisplayCode = null,
        activeInviteCode = null,
        pendingJoinRequest = null
    )

    fun simulateIncomingJoinRequest(nowEpochSeconds: Long): GuardAppState {
        val invite = activeInvite ?: return this
        val request = pairingService.createJoinRequest(
            invite = invite,
            deviceId = "simulated-android-${group.devices.size + 1}",
            displayName = "新手机 Android",
            platform = GuardPlatform.ANDROID,
            nowEpochSeconds = nowEpochSeconds
        )
        return copy(pendingJoinRequest = request)
    }

    fun approvePendingJoin(nowEpochSeconds: Long): GuardAppState {
        val invite = activeInvite ?: return this
        val request = pendingJoinRequest ?: return this
        val approved = pairingService.approveJoin(
            request = request,
            invite = invite,
            group = group,
            groupSecret = groupSecret,
            nowEpochSeconds = nowEpochSeconds
        )
        return copy(
            screen = GuardAppScreen.Home,
            group = approved.group,
            activeInvite = null,
            activeInviteDisplayCode = null,
            activeInviteCode = null,
            pendingJoinRequest = null
        )
    }

    fun rejectPendingJoin(): GuardAppState = copy(pendingJoinRequest = null)

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is GuardAppState) return false
        return screen == other.screen &&
            group == other.group &&
            groupSecret.contentEquals(other.groupSecret) &&
            mode == other.mode &&
            isGuarding == other.isGuarding &&
            activeInvite == other.activeInvite &&
            activeInviteDisplayCode == other.activeInviteDisplayCode &&
            activeInviteCode == other.activeInviteCode &&
            pendingJoinRequest == other.pendingJoinRequest
    }

    override fun hashCode(): Int {
        var result = screen.hashCode()
        result = 31 * result + group.hashCode()
        result = 31 * result + groupSecret.contentHashCode()
        result = 31 * result + mode.hashCode()
        result = 31 * result + isGuarding.hashCode()
        result = 31 * result + (activeInvite?.hashCode() ?: 0)
        result = 31 * result + (activeInviteDisplayCode?.hashCode() ?: 0)
        result = 31 * result + (activeInviteCode?.hashCode() ?: 0)
        result = 31 * result + (pendingJoinRequest?.hashCode() ?: 0)
        return result
    }

    companion object {
        fun initial(nowEpochSeconds: Long): GuardAppState {
            val pairingService = GuardPairingService()
            val (group, secret) = pairingService.createGroup(
                ownerDeviceId = "local-android",
                ownerDisplayName = "本机 Android",
                ownerPlatform = GuardPlatform.ANDROID,
                nowEpochSeconds = nowEpochSeconds
            )
            return GuardAppState(
                screen = GuardAppScreen.Home,
                group = group,
                groupSecret = secret,
                mode = GuardMode.OUTING,
                isGuarding = true,
                activeInvite = null,
                activeInviteDisplayCode = null,
                activeInviteCode = null,
                pendingJoinRequest = null,
                pairingService = pairingService
            )
        }

        private fun PairingInvite.toDisplayCode(): String {
            val normalized = joinToken
                .filter { it.isLetterOrDigit() }
                .uppercase()
                .padEnd(8, '0')
            return "${normalized.take(4)}-${normalized.drop(4).take(4)}"
        }
    }
}
