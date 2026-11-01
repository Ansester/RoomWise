# RoomWise — optional future iPhone App Store handoff

RoomWise can be used locally without App Store publication or paid model/search services. Simulator sample planning needs no Apple Developer Program enrollment or provider account. This packet is only for a future decision to publish; it does not record a submitted app, signed archive, hardware acceptance, or App Store approval. See [DEVICE_ACCEPTANCE.md](DEVICE_ACCEPTANCE.md) and [VALIDATION.md](VALIDATION.md) for verification boundaries.

## Details needed only if publishing later

- The Apple Developer Program account that owns or can register `dev.fitcheck.prototype`. Confirm that the preserved project team is the intended distribution account before signing.
- The publisher's actual legal/copyright name and App Review contact name/telephone number. Public support email: `info.roomwise@gmail.com`.
- Public HTTPS support and privacy-policy URLs. Finished static pages are in `docs/store-site/`; [PRIVACY.md](PRIVACY.md) contains the policy text. Nothing has been hosted.
- Final app pricing and regional availability choices. Each clone can use its own Groq free-plan key and Tavily Researcher free-tier key. Hosted conversation is independent of the device running this clone.

Apple requires a privacy-policy URL for iOS apps and a support URL leading to actual contact information. [Privacy setup](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [platform version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).

## Free search setup

Hosted shopping conversation uses a personal Groq free-plan key with the default `openai/gpt-oss-20b` model. That is a model served by Groq, not a connection to the OpenAI API. Exact free-plan limits depend on the Groq organization; its current free table includes this model. [Groq rate limits, checked November 1, 2026](https://console.groq.com/docs/rate-limits).

Automatic retailer discovery requires a personal Tavily key. Choose Tavily's **Researcher** free plan, with no payment card or paid upgrade. Tavily currently advertises 1,000 credits monthly and stops free requests when exhausted. RoomWise uses basic search only, up to three requests per search, with a local 300-request monthly limit per installation. It does not use extract, advanced search, automatic retries, or a paid fallback. The provider account's actual remaining quota can be lower if it is used elsewhere. If the key is absent, quota is exhausted, or retrieval fails, browser search links and manual chair entry remain available. [Tavily pricing, checked November 1, 2026](https://www.tavily.com/pricing).

The app cannot change the user's provider plan or determine charges configured elsewhere. Use the free account configuration described above. Do not promise exhaustive Amazon, Noon, or Temu catalogue access: search discovery can return incomplete coverage and uncertain product facts.

## Paste-ready product metadata

| Field | Text |
| --- | --- |
| Name | RoomWise |
| Subtitle | Chat. Browse. See it at home. |
| Primary category | Lifestyle |
| Secondary category | Shopping |
| Primary language | English |
| Initial version | 1.0.0 |
| Keywords | chair,room,lidar,floorplan,interior,ar,furniture,layout,dimensions,space,planning |

The name is subject to App Store availability. Category choices are recommendations to confirm when creating the app record.

**Promotional text**

```text
Talk about a chair, browse the options, and see the selected item in your room. Use personal free-tier accounts or explore samples; pair desktop browsing locally.
```

**Description**

```text
Talk about what you want to buy. Browse the options. See each one in your room.

RoomWise connects an ongoing chair-shopping conversation to product pages and a changing room preview on your iPhone. No RoomWise account or paid model is required.

CHAT AND REFINE
Describe a chair, then keep talking: change colour, budget, features, or size limits. Send updates the conversation using your optional personal Groq Free key; a clearly labelled limited local fallback remains available. Find matches sends a nonempty draft once before searching; with no draft, it uses accepted preferences without a model call.

BROWSE AND PREVIEW
Swipe between RoomWise product pages and the selected item changes in the room preview. Load a known retailer page explicitly to inspect the offer. Following another retailer page, a variant-related URL query/fragment change, or same-document navigation pauses the preview until a known product is selected again. The object is a schematic chair scaled to explicit assembled dimensions, not the seller's exact 3D design. Unknown dimensions stay unknown; enter reliable measurements to enable a size-based preview.

PAIR DESKTOP BROWSING
An optional desktop companion can drive the phone's product selection over trusted local Wi-Fi. Pair using a temporary private link and stop when finished. No hosted relay or subscription is needed. Pairing uses local HTTP and transfers products/selection only, not room geometry, chat, or keys. Keep its link private and do not expose the port publicly.

SCAN AND CHECK
Use Apple RoomPlan on a supported LiDAR iPhone, import a RoomWise room file, or explore the sample. Move, rotate, and recenter the chair; shared geometry checks captured floor footprints. Partial scans withhold boundary confirmation. Physical AR is available on supported hardware; Simulator offers a labelled rehearsal.

FREE-TIER DISCOVERY
Optional automatic discovery uses a personal Tavily Researcher free key. Requests use basic search, bounded calls, and a local monthly allowance, with no extra page extraction, automatic retries, or paid-provider fallback. Search covers indexed retailer pages rather than a complete catalog. Samples, manual chair entry, and direct retailer links remain available when a key or quota is unavailable.

EVIDENCE AND PRIVACY
Sample, live, saved-live, and user-entered data have distinct labels. Listing facts may be incomplete. Footprint checks do not assess hidden obstacles, overhead clearance, movement, door swings, or delivery routes. Confirm the actual product and room before buying.

Room, product, placement, and up to 40 recent chat messages/preferences are saved locally and may be included in device backups. With permission, Groq receives bounded chat/preferences and Tavily receives search requirements; neither receives room geometry or camera images. Keys use device Keychain. Delete planning data and clear keys separately. External retailer websites have their own policies. No advertising, analytics SDK, developer-operated account service, or OpenAI API connection is included.

Requires iOS 17 or later. Scanning requires a LiDAR-equipped iPhone; physical AR requires supported hardware/camera access. Provider free-plan quotas and terms apply.
```

**Copyright**

```text
2026 [ACTUAL RIGHTS HOLDER]
```

## App Privacy responses

Use these conservative responses, matching `iosApp/PrivacyInfo.xcprivacy`. Optional conversation and automatic search are part of the app's functionality; do not select “Data Not Collected” because offline use is possible. Confirm final provider terms and archive behavior before submitting. Apple explains collection, linkage, and optional disclosure in [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/).

| Question/data | Prepared response | Implementation basis |
| --- | --- | --- |
| Do you or third-party partners collect data from this app? | Yes | Optional requests go directly to Groq/Tavily; their account/retention terms apply. |
| Search History | Collected; App Functionality; linked to user; not tracking | Bounded shopping conversation/preferences sent to Groq; search requirements sent to Tavily. No room geometry/summary is transmitted. |
| Other User Content | Collected; App Functionality; linked to user; not tracking | Freeform shopping conversation sent to Groq. Declared in the current privacy manifest; confirm the corresponding App Store form at submission. |
| User ID | Collected; App Functionality; linked to user; not tracking | Personal keys authenticate to their respective Groq/Tavily accounts. No RoomWise account service. |
| Data used for tracking | No | No advertising, cross-app tracking, or analytics SDK. |
| Room geometry and camera photos | Not sent to hosted providers by this app | Local scan/fit processing; model sees bounded shopping conversation/preferences only; no saved/uploaded camera photos. User-selected exports and external links are explained in the policy. |
| Required reason API | UserDefaults, CA92.1 | Saved rooms/products/placement/preferences and local quota accounting accessible only to the app. |

Linkage is conservative because requests use an identifiable provider account. The bundled manifest and App Store questionnaire are separate steps. App Privacy must change if additional remote features or telemetry are added.

Historical prototypes embedded OpenAI/Tavily demo keys. Current iOS builds generate a nil-only compatibility stub in every configuration. If historical keys were used/shared, revoke/rotate them at the providers; current-source removal does not purge Git history or revoke credentials. No OpenAI key is offered in the current iPhone interface.

## Paste-ready App Review notes

```text
RoomWise is an iPhone conversational chair-shopping prototype. No RoomWise account or paid model is required.

1. Launch into the labelled sample room/chairs. Use Send for a request and follow-up refinements; sample mode uses the labelled limited local fallback without network calls. New chat resets context.
2. Use Find matches to retrieve from accepted preferences separately from chat. Live discovery needs a personal Tavily free key; Groq Free is optional for contextual LLM replies. Model openai/gpt-oss-20b is served by Groq, not OpenAI. The sharing disclosure covers bounded chat/preferences and search requirements, not room/camera data.
3. Swipe product pages or use Previous/Next. The selected product changes the room object immediately. Known assembled dimensions are required; Edit allows user-entered measurements. The schematic is not the exact retailer model.
4. Load retailer page opens an ephemeral embedded page explicitly. Following another page, a variant-related URL query/fragment change, or same-document navigation pauses preview rather than implying that the newly viewed item has verified dimensions. External browser navigation is not monitored.
5. Choose Camera AR on supported hardware, detect a surface, and tap to place. Switch products while the preview remains visible; the schematic updates while a usable placement is retained. Simulator uses a labelled rehearsal.
6. Optional Pair with desktop accepts a temporary private local HTTP URL from the companion. A trusted same-network session transmits product/selection state only. Stop/disconnect invalidates the session; no hosted account/server is required.
7. Room actions include scan/review/accept on LiDAR hardware, import/export, Connections, and Help & Privacy. Partial captures withhold complete-boundary confirmation. Keys are saved/cleared separately through Connections.
8. Local planning deletion clears saved room, search, products, placement, chat, and preferences. Provider keys and the local quota record remain separate. Support: info.roomwise@gmail.com.

Conversation is bounded to twelve recent messages at 1,500 characters each per model turn; up to 40 recent messages/preferences are saved locally. Send makes at most one Groq call; Find matches makes at most three basic Tavily calls and uses a local 300-request UTC-month allowance. No automatic retries, advanced/extract requests, or paid-provider switch occur. Changing pages and pairing make no hosted-provider calls.

RoomWise has no developer account service, advertising, or analytics SDK. Requests use the user's respective Groq/Tavily accounts and are governed by provider policies. Neither receives room geometry, fit summaries, or camera images. External websites and exported room JSON have separate privacy lifecycles.

Footprint checks do not certify movement, overhead clearance, hidden obstacles, delivery routes, or door swing. Entered dimensions and pasted text are not independently verified.
```

Decide how App Review will access optional automatic search before submission. If temporary provider credentials are needed, arrange them privately through the review process with a free account/quota, keep them valid during review, and revoke them afterward. Never put credentials in public metadata, screenshots, or this document. Supply any hardware/resources Apple needs. [App Review completeness](https://developer.apple.com/app-store/review/guidelines/#app-completeness).

## Screenshots

Capture the current app: contextual conversation; product-page selection changing the room preview; optional local pairing; dimension evidence; Help & Privacy. Do not expose provider keys or pairing tokens. Preserve sample/source labels. Real scan/AR screenshots should come from tested hardware and a room you have permission to show. Do not present simulator rehearsal as real AR. Use accepted large-iPhone portrait dimensions in Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). This release scope is iPhone only.

## Future publication steps — not needed to run locally

1. Review repository checks and [DEVICE_ACCEPTANCE.md](DEVICE_ACCEPTANCE.md) if distributing the iPhone app. Hardware validation is a future sensor/distribution check, not a prerequisite for finishing the standalone GitHub project. Record provider verification limits honestly.
2. Open `iosApp/FitCheck.xcodeproj`, choose **FitCheck**, and confirm the distribution team and `dev.fitcheck.prototype`. Target: iPhone only, portrait, iOS 17+. Confirm version `1.0.0`; use a new build number for every upload.
3. Run `sh scripts/release-check.sh`, `sh scripts/check.sh`, and `sh scripts/check-ios.sh`. These commands are not a claim that this candidate passed. Prepare a Release archive with `sh scripts/archive-ios.sh`; `--unsigned` is local verification only. The script never uploads. Use a fresh archive path if another exists.
4. Open the signed archive in Xcode Organizer, validate it, inspect privacy warnings/report, and upload through **Distribute App > App Store Connect**. An unsigned archive cannot be submitted. [Apple build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
5. In [App Store Connect](https://appstoreconnect.apple.com/), create/select the iOS record for the same bundle ID. Add metadata, real publisher/contact details, working support/privacy URLs, screenshots, pricing/availability, and App Privacy answers. Complete the current age-rating questionnaire for the actual external retailer links/search capability. [Age ratings](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).
6. Select the processed build and answer export-compliance questions for the actual app. It declares `ITSAppUsesNonExemptEncryption = NO`; reconsider that if cryptography changes. Add reviewer resources, choose **Manually release this version** to retain control, and submit when complete. Apple's review and public release have not been performed here.
