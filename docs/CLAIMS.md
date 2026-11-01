# What the evidence supports

This page is a claim guide for the README, CVs, portfolio pages, demos, and interviews. It describes the documented source and local verification as of November 1, 2026. Update it when new evidence changes a claim.

## Status

**RoomWise is a collaborative software prototype with local build and automated-test evidence.** It contains native iPhone and desktop frontends, shared geometry, optional hosted request interpretation, and retailer web-search integration. Publication of source code does not establish an App Store release, a deployed service, or an evaluated product.

The [validation record](VALIDATION.md) documents 67 passing tests: 13 shared Kotlin tests, 11 desktop shopping tests, 2 desktop UI smoke tests, and 41 iOS XCTest tests. It also records an unsigned iPhone build, an unsigned Release archive, and hosted iPhone render checks. Provider tests use HTTP mocks. The test count is an engineering coverage metric, not a measurement of real-world fit accuracy or user benefit.

## Claim-to-evidence map

| Topic | Supported wording | Evidence | Boundary |
| --- | --- | --- | --- |
| Product scope | “A furniture fit-checking prototype with native iPhone and desktop frontends.” | [iPhone UI](../iosApp/FitCheckApp.swift), [desktop UI](../desktop/src/main/kotlin/fitcheck/App.kt) | Do not imply a public app release or active user base. |
| Shared implementation | “Uses Kotlin Multiplatform for room models, geometry, product evidence, and serialization.” | [models](../shared/src/commonMain/kotlin/fitcheck/Models.kt), [geometry](../shared/src/commonMain/kotlin/fitcheck/Geometry.kt), [extraction](../shared/src/commonMain/kotlin/fitcheck/ProductExtraction.kt) | The frontends are native SwiftUI and Compose Desktop; they do not share one UI implementation. |
| Room capture | “Implements Apple RoomPlan capture and validated room-file import/export.” | [capture controller](../iosApp/RoomCaptureController.swift), [room contract](ROOM_FORMAT.md) | Hardware scanning is optional. The current release work did not reverify it on a physical iPhone. |
| Placement | “Checks rotated chair footprints against room boundaries and recognized furniture.” | `footprint`, `contained`, `overlaps`, and `checkPlacement` in [Geometry.kt](../shared/src/commonMain/kotlin/fitcheck/Geometry.kt) | A footprint fit is not proof of hidden-obstacle clearance, chair motion, overhead clearance, door swing, or delivery access. |
| Partial scans | “Withholds boundary-fit confirmation when the scan boundary is incomplete.” | `scanQuality` and `checkPlacement` in [Geometry.kt](../shared/src/commonMain/kotlin/fitcheck/Geometry.kt), [shared tests](../shared/src/commonTest/kotlin/fitcheck/CoreTest.kt) | Do not describe partial captures as complete room measurements. |
| AR | “Provides a dimension-based, simplified chair preview through ARKit on supported hardware.” | [FloorPlanCanvas.swift](../iosApp/FloorPlanCanvas.swift) | The schematic's aggregate bounds are normalized to the entered dimensions and checked by `testSimplifiedARChairBoundsMatchAssembledDimensions`. It remains a generic illustration, not the seller's exact 3D asset or proof of AR tracking accuracy. Simulator rehearsal is not a camera-AR test. |
| LLM role | “Uses hosted Groq to interpret chair requirements while keeping product facts and fit calculations outside model output.” | [iPhone parser](../iosApp/FreeShopping.swift), restricted `GroqPreferenceTools` in [desktop agent](../desktop/src/main/kotlin/fitcheck/Agent.kt) | Do not call the model's interpretation a verified understanding of user intent or claim hallucination-free operation. |
| Retailer discovery | “Finds indexed Amazon UAE, Noon UAE, and Temu product pages through Tavily basic search.” | [iPhone retailer service](../iosApp/RetailerService.swift), [desktop provider](../desktop/src/main/kotlin/fitcheck/Retailers.kt) | This is not a complete retailer catalog, an Amazon product API, a retailer partnership, or a live inventory feed. |
| Product evidence | “Keeps missing or conflicting price and assembled-size evidence unknown.” | [ProductExtraction.kt](../shared/src/commonMain/kotlin/fitcheck/ProductExtraction.kt), [shopping tests](../desktop/src/test/kotlin/fitcheck/ShoppingTest.kt) | A valid retailer URL does not establish the truth, freshness, or completeness of the listing facts. |
| Provenance | “Distinguishes sample, live-search, saved-live, and user-entered product data.” | `ProductProvenance` in [Models.kt](../shared/src/commonMain/kotlin/fitcheck/Models.kt), [persistence](../iosApp/RoomPersistence.swift) | Sample facts are synthetic. User-entered facts are not independently verified. |
| Cost controls | “Supports a keyless sample and optional free-tier provider accounts, with bounded iPhone search requests.” | [free pipeline](../iosApp/FreeShopping.swift), [configuration guide](../README.md#optional-free-tier-shopping) | Provider plans can change. The iPhone installation's local cap does not measure an account's total usage or control external billing settings. |
| Data handling | “Keeps room geometry local in the default shopping pipeline and stores iPhone provider keys in Keychain.” | [free pipeline](../iosApp/FreeShopping.swift), [credential store](../iosApp/CredentialStore.swift), [privacy policy](PRIVACY.md) | This is a specific data-flow statement, not a comprehensive security or privacy guarantee. Exported files and provider requests have separate lifecycles. |
| Verification | “Passed 67 automated tests and built an unsigned iPhone Release archive locally.” | [VALIDATION.md](VALIDATION.md), [test scripts](../scripts/check-ios.sh) | Do not turn this into a production-readiness, usability, field-accuracy, or store-approval claim. |

## Claims that need additional evidence

The current record does not support claims about reduced returns, money saved, higher purchase confidence, faster room planning, improved decision quality, real-world measurement accuracy, or adoption. Those would need an appropriate evaluation and recorded results.

Live provider reliability, current prices and stock, physical AR behavior, and a complete RoomPlan capture on the current candidate also need their own evidence. Mocks and hosted renders are useful regression checks; they do not establish those outcomes.

Avoid statements such as “production-ready,” “launched on the App Store,” “used by customers,” “guarantees furniture will fit,” “accesses Amazon's full catalog,” or “eliminates hallucinations” unless subsequent evidence supports the exact wording. Likewise, public source availability should not be labelled a permissive open-source licence when no such licence is present.

## Evidence labels for public material

| Label | Use it for |
| --- | --- |
| Implemented | Behavior visible in the checked-in code. |
| Locally verified | A named build, test, render, or source check actually completed and recorded. |
| Sample / synthetic | Demonstration rooms, chairs, or mocked responses. |
| User-entered | Information supplied by a person, including pasted listing details. |
| Not yet verified | Live-service, hardware, deployment, or user-outcome behavior without current evidence. |

Keep labels near the associated screenshot or statement. The [screenshots](screenshots/) are hosted iPhone renders using sample data, not photographs of a measured room or proof of live shopping results.
