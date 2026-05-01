package com.deviceguard.features.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.deviceguard.design.GuardColors
import com.deviceguard.design.GuardSpacing

@Composable
fun SettingsScreen(rows: List<String>) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(GuardColors.Surface50)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(GuardSpacing.Xl)
    ) {
        Text("设置", color = GuardColors.Ink900, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Column(
            modifier = Modifier
                .padding(top = GuardSpacing.Lg)
                .fillMaxWidth()
                .background(GuardColors.Surface0, RoundedCornerShape(20.dp))
                .border(1.dp, GuardColors.Line100, RoundedCornerShape(20.dp))
                .padding(GuardSpacing.Md)
        ) {
            rows.forEach { row ->
                Row(
                    modifier = Modifier.fillMaxWidth().height(44.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(row, color = GuardColors.Ink900, fontSize = 16.sp, fontWeight = FontWeight.Medium)
                    Spacer(Modifier.weight(1f))
                    Text("›", color = GuardColors.Ink500, fontSize = 22.sp)
                }
            }
        }
    }
}
