package fitcheck

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** A page selection is the single source of truth for both room previews. */
@Composable
fun ConnectedShoppingSidebar(
    messages: List<ChatMessage>, prompt: String, onPrompt: (String) -> Unit,
    searching: Boolean, sampleMode: Boolean, onMode: (Boolean) -> Unit,
    onSend: () -> Unit, onFindMatches: () -> Unit, onCancel: () -> Unit, onNewChat: () -> Unit,
    products: List<Product>, selectedId: String?, request: Preferences,
    onSelect: (Product) -> Unit, onEdit: (Product) -> Unit,
    stores: Map<String, String>, status: String, modifier: Modifier = Modifier
) {
    val green = Color(0xFF244A36)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Shopping conversation", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = green, modifier = Modifier.weight(1f))
            TextButton(onClick = onNewChat, enabled = !searching) { Text("New chat", fontSize = 11.sp) }
        }
        val scroll = rememberScrollState()
        LaunchedEffect(messages.size) { scroll.animateScrollTo(scroll.maxValue) }
        Column(
            Modifier.fillMaxWidth().heightIn(min = 50.dp, max = 145.dp)
                .background(Color(0xFFF0F3F0), RoundedCornerShape(8.dp)).verticalScroll(scroll).padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (messages.isEmpty()) Text("Tell me what chair you want, then refine it: “make it white” or “under AED 300”.", fontSize = 12.sp)
            messages.forEach { message ->
                Column {
                    Text(if (message.role == "user") "You" else "RoomWise", fontWeight = FontWeight.Bold, fontSize = 10.sp, color = green)
                    Text(message.content, fontSize = 12.sp)
                }
            }
        }
        OutlinedTextField(
            value = prompt, onValueChange = { onPrompt(it.take(1500)) }, modifier = Modifier.fillMaxWidth().testTag("shopping-message"),
            minLines = 1, maxLines = 2, enabled = !searching,
            placeholder = { Text("Describe a chair or refine your request", fontSize = 12.sp) }
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Switch(checked = sampleMode, onCheckedChange = onMode, enabled = !searching)
            Text(if (sampleMode) "Sample mode" else "Free-tier search", fontSize = 11.sp, modifier = Modifier.weight(1f))
            if (searching) TextButton(onClick = onCancel) { Text("Cancel") }
            else Button(onClick = onSend, enabled = prompt.isNotBlank(), modifier = Modifier.testTag("send-shopping-message")) { Text("Send") }
        }
        OutlinedButton(onClick = onFindMatches, enabled = !searching, modifier = Modifier.fillMaxWidth().testTag("find-shopping-matches")) { Text("Find matches") }
        val requirements = listOfNotNull(
            request.colour,
            request.budget?.let { "under ${request.currency} ${fmt(it)}" },
            request.requiredFeatures.takeIf { it.isNotEmpty() }?.joinToString(", "),
            request.maxWidth?.let { "width ≤ ${fmt(it * 100)} cm" },
            request.maxDepth?.let { "depth ≤ ${fmt(it * 100)} cm" }
        ).joinToString(" · ").ifBlank { "No specific preferences yet" }
        Text("Current request: $requirements", fontSize = 10.sp, maxLines = 2)
        if (stores.isNotEmpty()) Text(stores.entries.joinToString(" · ") { "${it.key}: ${it.value}" }, fontSize = 10.sp, maxLines = 2)
        Text(status, fontSize = 11.sp, maxLines = 2)

        if (products.isNotEmpty()) {
            val index = products.indexOfFirst { it.id == selectedId }.coerceAtLeast(0)
            val current = products[index]
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                OutlinedButton(onClick = { onSelect(products[index - 1]) }, enabled = index > 0, modifier = Modifier.testTag("previous-shopping-page")) { Text("‹ Previous", fontSize = 11.sp) }
                Text("${index + 1} / ${products.size}", fontSize = 12.sp)
                OutlinedButton(onClick = { onSelect(products[index + 1]) }, enabled = index < products.lastIndex, modifier = Modifier.testTag("next-shopping-page")) { Text("Next ›", fontSize = 11.sp) }
            }
            Text("Swipe between listings · your phone preview follows", color = green, fontSize = 11.sp)
            var drag by remember { mutableStateOf(0f) }
            Box(Modifier.weight(1f).fillMaxWidth().pointerInput(products.map { it.id }, index) {
                detectHorizontalDragGestures(
                    onDragStart = { drag = 0f },
                    onDragCancel = { drag = 0f },
                    onDragEnd = {
                        if (drag < -60 && index < products.lastIndex) onSelect(products[index + 1])
                        if (drag > 60 && index > 0) onSelect(products[index - 1])
                        drag = 0f
                    }
                ) { change, amount -> change.consume(); drag += amount }
            }) {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                    ProductCard(current, selected = true, r = request, isLowest = false,
                        select = { onSelect(current) }, manual = { onEdit(current) })
                    Text("RoomWise listing page · Open the retailer to confirm the offer. External browser navigation is not synchronized.", fontSize = 10.sp, modifier = Modifier.padding(8.dp))
                }
            }
        } else {
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Text("Your shopping pages will appear here.", fontSize = 12.sp)
            }
        }
    }
}
