# Conversational shopping and live room preview

RoomWise connects a shopping conversation, a product browser, and a phone room preview. The active RoomWise product page determines the selected chair. Changing that page updates the preview from that product's explicit assembled dimensions; there is no separate “preview this” step in the connected browsing loop.

The supported category is chairs. The model helps discuss and refine requirements; product evidence and spatial checks remain outside model output. A scaled schematic communicates size and placement, not the seller's exact design.

## Use one iPhone

1. Open RoomWise and start with the labelled sample room, import a room JSON file, or accept a RoomPlan scan on supported hardware.
2. Describe a chair, then continue the conversation. Try “a black office chair under AED 500,” followed by “make it white” and “under AED 300 instead.” **Send** updates the conversation without spending Tavily credits; **Find matches** sends a nonempty draft once before discovery; with no draft, it uses accepted preferences without a model call. The conversation retains context; review the interpreted requirements when wording is complex.
3. In sample mode, explore synthetic products without a provider account. For live discovery, enter your own Groq Free and Tavily Researcher keys in Connections, disable sample mode, and accept the provider-sharing disclosure.
4. Browse the product-page carousel. Each selected page changes the room preview immediately. Use the page controls when swiping is inconvenient.
5. Open a retailer page deliberately to inspect the current offer, variant, price, seller, and assembled dimensions. Returning to the RoomWise shortlist preserves the relationship between the active product and its preview.
6. If assembled dimensions are missing, the app withholds a size-based object preview. Use manual dimension entry from a reliable listing or your own measurements; it does not generate a plausible size from the product name or photograph.
7. Move, rotate, or recenter the object and inspect the captured-footprint result. Camera AR is optional; Simulator offers a labelled 3D rehearsal.

The conversational reply is not evidence of a product fact, current price, suitability, or physical clearance. Search results may not satisfy every preference; verify the listing.

## Browse on desktop and preview on a phone

Both apps can work independently. Pair only when you want the desktop's active shopping page to drive the phone preview.

1. Run the desktop companion with `sh scripts/run-desktop.sh` and load the sample or an imported room.
2. Connect the desktop and phone to the **same trusted local network**. A personal hotspot can be useful when a guest network blocks communication between devices.
3. Choose **Pair phone → Live phone preview → Start pairing** on desktop. It starts a temporary HTTP listener and displays a private session URL containing a random token.
4. On the phone, choose **Room actions → Pair with desktop**, paste that complete URL, and press **Connect**. Allow local-network access if iOS asks. Keep the link private: anyone who can reach that listener and holds the link can read the session's product list and change its selection.
5. Leave the phone preview visible in **Camera AR** or **Room view**. Browse to another product page on desktop. The phone polls for new session revisions about every 400 ms and replaces its selected product. Switching products on a paired phone can update the desktop selection too.
6. Use **Stop pairing** on desktop to close the listener, or **Disconnect** on the phone to stop its polling. Phone backgrounding also disconnects; three consecutive polling failures end its active connection. Starting a new session creates a new link. Do not publish a session link in screenshots, issues, or documentation.

Pairing updates do not replace the phone conversation, and you may continue chatting while paired. Pressing **Find matches** on the phone disconnects pairing first so the phone takes ownership of its local search/shortlist.

No RoomWise account, developer server, relay subscription, public tunnel, or paid API is required for pairing. The phone uses its own accepted room; pairing does not transfer a room or align the phone's AR coordinate system with the desktop's scene. If you want both views to use the same captured geometry, transfer a validated room file separately.

The session uses plain local HTTP with an unguessable bearer token. It is intended for a trusted Wi-Fi network, not public internet exposure. Do not forward its port or treat the token as encrypted transport. Pairing does not send provider keys, chat history, room coordinates, camera images, or purchases between devices.

## What “live” means

Within one app, the carousel's selection and preview use the same selected-product state. With a paired desktop, the phone periodically reads session revisions. It is a near-real-time local connection, not a frame-synchronized rendering or latency guarantee. Device sleep, backgrounding, Wi-Fi quality, firewall rules, and local-network permissions affect delivery.

The schematic changes to the active chair's known width, depth, and height. A listing without valid assembled dimensions clears the size-based preview instead of leaving the previous chair visible. Once a valid product is selected, an existing AR placement can be reused while the geometry changes. Actual plane detection and tracking require supported hardware.

## Shopping pages and retailer websites

RoomWise presents one product page per retrieved or manually entered listing, with its title, source, evidence, dimensions, and available image. Swiping those pages is what drives object selection. On iPhone, **Load retailer page** opens an ephemeral embedded website for the known listing; on desktop, **Store** opens the system browser. These visits happen only when requested.

The application does not monitor arbitrary Chrome/Safari tabs, infer which product a person is viewing elsewhere, intercept a retailer checkout, or manufacture a seller-specific 3D model. On iPhone, following another retailer page, a variant-related URL query/fragment change, or same-document navigation pauses the preview, because that navigation does not establish validated dimensions for the newly viewed item. Navigating a different item in an external browser also does not update the RoomWise selection. Add the item to RoomWise or select it from the retrieved shortlist before relying on its preview.

A retailer may block embedded browsing, require a region/cookie choice, or change its site. Open the original URL in the system browser when needed. Neither a successful page load nor a valid retailer URL independently verifies its dimensions or offer.

## Conversation and cost boundaries

The current free-provider path sends at most one Groq request per conversational turn. It includes at most twelve recent messages, bounded to 1,500 characters each, plus structured shopping preferences. It returns a reply and full validated preferences. **Send** performs this conversational step only; **Find matches** sends any nonempty draft once first; otherwise it retrieves from accepted preferences without a model call. Subsequent messages can override or remove earlier constraints.

No room or catalog content is sent to the model. Without a configured Groq key, or when its quota/output/network fails, a clearly labelled limited local fallback handles common refinements. That fallback is deterministic, not an offline LLM, and can misunderstand complex requests.

Fallback retailer search links are built from accepted preferences, rather than an unsent refinement fragment, so they retain the current shopping context.

Catalog discovery is bounded separately. A phone search reserves three basic Tavily requests against a 300-request per-installation UTC-month allowance. Page changes, AR updates, and local pairing do not call Groq or Tavily. Provider accounts still have their own rate limits and quotas. No automatic retries or paid-provider switch are used. [Full search pipeline](SHOPPING_PIPELINE.md).

## Local session protocol

The desktop owns a revisioned snapshot:

```json
{
  "schemaVersion": 1,
  "revision": 12,
  "products": [],
  "selectedProductId": null
}
```

`products` uses the shared [Product contract](../shared/src/commonMain/kotlin/fitcheck/Models.kt), including evidence and provenance. The token is part of the private pairing URL, not the JSON payload.

| Request | Behavior |
| --- | --- |
| `GET /session/<token>` | Read the current product list, selected product ID, schema version, and revision. |
| `POST /session/<token>/selection` with `{"productId":"known-id"}` | Select a product already present in the current session. Unknown IDs and malformed bodies are rejected. |

The host caps snapshots at 50 products and selection request bodies at 4 KiB. It accepts private/loopback network peers and rejects browser-origin mutation requests; the native phone client does not follow redirects that could expose its private token. The phone accepts private IPv4, loopback, or `.local` hostnames in its pairing URL. State changes increase the revision. Requests with invalid tokens, unsupported paths/methods, or oversized selection bodies are rejected. The listener does not expose filesystem access, provider credentials, arbitrary proxying, room data, or a general browser API. The session token changes when pairing restarts. See the implemented host/client and [validation record](VALIDATION.md) for exact verification coverage.

Retailers can change a variant without changing its URL. RoomWise does not inspect arbitrary page content or infer a replacement object: confirm the current variant and its measurements. The preview is tied to the saved shortlist record.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Phone cannot connect | Same network; complete current URL; desktop pairing still running; firewall allows the app; iOS local-network permission granted. |
| Guest/university network fails | Client isolation may block local device traffic. Try a trusted home network or personal hotspot. |
| Desktop shows several possible addresses | Use the address on the phone's current Wi-Fi network; VPN/virtual interfaces may not be reachable. |
| Old link stops working | Stopping/restarting pairing invalidates its session. Paste the new link. |
| Phone stops updating after sleep | Return RoomWise to the foreground, check the connection status, and reconnect if needed. |
| Product updates but no object appears | The selected listing may have unknown assembled dimensions. Add reliable measurements. |
| Schematic looks unlike the listing | It represents the dimensions of a generic chair, not a retrieved exact 3D asset. |
| Retailer page fails | Open the original URL externally; use manual evidence/dimensions if needed. |
| Chat misunderstands a refinement | Inspect the interpreted requirements and state the desired value explicitly. Local fallback supports a limited grammar. |
| Automatic discovery stops | Check your own free-provider quotas. Samples, manual products, local preview, and pairing remain available. |

The phone saves its last 40 chat messages and accepted preferences locally. Desktop keeps up to 24 chat messages in session memory. **New chat** clears active conversation context. Neither transcript is part of the pairing snapshot.

## Verification scope

The reproducible `sh scripts/check-live-pairing.sh` check runs the real desktop JVM host against the native Simulator client's default URLSession transport: receive A, POST selection B, observe host-published C with unknown size. It needs macOS, Xcode, JDK 21, and Python 3, but no provider accounts or physical device. The normal iOS suite skips that optional case without its private test endpoint; run the separate script for this boundary. See [developer instructions](DEVELOPMENT.md#real-jvm-to-native-pairing-check) and the validation record for actual results.

Automated tests can verify contextual conversation handling with mocked responses, schema/validation/fallback behavior, local protocol authorization/revisions, and preview state changes. They do not demonstrate authenticated free-provider availability, successful browsing on every retailer, two physical devices on a particular network, or camera AR tracking. The [validation record](VALIDATION.md) names completed checks and any outstanding manual acceptance.
