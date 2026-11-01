package fitcheck

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.SemanticsProperties
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.serialization.json.*
import org.junit.Rule
import org.junit.Test

class ConnectedShopUiTest {
    @get:Rule val ui = createComposeRule()

    @Test fun shoppingPagesImmediatelyChangeRoomDimensionsAndUnknownsRemovePreview() {
        ui.setContent { Box(Modifier.size(1320.dp, 880.dp)) { RoomWiseApp() } }
        ui.onAllNodesWithText("Explore sample room").onFirst().performClick()
        ui.onAllNodesWithText("62 × 64 × 112 cm").onFirst().assertExists()
        ui.onNodeWithTag("next-shopping-page").performClick()
        ui.onAllNodesWithText("56 × 58 × 102 cm").onFirst().assertExists()
        ui.onNodeWithText("2 / 3").assertExists()
        ui.onNodeWithTag("next-shopping-page").performClick()
        ui.onNodeWithText("Dimensions unavailable. Add them to preview this chair.").assertExists()
        ui.onNodeWithTag("previous-shopping-page").performClick()
        ui.onAllNodesWithText("56 × 58 × 102 cm").onFirst().assertExists()
    }

    @Test fun multiTurnConversationRetainsMessagesAndCanResetWithoutProviderAccounts() {
        ui.setContent { Box(Modifier.size(1320.dp, 880.dp)) { RoomWiseApp() } }
        ui.onNodeWithText("New chat").performClick()
        ui.onNodeWithTag("shopping-message").performTextInput("Black chair under AED 400")
        ui.onNodeWithTag("send-shopping-message").performClick()
        ui.waitForIdle()
        ui.onNodeWithText("Black chair under AED 400").assertExists()
        ui.onNodeWithTag("shopping-message").performTextInput("Make it white under AED 300")
        ui.onNodeWithTag("send-shopping-message").performClick()
        ui.waitForIdle()
        ui.onNodeWithText("Black chair under AED 400").assertExists()
        ui.onNodeWithText("Make it white under AED 300").assertExists()
        ui.onNodeWithText("New chat").performClick()
        ui.onNodeWithText("Make it white under AED 300").assertDoesNotExist()
    }

    @Test fun pairedPhoneSelectionChangesDesktopPreview() {
        ui.setContent { Box(Modifier.size(1320.dp, 880.dp)) { RoomWiseApp() } }
        ui.onAllNodesWithText("Explore sample room").onFirst().performClick()
        ui.onNodeWithText("Pair phone").performClick()
        ui.onNodeWithText("Start pairing").performClick()
        val displayed = ui.onNode(hasText("http://", substring = true)).fetchSemanticsNode()
            .config[SemanticsProperties.Text].first().text.lineSequence().first()
        val uri = URI(displayed)
        val local = URI("http", null, "127.0.0.1", uri.port, uri.path + "/selection", null, null)
        val response = HttpClient.newHttpClient().send(
            HttpRequest.newBuilder(local).POST(HttpRequest.BodyPublishers.ofString("{\"productId\":\"fixture-b\"}")).build(),
            HttpResponse.BodyHandlers.ofString()
        )
        kotlin.test.assertEquals(200, response.statusCode())
        ui.waitForIdle()
        ui.onNodeWithText("Stop pairing").performClick()
        ui.onNodeWithText("Done").performClick()
        ui.onAllNodesWithText("56 × 58 × 102 cm").onFirst().assertExists()
        ui.onNodeWithText("2 / 3").assertExists()
    }

    @Test fun findMatchesInterpretsUnsentDraftBeforeSearchingFixtures() {
        ui.setContent { Box(Modifier.size(1320.dp, 880.dp)) { RoomWiseApp() } }
        ui.onNodeWithText("New chat").performClick()
        ui.onNodeWithTag("shopping-message").performTextInput("White chair under AED 300")
        ui.onNodeWithTag("find-shopping-matches").performClick()
        ui.waitForIdle()
        ui.onNodeWithText("White chair under AED 300").assertExists()
        ui.onNode(hasText("Current request:", substring = true) and hasText("white", substring = true) and hasText("300", substring = true)).assertExists()
        ui.onNodeWithText("No sample fixtures match these preferences. No retailer requests were made.").assertExists()
    }

    @Test fun groqConversationWorksWithoutCatalogCredentials() {
        val calls = AtomicInteger()
        val config = RuntimeConfig(environment = mapOf("FITCHECK_PROVIDER" to "groq", "GROQ_API_KEY" to "mock-key"), localCredentials = emptyMap())
        val transport = ConversationTransport { _, _ ->
            calls.incrementAndGet()
            val content = """{"reply":"Ready to refine your chair preferences.","budget":300,"currency":"AED","colour":"white","requiredFeatures":[],"maxWidthMetres":null,"maxDepthMetres":null}"""
            ConversationResponse(200, buildJsonObject {
                putJsonArray("choices") { add(buildJsonObject { putJsonObject("message") { put("content", content) } }) }
            }.toString())
        }
        ui.setContent { Box(Modifier.size(1320.dp, 880.dp)) { RoomWiseApp(config, transport) } }
        ui.onNodeWithText("New chat").performClick()
        ui.onNodeWithTag("shopping-message").performTextInput("White chair under AED 300")
        ui.onNodeWithTag("send-shopping-message").performClick()
        ui.waitForIdle()
        kotlin.test.assertEquals(1, calls.get())
        ui.onNodeWithText("Ready to refine your chair preferences.").assertExists()
        ui.onNodeWithText("Free-tier search").assertExists()
        ui.onNodeWithText("Desktop connections").assertDoesNotExist()
    }
}
