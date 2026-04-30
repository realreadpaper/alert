package com.deviceguard.features.alarm

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.deviceguard.design.GuardColors
import com.deviceguard.design.GuardPrimaryButton
import com.deviceguard.design.GuardSecondaryButton
import com.deviceguard.design.GuardSpacing

@Composable
fun AlarmScreen(
    deviceName: String,
    elapsedText: String,
    isStrongAlarm: Boolean,
    onPause: () -> Unit,
    onAcknowledge: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(GuardColors.Surface50)
            .padding(GuardSpacing.Xl),
        verticalArrangement = Arrangement.spacedBy(GuardSpacing.Lg)
    ) {
        Text(if (isStrongAlarm) "ALARM" else "ATTENTION", color = GuardColors.Danger, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Text(
            if (isStrongAlarm) "设备已离开看护范围" else "设备可能离开",
            color = GuardColors.Ink900,
            fontSize = 30.sp,
            fontWeight = FontWeight.Bold
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(GuardColors.Surface0, RoundedCornerShape(20.dp))
                .border(1.dp, GuardColors.Danger.copy(alpha = 0.35f), RoundedCornerShape(20.dp))
                .padding(GuardSpacing.Lg)
        ) {
            Text("失联设备", color = GuardColors.Ink500, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text(deviceName, color = GuardColors.Ink900, fontSize = 32.sp, fontWeight = FontWeight.Black)
            Text(
                if (isStrongAlarm) "$elapsedText。正在响铃提醒。" else "$elapsedText。若仍未恢复连接，将启动响铃提醒。",
                color = GuardColors.Ink700,
                fontSize = 16.sp,
                lineHeight = 24.sp
            )
        }

        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .background(GuardColors.Danger.copy(alpha = 0.12f), RoundedCornerShape(999.dp))
        )

        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(GuardSpacing.Sm)) {
            GuardSecondaryButton("暂停 10 分钟", onPause, modifier = Modifier.weight(1f))
            GuardPrimaryButton("我知道了", onAcknowledge, modifier = Modifier.weight(1f))
        }
    }
}
