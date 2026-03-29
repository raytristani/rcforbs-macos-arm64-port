package com.rcforb.android.ui.lobby

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.rcforb.android.models.RemoteStation
import com.rcforb.android.services.ConnectionManagerViewModel
import com.rcforb.android.services.FavoriteStation
import com.rcforb.android.services.FavoritesStore
import com.rcforb.android.ui.components.MetalButton
import com.rcforb.android.ui.components.MetalButtonStyle
import com.rcforb.android.ui.radio.Digital7MonoFamily
import com.rcforb.android.ui.theme.AppColors
import com.rcforb.android.ui.theme.noRippleClickable
import kotlinx.coroutines.launch

@Composable
fun LobbyScreen(vm: ConnectionManagerViewModel) {
    val stations by vm.stations.collectAsState()
    var search by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var showFavorites by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var favorites by remember { mutableStateOf(FavoritesStore.load(context)) }

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
                .background(AppColors.ChassisGradientTo)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Station Lobby", color = AppColors.Cream, fontSize = AppColors.sp18, fontWeight = FontWeight.Bold)

            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(30.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.InputBg)
                    .border(1.dp, AppColors.Border, RoundedCornerShape(10.dp))
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

            MetalButton(
                title = "My Stations",
                isOn = showFavorites,
                fontSize = AppColors.sp12
            ) {
                showFavorites = !showFavorites
                if (showFavorites) favorites = FavoritesStore.load(context)
            }

            MetalButton(title = "Logout", isOn = false) { vm.logout() }
        }

        // Main content with optional favorites sidebar
        Row(modifier = Modifier.weight(1f)) {
            Column(modifier = Modifier.weight(1f).fillMaxHeight()) {
                // Column headers
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.Card)
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Station", color = AppColors.LabelMuted, fontSize = AppColors.sp10, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Radio", color = AppColors.LabelMuted, fontSize = AppColors.sp10, fontWeight = FontWeight.Bold, modifier = Modifier.width(100.dp))
                    Text("Country", color = AppColors.LabelMuted, fontSize = AppColors.sp10, fontWeight = FontWeight.Bold, modifier = Modifier.width(80.dp))
                    Text("Grid", color = AppColors.LabelMuted, fontSize = AppColors.sp10, fontWeight = FontWeight.Bold, modifier = Modifier.width(60.dp))
                    Text("Proto", color = AppColors.LabelMuted, fontSize = AppColors.sp10, fontWeight = FontWeight.Bold, modifier = Modifier.width(38.dp))
                    Spacer(modifier = Modifier.width(8.dp))
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
            } // end Column wrapping headers + list

            // Favorites sidebar
            if (showFavorites) {
                FavoritesSidebar(
                    favorites = favorites,
                    stations = stations,
                    onConnect = { fav ->
                        val station = stations.find { it.serverId == fav.serverId }
                        if (station != null) {
                            vm.connectToStation(station)
                        } else {
                            vm.connectToStation(RemoteStation(
                                serverId = fav.serverId,
                                serverName = fav.serverName,
                                description = fav.description,
                                host = fav.host,
                                port = fav.port,
                                voipPort = fav.voipPort,
                                online = true,
                                radioInUse = false,
                                radioOpen = false,
                                serverVersion = "",
                                radioModel = fav.radioModel,
                                country = "",
                                gridSquare = "",
                                latitude = 0.0,
                                longitude = 0.0,
                                userCount = 0,
                                maxUsers = 0,
                                isV7 = fav.isV7
                            ))
                        }
                    },
                    onRemove = { fav ->
                        FavoritesStore.removeFavorite(context, fav.serverId)
                        favorites = FavoritesStore.load(context)
                    }
                )
            }
        }

        // Footer
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.InputBgBottom)
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
private fun FavoritesSidebar(
    favorites: List<FavoriteStation>,
    stations: List<RemoteStation>,
    onConnect: (FavoriteStation) -> Unit,
    onRemove: (FavoriteStation) -> Unit
) {
    Column(
        modifier = Modifier
            .width(260.dp)
            .fillMaxHeight()
            .background(AppColors.DarkPanel)
            .border(width = 1.dp, color = AppColors.PanelBorder, shape = RoundedCornerShape(0.dp))
    ) {
        // Header
        Text(
            "Favorites",
            color = AppColors.Cream,
            fontSize = AppColors.sp12,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.ChassisGradientTo)
                .padding(horizontal = 8.dp, vertical = 6.dp)
        )

        if (favorites.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "No favorites yet.\nTap \u2661 while connected\nto add a station.",
                    color = AppColors.LabelDim,
                    fontSize = AppColors.sp12,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                favorites.forEach { fav ->
                    val isOnline = stations.any { it.serverId == fav.serverId && it.online }
                    FavoriteStationCard(
                        favorite = fav,
                        isOnline = isOnline,
                        onConnect = { onConnect(fav) },
                        onRemove = { onRemove(fav) }
                    )
                }
            }
        }
    }
}

@Composable
private fun FavoriteStationCard(
    favorite: FavoriteStation,
    isOnline: Boolean,
    onConnect: () -> Unit,
    onRemove: () -> Unit
) {
    val shape = RoundedCornerShape(10.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color(0xFFE8D888))
            .noRippleClickable { if (isOnline) onConnect() }
            .padding(horizontal = 8.dp, vertical = 6.dp)
    ) {
        // Station name
        Text(
            favorite.serverName,
            color = Color(0xFF553300),
            fontSize = AppColors.sp13,
            fontFamily = Digital7MonoFamily,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        // Radio model
        if (favorite.radioModel.isNotEmpty()) {
            Text(
                favorite.radioModel,
                color = Color(0xFF887744),
                fontSize = AppColors.sp10,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        // Description
        if (favorite.description.isNotEmpty()) {
            Text(
                favorite.description,
                color = Color(0xFF887744).copy(alpha = 0.7f),
                fontSize = AppColors.sp9,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Spacer(Modifier.height(4.dp))
        // Bottom row: online status + remove button
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(androidx.compose.foundation.shape.CircleShape)
                        .background(if (isOnline) AppColors.LedGreen else AppColors.LedRed)
                )
                Text(
                    if (isOnline) "Online" else "Offline",
                    color = Color(0xFF887744),
                    fontSize = AppColors.sp9
                )
            }
            Text(
                "\u2716",
                color = Color(0xFFAA6644),
                fontSize = AppColors.sp11,
                modifier = Modifier.noRippleClickable { onRemove() }.padding(2.dp)
            )
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
    val bgColor = if (isSelected) AppColors.CreamDark else Color.Transparent
    val textColor = if (isSelected) AppColors.TextDark else AppColors.Cream

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(bgColor)
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
        val badgeColor = if (station.isV7) AppColors.LedRed else AppColors.LedGreen
        Text(
            text = if (station.isV7) "V7" else "V10",
            color = AppColors.Cream,
            fontSize = AppColors.sp11,
            modifier = Modifier
                .clip(RoundedCornerShape(6.dp))
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
