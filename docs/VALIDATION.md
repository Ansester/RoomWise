# Verification evidence — November 1, 2026

This record covers the standalone GitHub source with hosted free-tier Groq request interpretation and Tavily basic search. It does not depend on the author's phone, provider credentials, server, or Apple Intelligence.

## Automated evidence

| Check | Result |
| --- | --- |
| Shared Kotlin JVM tests | 13 passed |
| Desktop shopping/provider tests | 11 passed |
| Desktop Compose UI smoke tests | 2 passed |
| iPhone XCTest suite | 41 passed |
| iPhone unsigned device build | Succeeded |
| Clean public checkout | Unsigned device build and all 41 XCTest tests passed with no pre-existing generated compatibility source |
| Final unsigned Release archive | Succeeded, version 1.0.0 (1) |
| iPhone hosted renders | 10 images captured across 375×812 and 430×932 viewports |
| Source/resource/credential checks | Passed |

Commands: `sh scripts/check.sh`, `sh scripts/check-ios.sh`, `sh scripts/release-check.sh`. The suites cover geometry/concave boundaries, ambiguous scan joins, bounded file import, retailer URL constraints, manual listing provenance, local persistence, Keychain separation, stale/cancelled requests, provider errors, and secret-exclusion regressions. Hosted render images cover the initial screen, help/privacy, dimensions, free-provider settings, and manual chair entry; representative exports were visually inspected. Hosted rendering does not exercise full touch navigation, camera, or AR tracking.

Provider tests use local HTTP mocks, with no live credentials or paid requests. They verify Groq's endpoint/model/schema and single-request/offline fallback; Tavily basic-only requests, no extraction/advanced retries, a maximum of three retailer calls, upfront local quota reservations, month rollover, quota failure/cancellation, and no implicit paid escalation. Groq receives only requirements; room/catalog/fit tools stay local. Source is configured from official provider documentation; authenticated live endpoint behavior remains untested in this run.

The first hosted-render run found an overly coarse blank-image assertion on the compact Add Chair form. The exported image was visually correct. Sampling was increased from 32×32 to 128×128 to retain thin form text, while preserving contrast and nonempty-content assertions; the corrected suite passed.

The public-documentation audit added a SceneKit regression checking the schematic AR chair's aggregate width/depth/height, ground plane, and centering across three dimension sets. The node is normalized inside an unscaled placement container. This checks model geometry, not physical AR tracking. The desktop entry script now delegates to the credential-isolating launcher; a host-specific desktop JAR was built successfully.

## Local release packaging

The project contains a RoomWise icon, version/build metadata, privacy manifest, shared schemes, and a repeatable `scripts/archive-ios.sh --unsigned` command. Release archives are local build artifacts, not an App Store submission or an installable signed IPA. The final unsigned archive was built successfully and its version, icon/resource metadata, iPhone targeting, privacy manifest, nil-only credential stub, and absence of known local credentials were checked. Signing, enrollment, hosting support URLs, and store submission are optional future work, separate from repository completion.

No app, website, or App Store release was published. Public-repository CI is configured in `.github/workflows/verify.yml`; local success is separate from the remote run. It deliberately skips private repositories to avoid paid private macOS runner work. Public-run evidence is recorded after publication.

## Boundaries

- Live Groq/Tavily calls need each user's own free accounts/keys. Provider quotas and free plans can change; local counters do not determine account billing status or quota shared with other devices/apps.
- Retailer discovery uses indexed product pages, not exhaustive or authoritative Amazon catalog access. Search snippets can omit dimensions/prices; missing or ambiguous facts remain unknown.
- Current RoomPlan and real-camera AR behavior were not reverified on a physical iPhone in this run. The repository can build, run samples, and execute automated tests without one. Hardware checks are optional and documented in `DEVICE_ACCEPTANCE.md`.
- Fit checks only cover captured floor footprints and recognized objects; they are not real-world clearance or purchase guarantees.
- The current tracked source excludes keys and all iPhone configurations generate a nil-only compatibility stub. Historical commits once contained demo keys. The public copy excludes that private development history entirely. Source scanning does not revoke those old credentials; their owner should still rotate them. The original private repository remains separate.
