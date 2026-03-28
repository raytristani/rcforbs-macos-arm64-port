package com.rcforb.android.ui.lobby

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.rcforb.android.models.RemoteStation
import com.rcforb.android.services.ConnectionManagerViewModel
import com.rcforb.android.ui.components.MetalButton
import com.rcforb.android.ui.components.MetalButtonStyle
import com.rcforb.android.ui.theme.AppColors
import com.rcforb.android.ui.theme.noRippleClickable
import kotlinx.coroutines.launch

@Composable
fun LobbyScreen(vm: ConnectionManagerViewModel) {
    val stations by vm.stations.collectAsState()
    var search by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val filtered = if (search.isEmpty()) stations else {
        val q = search.lowercase()
        stations.filter {
            it.serverName.lowercase().contains(q) ||
            it.radioModel.lowercase().contains(q) ||
            it.country.lowercase().contains(q) ||
            it.gridSquare.lowercase().contains(q) ||
            it.description.lowercase().contains(q)
        }
    }

    LaunchedEffect(Unit) {
        loading = true
        vm.refreshLobby()
        loading = false
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.SurfaceDark)) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Brush.verticalGradient(listOf(AppColors.ChassisGradientFrom, AppColors.ChassisGradientTo)))
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Station Lobby", color = AppColors.Cream, fontSize = AppColors.sp18, fontWeight = FontWeight.Bold)

            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(30.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Brush.verticalGradient(listOf(AppColors.InputBgTop, AppColors.InputBgBottom)))
                    .border(1.dp, AppColors.MetalDarkBorder, RoundedCornerShape(4.dp))
                    .padding(horizontal = 8.dp),
                contentAlignment = Alignment.CenterStart
            ) {
                if (search.isEmpty()) {
                    Text("Search stations...", color = AppColors.LabelDim, fontSize = AppColors.sp12)
                }
                BasicTextField(
                    value = search,
                    onValueChange = { search = it },
                    singleLine = true,
                    textStyle = androidx.compose.ui.text.TextStyle(
                        color = AppColors.Cream,
                        fontSize = AppColors.sp12
                    ),
                    cursorBrush = androidx.compose.ui.graphics.SolidColor(AppColors.Cream),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            MetalButton(
                title = if (loading) "Loading..." else "Refresh",
                isOn = false,
                style = MetalButtonStyle.LIGHT
            ) {
                scope.launch {
                    loading = true
                    vm.refreshLobby()
                    loading = false
                }
            }

            MetalButton(title = "Logout", isOn = false) { vm.logout() }
        }

        // Station list
        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth()
        ) {
            items(filtered, key = { it.serverId }) { station ->
                StationRow(
                    station = station,
                    isSelected = selectedId == station.serverId,
                    onSelect = { selectedId = station.serverId },
                    onConnect = { vm.connectToStation(station) }
                )
            }

            if (filtered.isEmpty() && !loading) {
                item {
                    Box(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = if (stations.isEmpty()) "No stations online" else "No matching stations",
                            color = AppColors.LabelSubtle.copy(alpha = 0.5f)
                        )
                    }
                }
            }
        }

        // Footer
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Brush.verticalGradient(listOf(AppColors.InputBgTop, AppColors.InputBgBottom)))
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                "${filtered.size} station${if (filtered.size != 1) "s" else ""} online",
                color = AppColors.LabelSubtle,
                fontSize = AppColors.sp11
            )
            Text("Tap a station to connect", color = AppColors.LabelSubtle, fontSize = AppColors.sp11)
        }
    }
}

@Composable
private fun StationRow(
    station: RemoteStation,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onConnect: () -> Unit
) {
    val bg = if (isSelected) {
        Brush.verticalGradient(listOf(AppColors.Cream, AppColors.CreamDark))
    } else {
        Brush.verticalGradient(listOf(Color.Transparent, Color.Transparent))
    }
    val textColor = if (isSelected) AppColors.TextDark else AppColors.Cream

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(bg)
            .noRippleClickable { onSelect() }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(station.serverName, color = textColor, fontSize = AppColors.sp13, fontWeight = FontWeight.Medium)
            if (station.description.isNotEmpty()) {
                Text(
                    station.description,
                    color = textColor.copy(alpha = 0.6f),
                    fontSize = AppColors.sp11,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        Spacer(modifier = Modifier.width(8.dp))
        Text(station.radioModel, color = textColor, fontSize = AppColors.sp12, modifier = Modifier.width(100.dp))
        Text(station.country, color = textColor, fontSize = AppColors.sp12, modifier = Modifier.width(80.dp))
        Text(station.gridSquare, color = textColor, fontSize = AppColors.sp12, modifier = Modifier.width(60.dp))

        // Protocol badge
        val badgeColor = if (station.isV7) Color(0xFF884444) else Color(0xFF448844)
        Text(
            text = if (station.isV7) "V7" else "V10",
            color = AppColors.Cream,
            fontSize = AppColors.sp11,
            modifier = Modifier
                .clip(RoundedCornerShape(4.dp))
                .background(badgeColor)
                .padding(horizontal = 8.dp, vertical = 2.dp)
        )

        Spacer(modifier = Modifier.width(8.dp))

        // Connect button (replaces double-click)
        if (isSelected) {
            MetalButton(title = "Connect", isOn = false, style = MetalButtonStyle.LIGHT) {
                onConnect()
            }
        }
    }
}
