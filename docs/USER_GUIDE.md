# User guide

RoomWise lets you keep talking about a chair you want to buy, browse product pages, and see the selected chair change in a room preview. Shared geometry also compares its assembled floor footprint with captured walls and recognized furniture. Start with the sample; no provider account, particular phone, or paid service is needed for that workflow. Installation and developer prerequisites are in [development](DEVELOPMENT.md).

## Choose a starting point

| Starting point | Use it when | What it establishes |
| --- | --- | --- |
| Sample room/chairs | Exploring or demonstrating the interface | Synthetic geometry and product examples, clearly labelled |
| Imported RoomWise JSON | You already have a compatible room file | Validated geometry with its original coordinate system |
| LiDAR room capture | A supported physical iPhone is available | A captured room candidate that you review before accepting |
| Your own chair measurements | You know the assembled dimensions | A user-entered size for local preview and fit checks |

The iPhone Simulator supports the sample and import workflows. It cannot provide a real camera/LiDAR room scan. Real AR requires supported physical hardware and camera permission; Simulator instead offers a labelled 3D rehearsal.

## iPhone workspace

The ellipsis at the top is **Room actions**. It opens scanning, sample-room loading, room-file import/export, Connections, and Help & Privacy. The workspace connects the persistent room preview, chair placement controls, ongoing shopping conversation, and product-page carousel. Choose **Camera AR** or **Room view** for the preview. Optional pairing lets a desktop product page drive the phone selection. [Detailed connected-shopping guide](LIVE_SHOPPING.md).

### Explore the sample

Swipe or step to another product page. That page becomes the selected chair and changes the size-based object automatically. The selected chair appears as a scaled schematic volume when its assembled dimensions are known. Drag it in the room, use the 10 cm movement arrows, adjust rotation, or press **Recenter**. The fit banner updates from local geometry. **Details** explains boundary or object conflicts.

A green “Fits captured geometry” result means the current rectangular footprint is inside a complete known boundary without overlap with recognized objects. It does not establish that the chair can recline, roll, pass through a doorway, or leave comfortable walking space. Always check the actual room and product before buying.

### Add or edit a chair

Press **Add chair** to enter a name and optional retailer product URL. You may leave the URL blank for a chair you already own. Supported links are full Amazon UAE, Noon UAE, or Temu product links; homepages, search URLs, and shortened or unsupported links may be rejected.

You can paste listing details for local parsing. For example:

```text
AED 349
Assembled width 62 cm; depth 64 cm; height 112 cm
Colour: black
Armrests: fixed
```

The parser needs explicit, unambiguous evidence. It will not infer assembled size from package dimensions or a photograph. You can enter width, depth, and height yourself, in centimetres. Supply all three positive dimensions up to 1,000 cm, or leave all three blank. The chair can be saved without a complete size, but a valid assembled size is needed for meaningful preview/fit checks.

Use **Edit** on an existing card to enter assembled dimensions. User-entered dimensions are labelled as such. Use **Details** to inspect evidence and uncertainty notes. Long-press a card for **Remove from shortlist**.

### Import or capture a room

Use **Room actions → Import room file** and select a compatible JSON file through Files. A malformed or incompatible file leaves the current room intact. The [format reference](ROOM_FORMAT.md) describes supported data.

For a new capture, select **Scan my room** or the scan action. On a supported LiDAR iPhone, grant camera permission, move slowly, and capture walls, openings, and furniture. Press **Finish scan** and review the candidate. A closed validated boundary can be accepted as complete. A partial room can be used for visualization with boundary fit explicitly withheld. Discard or scan again if the geometry is not useful.

The app keeps the previous accepted room while scanning/processing. Cancel or close the scan when needed. If processing takes longer than expected, the recovery controls allow you to preserve the previous room. Camera-denied messages link to Settings; unsupported hardware can still use samples and imported rooms.

### Continue the shopping conversation

Describe the chair you want, press **Send**, then refine the same request. **Send** is conversation only; use **Find matches** when ready to retrieve listings from the current preferences. For example: “black office chair under AED 500 with armrests,” “make it white,” and “under AED 300 instead.” The reply and structured preferences retain recent context. Start a new chat to begin a separate request.

Groq is optional. Sample mode and a missing/unavailable Groq key use a clearly labelled limited local fallback. It handles common refinements, not unrestricted language understanding. Review the interpreted preferences when a change is ambiguous. Assistant replies do not verify products or physical fit.

### Browse product pages

Swipe horizontally or use page controls to move through the RoomWise shortlist. The active page changes the preview immediately. Each page presents source information and available product evidence. A product with missing assembled dimensions has no size-based object until reliable measurements are entered.

Choose **Load retailer page** to inspect the current offer in an ephemeral embedded browser. Following a different retailer page, a variant-related URL query/fragment change, or same-document navigation pauses the preview until a known RoomWise product is selected again. RoomWise does not monitor arbitrary browser tabs or recognize every item reached by navigating within a retailer site. To preview a new listing, retrieve or add it to the RoomWise shortlist first. [What live browsing means](LIVE_SHOPPING.md#shopping-pages-and-retailer-websites).

### Use automatic discovery

1. Open **Room actions → Connections**.
2. Add your own Tavily free-plan key. A Groq free-plan key is optional for ongoing LLM chat; without it the limited local conversation fallback is labelled.
3. Save keys securely, turn off **Sample mode**, and send a chair request or refinement, then press **Find matches**.
4. Read and accept the Groq/Tavily sharing disclosure if you want automatic retrieval.
5. Inspect the conversational reply, interpreted preferences, and each retailer's result status.
6. Open the product page to confirm the current selected variant, price, and assembled dimensions.

This searches indexed retailer pages, not a complete Amazon catalog. Missing or ambiguous dimensions remain unknown; use **Edit** rather than treating an approximate product title as a measurement. Samples, live evidence, saved live evidence, and user-entered chairs have different labels.

Each iPhone search reserves up to three Tavily basic requests, with a separate 300-request local monthly allowance. Your provider account may reach its own quota earlier. There is no automatic paid-provider upgrade. If automatic results are unavailable, use **Browse retailer websites** and **Add chair**. [Shopping pipeline](SHOPPING_PIPELINE.md) explains the exact limits and platform differences.

### Pair a desktop preview session

On desktop, open **Pair phone → Live phone preview** and choose **Start pairing**. With both devices on trusted local Wi-Fi, choose **Room actions → Pair with desktop** on the phone, paste its complete private session URL, and press **Connect**. Product-page changes on desktop then update the phone selection; paired phone selections can update desktop too.

Paired product changes do not clear the phone conversation; you can continue chatting. Pressing **Find matches** on the phone disconnects pairing first, then searches locally from accepted preferences. Fallback retailer links also use accepted preferences so a short refinement does not lose earlier context.

The phone keeps its own room. Pairing sends only product/selection state, not room data, chat, or keys. It uses a temporary plain-HTTP listener with a random bearer token and has no hosted-service charge. Keep the URL private, do not expose its port publicly, and use **Stop pairing** or disconnect when finished. Network isolation, permissions, or sleep can interrupt updates. [Full pairing steps and troubleshooting](LIVE_SHOPPING.md).

### Save, share, and delete

The iPhone automatically saves its accepted room, query, chair list, selection, placement, mode, the last 40 chat messages, and accepted preferences locally. **New chat** clears the active transcript/preferences; desktop chat stays in session memory (up to 24 messages displayed/retained). At most twelve recent messages are sent to the model. Saved live products are labelled accordingly after relaunch. Provider keys use Keychain rather than room/session JSON.

**Export room file** creates validated room JSON for the system share sheet. This transfers room geometry only, not the current chair shortlist or API keys. Treat the exported geometry as private and choose its recipient deliberately.

**Help & Privacy** provides the policy, support contact, sharing-permission revocation, and saved-room/search deletion. Deleting planning data restores the sample workflow and leaves provider keys and the monthly request allowance separate. Clear keys in Connections. Copies you exported and data already received by providers must be managed separately.

## Desktop companion

Run the desktop entry point from the repository, then choose **Explore sample room** or **Import scan**. Desktop starts with an empty workspace rather than automatically loading the iPhone sample. Room import reads the same validated JSON contract.

Use **Shopping conversation** to send a request and follow-up messages with **Send**; **Find matches** sends a nonempty draft once first, or uses accepted preferences without a model call when the draft is empty. **New chat** resets that context. Browse product pages with Previous/Next or horizontal dragging. The active product updates the desktop projection and, while paired, the phone preview. Use placement/rotation controls for local fit checks. **Connections** offers `fixture`, `local`, and `groq` parsing modes. Sample mode performs no network retrieval. Live mode needs a personal Tavily key; `local` uses the limited local contextual fallback, while `groq` uses a personal Groq key and the pinned supported model.

Desktop currently keeps workspace state in memory and does not have the iPhone's automatic session-restoration, Keychain UI, permission-revocation sheet, or persisted 300-request monthly cap. Closing the app ends the workspace session. Your imported room file remains available for the next run. Desktop support is implemented as a companion, not a feature-identical port of every iPhone screen.

## Common outcomes

| Message/outcome | Next action |
| --- | --- |
| Boundary check incomplete | Capture/import a more complete boundary; use the preview without a wall-fit conclusion |
| Outside scanned boundary | Move or rotate the chair, or recenter it |
| Overlaps a recognized object | Move the chair and verify that the captured object's footprint is accurate |
| Dimensions unavailable | Add the assembled width, depth, and height from a reliable listing or measurement |
| No indexed listings | Try a clearer chair request or browse the retailer directly |
| Groq unavailable | Continue with the labelled limited local conversation fallback and inspect interpreted requirements |
| Paired phone is not updating | Check the current private URL, same trusted Wi-Fi, local-network permission, desktop firewall, and session status |
| Tavily key/quota failure | Check your free account or use browser/manual entry; local fit checking remains available |
| Import failed | Use a RoomWise v1 JSON file; check schema, units, coordinate string, and geometry limits |

For support, contact `info.roomwise@gmail.com`. When reporting a problem, include the app version, platform, steps, and a redacted/synthetic example. Do not send API keys or private room files by default.
