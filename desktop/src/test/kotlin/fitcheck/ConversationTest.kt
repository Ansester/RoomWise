package fitcheck

import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import kotlin.test.*

class ConversationTest {
    private val valid = """{"reply":"I kept the mesh requirement and changed the colour. What budget works?","budget":300,"currency":"AED","colour":"white","requiredFeatures":["mesh"],"maxWidthMetres":null,"maxDepthMetres":null}"""
    private fun response(content: String = valid, status: Int = 200): ConversationResponse = ConversationResponse(status,
        buildJsonObject { putJsonArray("choices") { add(buildJsonObject { putJsonObject("message") { put("content", content) } }) } }.toString())

    @Test fun ongoingLocalRefinementsPreserveAndOverrideAcceptedPreferences() = runBlocking {
        val first = ShoppingConversation.reply(listOf(ChatMessage("user", "black mesh chair under AED 400 with armrests")))
        val second = ShoppingConversation.reply(listOf(ChatMessage("user", "make it white, under 300, no armrests")), first.preferences)
        assertEquals("white", second.preferences.colour)
        assertEquals(300.0, second.preferences.budget)
        assertContains(second.preferences.requiredFeatures, "mesh")
        assertContains(second.preferences.requiredFeatures, "without armrests")
        assertFalse("armrests" in second.preferences.requiredFeatures)
        assertContains(second.engineLabel, "no LLM")
        val third = ShoppingConversation.reply(listOf(ChatMessage("user", "remove budget and any colour")), second.preferences)
        assertNull(third.preferences.budget); assertNull(third.preferences.colour)
        assertContains(third.preferences.requiredFeatures, "mesh")
    }

    @Test fun vagueCheaperAndSmallerRequestsAskWithoutInventingLimits() = runBlocking {
        val previous = Preferences(budget = 400.0, maxWidth = .7)
        val cheaper = ShoppingConversation.reply(listOf(ChatMessage("user", "cheaper please")), previous)
        assertEquals(400.0, cheaper.preferences.budget)
        assertContains(cheaper.reply, "maximum budget")
        val smaller = ShoppingConversation.reply(listOf(ChatMessage("user", "something narrower")), previous)
        assertEquals(.7, smaller.preferences.maxWidth)
        assertContains(smaller.reply, "maximum width")
        val specified = ShoppingConversation.reply(listOf(ChatMessage("user", "maximum width 55 cm and depth 24 inches")), previous)
        assertEquals(.55, specified.preferences.maxWidth!!, 1e-9)
        assertEquals(.6096, specified.preferences.maxDepth!!, 1e-9)
        assertEquals(400.0, specified.preferences.budget)
    }

    @Test fun hostedConversationReceivesBoundedHistoryAndSnapshotExactlyOnce() = runBlocking {
        var calls = 0
        val messages = (1..20).map { ChatMessage(if (it % 2 == 0) "user" else "assistant", "turn$it " + "x".repeat(1600)) }
        val transport = ConversationTransport { key, body ->
            calls++
            assertEquals("fake-key", key)
            assertEquals("openai/gpt-oss-20b", body["model"]!!.jsonPrimitive.content)
            val wire = body["messages"]!!.jsonArray
            assertEquals(13, wire.size)
            assertTrue(wire.drop(1).all { it.jsonObject["content"]!!.jsonPrimitive.content.length <= 1500 })
            assertContains(wire[1].jsonObject["content"]!!.jsonPrimitive.content, "turn9")
            val system = wire[0].jsonObject["content"]!!.jsonPrimitive.content
            assertContains(system, "350.0"); assertContains(system, "mesh")
            assertFalse(body.toString().contains("fake-key"))
            assertFalse(body.containsKey("tools"))
            response()
        }
        val result = ShoppingConversation.reply(messages, Preferences(budget = 350.0, requiredFeatures = listOf("mesh")), "fake-key", transport = transport)
        assertEquals(1, calls); assertEquals(300.0, result.preferences.budget)
        assertEquals("white", result.preferences.colour); assertContains(result.engineLabel, "Groq")
        assertContains(result.reply, "mesh")
    }

    @Test fun quotaAndMalformedOutputUseLocalRefinementWithoutRetry() = runBlocking {
        for (bad in listOf(response(status = 429), response(valid.replace("300", "-10")), response("{}"), response(valid.replace("\"white\"", "true")))) {
            var calls = 0
            val transport = ConversationTransport { _, _ -> calls++; bad }
            val result = ShoppingConversation.reply(listOf(ChatMessage("user", "make it white")), Preferences(budget = 400.0), "fake-key", transport = transport)
            assertEquals(1, calls); assertEquals(400.0, result.preferences.budget); assertEquals("white", result.preferences.colour)
            assertContains(result.engineLabel, "Offline")
        }
    }

    @Test fun missingOrUnsupportedConnectionNeverContactsProvider() = runBlocking {
        val transport = ConversationTransport { _, _ -> error("Must remain local") }
        for (connection in listOf("" to ShoppingConversation.MODEL, "fake-key" to "unsupported")) {
            val result = ShoppingConversation.reply(listOf(ChatMessage("user", "blue chair")), groqKey = connection.first, model = connection.second, transport = transport)
            assertEquals("blue", result.preferences.colour); assertContains(result.engineLabel, "Offline")
        }
    }

    @Test fun cancellationDoesNotCreateAnAssistantFallback() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val transport = ConversationTransport { _, _ -> entered.complete(Unit); awaitCancellation() }
        var returned = false
        val job = launch { ShoppingConversation.reply(listOf(ChatMessage("user", "chair")), groqKey = "fake-key", transport = transport); returned = true }
        entered.await(); job.cancelAndJoin(); assertFalse(returned)
    }

    @Test fun emptyOrAssistantOnlyTurnIsRejected() = runBlocking {
        assertFailsWith<IllegalArgumentException> { ShoppingConversation.reply(emptyList()) }
        assertFailsWith<IllegalArgumentException> { ShoppingConversation.reply(listOf(ChatMessage("assistant", "Hello"))) }
        assertFailsWith<IllegalArgumentException> { ShoppingConversation.reply(listOf(ChatMessage("user", " "))) }
        Unit
    }
}
