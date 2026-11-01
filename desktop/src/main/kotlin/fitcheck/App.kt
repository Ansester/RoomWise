package fitcheck

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.*
import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString
import java.awt.FileDialog
import java.awt.Frame
import java.awt.Desktop
import java.net.URI
import java.io.File
import kotlin.math.*

// Coherent, restrained design palette
private val NeutralCanvas = Color(0xFFF7F7F5)
private val SurfaceWhite = Color(0xFFFFFFFF)
private val SageSurface = Color(0xFFF0F3F0)
private val SageBorder = Color(0xFFDCE3DD)
private val Forest = Color(0xFF244A36)
private val ForestDark = Color(0xFF162E22)
private val TextPrimary = Color(0xFF18221C)
private val TextMuted = Color(0xFF5E6E64)
private val Amber = Color(0xFFBA6820)
private val AmberBg = Color(0xFFFDF7F0)
private val OpeningGold = Color(0xFFCFA043)
private val ObjectGrey = Color(0xFFBAC5BF)
private val ObjectGreyBorder = Color(0xFFA3B0A9)

fun fmt(d: Double) = "%.2f".format(d)

fun requirementFailures(p: Product, r: Preferences): Int =
    (r.requiredFeatures + listOfNotNull(r.colour)).count { name ->
        p.features.none { it.name.equals(name, true) && it.status == EvidenceStatus.SUPPORTED }
    } + (if (r.maxWidth != null && (p.previewSize()?.width ?: Double.MAX_VALUE) > r.maxWidth!!) 1 else 0) +
        (if (r.maxDepth != null && (p.previewSize()?.depth ?: Double.MAX_VALUE) > r.maxDepth!!) 1 else 0)

internal fun sampleMatchesPreferences(product: Product, request: Preferences): Boolean {
    if (budgetStatus(product, request) != EvidenceStatus.SUPPORTED) return false
    if (request.colour != null && product.features.none { it.name.equals(request.colour, true) && it.status == EvidenceStatus.SUPPORTED }) return false
    val size = product.previewSize()
    if (request.maxWidth != null && (size == null || size.width > request.maxWidth!!)) return false
    if (request.maxDepth != null && (size == null || size.depth > request.maxDepth!!)) return false
    return request.requiredFeatures.all { name ->
        if (name.equals("without armrests", true)) product.features.any { it.name.equals("armrests", true) && it.status == EvidenceStatus.UNSUPPORTED }
        else product.features.any { it.name.equals(name, true) && it.status == EvidenceStatus.SUPPORTED }
    }
}

fun featureLabel(status: EvidenceStatus): String = when (status) {
    EvidenceStatus.SUPPORTED -> "Listed"
    EvidenceStatus.UNSUPPORTED -> "Not listed"
    EvidenceStatus.UNKNOWN -> "Not verified"
}

@Composable
fun FitCheck() = RoomWiseApp()

@Composable
fun RoomWiseApp(configOverride: RuntimeConfig? = null, conversationTransport: ConversationTransport? = null) {
    val config = remember(configOverride) { configOverride ?: RuntimeConfig() }
    val chatTransport = remember(conversationTransport) { conversationTransport ?: GroqConversationTransport() }
    var room by remember { mutableStateOf<Room?>(null) }
    var products by remember { mutableStateOf(emptyList<Product>()) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var pose by remember { mutableStateOf(Pose(2.5, 2.0)) }
    var prompt by remember { mutableStateOf("Black office chair with armrests under AED 400") }
    var request by remember { mutableStateOf(Preferences()) }
    var status by remember { mutableStateOf("Import a room scan, or explore the sample room.") }

    // A fresh checkout always starts offline. Explicit local/Groq launches may opt into live search.
    var saved by remember {
        // Provider choice is explicit. Missing catalog access must not disable Groq chat.
        mutableStateOf(config.provider == "fixture")
    }

    var stores by remember { mutableStateOf(emptyMap<String, String>()) }
    val activity = remember { mutableStateListOf<String>() }
    var showActivity by remember { mutableStateOf(false) }
    var showFitDetails by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()
    var job by remember { mutableStateOf<Job?>(null) }
    var isSearching by remember { mutableStateOf(false) }

    var manualFor by remember { mutableStateOf<Product?>(null) }
    var settings by remember { mutableStateOf(false) }
    val messages = remember { mutableStateListOf<ChatMessage>() }
    var showPairing by remember { mutableStateOf(false) }
    var pairingUrls by remember { mutableStateOf(emptyList<String>()) }
    val pairing = remember {
        LivePreviewSession { id ->
            scope.launch {
                products.firstOrNull { it.id == id }?.let {
                    selectedId = id
                }
            }
        }
    }
    DisposableEffect(pairing) { onDispose { pairing.close() } }
    LaunchedEffect(products, selectedId) { pairing.publish(products, selectedId) }

    fun selectProduct(product: Product) {
        selectedId = product.id
        // Preserve the placement while browsing; replace the dimensions immediately.
        activity.add("Selected: ${product.title.take(50)}")
        if (activity.size > 40) activity.removeAt(0)
    }

    fun newChat() {
        messages.clear()
        request = Preferences()
        prompt = ""
        status = "New conversation. Describe the chair you want."
    }

    suspend fun interpretMessage(text: String): ChatTurn {
        messages.add(ChatMessage("user", text))
        while (messages.size > 24) messages.removeAt(0)
        val turn = ShoppingConversation.reply(
            messages.toList(), request,
            groqKey = if (!saved && config.provider == "groq") config.llmKey else "",
            model = config.model, transport = chatTransport
        )
        messages.add(ChatMessage("assistant", turn.reply))
        request = turn.preferences
        activity.add(turn.engineLabel)
        return turn
    }

    fun sendMessage() {
        val text = prompt.trim().take(1500)
        if (text.isEmpty() || isSearching) return
        prompt = ""
        isSearching = true
        job = scope.launch {
            try {
                val turn = interpretMessage(text)
                status = "${turn.engineLabel} · preferences updated. Choose Find matches when ready."
            } catch (error: CancellationException) {
                status = "Conversation cancelled. Shopping pages preserved."
                throw error
            } catch (_: Exception) {
                status = "Could not complete that message. Try again or use Sample mode."
            } finally {
                isSearching = false
                while (messages.size > 24) messages.removeAt(0)
                while (activity.size > 40) activity.removeAt(0)
            }
        }
    }

    fun findMatches() {
        if (isSearching) return
        val draft = prompt.trim().take(1500)
        prompt = ""
        val previousProducts = products
        val previousSelectedId = selectedId
        val previousStores = stores
        isSearching = true
        job = scope.launch {
            try {
                // Find matches accepts a draft directly, through the same one-call chat path.
                if (draft.isNotEmpty()) interpretMessage(draft)
                if (!saved && config.tavilyKey.isBlank()) {
                    settings = true
                    status = "Preferences updated. Add your free Tavily key to search, or turn on Sample mode."
                    return@launch
                }
                if (room == null) room = demoRoom()
                if (saved) {
                    products = demoProducts().filter { sampleMatchesPreferences(it, request) }
                    stores = mapOf("Amazon UAE" to "Sample fixture", "Noon UAE" to "Sample fixture", "Temu" to "Sample fixture")
                    status = if (products.isEmpty()) "No sample fixtures match these preferences. No retailer requests were made."
                        else "${products.size} matching sample shopping pages. No retailer requests were made."
                } else {
                    products = emptyList()
                    selectedId = null
                    stores = emptyMap()
                    status = "Searching retailer listings…"
                    val tools = ShoppingTools(room!!, TavilyProvider(config.tavilyKey),
                        log = { activity.add(it) },
                        onStore = { name, result ->
                            stores = stores + (name to result.status)
                            products = products.filter { it.retailer != name } + result.products
                            if (selectedId == null) selectedId = products.firstOrNull()?.id
                        },
                        onPreview = { id, position -> selectedId = id; pose = position })
                    check(tools.set_preferences(roomJson.encodeToString(request)) == "Preferences accepted")
                    tools.finishRetrieval()
                    status = "${products.size} shopping pages · swipe to change the room preview."
                }
                if (products.none { it.id == selectedId }) selectedId = products.firstOrNull()?.id
            } catch (error: CancellationException) {
                products = previousProducts
                selectedId = previousSelectedId
                stores = previousStores
                status = "Cancelled. Previous shopping pages preserved."
                throw error
            } catch (_: Exception) {
                products = previousProducts
                selectedId = previousSelectedId
                stores = previousStores
                status = "Could not complete retrieval. Previous shopping pages preserved."
            } finally {
                isSearching = false
                while (messages.size > 24) messages.removeAt(0)
                while (activity.size > 40) activity.removeAt(0)
            }
        }
    }

    val selected = products.find { it.id == selectedId }
    val dimensions = selected?.previewSize()

    fun log(s: String) {
        activity.add(s)
        if (activity.size > 40) activity.removeAt(0)
    }

    fun reset() {
        pose = room?.let { initialPlacement(it, products.find { product -> product.id == selectedId }?.previewSize()) } ?: Pose()
    }

    fun importRoomFile() {
        FileDialog(null as Frame?, "Import RoomWise room scan", FileDialog.LOAD).apply {
            file = "*.json"
            isVisible = true
            if (file != null) try {
                val f = File(directory, file)
                require(f.length() <= 5_000_000)
                room = decodeRoom(f.readText())
                reset()
                status = "Scan loaded: ${room!!.name} (${room!!.objects.size} recognized objects)"
                log("Imported room scan: ${room!!.name}")
            } catch (_: Exception) {
                status = "Import failed: invalid room scan file."
            }
            dispose()
        }
    }

    fun loadSampleRoom() {
        saved = true
        messages.clear()
        room = demoRoom()
        products = demoProducts()
        request = parseFixtureRequest(prompt)
        selectedId = products.firstOrNull()?.id
        reset()
        stores = mapOf("Amazon UAE" to "Sample fixture", "Noon UAE" to "Sample fixture", "Temu" to "Sample fixture")
        status = "Sample room loaded · 3 sample chairs"
        log("Loaded sample room and fixtures")
    }

    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Forest,
            onPrimary = Color.White,
            background = NeutralCanvas,
            surface = SurfaceWhite,
            onSurface = TextPrimary,
            surfaceVariant = SageSurface,
            outline = SageBorder
        )
    ) {
        Surface(Modifier.fillMaxSize(), color = NeutralCanvas) {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {

                // ── HEADER ──
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("RoomWise", fontSize = 21.sp, fontWeight = FontWeight.Bold, color = Forest)
                        if (room != null) {
                            Text("—", color = TextMuted, fontSize = 14.sp)
                            Text(room!!.name, color = TextPrimary, fontSize = 14.sp, fontWeight = FontWeight.Medium)
                            if (room!!.savedDemo) {
                                Box(Modifier.background(SageSurface, RoundedCornerShape(4.dp)).padding(horizontal = 6.dp, vertical = 2.dp)) {
                                    Text("Sample room", fontSize = 11.sp, color = TextMuted)
                                }
                            }
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { showPairing = true }, shape = RoundedCornerShape(6.dp)) {
                            Text(if (pairingUrls.isEmpty()) "Pair phone" else "Pair phone · On", fontSize = 12.sp)
                        }
                        OutlinedButton(
                            onClick = { settings = true },
                            enabled = !isSearching,
                            shape = RoundedCornerShape(6.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text("Connections", fontSize = 12.sp, color = Forest)
                        }

                        if (room != null) {
                            OutlinedButton(
                                onClick = { importRoomFile() },
                                enabled = !isSearching,
                                shape = RoundedCornerShape(6.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Text("Replace scan", fontSize = 12.sp, color = TextPrimary)
                            }
                            TextButton(
                                onClick = { loadSampleRoom() },
                                enabled = !isSearching,
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp)
                            ) {
                                Text("Sample room", fontSize = 12.sp, color = TextMuted)
                            }
                        } else {
                            OutlinedButton(
                                onClick = { importRoomFile() },
                                enabled = !isSearching,
                                shape = RoundedCornerShape(6.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Text("Import scan", fontSize = 12.sp, color = TextPrimary)
                            }
                            Button(
                                onClick = { loadSampleRoom() },
                                enabled = !isSearching,
                                shape = RoundedCornerShape(6.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = Forest),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Text("Explore sample room", fontSize = 12.sp)
                            }
                        }
                    }
                }

                // ── MAIN TWO-COLUMN WORKSPACE ──
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.weight(1f)) {

                    // ── LEFT: ROOM WORKSPACE (~60%) ──
                    Column(Modifier.weight(1.4f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Card(
                            Modifier.weight(1f).fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            colors = CardDefaults.cardColors(containerColor = SurfaceWhite),
                            border = BorderStroke(1.dp, SageBorder)
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                if (room != null) {
                                    RoomCanvas(room!!, dimensions, pose, { pose = it }, Modifier.weight(1f).fillMaxWidth())

                                    // Compact Legend & Scale
                                    Row(
                                        Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                                Box(Modifier.size(9.dp).background(ObjectGrey, RoundedCornerShape(2.dp)))
                                                Text("Existing furniture", fontSize = 11.sp, color = TextMuted)
                                            }
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                                Box(Modifier.size(9.dp).border(1.5.dp, Forest, RoundedCornerShape(2.dp)))
                                                Text("Selected chair", fontSize = 11.sp, color = TextMuted)
                                            }
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                                Box(Modifier.width(10.dp).height(2.5.dp).background(OpeningGold))
                                                Text("Openings", fontSize = 11.sp, color = TextMuted)
                                            }
                                        }
                                        Text("Interactive 3D · Metres", fontSize = 11.sp, color = TextMuted)
                                    }
                                } else {
                                    Box(
                                        Modifier.weight(1f).fillMaxWidth().background(SageSurface, RoundedCornerShape(8.dp)).padding(28.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                            Text("Scan on your iPhone, then share the room file to this Mac.", color = TextMuted, fontSize = 14.sp)
                                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                                Button(
                                                    onClick = { importRoomFile() },
                                                    shape = RoundedCornerShape(6.dp),
                                                    colors = ButtonDefaults.buttonColors(containerColor = Forest)
                                                ) {
                                                    Text("Import a room scan", fontSize = 13.sp)
                                                }
                                                OutlinedButton(
                                                    onClick = { loadSampleRoom() },
                                                    shape = RoundedCornerShape(6.dp)
                                                ) {
                                                    Text("Explore sample room", fontSize = 13.sp)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Selected product controls (compact)
                        Card(
                            Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            colors = CardDefaults.cardColors(containerColor = SurfaceWhite),
                            border = BorderStroke(1.dp, SageBorder)
                        ) {
                            Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                if (selected != null && room != null) {
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                        Text(selected.title, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1, modifier = Modifier.weight(1f))
                                        if (dimensions != null) {
                                            val wCm = (dimensions.width * 100).roundToInt()
                                            val dCm = (dimensions.depth * 100).roundToInt()
                                            val hCm = (dimensions.height * 100).roundToInt()
                                            Text("$wCm × $dCm × $hCm cm", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
                                        }
                                    }

                                    if (dimensions != null) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                            Text("Rotation ${(pose.yaw * 180 / PI).roundToInt()}°", modifier = Modifier.width(85.dp), fontSize = 12.sp)
                                            Slider(
                                                value = ((pose.yaw * 180 / PI).toFloat() + 360) % 360,
                                                onValueChange = { pose = pose.copy(yaw = it * PI / 180) },
                                                valueRange = 0f..359f,
                                                modifier = Modifier.weight(1f),
                                                colors = SliderDefaults.colors(
                                                    thumbColor = Forest,
                                                    activeTrackColor = Forest,
                                                    inactiveTrackColor = SageBorder
                                                )
                                            )
                                            OutlinedButton(
                                                onClick = {
                                                    val deg = (((pose.yaw * 180 / PI).roundToInt() + 90) % 360).toDouble()
                                                    pose = pose.copy(yaw = deg * PI / 180)
                                                },
                                                shape = RoundedCornerShape(6.dp),
                                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                            ) {
                                                Text("+90°", fontSize = 12.sp, color = TextPrimary)
                                            }
                                            TextButton(
                                                onClick = { reset(); log("Reset chair placement") },
                                                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
                                            ) {
                                                Text("Reset", fontSize = 12.sp, color = TextMuted)
                                            }
                                        }

                                        val check = checkPlacement(room!!, dimensions, pose)
                                        val conciseStatus = when {
                                            check.collisions.isNotEmpty() -> "Overlaps ${check.collisions.joinToString()}"
                                            !check.complete -> "Boundary not verified"
                                            check.boundary != "Inside scanned boundary" -> "Outside scanned boundary"
                                            check.fits -> "Fits captured geometry"
                                            else -> "Fit not confirmed"
                                        }

                                        Row(
                                            Modifier.fillMaxWidth().background(
                                                if (check.fits) SageSurface else AmberBg,
                                                RoundedCornerShape(6.dp)
                                            ).padding(horizontal = 10.dp, vertical = 6.dp),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Text(
                                                conciseStatus,
                                                color = if (check.fits) Forest else Amber,
                                                fontSize = 12.sp,
                                                fontWeight = FontWeight.Medium
                                            )
                                            TextButton(
                                                onClick = { showFitDetails = !showFitDetails },
                                                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                                            ) {
                                                Text(if (showFitDetails) "Hide details" else "Details", fontSize = 11.sp, color = TextMuted)
                                            }
                                        }

                                        if (showFitDetails) {
                                            Text(
                                                check.explanation(),
                                                fontSize = 11.sp,
                                                color = TextMuted,
                                                modifier = Modifier.padding(horizontal = 4.dp)
                                            )
                                        }
                                    } else {
                                        Text("Dimensions unavailable. Add them to preview this chair.", color = TextMuted, fontSize = 12.sp)
                                    }
                                } else {
                                    Text("Select a chair from the shortlist to preview its dimensions in your room.", color = TextMuted, fontSize = 12.sp)
                                }
                            }
                        }
                    }

                    ConnectedShoppingSidebar(
                        messages = messages.toList(), prompt = prompt, onPrompt = { prompt = it },
                        searching = isSearching, sampleMode = saved,
                        onMode = { saved = it; newChat() },
                        onSend = ::sendMessage, onFindMatches = ::findMatches, onCancel = { job?.cancel() }, onNewChat = ::newChat,
                        products = products, selectedId = selectedId, request = request,
                        onSelect = ::selectProduct, onEdit = { manualFor = it },
                        stores = stores, status = status,
                        modifier = Modifier.weight(1f).fillMaxHeight()
                    )
                }
            }
        }

        if (manualFor != null) {
            ManualDimensions(manualFor!!, dismiss = { manualFor = null }) { d, source ->
                val p = manualFor!!
                products = products.map { if (it.id == p.id) it.copy(dimensions = SizeEvidence(d, source, "user-provided")) else it }
                selectedId = p.id
                manualFor = null
                log("Applied user-entered dimensions")
            }
        }

        if (showPairing) {
            AlertDialog(
                onDismissRequest = { showPairing = false },
                title = { Text("Live phone preview") },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("Put this computer and iPhone on the same trusted Wi-Fi. On iPhone, open Room actions → Pair with desktop and paste the pairing link.")
                        Text("Only the shopping listings and selected item are shared. Room scans, chat and API keys stay on their device. This local HTTP link is a temporary secret; anyone with it on this network can select an item.", fontSize = 12.sp)
                        if (pairingUrls.isNotEmpty()) {
                            Text("Pairing is on. Use the address for your Wi-Fi network.", fontWeight = FontWeight.SemiBold)
                            SelectionContainer { Text(pairingUrls.joinToString("\n\n"), fontSize = 12.sp) }
                            Text("A 127.0.0.1 address works only with Simulator on this computer. A phone needs your computer’s Wi-Fi address. If pairing is blocked, allow local connections in your firewall.", fontSize = 11.sp)
                        }
                    }
                },
                confirmButton = {
                    if (pairingUrls.isEmpty()) Button(onClick = {
                        runCatching { pairing.start() }.onSuccess { pairingUrls = it }
                            .onFailure { status = "Could not start pairing. Check local network access." }
                    }) { Text("Start pairing") }
                    else Button(onClick = { pairing.close(); pairingUrls = emptyList() }) { Text("Stop pairing") }
                },
                dismissButton = { TextButton(onClick = { showPairing = false }) { Text("Done") } }
            )
        }
        if (settings) {
            ConnectionDialog(config) { settings = false }
        }
    }
}

@Composable
fun ProductCard(
    p: Product,
    selected: Boolean,
    r: Preferences,
    isLowest: Boolean,
    select: () -> Unit,
    manual: () -> Unit
) {
    Card(
        Modifier.fillMaxWidth().border(
            if (selected) 2.dp else 1.dp,
            if (selected) Forest else SageBorder,
            RoundedCornerShape(8.dp)
        ),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = SurfaceWhite)
    ) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(p.retailer, fontSize = 11.sp, color = Forest, fontWeight = FontWeight.Bold)
                Text(when (p.provenance) {
                    ProductProvenance.FIXTURE -> "Sample fixture"
                    ProductProvenance.LIVE -> "Live result"
                    ProductProvenance.SAVED_LIVE -> "Saved live result"
                    ProductProvenance.USER_ENTERED -> "User-entered details"
                }, fontSize = 10.sp, color = TextMuted)
            }

            Text(p.title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val priceVal = p.price
                val priceText = if (priceVal != null && p.currency != null) "${p.currency} ${fmt(priceVal)}"
                                else if (priceVal != null) "Price: ${fmt(priceVal)}"
                                else "Price unavailable"
                Text(priceText, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Forest)

                if (isLowest) {
                    Text("Lowest price in these results", fontSize = 10.sp, color = Forest, fontWeight = FontWeight.Medium)
                }
            }

            val d = p.previewSize()
            if (d != null) {
                val wCm = (d.width * 100).roundToInt()
                val dCm = (d.depth * 100).roundToInt()
                val hCm = (d.height * 100).roundToInt()
                Text("$wCm × $dCm × $hCm cm", fontSize = 12.sp, color = TextPrimary)
            } else {
                Text("Dimensions unavailable", fontSize = 12.sp, color = Amber)
            }

            // Plain-language features
            val reqFeatures = (r.requiredFeatures + r.preferredFeatures + listOfNotNull(r.colour)).distinct()
            if (reqFeatures.isNotEmpty()) {
                val featuresSummary = reqFeatures.joinToString(" · ") { name ->
                    val f = p.features.find { it.name.equals(name, true) }
                    val label = f?.let { featureLabel(it.status) } ?: "Not verified"
                    "$name: $label"
                }
                Text(featuresSummary, fontSize = 11.sp, color = TextMuted)
            }

            var detailsOpen by remember(p.id) { mutableStateOf(false) }

            // Action Buttons
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Button(
                    onClick = select,
                    shape = RoundedCornerShape(6.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Forest),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(if (d == null) "Add dimensions" else "Preview in room", fontSize = 11.sp)
                }

                if (d != null) {
                    OutlinedButton(
                        onClick = manual,
                        shape = RoundedCornerShape(6.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text("Edit", fontSize = 11.sp, color = TextPrimary)
                    }
                }

                TextButton(
                    onClick = { detailsOpen = !detailsOpen },
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
                ) {
                    Text(if (detailsOpen) "Hide" else "Details", fontSize = 11.sp, color = TextMuted)
                }

                Spacer(Modifier.weight(1f))

                if (!p.savedDemo) {
                    TextButton(
                        onClick = { runCatching { Desktop.getDesktop().browse(URI(p.url)) } },
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
                    ) {
                        Text("Store ↗", fontSize = 11.sp, color = Forest)
                    }
                }
            }

            if (detailsOpen) {
                Column(Modifier.background(SageSurface, RoundedCornerShape(6.dp)).padding(8.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text("Model: ${p.variant ?: "Unknown"} · Seller: ${p.seller ?: "Unknown"}", fontSize = 10.sp, color = TextMuted)
                    if (p.delivery != null) Text("Delivery: ${p.delivery}", fontSize = 10.sp, color = TextMuted)
                    if (p.issues.isNotEmpty()) Text(p.issues.joinToString(" · "), fontSize = 10.sp, color = Amber)
                    Text("Retrieved: ${p.retrievedAt}", fontSize = 9.sp, color = TextMuted)
                    val dimSource = p.dimensions?.source
                    if (!dimSource.isNullOrBlank()) Text("Dimensions source: $dimSource", fontSize = 9.sp, color = TextMuted)
                }
            }
        }
    }
}

@Composable
fun RoomCanvas(room: Room, d: Dimensions?, pose: Pose, change: (Pose) -> Unit, modifier: Modifier) {
    val textMeasurer = rememberTextMeasurer()
    val points = room.walls.flatMap(::wallEnds) + room.boundary + room.objects.flatMap { footprint(it.dimensions, it.pose) }
    val minX = (points.minOfOrNull { it.x } ?: -2.0) - .5
    val minZ = (points.minOfOrNull { it.z } ?: -2.0) - .5
    val maxX = (points.maxOfOrNull { it.x } ?: 2.0) + .5
    val maxZ = (points.maxOfOrNull { it.z } ?: 2.0) + .5
    val roomWidth = (maxX - minX).coerceAtLeast(1.0)
    val roomDepth = (maxZ - minZ).coerceAtLeast(1.0)
    val centreX = (minX + maxX) / 2
    val centreZ = (minZ + maxZ) / 2
    val maxHeight = (room.walls.map { it.dimensions.height.coerceIn(.4, 4.0) } +
        room.objects.map { it.dimensions.height.coerceIn(.1, 4.0) } + listOfNotNull(d?.height)).maxOrNull() ?: 2.6
    var scale by remember { mutableStateOf(1f) }
    var origin by remember { mutableStateOf(Offset.Zero) }
    val latestPose by rememberUpdatedState(pose)
    var dragging by remember { mutableStateOf(false) }

    Canvas(
        modifier.background(SageSurface, RoundedCornerShape(8.dp)).pointerInput(room, d) {
            detectDragGestures(
                onDragStart = { dragging = d != null },
                onDragEnd = { dragging = false }
            ) { event, delta ->
                if (dragging) {
                    event.consume()
                    val projectedX = delta.x / (scale * .72f)
                    val projectedZ = delta.y / (scale * .36f)
                    change(latestPose.copy(
                        x = latestPose.x + (projectedX + projectedZ) / 2,
                        z = latestPose.z + (projectedZ - projectedX) / 2
                    ))
                }
            }
        }
    ) {
        val projectedWidth = ((roomWidth + roomDepth) * .72).toFloat().coerceAtLeast(1f)
        val projectedHeight = ((roomWidth + roomDepth) * .36 + maxHeight * .75).toFloat().coerceAtLeast(1f)
        scale = min((size.width - 32f).coerceAtLeast(1f) / projectedWidth, (size.height - 32f).coerceAtLeast(1f) / projectedHeight)
        val floorHalfHeight = ((roomWidth + roomDepth) * .18 * scale).toFloat()
        origin = Offset(size.width / 2, 16f + (maxHeight * .75 * scale).toFloat() + floorHalfHeight)

        fun pt(p: Point, y: Double = 0.0) = origin + Offset(
            (((p.x - centreX) - (p.z - centreZ)) * scale * .72).toFloat(),
            (((p.x - centreX) + (p.z - centreZ)) * scale * .36 - y * scale * .75).toFloat()
        )
        fun path(points: List<Point>, y: Double = 0.0) = Path().apply {
            points.forEachIndexed { i, p ->
                val q = pt(p, y)
                if (i == 0) moveTo(q.x, q.y) else lineTo(q.x, q.y)
            }
            close()
        }
        fun face(points: List<Pair<Point, Double>>) = Path().apply {
            points.forEachIndexed { i, (p, y) ->
                val q = pt(p, y)
                if (i == 0) moveTo(q.x, q.y) else lineTo(q.x, q.y)
            }
            close()
        }
        fun drawBox(fp: List<Point>, height: Double, fill: Color, stroke: Color) {
            if (fp.size < 4) return
            val h = height.coerceIn(.08, 4.0)
            fp.indices.forEach { i ->
                val next = (i + 1) % fp.size
                val side = face(listOf(fp[i] to 0.0, fp[next] to 0.0, fp[next] to h, fp[i] to h))
                drawPath(side, fill.copy(alpha = .56f))
                drawPath(side, stroke.copy(alpha = .68f), style = Stroke(1f))
            }
            val top = path(fp, h)
            drawPath(top, fill.copy(alpha = .94f))
            drawPath(top, stroke, style = Stroke(1.3f))
        }

        // Background Grid (0.5m)
        for (x in floor(minX * 2).toInt()..ceil(maxX * 2).toInt()) drawLine(Color(0xFFE2E8E3), pt(Point(x / 2.0, minZ)), pt(Point(x / 2.0, maxZ)), 1f)
        for (z in floor(minZ * 2).toInt()..ceil(maxZ * 2).toInt()) drawLine(Color(0xFFE2E8E3), pt(Point(minX, z / 2.0)), pt(Point(maxX, z / 2.0)), 1f)

        // Captured walls extruded to their measured height.
        room.walls.forEach {
            val e = wallEnds(it)
            val h = it.dimensions.height.coerceIn(.4, 4.0)
            val wallFace = face(listOf(e[0] to 0.0, e[1] to 0.0, e[1] to h, e[0] to h))
            drawPath(wallFace, Forest.copy(alpha = .18f))
            drawPath(wallFace, ForestDark, style = Stroke(1.7f))
        }

        // Door/window surfaces.
        room.openings.forEach {
            val e = wallEnds(it)
            val h = it.dimensions.height.coerceIn(.4, 3.2)
            val openingFace = face(listOf(e[0] to 0.0, e[1] to 0.0, e[1] to h, e[0] to h))
            drawPath(openingFace, OpeningGold.copy(alpha = .34f))
            drawPath(openingFace, OpeningGold, style = Stroke(2f))
        }

        // Recognized furniture as dimensionally scaled 3D boxes.
        room.objects.sortedBy { it.pose.x + it.pose.z }.forEach {
            drawBox(footprint(it.dimensions, it.pose), it.dimensions.height, ObjectGrey, ObjectGreyBorder)
        }

        fun label(text: String, x: Float, y: Float) {
            drawText(textMeasurer, text, topLeft = Offset(x, y), style = TextStyle(color = Forest, fontSize = 11.sp, fontWeight = FontWeight.Normal))
        }

        // Selected candidate as a highlighted 3D volume.
        if (d != null) {
            val fp = footprint(d, pose)
            drawBox(fp, d.height, Forest.copy(alpha = .58f), Forest)

            // Direction arrow line
            val centre = pt(Point(pose.x, pose.z), d.height + .08)
            val end = pt(Point(pose.x + cos(pose.yaw) * d.width / 2, pose.z + sin(pose.yaw) * d.width / 2), d.height + .08)
            drawLine(Forest, centre, end, 2f)

            val wCm = (d.width * 100).roundToInt()
            val dCm = (d.depth * 100).roundToInt()
            val hCm = (d.height * 100).roundToInt()
            label("$wCm × $dCm × $hCm cm", centre.x - 45, centre.y - 20)
        }

        // Projected one-metre scale and explicit view label.
        val scaleStart = pt(Point(minX, maxZ))
        val scaleEnd = pt(Point(minX + 1, maxZ))
        drawLine(Forest, scaleStart, scaleEnd, 2.5f)
        label("1 m", (scaleStart.x + scaleEnd.x) / 2 - 10, (scaleStart.y + scaleEnd.y) / 2 + 6)
        label("3D ROOM PREVIEW", size.width - 118, 10f)
    }
}

@Composable
fun ManualDimensions(p: Product, dismiss: () -> Unit, save: (Dimensions, String) -> Unit) {
    var width by remember { mutableStateOf("") }
    var depth by remember { mutableStateOf("") }
    var height by remember { mutableStateOf("") }
    var source by remember { mutableStateOf("") }
    val d = runCatching {
        Dimensions(metres(width.toDouble(), "cm"), metres(depth.toDouble(), "cm"), metres(height.toDouble(), "cm"))
    }.getOrNull()?.takeIf { it.valid() }

    AlertDialog(
        onDismissRequest = dismiss,
        title = { Text("Add assembled dimensions", fontWeight = FontWeight.Bold, color = Forest) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("${p.title}\n\nEnter assembled dimensions (not package dimensions). Values will be marked 'user-provided'.", fontSize = 12.sp, color = TextMuted)
                OutlinedTextField(width, { width = it }, label = { Text("Width (cm)") }, shape = RoundedCornerShape(6.dp))
                OutlinedTextField(depth, { depth = it }, label = { Text("Depth (cm)") }, shape = RoundedCornerShape(6.dp))
                OutlinedTextField(height, { height = it }, label = { Text("Height (cm)") }, shape = RoundedCornerShape(6.dp))
                OutlinedTextField(source, { source = it.take(4000) }, label = { Text("Source notes or measurements") }, shape = RoundedCornerShape(6.dp))
            }
        },
        confirmButton = {
            Button(
                enabled = d != null && source.isNotBlank(),
                onClick = { save(d!!, source) },
                shape = RoundedCornerShape(6.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Forest)
            ) {
                Text("Use dimensions")
            }
        },
        dismissButton = {
            TextButton(onClick = dismiss) { Text("Cancel", color = TextMuted) }
        }
    )
}
