# RoomWise: conversation, shopping pages, and a live room preview

**Status:** collaborative software prototype

**Contributors:** [Ashmit Mukherjee and Aadil Chasmawala](CONTRIBUTORS.md)

**Repository:** https://github.com/Ansester/RoomWise

**Stack:** Kotlin Multiplatform, SwiftUI, RoomPlan, ARKit/SceneKit, Compose Desktop, Groq, Tavily, local HTTP pairing

RoomWise connects three actions that otherwise happen separately: describing a purchase, browsing listings, and imagining the item in a room. A person can refine a chair request over several chat turns, move through product pages, and see the selected item change in the iPhone room preview. The desktop companion can drive that selection over a temporary local-network session.

The current visual is a generic chair scaled to explicit assembled dimensions. The system does not retrieve every retailer's exact 3D asset or infer reliable dimensions from photographs. Its spatial result is a check of captured floor footprints, not a guarantee of real-world clearance.

## The product loop

The central state is the **selected product**. The active shopping page sets that state. The room drawing, schematic/AR object, and local footprint calculation consume it. A paired desktop publishes the shortlist and selected ID, and the phone applies the corresponding state locally. That keeps page changes connected to preview changes instead of requiring a separate preview action for every listing.

The room belongs to the phone's workspace. Pairing transfers products and selection, not room geometry or AR alignment. A room JSON file can be transferred separately when both frontends should use the same measured geometry.

A product without valid assembled dimensions clears the size-based preview. Leaving the previous chair visible would suggest that the new listing had a known size, so uncertainty needs to change the visual state as well as the text.

## Conversation that retains intent

The **Send** action returns both a natural-language reply and validated structured preferences. **Find matches** separately retrieves products: a nonempty draft is sent once first; with no draft, accepted preferences are used without a model call. A casual conversation turn does not automatically spend search credits. Recent messages and the current preferences provide context for refinements such as “make it white” or “under AED 300 instead.” The history and message sizes are bounded, and each turn permits one Groq request without retries or a paid-provider switch.

The supported model is `openai/gpt-oss-20b`, hosted by Groq. The model receives conversation and preferences rather than room coordinates, product excerpts, or fit-tool output. Product facts and placement results therefore remain outside the language model's authority.

Missing credentials, quota failures, invalid output, or unavailable networking select a clearly labelled deterministic fallback. It handles a limited set of refinements; it is not an offline LLM or proof that every request was understood. A sample workflow remains useful without provider accounts.

## Retrieval and evidence

Tavily basic search discovers indexed Amazon UAE, Noon UAE, and Temu product pages. Returned URLs pass retailer-specific validation; explicit snippets are parsed locally for price and assembled dimensions. Search preferences guide discovery but do not prove that each hit satisfies the request.

Package sizes are not assembled sizes. Multiple conflicting prices or dimensions remain unknown. Manual measurements and pasted details carry user-entered provenance. Fixture, live, saved-live, and user-entered data remain distinguishable.

The free path performs no extra page-extraction requests or advanced-search escalation. On iPhone, three retailer calls are reserved before dispatch against a local 300-request UTC-month allowance. That counter is not the provider account's authoritative balance. Chat turns, carousel page changes, and local pairing have separate behavior; page changes and pairing consume no hosted-provider calls.

## Free local pairing

The desktop starts its built-in HTTP listener only when the user enables pairing. A random bearer token is included in the private URL. The phone reads revisioned snapshots containing the product list and selected ID; selection mutations accept only IDs already in the session.

This avoids a hosted backend, shared developer account, database, or relay subscription. It also creates a clear transport limitation: the connection is plain HTTP for a trusted local network, not encrypted public-internet communication. The link is a temporary secret and should not be published. Stopping pairing closes the session; a new session uses a new token.

The listener is a narrow product-selection interface. It does not expose filesystem access, credentials, arbitrary web proxying, chat history, or room coordinates. The [protocol guide](LIVE_SHOPPING.md) records its wire contract and troubleshooting boundaries.

## Local geometry and rendering

Shared Kotlin code supplies immutable room/product contracts, serialization, scan validation, rotated footprints, boundary containment, recognized-object overlap, and candidate placement. Both frontends use those contracts while retaining native presentation layers.

The geometry accounts for rotation and concave room boundaries. Incomplete scans withhold a complete-boundary conclusion. Bounded initial-placement/recenter logic finds a candidate rather than claiming an optimal layout. Exact mathematical limits are documented in [geometry](GEOMETRY.md).

SwiftUI coordinates the phone workspace, while RoomPlan handles supported capture and ARKit/SceneKit provide the physical/rehearsal previews. The schematic's aggregate dimensions are normalized to the product's explicit size. Product changes replace the object geometry while retaining a usable existing AR placement; tracking and surface accuracy remain hardware concerns.

## Data ownership and failure behavior

Phone provider keys use Keychain and are not embedded into any build configuration. The desktop uses session keys or explicitly supplied local configuration. Groq receives bounded conversation; Tavily receives search requirements; neither receives room/camera data through this pipeline.

Request cancellation and session identity prevent stale search callbacks from overwriting newer state. Pairing has a separate disconnect lifecycle. Local planning data, provider keys, and the anti-reset request allowance have distinct deletion controls. Website visits and exported room files have their own data lifecycles.

## Verification and limits

The repository provides automated tests for shared geometry, product evidence, mocked conversation/provider behavior, local protocol state, desktop UI, and iPhone rendering/state. The [validation record](VALIDATION.md) names the exact completed commands, tested revisions, and scope. A previous green build must not be treated as verification of later changes.

Mocked providers do not establish authenticated endpoint availability or search usefulness. Loopback protocol checks do not establish that two physical devices can communicate on every network. Hosted views do not establish camera AR tracking, retailer compatibility, user benefit, adoption, or reduced returns. Those require separate recorded acceptance or evaluation.

## Further reading

- [Live-shopping workflow and protocol](LIVE_SHOPPING.md)
- [Architecture](ARCHITECTURE.md) and [shopping pipeline](SHOPPING_PIPELINE.md)
- [Geometry](GEOMETRY.md) and [room format](ROOM_FORMAT.md)
- [Development](DEVELOPMENT.md) and [validation](VALIDATION.md)
- [Prepared CV/website copy](PORTFOLIO.md) and [claim ledger](CLAIMS.md)
