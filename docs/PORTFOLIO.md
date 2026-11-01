# Portfolio and CV material

Prepared copy for featuring RoomWise at **https://github.com/Ansester/RoomWise**. This file does not update or publish a CV or website.

Describe RoomWise as a **collaborative conversational-shopping prototype with a live room preview**. Retain [contributor credit](CONTRIBUTORS.md). Project-level claims below describe the shared implementation; select first-person responsibilities only after confirming they match your contribution.

## Recommended project header

**RoomWise — conversational shopping with a live room preview**

Collaborative software project · 2026

Kotlin Multiplatform · SwiftUI · RoomPlan · ARKit · Compose Desktop · Groq · Tavily

## CV wording

### Compact version

- Co-developed RoomWise, a conversational furniture-shopping prototype that connects contextual LLM chat and swipeable product browsing to a changing iPhone room preview.
- Connected native iPhone and desktop interfaces through shared Kotlin geometry and an account-free local pairing protocol; separated sourced product dimensions and footprint checks from model-generated conversation.

If only one bullet fits:

> Co-developed RoomWise, a Kotlin Multiplatform shopping prototype combining ongoing LLM chat, swipeable chair listings, and a live dimension-based iPhone room preview, with optional desktop-to-phone pairing over local Wi-Fi.

### Systems-focused alternative

> Co-developed native iPhone and desktop shopping interfaces with shared Kotlin models/geometry, revisioned local product-selection synchronization, contextual chat, and explicit handling of missing retailer evidence.

### AI-application alternative

> Co-developed a conversational furniture-shopping prototype using Groq for contextual requirements and Tavily for retailer discovery; linked product-page selection to a phone room preview while keeping product facts and geometric fit outside LLM output.

These are descriptions of implemented systems, not user-impact results. Use the [validation record](VALIDATION.md) if adding exact test/build evidence; do not carry a prior test total forward after changing the implementation. No supported adoption, accuracy-improvement, or reduced-return percentages are available.

## Website project card

**Title:** RoomWise

**Subtitle:** Talk, browse, and preview furniture in your room

**Status:** Collaborative software prototype

**Code:** https://github.com/Ansester/RoomWise

**Short description:**

RoomWise connects an ongoing shopping conversation to swipeable chair listings and a live iPhone room preview. Browse on the phone or pair a desktop over local Wi-Fi; the selected product changes the dimension-based schematic in the room. Groq and Tavily provide optional free-tier chat and discovery, while shared Kotlin code validates product evidence and checks captured floor footprints.

**Suggested tags:** Kotlin Multiplatform, SwiftUI, ARKit, conversational AI, local networking, computational geometry.

**Image:** [Connected shopping page and room preview](screenshots/shopping-page-live-preview.png). Optional [ongoing conversation capture](screenshots/ongoing-conversation.png).

**Alt text for the existing image:** RoomWise sample room with a scaled chair, rotation and movement controls, and furniture search.

**Caption:** Actual Simulator interaction capture using synthetic sample products. The conversation capture shows the explicitly labelled offline helper; it is not a live-provider demonstration.

## Website case-study introduction

RoomWise explores a shopping experience where a person can keep talking about what they want, browse product options, and see the selected chair change in their room. A native SwiftUI iPhone app connects contextual conversation, product-page browsing, and a dimension-based room preview. A Compose Desktop companion can drive the phone's product selection through a temporary local-network session.

The engineering challenge is keeping that connected experience honest about evidence. Groq generates conversational replies and structured preferences; Tavily discovers indexed retailer listings; explicit source text supplies dimensions; and shared Kotlin geometry calculates floor-footprint checks. A missing measurement remains unknown rather than becoming a model estimate. The visual object is a generic scaled chair, not a seller-specific 3D asset.

Sample mode and local pairing need no RoomWise account or cloud deployment. Hosted chat and search use each user's optional free-tier keys. Automated checks and recorded builds are engineering evidence; live-provider reliability, physical-device behavior, and user outcomes need their own validation.

**Credit line:** A collaborative project by [Ashmit Mukherjee](https://github.com/Ansester) and [Aadil Chasmawala](https://github.com/Aarz1401).

Link to the [case study](CASE_STUDY.md), [live-shopping walkthrough](LIVE_SHOPPING.md), and [validation record](VALIDATION.md) for detail.

## Personal contribution paragraph

Choose two or three responsibilities you can explain in an interview, such as conversation state, native browsing/preview integration, local pairing, shared geometry, provider adapters, or verification/release tooling. State which parts you actually owned and one design decision you can defend. Confirm the division of work with your collaborator when needed.

The public repository begins from a clean source snapshot with contributor credit; it does not reproduce the whole private development history or establish sole authorship.

## Interview walkthrough

1. State the intended loop: conversation → product page → changing room preview.
2. Refine an existing request and explain bounded history, structured preferences, and local fallback.
3. Swipe between product pages; explain why selected-product state drives both the page and the visual object.
4. Start a local pairing session, explain revisions and token authorization, and distinguish local HTTP from encrypted internet transport.
5. Show missing-dimension behavior, provenance, and a rotated-footprint conflict. Explain the boundary between a schematic, evidence, and actual physical fit.
6. Use [validation](VALIDATION.md) to distinguish mocked tests, loopback protocol checks, hosted renders, live providers, and hardware acceptance.

Use the [claim ledger](CLAIMS.md) as the final wording check.
