package cl.urcalab.chao600

import android.app.role.RoleManager
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val Red = Color(0xFFDF243C)
private val RedDark = Color(0xFFFF4C5A)
private val Green = Color(0xFF2E9E5B)
private val Orange = Color(0xFFE08A00)

private val LightColors = lightColorScheme(
    primary = Red, onPrimary = Color.White,
    background = Color(0xFFFBF9F9), onBackground = Color(0xFF1C1B1B),
    surface = Color(0xFFFBF9F9), onSurface = Color(0xFF1C1B1B),
    surfaceContainer = Color.White, onSurfaceVariant = Color(0xFF6B6566),
    outlineVariant = Color(0xFFE6E0E1),
)
private val DarkColors = darkColorScheme(
    primary = RedDark, onPrimary = Color.White,
    background = Color(0xFF141112), onBackground = Color(0xFFF1EDED),
    surface = Color(0xFF141112), onSurface = Color(0xFFF1EDED),
    surfaceContainer = Color(0xFF211D1E), onSurfaceVariant = Color(0xFFAAA3A4),
    outlineVariant = Color(0xFF3A3436),
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val store = BlockStore.get(this)
        setContent {
            MaterialTheme(colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors) {
                Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    Screen(store)
                }
            }
        }
    }
}

/** Whether Chao 600 is the phone's call-screening app. Re-read whenever the app comes back to the front. */
@Composable
private fun rememberScreeningRoleHeld(): Pair<Boolean, () -> Unit> {
    val context = LocalContext.current
    val roleManager = remember { context.getSystemService(Context.ROLE_SERVICE) as RoleManager }
    fun held() = roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
        roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)

    var isHeld by remember { mutableStateOf(held()) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) isHeld = held()
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        isHeld = held()
    }
    return isHeld to {
        if (roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            launcher.launch(roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING))
        }
    }
}

@Composable
private fun Screen(store: BlockStore) {
    val config by store.config.collectAsStateWithLifecycle()
    val log by store.log.collectAsStateWithLifecycle()
    val (isHeld, requestRole) = rememberScreeningRoleHeld()
    val colors = MaterialTheme.colorScheme

    LazyColumn(
        modifier = Modifier.fillMaxSize().safeDrawingPadding(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text("Chao 600", fontSize = 32.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 8.dp))
        }
        item { StatusCard(isHeld, config, log.size, requestRole) }
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = colors.surfaceContainer),
            ) {
                PrefixRow(
                    prefix = "600",
                    detail = "Empresas con las que tienes relación: bancos, isapres, retail, cobranzas.",
                    checked = config.block600,
                    onChange = { store.setConfig(config.copy(block600 = it)) },
                )
                HorizontalDivider(color = colors.outlineVariant, modifier = Modifier.padding(horizontal = 16.dp))
                PrefixRow(
                    prefix = "809",
                    detail = "Telemarketing que no pediste.",
                    checked = config.block809,
                    onChange = { store.setConfig(config.copy(block809 = it)) },
                )
            }
        }
        item {
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Llamadas bloqueadas", fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                if (log.isNotEmpty()) TextButton(onClick = store::clearLog) { Text("Borrar registro") }
            }
        }
        if (log.isEmpty()) {
            item {
                Text(
                    "Aún no has bloqueado ninguna llamada. Cuando llegue una, aparecerá aquí.",
                    color = colors.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 8.dp),
                )
            }
        } else {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = colors.surfaceContainer),
                ) {
                    Column {
                        log.forEachIndexed { i, call ->
                            if (i > 0) HorizontalDivider(color = colors.outlineVariant, modifier = Modifier.padding(horizontal = 16.dp))
                            LogRow(call)
                        }
                    }
                }
            }
        }
        item {
            Text(
                "Todo ocurre en tu teléfono. Chao 600 no pide permisos, no ve tus contactos ni tu historial y no tiene acceso a internet. Este registro solo existe aquí.",
                color = colors.onSurfaceVariant,
                fontSize = 13.sp,
                modifier = Modifier.padding(vertical = 8.dp),
            )
        }
    }
}

@Composable
private fun StatusCard(isHeld: Boolean, config: BlockConfig, blocked: Int, requestRole: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val nothingSelected = !config.block600 && !config.block809
    val (color, title, detail) = when {
        !isHeld -> Triple(Orange, "Falta un paso", "Elige Chao 600 como app de identificación de llamadas y spam para que Android le consulte cada llamada.")
        nothingSelected -> Triple(colors.onSurfaceVariant, "Sin bloqueo", "Activa 600 u 809 para empezar.")
        else -> Triple(
            Green,
            "Protegido",
            "Bloqueando " + listOfNotNull("600".takeIf { config.block600 }, "809".takeIf { config.block809 }).joinToString(" y ") +
                if (blocked > 0) ". ${NumberFormat.getInstance(Locale("es", "CL")).format(blocked)} bloqueadas." else ".",
        )
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surfaceContainer),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.padding(top = 6.dp).size(14.dp).background(color, RoundedCornerShape(50)))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(title, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text(detail, color = colors.onSurfaceVariant, fontSize = 14.sp)
                }
            }
            if (!isHeld) {
                Button(onClick = requestRole, modifier = Modifier.fillMaxWidth()) { Text("Activar bloqueo") }
            }
        }
    }
}

@Composable
private fun PrefixRow(prefix: String, detail: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        PrefixBadge(prefix)
        Column(Modifier.weight(1f).padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("Números $prefix", fontSize = 16.sp)
            Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
        }
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(checkedTrackColor = Green, checkedThumbColor = Color.White),
        )
    }
}

@Composable
private fun PrefixBadge(prefix: String) {
    Box(Modifier.background(MaterialTheme.colorScheme.primary, RoundedCornerShape(6.dp)).padding(horizontal = 8.dp, vertical = 4.dp)) {
        Text(prefix, color = Color.White, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, fontSize = 14.sp)
    }
}

@Composable
private fun LogRow(call: BlockedCall) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        PrefixBadge(call.prefix.code)
        Text(
            formatNumber(call.number),
            fontSize = 16.sp,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.weight(1f).padding(horizontal = 12.dp),
        )
        Text(formatTime(call.timeMillis), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
    }
}

/** "+56 600 123 4567" for any of the formats Android may report. */
internal fun formatNumber(raw: String): String {
    val digits = raw.filter { it.isDigit() }.removePrefix("00").removePrefix("56")
    return when (digits.length) {
        10 -> "${digits.take(3)} ${digits.substring(3, 6)} ${digits.substring(6)}"
        9 -> "${digits.take(3)} ${digits.substring(3, 6)} ${digits.substring(6)}"
        else -> raw
    }
}

private fun formatTime(millis: Long): String {
    val now = System.currentTimeMillis()
    val pattern = if (now - millis < 20 * 60 * 60 * 1000L) "HH:mm" else "d MMM, HH:mm"
    return SimpleDateFormat(pattern, Locale("es", "CL")).format(Date(millis))
}
