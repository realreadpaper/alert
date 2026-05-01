package com.deviceguard

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.deviceguard.core.guardengine.GuardMode
import com.deviceguard.design.GuardColors
import com.deviceguard.features.home.HomeDeviceRow
import com.deviceguard.features.home.HomeScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HomeScreen(
                mode = GuardMode.OUTING,
                deviceRows = listOf(
                    HomeDeviceRow("iphone", "主力 iPhone", "在线", GuardColors.Safe),
                    HomeDeviceRow("android", "商务 Android", "在线", GuardColors.Safe),
                    HomeDeviceRow("backup", "备用机", "在线", GuardColors.Safe)
                ),
                isGuarding = true,
                onToggleGuarding = {},
                onSelectMode = {}
            )
        }
    }
}
