# Portfolio and CV material

This is prepared copy for featuring RoomWise. It does not update or publish a CV or website. The canonical public repository is: **https://github.com/Ansester/RoomWise**.

Describe the work as a **collaborative software prototype** and retain [contributor credit](CONTRIBUTORS.md). The project-level descriptions below are supported by the source; select any first-person implementation claims only after confirming they match your own contribution.

## Recommended project header

**RoomWise — furniture fit checking**

Collaborative software project · 2026

Kotlin Multiplatform · SwiftUI · RoomPlan · ARKit · Compose Desktop · Groq · Tavily

## CV wording

### Compact version

- Co-developed RoomWise, a furniture-planning prototype with native iPhone and desktop interfaces, shared Kotlin geometry, room-file transfer, and dimension-based chair placement.
- Separated LLM request interpretation from sourced product facts and deterministic fit checks; the repository includes 67 passing automated tests and an unsigned iPhone Release build.

The second bullet describes project evidence, not a claim that one contributor personally wrote every test or component. If a CV needs one bullet, use:

> Co-developed RoomWise, a Kotlin Multiplatform furniture fit-checking prototype combining native RoomPlan/ARKit interaction, rotated-footprint geometry, and evidence-labelled retailer search across iPhone and desktop.

### Systems-focused alternative

> Co-developed a native iPhone and desktop room-planning prototype with shared Kotlin serialization and geometry; handled rotated footprints, concave boundaries, incomplete scans, and provenance for sample, retrieved, and user-entered furniture data.

### AI-application alternative

> Co-developed a furniture-shopping prototype that uses hosted Groq for structured chair requirements and Tavily for indexed retailer listings, while validating product evidence and calculating geometric fit outside the LLM.

Use the alternatives to emphasize the relevant engineering work. They are not additional claims of user impact, field accuracy, or production deployment. There are no supported percentage improvements or user/adoption metrics to add.

## Website project card

**Title:** RoomWise

**Subtitle:** Room-aware chair planning across iPhone and desktop

**Status:** Collaborative software prototype

**Code:** https://github.com/Ansester/RoomWise

**Short description:**

RoomWise combines native room capture, dimension-based chair previews, and shared Kotlin geometry to check furniture footprints against a captured space. Optional Groq and Tavily integrations interpret shopping requests and find retailer listings, while missing dimensions and uncertain facts remain explicit.

**Suggested tags:** Kotlin Multiplatform, SwiftUI, ARKit, computational geometry, AI applications.

**Image:** [iPhone sample preview](screenshots/iphone-sample-preview.png)

**Alt text:** RoomWise sample room with a scaled chair, rotation and movement controls, and furniture search.

**Caption:** Hosted iPhone render with synthetic sample room and chair data.

## Website case-study introduction

RoomWise is a collaborative furniture-planning prototype for checking whether a chair's footprint fits a captured room. It connects a native SwiftUI iPhone interface and a Compose Desktop companion through Kotlin Multiplatform models and geometry.

The engineering focus is the boundary between uncertain shopping information and deterministic spatial checks. A hosted LLM interprets chair requirements, retailer search supplies listing evidence, and shared code performs the footprint calculations. Missing assembled dimensions, conflicting prices, and incomplete room boundaries remain visible instead of being filled in by the model.

The repository includes a keyless sample workflow, optional free-tier provider setup, local data controls, and reproducible build/test instructions. Local verification covers 67 automated tests, an unsigned iPhone Release archive, and hosted interface renders. Live-provider reliability and user outcomes have not been evaluated in that record.

**Credit line:** A collaborative project by [Ashmit Mukherjee](https://github.com/Ansester) and [Aadil Chasmawala](https://github.com/Aarz1401).

Link the card to the [full case study](CASE_STUDY.md) or adapt that page for the website. Keep the claim boundaries even when shortening the copy.

## Add a personal contribution paragraph

Before using first-person language, record two or three concrete responsibilities that you can explain in an interview. Useful categories are frontend/workflow work, shared geometry and contracts, provider integration, tests and release tooling, and project coordination. Name the parts you actually owned; do not select the whole list by default.

For each responsibility, add a source link or a specific design decision you can discuss. Confirm the division of work with your collaborator if it is unclear. The public repository's clean snapshot preserves contributor credit but does not reproduce the entire development history.

## Interview walkthrough

1. Show the keyless sample and explain why a clone does not need the author's device or keys.
2. Rotate and move a chair. Explain the difference between a footprint check and a real-world clearance guarantee.
3. Show the incomplete-boundary behavior and the test for a concave notch.
4. Trace request interpretation → retailer search → evidence parsing → geometric check. Explain which outputs the LLM is permitted to influence.
5. Explain sample/live/user-entered provenance, cancellation isolation, and missing-data handling.
6. Use the [validation record](VALIDATION.md) to distinguish tests, renders, live calls, and hardware evidence.

The [claims guide](CLAIMS.md) is the final wording check for any public description.
