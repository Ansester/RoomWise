package fitcheck
import kotlin.test.*
import kotlinx.coroutines.*
import ai.koog.agents.core.tools.ToolRegistry

class ShoppingTest {
    private val listing=Listing("one",Retailer.AMAZON,"Test black office chair","https://www.amazon.ae/dp/B000000001","")
    private val source="""Test office chair
        |Price: AED 349.00
        |Product dimensions: width 62 cm; depth 64 cm; height 112 cm
        |Colour: Black
        |Armrests: Fixed
        |Model: FC-1
        |Sold by: Fixture shop
        |Availability: In stock
    """.trimMargin()
    @Test fun freshCheckoutStartsOfflineAndUsesOnlyOwnFreePlanConfiguration() {
        val empty = RuntimeConfig(environment = emptyMap(), localCredentials = emptyMap())
        assertEquals("fixture", empty.provider)
        assertEquals("openai/gpt-oss-20b", empty.model)
        assertTrue(empty.llmKey.isEmpty())
        assertTrue(empty.tavilyKey.isEmpty())
        val configured = RuntimeConfig(
            environment = mapOf("GROQ_API_KEY" to "fake-env-key", "TAVILY_API_KEY" to "fake-search-key", "FITCHECK_PROVIDER" to "groq"),
            localCredentials = mapOf("GROQ_API_KEY" to "fake-file-key", "OPENAI_API_KEY" to "ignored-old-key")
        )
        assertEquals("groq", configured.provider)
        assertEquals("fake-env-key", configured.llmKey)
        assertEquals("fake-search-key", configured.tavilyKey)
        assertEquals("fixture", RuntimeConfig(environment = mapOf("FITCHECK_PROVIDER" to "openai"), localCredentials = emptyMap()).provider)
    }
    @Test fun groqCompatibleClientUsesGroqEndpoint() {
        val settings = groqClientSettings()
        assertEquals("https://api.groq.com", settings.baseUrl)
        assertEquals("openai/v1/chat/completions", settings.chatCompletionsPath)
        assertEquals("openai/v1/responses", settings.responsesAPIPath)
    }
    @Test fun hostedPreferenceParserCannotAccessRoomsProductsOrRetailers() {
        val provider = object : RetailerProvider {
            override suspend fun search(store: Retailer, request: Preferences): List<Listing> = error("Remote parser must not search")
            override suspend fun extract(listing: Listing): String = error("Remote parser must not extract")
        }
        val local = ShoppingTools(demoRoom(), provider, {}, { _, _ -> }, { _, _ -> })
        val preferenceTools = GroqPreferenceTools(local)
        val registry = ToolRegistry { tools(preferenceTools) }
        assertEquals(1, registry.tools.size)
        assertNotNull(registry.getToolOrNull("set_preferences"))
        for (name in listOf("read_room_summary", "search_retailer_listings", "extract_listing", "check_candidate_placement", "preview_selected_candidate")) {
            assertNull(registry.getToolOrNull(name))
        }
        assertEquals("Preferences accepted", preferenceTools.set_preferences("""{"budget":400}"""))
        assertEquals(400.0, local.preferences!!.budget)
        assertTrue(local.products.isEmpty())
    }
    @Test fun extractsLabelledAssembledFactsAndSources() {
        val p=extractProduct(listing,source,Preferences(colour="black",requiredFeatures=listOf("armrests")))
        assertEquals(349.0,p.price);assertEquals(.62,p.previewSize()!!.width)
        assertContains(p.dimensions!!.source,"Product dimensions")
        assertTrue(p.features.all {it.status==EvidenceStatus.SUPPORTED})
        assertEquals("FC-1",p.variant);assertEquals("Fixture shop",p.seller)
    }
    @Test fun packageDimensionsNeverBecomeProductDimensions() {
        val p=extractProduct(listing,source.replace("Product dimensions", "Package dimensions"),Preferences())
        assertNull(p.previewSize());assertNull(parseLabelledSize("Product package dimensions: width 60 cm; depth 50 cm; height 100 cm"))
    }
    @Test fun conflictsRemainUnknown() {
        val p=extractProduct(listing,source+"\nAnother variant AED 499\nProduct dimensions: width 70 cm; depth 80 cm; height 110 cm",Preferences())
        assertNull(p.price);assertNull(p.previewSize());assertTrue(p.issues.any {"Conflicting" in it})
    }
    @Test fun missingFactsAndComfortStayUnknown() {
        val p=extractProduct(listing,"Review: most comfortable chair ever!",Preferences(preferredFeatures=listOf("comfort")))
        assertNull(p.price);assertNull(p.previewSize());assertEquals(EvidenceStatus.UNKNOWN,p.features.single().status)
    }
    @Test fun maliciousAndNonListingURLsRejected() {
        assertFalse(Retailer.AMAZON.accepts("https://amazon.ae.evil.com/dp/B000000001"))
        assertFalse(Retailer.AMAZON.accepts("https://www.amazon.ae/s?k=chairs"))
        assertFalse(Retailer.AMAZON.accepts("http://www.amazon.ae/dp/B000000001"))
        assertTrue(Retailer.AMAZON.accepts(listing.url))
        assertTrue(Retailer.NOON.accepts("https://www.noon.com/uae-en/chair/N00001/p/"))
        assertFalse(Retailer.NOON.accepts("https://www.noon.com/uae-en/privacy"))
        assertFalse(Retailer.NOON.accepts("https://www.noon.com/uae-en/product-guides"))
        assertFalse(Retailer.AMAZON.accepts("https://www.amazon.ae/dp/B000000001\n"))
        assertFalse(Retailer.AMAZON.accepts("https://www.amazon.ae\\@evil.com/dp/B000000001"))
        assertTrue(Retailer.TEMU.accepts("https://www.temu.com/chair-g-601234567890.html"))
    }
    @Test fun failedRetailerPreservesOtherResults()=runBlocking {
        val outcomes=mutableMapOf<String,StoreResult>()
        val fake=object:RetailerProvider {
            override suspend fun search(store:Retailer,request:Preferences):List<Listing> {
                if(store==Retailer.NOON) error("fixture failure")
                return listOf(listing.copy(id=store.name,retailer=store))
            }
            override suspend fun extract(listing:Listing)=source
        }
        retrieveStores(fake,Preferences()) {name,result ->outcomes[name]=result}
        assertEquals(1,outcomes["Amazon UAE"]!!.products.size)
        assertEquals(1,outcomes["Temu"]!!.products.size)
        assertEquals("Retrieval error",outcomes["Noon UAE"]!!.status)
    }
    @Test fun cancellationStopsRetrieval()=runBlocking {
        var cancelled=false
        val fake=object:RetailerProvider {
            override suspend fun search(store:Retailer,request:Preferences):List<Listing> {try {delay(10_000)} finally {cancelled=true};return emptyList()}
            override suspend fun extract(listing:Listing)=""
        }
        val job=launch {retrieveStores(fake,Preferences()) {_,_->}}
        delay(20);job.cancelAndJoin();assertTrue(cancelled)
    }
    @Test fun koogRegistryAndToolsAreBoundedAndValidated()=runBlocking {
        var count=0;var previewed=false
        val fake=object:RetailerProvider {
            override suspend fun search(store:Retailer,request:Preferences):List<Listing> {count++;return if(store==Retailer.AMAZON) listOf(listing) else emptyList()}
            override suspend fun extract(listing:Listing)=source
        }
        val tools=ShoppingTools(demoRoom(),fake,{}, {_,_->}, {_,_->previewed=true})
        val registry=ToolRegistry {tools(tools)}
        assertNotNull(registry)
        assertContains(tools.set_preferences("""{"budget":-4}"""),"Invalid")
        assertEquals("Preferences accepted",tools.set_preferences("""{"budget":400}"""))
        tools.finishRetrieval();tools.finishRetrieval();assertEquals(3,count)
        assertContains(tools.preview_selected_candidate("invented",2.0,2.0,0.0),"Dimensions missing");assertFalse(previewed)
        assertContains(tools.preview_selected_candidate("one",2.5,2.0,45.0),"footprint fits");assertTrue(previewed)
    }
}
