# RoomWise walkthrough

The project can be demonstrated from a clean clone with no physical device or provider account.

1. Open the FitCheck scheme on an iPhone Simulator, or run `sh scripts/run-desktop.sh`.
2. Start with the labelled sample room and sample chairs. Select a chair, rotate it, move it, and show the geometry result. Fit reflects captured floor footprints only.
3. Open Edit and enter assembled dimensions. Show how a chair that crosses a wall or another object changes the fit result. Recenter restores a candidate placement, without claiming an optimal layout.
4. On iPhone, Add chair accepts a name, optional retailer product URL, optional pasted listing text, and your own assembled dimensions. User-entered provenance survives relaunch.
5. Import a validated room JSON and export it for transfer. A partial scan is visualized with boundary fit withheld. Invalid files preserve the current room.
6. Optional automatic shopping: add personal Groq Free and Tavily Researcher keys in Connections, disable Sample mode, consent to sharing, and search. Groq interprets preferences; Tavily basic search supplies validated retailer listing evidence. Unobserved price/dimensions remain unknown. Missing Groq uses an honestly labelled offline parser.
7. Explain limits: three basic Tavily requests reserved per search, 300 per install per UTC month, no retry/paid escalation, and retailer search links/manual entry when provider quotas fail.
8. Help & Privacy exposes the policy, provider-sharing revocation, saved-data deletion, and support contact. Keys are cleared separately in Connections.

Physical LiDAR scanning and real camera AR are optional hardware demonstrations. Simulator AR is explicitly labelled rehearsal. The AR chair is a simplified volume at the selected dimensions, rather than a retailer-specific 3D model.

Do not use historical demo credentials. Live provider tests need the presenter’s own free accounts and are not part of the automated suite.
