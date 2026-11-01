package fitcheck
import androidx.compose.material3.*
import androidx.compose.ui.window.*
fun main() = application { Window(onCloseRequest = ::exitApplication, title = "RoomWise", state = rememberWindowState(width = androidx.compose.ui.unit.Dp(1360f), height = androidx.compose.ui.unit.Dp(900f))) { MaterialTheme { RoomWiseApp() } } }
