package com.rcforb.android.ui.login

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.rcforb.android.services.ConnectionManagerViewModel
import com.rcforb.android.services.CredentialStore
import com.rcforb.android.ui.theme.AppColors
import com.rcforb.android.ui.theme.noRippleClickable
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(vm: ConnectionManagerViewModel) {
    val context = LocalContext.current
    var user by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var rememberMe by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        val creds = CredentialStore.load(context)
        if (creds != null) {
            user = creds.user
            password = creds.password
            rememberMe = true
        }
    }

    fun handleLogin() {
        if (user.isEmpty() || password.isEmpty()) return
        loading = true
        error = ""
        val ctx = context
        val shouldRemember = rememberMe
        val loginUser = user
        val loginPass = password
        vm.authenticate(loginUser, loginPass) { result ->
            if (result.success) {
                if (shouldRemember) {
                    CredentialStore.save(ctx, loginUser, loginPass)
                }
            } else {
                error = result.message.ifEmpty { "Login failed" }
                loading = false
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.SurfaceDark),
        contentAlignment = Alignment.Center
    ) {
        val cardShape = RoundedCornerShape(14.dp)
        Column(
            modifier = Modifier
                .widthIn(max = 384.dp)
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .shadow(20.dp, cardShape)
                .clip(cardShape)
                .background(AppColors.ChassisGradientTo)
                .border(2.dp, AppColors.BtnBorder, cardShape)
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "RCForb",
                color = AppColors.Cream,
                fontSize = AppColors.sp24,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "Remote Ham Radio Control",
                color = AppColors.CreamDark,
                fontSize = AppColors.sp13
            )
            Spacer(modifier = Modifier.height(24.dp))

            if (error.isNotEmpty()) {
                Text(
                    text = error,
                    color = AppColors.ErrorText,
                    fontSize = AppColors.sp13,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.ErrorBg, RoundedCornerShape(10.dp))
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Username
            Text("Username", color = AppColors.Cream, fontSize = AppColors.sp13)
            Spacer(modifier = Modifier.height(4.dp))
            CompactLoginField(
                value = user,
                onValueChange = { user = it },
                placeholder = "Your RemoteHams.com username",
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
            )
            Spacer(modifier = Modifier.height(16.dp))

            // Password
            Text("Password", color = AppColors.Cream, fontSize = AppColors.sp13)
            Spacer(modifier = Modifier.height(4.dp))
            CompactLoginField(
                value = password,
                onValueChange = { password = it },
                placeholder = "Password",
                isPassword = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { handleLogin() })
            )
            Spacer(modifier = Modifier.height(16.dp))

            // Remember me
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = rememberMe,
                    onCheckedChange = { rememberMe = it },
                    colors = CheckboxDefaults.colors(
                        checkedColor = AppColors.Cream,
                        checkmarkColor = AppColors.TextDark
                    )
                )
                Text("Remember me", color = AppColors.CreamDark, fontSize = AppColors.sp13)
            }
            Spacer(modifier = Modifier.height(16.dp))

            // Login button
            val loginShape = RoundedCornerShape(10.dp)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(40.dp)
                    .clip(loginShape)
                    .background(if (loading) AppColors.InputBgBottom else AppColors.CreamDark)
                    .border(2.dp, AppColors.Cream, loginShape)
                    .noRippleClickable { if (!loading) handleLogin() }
                    .let { if (loading || user.isEmpty() || password.isEmpty()) it.then(Modifier) else it },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = if (loading) "Logging in..." else "Login",
                    color = AppColors.TextDark,
                    fontSize = AppColors.sp13,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
private fun CompactLoginField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    isPassword: Boolean = false,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default
) {
    val shape = RoundedCornerShape(10.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(34.dp)
            .clip(shape)
            .background(AppColors.InputBgBottom)
            .border(1.dp, AppColors.MetalDarkBorder, shape)
            .padding(horizontal = 10.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        if (value.isEmpty()) {
            Text(placeholder, color = AppColors.LabelDim, fontSize = AppColors.sp13)
        }
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(
                color = AppColors.Cream,
                fontSize = AppColors.sp13
            ),
            visualTransformation = if (isPassword) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            cursorBrush = androidx.compose.ui.graphics.SolidColor(AppColors.Cream),
            modifier = Modifier.fillMaxWidth()
        )
    }
}
