package com.rcforb.android.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object AppColors {
    val Background = Color(0xFF1A1A1A)
    val ChassisGradientFrom = Color(0xFF888666)
    val ChassisGradientTo = Color(0xFF666555)
    val Cream = Color(0xFFEEECCC)
    val CreamDark = Color(0xFFCCCAAA)
    val TextDark = Color(0xFF555333)
    val LcdText = Color(0xFF3A0500)
    val LcdGlow = Color(0xFFAA6633)
    val LedGreen = Color(0xFF00CC00)
    val LedRed = Color(0xFFCC0000)
    val BtnBorder = Color(0xFFAAA999)
    val StatusActive = Color(0xFFFAED80)
    val PanelBgTop = Color(0xFF4A4A3C)
    val PanelBgBottom = Color(0xFF3A3A2E)
    val PanelBorder = Color(0xFF5A5A48)
    val MetalLightTop = Color(0xFFEEECCC)
    val MetalLightBottom = Color(0xFFCCCAAA)
    val MetalDarkTop = Color(0xFF7A7A60)
    val MetalDarkBottom = Color(0xFF5A5A48)
    val MetalDarkBorder = Color(0xFF8A8A70)
    val InputBgTop = Color(0xFF555444)
    val InputBgBottom = Color(0xFF444333)
    val LabelDim = Color(0xFF888870)
    val LabelMuted = Color(0xFF999980)
    val LabelSubtle = Color(0xFFAAA999)
    val ErrorBg = Color(0xCC7F1D1D.toInt())
    val ErrorText = Color(0xFFFCA5A5)
    val ErrorDismiss = Color(0xFFF87171)
    val SurfaceDark = Color(0xFF2A2A2A)
    val ChatBg = Color(0xFF2A2A2A)
    val DarkPanel = Color(0xFF33332A)

    val dp2 = 2.dp
    val dp4 = 4.dp
    val dp6 = 6.dp
    val dp8 = 8.dp
    val dp12 = 12.dp
    val dp16 = 16.dp
    val dp24 = 24.dp
    val dp32 = 32.dp

    val sp9 = 9.sp
    val sp10 = 10.sp
    val sp11 = 11.sp
    val sp12 = 12.sp
    val sp13 = 13.sp
    val sp18 = 18.sp
    val sp24 = 24.sp
    val sp38 = 38.sp
}

fun hexColor(hex: String): Color {
    val clean = hex.removePrefix("#")
    return Color(android.graphics.Color.parseColor("#$clean"))
}
