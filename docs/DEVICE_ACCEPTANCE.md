# iPhone hardware and future-release acceptance record

This optional future iPhone hardware/distribution checklist does not block completion of the standalone GitHub project. The hosted request parser is independent of the device running the clone. Automatic features use each clone's own Groq free-plan and Tavily Researcher free-tier keys. Historical demos do not complete these hardware/provider checks.

| Record | Value |
| --- | --- |
| App version/build and source reference | To record |
| Tester and date | To record |
| LiDAR iPhone model/iOS | To record |
| Other supported/smallest tested iPhone | To record |
| Groq model/account and Tavily free-tier configuration | To record if tested |
| Installation method/signing team | To record |
| Free Groq/Tavily test accounts and quota (never the key) | To record if tested |

Use a signed Release build on a trusted physical iPhone. Local device signing is governed by Xcode and the user's Apple account; App Store enrollment is only relevant if distribution is chosen later. A simulator cannot verify camera, RoomPlan, or real AR.

## Local planning

- [ ] Launch/relaunch without credentials/network. Sample content is clearly labelled; no remote request starts automatically.
- [ ] Select sample chairs; drag, rotate, and recenter. Comparison/fit follows the chair and pose.
- [ ] Edit assembled dimensions. Check user-entered labels, updated preview, and rejection of invalid/oversized values.
- [ ] With permission and a Groq free-plan key, parse chair requirements using the default hosted openai/gpt-oss-20b model. Verify no room data is in the request. Repeat with no/invalid key and a provider error; verify deterministic fallback without any paid-provider retry.
- [ ] Open a retailer link deliberately; check its actual external browser destination. Add a chair through pasted text/manual entry and confirm provenance, unknown dimensions, prices/currencies, and relaunch persistence.
- [ ] Cancel processing, switch sample mode, and change rooms; late results must not overwrite the new session.
- [ ] Export/import room JSON; cancel import and test malformed JSON without breaking the active room.
- [ ] Delete planning data in Help & Privacy and relaunch. Old saved planning data should be gone and samples shown. Exported files remain under the user's control. Deletion must not reset the separately maintained monthly request budget.

## Optional free automatic discovery

No live provider test is implied by this checklist. Use an owner-controlled **free Groq account and Tavily Researcher account**, no payment card/paid upgrade, and record quota use without exposing its key. Opening an account or accepting its terms is the user's action.

- [ ] Save Groq and Tavily keys through Connections; relaunch and verify non-secret saved status. No paid OpenAI API key is offered. Only requests to the respective providers should carry each credential.
- [ ] Cancel the sharing-permission prompt before first automatic search; no request should start. Allow it on the next attempt and inspect results/statuses.
- [ ] Confirm the request path uses basic search only, at most three requests for a search, no extract/advanced calls, and no automatic retries. Groq requests should contain only the chair query; Tavily searches should contain parsed chair requirements. Both authenticate to their respective providers; neither includes room geometry/summaries or camera images.
- [ ] Inspect actual retailer results, exact URLs, dimensions/evidence, and price currencies. Record incomplete coverage and zero results honestly; never infer a complete Amazon/Noon/Temu catalogue.
- [ ] Verify missing-key, denied-permission, provider quota/error, and local monthly-cap states show useful browser/manual fallback. Do not consume hundreds of live credits to test the cap; use the automated injected-budget/transport tests for that boundary.
- [ ] Cancel a search and quickly start another; old results must not replace the new state. Relaunch after results/zero results and inspect provenance.
- [ ] Revoke permission and clear the key; future search should ask again and require a key. Confirm no credential appears in exports, app diagnostics, or screenshots. Use the provider account to revoke temporary credentials after testing if appropriate.

## Camera and hardware

- [ ] Deny camera access on a LiDAR iPhone; check the actionable state and dismissal. Grant it in system Settings and retry.
- [ ] Scan, finish, review, accept, and relaunch. Record actual complete/partial quality.
- [ ] Accept an incomplete scan and confirm boundary fit is withheld. Cancel another scan, background/resume, and start again without a stale callback/crash.
- [ ] In physical AR, detect a surface and place/adjust the chair. Compare against a known measured reference for gross scaling errors; this is a dimensional preview, not precision measurement.
- [ ] On a supported non-LiDAR iPhone, sample/import remain usable and scanning is honestly unavailable. Check the smallest available screen, increased text, keyboard dismissal, menus, sheets, and accessibility labels. Do not claim an App Store accessibility capability before testing its full flow.

## Outcome

- Final outcome: **Not yet recorded**.
- Failures, fix/source references, and focused retest evidence: to record.
- Hardware/model/provider limitations: to record.

Keep [APP_STORE.md](APP_STORE.md) and [PRIVACY.md](PRIVACY.md) aligned with the final tested candidate. App Store distribution and Apple's review remain optional future work.
