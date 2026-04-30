package com.deviceguard.features.home

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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.deviceguard.core.guardengine.GuardMode
import com.deviceguard.design.GuardColors
import com.deviceguard.design.GuardPrimaryButton
import com.deviceguard.design.GuardSpacing

data class HomeDeviceRow(
    val id: String,
    val name: String,
    val stateText: String,
    val stateColor: Color
)

@Composable
fun HomeScreen(
    mode: GuardMode,
    deviceRows: List<HomeDeviceRow>,
    isGuarding: Boolean,
    onToggleGuarding: () -> Unit,
    onSelectMode: (GuardMode) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(GuardColors.Surface50)
            .padding(GuardSpacing.Xl),
        verticalArrangement = Arrangement.spacedBy(GuardSpacing.Lg)
    ) {
        Text("PRIVATE GUARD", color = GuardColors.Ink500, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Text("看护组", color = GuardColors.Ink900, fontSize = 30.sp, fontWeight = FontWeight.Bold)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(GuardColors.Surface0, RoundedCornerShape(20.dp))
                .border(1.dp, GuardColors.Line100, RoundedCornerShape(20.dp))
                .padding(GuardSpacing.Lg)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("当前状态", color = GuardColors.Ink500, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                Text(if (isGuarding) "安全" else "未开启", color = if (isGuarding) GuardColors.Safe else GuardColors.Ink500)
            }
            Text(deviceRows.size.toString(), color = GuardColors.Ink900, fontSize = 46.sp, fontWeight = FontWeight.Black)
            Text(
                if (isGuarding) "台设备正在本地看护" else "开启后，将在设备离开时提醒你",
                color = GuardColors.Ink500,
                fontSize = 15.sp
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(GuardSpacing.Sm)) {
            ModeChip("外出", mode == GuardMode.OUTING) { onSelectMode(GuardMode.OUTING) }
            ModeChip("室内", mode == GuardMode.INDOOR) { onSelectMode(GuardMode.INDOOR) }
            ModeChip("静音", mode == GuardMode.SILENT) { onSelectMode(GuardMode.SILENT) }
        }

        Column(verticalArrangement = Arrangement.spacedBy(GuardSpacing.Sm)) {
            deviceRows.forEach { row ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .background(GuardColors.Surface0, RoundedCornerShape(16.dp))
                        .border(1.dp, GuardColors.Line100, RoundedCornerShape(16.dp))
                        .padding(horizontal = GuardSpacing.Md),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(row.name, color = GuardColors.Ink900, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    Text(row.stateText, color = row.stateColor, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        Spacer(Modifier.weight(1f))
        GuardPrimaryButton(if (isGuarding) "停止看护" else "开始看护", onToggleGuarding)
    }
}

@Composable
private fun ModeChip(title: String, selected: Boolean, onClick: () -> Unit) {
    androidx.compose.material3.Button(
        onClick = onClick,
        modifier = Modifier.weight(1f),
        colors = androidx.compose.material3.ButtonDefaults.buttonColors(
            containerColor = if (selected) GuardColors.Ink900 else GuardColors.Surface0,
            contentColor = if (selected) Color.White else GuardColors.Ink700
        ),
        shape = RoundedCornerShape(999.dp)
    ) {
        Text(title, fontWeight = FontWeight.SemiBold)
    }
}
