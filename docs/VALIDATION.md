# Verification evidence — November 1, 2026

This record covers the connected shopping implementation: contextual chat, swipeable product pages, persistent phone preview, and optional desktop-to-phone pairing. All checks use the repository and Simulator; no author's phone, provider credentials, hosted backend, or App Store enrollment is required.

## Current local evidence

| Check | Result |
| --- | --- |
| Shared Kotlin JVM tests | 13 passed |
| Desktop tests | 28 passed: 11 shopping/provider, 7 conversation, 3 real HTTP session, 5 connected UI, and 2 earlier UI smoke cases |
| Native XCTest suite | 56 passed; 1 endpoint-dependent case intentionally skipped here and passed separately below |
| Real iPhone touch workflow | 2 UI tests passed: ongoing two-turn chat, actual horizontal page swipe, unknown-size removal, and return to a measured item |
| Actual desktop JVM to native client | 1 integration test passed via `sh scripts/check-live-pairing.sh` |
| Unsigned Release archive | Succeeded, version 1.0.0 (1), including local-network permission and scoped transport settings |
| Source/resource/credential checks | Passed |

The final combined local native run passed: 57 unit/integration cases executed with zero failures and one deliberate skip, followed by both real UI cases passing. The skipped endpoint-dependent case passed in the separate actual JVM/native run. Together with the 41 shared/desktop cases, **100 distinct automated cases passed** across these checks. Public CI for the published revision is recorded separately below.

## What the connected tests establish

The desktop tests exercise the actual temporary HTTP listener, schema/version/revision handling, token rejection and rotation, known-product selection, oversized/malformed mutations, browser-Origin rejection, and stopping. Compose tests show that changing the active shopping page updates the dimensions shown by the room preview; missing dimensions withhold it. Chat tests inject model responses and verify history, overrides, cancellation, malformed output, free-provider errors, and explicit local fallback. Chat without a Tavily key and a nonempty draft passed directly to Find matches have regressions.

The native tests cover the same bounded conversation contract and local persistence. Selection regressions hold a request during rapid A → B → A swipes and require the final selection to remain A. SceneKit replacement preserves the floor placement while changing dimensions, removes a node with unknown dimensions, and restores the next measured item at the retained transform. Retailer page identity checks reject a different product or meaningful variant query. A real local TCP fixture exercises the native URLSession transport separately from HTTP mocks.

The separate **actual JVM/native integration** builds the packaged desktop application and native Simulator test. A Java fixture runs the production `LivePreviewSession` with production shared products. The phone uses its production `LivePhoneSession` and default URLSession transport to receive A, send selection B through HTTP POST, then receive C published by the JVM after that selection. It verifies product identity, provenance, dimensions, and missing dimensions across the language/runtime boundary. The case passed with one test, zero failures. This is real loopback networking and Kotlin/JVM → Swift serialization, rather than a mock transport. It does not establish connectivity between two physical devices on a particular Wi-Fi network.

The ordinary native suite intentionally skips `testActualJVMDesktopPairing` when no temporary test endpoint is provided. `scripts/check-live-pairing.sh` starts the real fixture, injects its temporary endpoint, requires an explicit pass rather than a skip, sanitizes retained text logs, and tears down its listener and temporary configuration. Public CI runs this separate script after the regular suites.

Real XCUITest interaction, beyond hosted layout renders, verifies two shopping messages and replies, earlier context still visible, a horizontal carousel swipe updating the sticky room preview, a page with unknown size clearing the old object, and returning to a measured page. Screenshots use labelled synthetic sample products. These tests do not open live retailer websites or exercise the camera.

## Reproduce

```sh
sh scripts/check.sh
sh scripts/check-ios.sh
sh scripts/check-live-pairing.sh
sh scripts/release-check.sh
python3 scripts/check-public-source.py
# Optional local packaging; supply a fresh path to preserve an existing archive.
sh scripts/archive-ios.sh --unsigned build/release/RoomWise-new.xcarchive
```

Provider tests use injected HTTP responses, with no live keys or paid requests. They verify the supported Groq endpoint/model/strict schema and one model request per chat turn, plus Tavily basic-only retrieval, no extraction/advanced escalation/retries, and the iPhone's upfront local monthly allowance. Find matches uses accepted preferences with no new model call when the draft is empty; an unsent draft is interpreted once first. Authenticated provider availability, quota behavior on a particular account, catalog coverage, and current product facts remain untested by that evidence.

## Release and public CI

The public source is [Ansester/RoomWise](https://github.com/Ansester/RoomWise). The workflow skips private repositories and uses no provider secrets. Its connected-flow checks include source/resources, shared/desktop tests, unsigned device compilation, native tests/UI tests, and the real local JVM/native exchange.

The first connected-flow public [run 41304508664](https://github.com/Ansester/RoomWise/actions/runs/41304508664) for application revision `ab008dd` passed source/resource checks, all shared/desktop cases, unsigned iPhone compilation, the native suite, and both actual UI cases. Its final separate pairing command exceeded its 150-second test-process limit on the hosted Simulator. That run is not an overall green CI result. The harness now waits for Simulator boot before starting its temporary server and allows bounded slower test startup. Independent checks run in parallel; their final result is recorded separately. Application behavior and test assertions were not weakened.

Historical [run 41286710634](https://github.com/Ansester/RoomWise/actions/runs/41286710634) passed for the earlier revision `8da670f` with 41 native tests. That result predates this connected-shopping implementation. Current code and CI evidence must be identified separately.

The unsigned Release archive contains version/build metadata, icon, privacy manifest, scoped local-network transport exception, and a nil-only compatibility credential stub. It is an inspection/build artifact, not a signed installable IPA or an App Store submission. No app, support website, or App Store distribution was deployed.

## Boundaries

- Each user supplies their own free-provider accounts/keys. Provider quotas and plans can change; local counters do not determine external billing choices or quota shared with other projects.
- Product discovery uses indexed retailer pages, not exhaustive or authoritative Amazon catalog access. Missing or ambiguous measurements remain unknown.
- The preview is a generic, dimension-based chair schematic. No retailer-specific 3D model is implied. The supported category is chairs.
- Embedded retailer browsing is tied to saved shortlist records. Detected product/variant URL changes pause the preview; a retailer can change a variant without changing its URL, so users must verify its measurements.
- Pairing is temporary plaintext HTTP on a trusted local network with a private bearer link. It carries products and selection, not room geometry, chat, or keys. It is not an internet service or an authenticated encrypted multi-user backend.
- Physical RoomPlan scanning, two-device Wi-Fi behavior, and camera AR tracking were not evaluated in this run. Hardware acceptance is optional and documented in [DEVICE_ACCEPTANCE.md](DEVICE_ACCEPTANCE.md).
- Fit checks cover captured floor footprints and recognized objects, without guaranteeing hidden obstacles, movement, overhead clearance, door swings, delivery routes, or purchase suitability.
- Source checks cover the current tracked/exported snapshot; they do not prove all secrets absent, revoke historical credentials, or establish licence rights. Earlier private history is excluded from the public repository; the original private project remains separate.
