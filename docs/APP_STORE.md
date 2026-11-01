# RoomWise — optional future iPhone App Store handoff

RoomWise can be used locally without App Store publication or paid model/search services. Simulator sample planning needs no Apple Developer Program enrollment or provider account. This packet is only for a future decision to publish; it does not record a submitted app, signed archive, hardware acceptance, or App Store approval. See [DEVICE_ACCEPTANCE.md](DEVICE_ACCEPTANCE.md) and [VALIDATION.md](VALIDATION.md) for verification boundaries.

## Details needed only if publishing later

- The Apple Developer Program account that owns or can register `dev.fitcheck.prototype`. Confirm that the preserved project team is the intended distribution account before signing.
- The publisher's actual legal/copyright name and App Review contact name/telephone number. Public support email: `info.roomwise@gmail.com`.
- Public HTTPS support and privacy-policy URLs. Finished static pages are in `docs/store-site/`; [PRIVACY.md](PRIVACY.md) contains the policy text. Nothing has been hosted.
- Final app pricing and regional availability choices. Each clone can use its own Groq free-plan key and Tavily Researcher free-tier key. Hosted interpretation is independent of the device running this clone.

Apple requires a privacy-policy URL for iOS apps and a support URL leading to actual contact information. [Privacy setup](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [platform version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).

## Free search setup

Hosted request interpretation uses a personal Groq free-plan key with the default `openai/gpt-oss-20b` model. That is a model served by Groq, not a connection to the OpenAI API. Exact free-plan limits depend on the Groq organization; its current free table includes this model. [Groq rate limits, checked November 1, 2026](https://console.groq.com/docs/rate-limits).

Automatic retailer discovery requires a personal Tavily key. Choose Tavily's **Researcher** free plan, with no payment card or paid upgrade. Tavily currently advertises 1,000 credits monthly and stops free requests when exhausted. RoomWise uses basic search only, up to three requests per search, with a local 300-request monthly limit per installation. It does not use extract, advanced search, automatic retries, or a paid fallback. The provider account's actual remaining quota can be lower if it is used elsewhere. If the key is absent, quota is exhausted, or retrieval fails, browser search links and manual chair entry remain available. [Tavily pricing, checked November 1, 2026](https://www.tavily.com/pricing).

The app cannot change the user's provider plan or determine charges configured elsewhere. Use the free account configuration described above. Do not promise exhaustive Amazon, Noon, or Temu catalogue access: search discovery can return incomplete coverage and uncertain product facts.

## Paste-ready product metadata

| Field | Text |
| --- | --- |
| Name | RoomWise |
| Subtitle | Scan rooms. Preview chair fit. |
| Primary category | Lifestyle |
| Secondary category | Shopping |
| Primary language | English |
| Initial version | 1.0.0 |
| Keywords | chair,room,lidar,floorplan,interior,ar,furniture,layout,dimensions,space,planning |

The name is subject to App Store availability. Category choices are recommendations to confirm when creating the app record.

**Promotional text**

```text
Scan your room, compare chair dimensions, and preview in 3D or AR. Discover listings with your own free-tier Groq and Tavily accounts, or plan with samples.
```

**Description**

```text
Plan a chair's place before you buy.

RoomWise brings room scanning, dimension-based chair previews, and floor-footprint checks together on your iPhone. No paid AI model is needed.

SCAN AND REVIEW
Use Apple RoomPlan on a supported LiDAR iPhone to capture walls, openings, and recognized furniture. Review the room in 3D. Partial scans are clearly labelled and cannot confirm the room boundary.

PLACE AND COMPARE
Choose a sample chair, discover a retailer listing, or enter a chair's details yourself. Add assembled dimensions from the seller's page and compare it with your room. Drag, rotate, and recenter the chair. On supported physical iPhones, place a simplified chair in AR at those dimensions. The preview represents size, not the seller's exact design.

FREE-TIER INTERPRETATION AND RETAILER SEARCH
Describe what you want. With your own free-plan Groq key, RoomWise interprets the chair request using a hosted model. A deterministic parser remains available if the key or service is unavailable. Optional automatic discovery uses your own Tavily Researcher free-tier key, with basic requests and a local monthly limit. No key is needed for sample planning, scanning, dimension editing, or fit checks. Browser search links and manual chair entry remain available when the key or quota is unavailable.

UNDERSTAND THE EVIDENCE
Search discovery does not guarantee complete retailer coverage. Sample chairs are labelled; listing text, prices, and dimensions may be incomplete. User-entered dimensions are identified and missing dimensions remain unknown. Fit checks compare the chair's floor footprint with captured walls and recognized furniture. They do not assess hidden obstacles, overhead clearance, movement, door swings, or delivery routes. Always measure and confirm the seller's details before buying.

KEEP CONTROL OF YOUR ROOM
Rooms, search text, product information, and placement are saved locally and may be included in device backups. RoomWise asks permission before sending your chair request to Groq and search requirements to Tavily. Room geometry and camera photos are not uploaded to that service. Provider keys are stored in this device's Keychain. There is no RoomWise account, advertising, analytics SDK, or remote OpenAI connection. Export room JSON when you choose or delete local data in Help & Privacy.

Requires iOS 17 or later. Room scanning requires a LiDAR-equipped iPhone. AR requires supported hardware and camera access. Other iPhones can use the sample room or import a RoomWise room file. Groq and Tavily free-account quotas and terms apply to automatic features.
```

**Copyright**

```text
2026 [ACTUAL RIGHTS HOLDER]
```

## App Privacy responses

Use these conservative responses, matching `iosApp/PrivacyInfo.xcprivacy`. Optional automatic search is part of the app's functionality; do not select “Data Not Collected” because offline use is possible. Confirm final provider terms and archive behavior before submitting. Apple explains collection, linkage, and optional disclosure in [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/).

| Question/data | Prepared response | Implementation basis |
| --- | --- | --- |
| Do you or third-party partners collect data from this app? | Yes | Optional requests go directly to Groq/Tavily; their account/retention terms apply. |
| Search History | Collected; App Functionality; linked to user; not tracking | Chair requests sent to Groq and search requirements sent to Tavily. No room geometry/summary is transmitted. |
| User ID | Collected; App Functionality; linked to user; not tracking | Personal keys authenticate to their respective Groq/Tavily accounts. No RoomWise account service. |
| Data used for tracking | No | No advertising, cross-app tracking, or analytics SDK. |
| Other User Content, room geometry, photos | Not collected off device by this app | Local scan/fit processing; model sees chair request only; no saved/uploaded camera photos. User-selected exports and external links are explained in the policy. |
| Required reason API | UserDefaults, CA92.1 | Saved rooms/products/placement/preferences and local quota accounting accessible only to the app. |

Linkage is conservative because requests use an identifiable provider account. The bundled manifest and App Store questionnaire are separate steps. App Privacy must change if additional remote features or telemetry are added.

Historical prototypes embedded OpenAI/Tavily demo keys. Current iOS builds generate a nil-only compatibility stub in every configuration. If historical keys were used/shared, revoke/rotate them at the providers; current-source removal does not purge Git history or revoke credentials. No OpenAI key is offered in the current iPhone interface.

## Paste-ready App Review notes

```text
RoomWise is an iPhone room-planning app. No RoomWise account or paid AI model is required.

1. Launch the app. It opens with a labelled sample room and sample chairs.
2. Select a chair, drag it in the room, and use rotation/recenter controls. Open details and Edit to enter assembled dimensions.
3. Describe chair requirements. The default hosted parser uses the user's Groq free-plan key and openai/gpt-oss-20b, with deterministic fallback. Only the chair request is sent; no room data is included. The service is Groq; there is no OpenAI API connection.
4. Optional automatic retailer discovery uses a personal Tavily free-tier key saved through Connections in the device Keychain. It asks permission before sharing chair-search requirements. Only basic search is used, up to three requests per search, with a local 300-request monthly limit. It does not send room geometry, room summaries, or camera photos. No extract/advanced requests or automatic retries are used.
5. With no key, exhausted quota, or retrieval errors, use external retailer search links or add a chair by pasting listing information/entering details. No key is needed for sample planning, scanning, dimension editing, or fit checks. Search coverage and listing facts can be incomplete; this is not a complete retailer catalogue.
6. On a supported physical iPhone, open AR Preview, detect a horizontal surface, and tap to place a simplified chair at the selected dimensions. The simulator uses a labelled 3D rehearsal.
7. For a real scan, use the Room actions menu on a LiDAR-equipped iPhone and grant camera access. Finish/review/accept the scan. Partial scans withhold boundary confirmation.
8. Room actions also offer JSON import/export and Help & Privacy, including permission revocation and local saved-data deletion. Clear the separately stored Tavily key in Connections. Support: info.roomwise@gmail.com.

The app has no developer-operated account service, advertising, or analytics SDK. Saved room/search/product state stays in local storage. With permission, Groq receives the chair request and its authentication; Tavily receives search requirements and its authentication. Requests are associated with the respective user-owned provider accounts. Neither service receives room geometry, fit summaries, or camera photos. External retailer links open only on user action and follow the site's own policies. User-selected JSON exports contain room geometry.

A chair preview is a dimensional model, not the exact seller design. Footprint checks do not certify movement, overhead clearance, hidden obstacles, delivery routes, or door swing. Entered dimensions and pasted content are not independently verified.
```

Decide how App Review will access optional automatic search before submission. If temporary provider credentials are needed, arrange them privately through the review process with a free account/quota, keep them valid during review, and revoke them afterward. Never put credentials in public metadata, screenshots, or this document. Supply any hardware/resources Apple needs. [App Review completeness](https://developer.apple.com/app-store/review/guidelines/#app-completeness).

## Screenshots

Capture the current app: placement; chair comparison/dimension evidence; search/manual chair entry; Help & Privacy. Preserve sample/source labels. Real scan/AR screenshots should come from tested hardware and a room you have permission to show. Do not present simulator rehearsal as real AR. Use accepted large-iPhone portrait dimensions in Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). This release scope is iPhone only.

## Future publication steps — not needed to run locally

1. Review repository checks and [DEVICE_ACCEPTANCE.md](DEVICE_ACCEPTANCE.md) if distributing the iPhone app. Hardware validation is a future sensor/distribution check, not a prerequisite for finishing the standalone GitHub project. Record provider verification limits honestly.
2. Open `iosApp/FitCheck.xcodeproj`, choose **FitCheck**, and confirm the distribution team and `dev.fitcheck.prototype`. Target: iPhone only, portrait, iOS 17+. Confirm version `1.0.0`; use a new build number for every upload.
3. Run `sh scripts/release-check.sh`, `sh scripts/check.sh`, and `sh scripts/check-ios.sh`. These commands are not a claim that this candidate passed. Prepare a Release archive with `sh scripts/archive-ios.sh`; `--unsigned` is local verification only. The script never uploads. Use a fresh archive path if another exists.
4. Open the signed archive in Xcode Organizer, validate it, inspect privacy warnings/report, and upload through **Distribute App > App Store Connect**. An unsigned archive cannot be submitted. [Apple build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
5. In [App Store Connect](https://appstoreconnect.apple.com/), create/select the iOS record for the same bundle ID. Add metadata, real publisher/contact details, working support/privacy URLs, screenshots, pricing/availability, and App Privacy answers. Complete the current age-rating questionnaire for the actual external retailer links/search capability. [Age ratings](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).
6. Select the processed build and answer export-compliance questions for the actual app. It declares `ITSAppUsesNonExemptEncryption = NO`; reconsider that if cryptography changes. Add reviewer resources, choose **Manually release this version** to retain control, and submit when complete. Apple's review and public release have not been performed here.
