package com.rcforb.android.ui.theme

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed

private val DarkColorScheme = darkColorScheme(
    primary = AppColors.Cream,
    secondary = AppColors.CreamDark,
    background = AppColors.Background,
    surface = AppColors.SurfaceDark,
    onPrimary = AppColors.TextDark,
    onSecondary = AppColors.TextDark,
    onBackground = AppColors.Cream,
    onSurface = AppColors.Cream,
)

@Composable
fun RCForbTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}

fun Modifier.noRippleClickable(onClick: () -> Unit): Modifier = composed {
    clickable(
        indication = null,
        interactionSource = remember { MutableInteractionSource() },
        onClick = onClick
    )
}
