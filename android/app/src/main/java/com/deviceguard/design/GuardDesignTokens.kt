package com.deviceguard.design

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object GuardColors {
    val Ink900 = Color(0xFF0F172A)
    val Ink700 = Color(0xFF334155)
    val Ink500 = Color(0xFF64748B)
    val Surface0 = Color(0xFFFFFFFF)
    val Surface50 = Color(0xFFFBFCFD)
    val Surface100 = Color(0xFFF4F6F8)
    val Line100 = Color(0xFFE2E8F0)
    val Line200 = Color(0xFFD6DCE5)
    val Safe = Color(0xFF0F766E)
    val Warning = Color(0xFFB45309)
    val Danger = Color(0xFF991B1B)
}

object GuardSpacing {
    val Xs = 6.dp
    val Sm = 10.dp
    val Md = 14.dp
    val Lg = 18.dp
    val Xl = 24.dp
}

@Composable
fun GuardPrimaryButton(title: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(54.dp),
        colors = ButtonDefaults.buttonColors(containerColor = GuardColors.Ink900),
        shape = RoundedCornerShape(16.dp)
    ) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun GuardSecondaryButton(title: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(52.dp),
        border = BorderStroke(1.dp, GuardColors.Line200),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = GuardColors.Ink900)
    ) {
        Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun GuardCard(modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    androidx.compose.foundation.layout.Row(
        modifier = modifier
            .fillMaxWidth()
            .background(GuardColors.Surface0, RoundedCornerShape(20.dp))
            .border(1.dp, GuardColors.Line100, RoundedCornerShape(20.dp)),
        content = content
    )
}

@Composable
fun GuardStatusDot(color: Color, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .height(8.dp)
            .background(color, RoundedCornerShape(999.dp))
    )
}
