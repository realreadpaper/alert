package com.deviceguard.features.pairing

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.deviceguard.design.GuardColors
import com.deviceguard.design.GuardSecondaryButton
import com.deviceguard.design.GuardSpacing

@Composable
fun AddDeviceScreen(
    inviteCode: String,
    expiresInText: String,
    onCancel: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(GuardColors.Surface50)
            .padding(GuardSpacing.Xl),
        verticalArrangement = Arrangement.spacedBy(GuardSpacing.Lg)
    ) {
        Text("ADD DEVICE", color = GuardColors.Ink500, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Text("添加设备", color = GuardColors.Ink900, fontSize = 30.sp, fontWeight = FontWeight.Bold)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(GuardColors.Surface0, RoundedCornerShape(20.dp))
                .border(1.dp, GuardColors.Line100, RoundedCornerShape(20.dp))
                .padding(GuardSpacing.Lg),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("邀请二维码", color = GuardColors.Ink700, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f)
                    .padding(vertical = GuardSpacing.Lg)
                    .border(2.dp, GuardColors.Ink900, RoundedCornerShape(18.dp)),
                contentAlignment = Alignment.Center
            ) {
                Text("QR", color = GuardColors.Ink900, fontSize = 34.sp, fontWeight = FontWeight.Black)
            }
            Text(expiresInText, color = GuardColors.Ink500, fontSize = 13.sp)
        }

        Text(
            "新手机打开 App 后选择“加入看护组”，扫描此二维码。原设备确认后才会加入。",
            color = GuardColors.Ink500,
            fontSize = 15.sp,
            lineHeight = 22.sp,
            modifier = Modifier
                .background(GuardColors.Surface100, RoundedCornerShape(16.dp))
                .padding(GuardSpacing.Md)
        )

        Text(inviteCode, color = GuardColors.Ink500, fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Spacer(Modifier.weight(1f))
        GuardSecondaryButton("取消邀请", onCancel)
    }
}
