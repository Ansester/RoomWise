# Privacy policy publication copy

Prepared for optional future publication. Local support/privacy pages are in `docs/store-site/`; they have not been hosted. If the app is published later, host this policy at a stable public HTTPS URL and use it in App Store Connect. Keep in-app Help & Privacy and this policy synchronized.

---

# RoomWise Privacy Policy

Last updated: November 1, 2026

RoomWise connects a shopping conversation, product-page browsing, and a dimension-based room preview on your iPhone. No RoomWise account is required. Each user can optionally connect personal Groq and Tavily accounts for free-tier contextual conversation and automatic retailer discovery. An optional desktop companion can send product-selection changes to your phone over the local network.

## Room data and camera access

The camera supports Apple RoomPlan scanning and augmented-reality placement. Scanning requires a supported LiDAR-equipped iPhone. RoomWise does not upload or save camera photos.

Accepted scans are stored locally, together with search text, the last 40 shopping messages and accepted preferences, saved/pasted/entered product information, the selected chair, placement, and local search-quota accounting. A room file includes dimensions, coordinates, walls, openings, and recognized furniture. The operating system may include local data in device backups according to device settings. RoomWise does not operate a cloud room-storage service.

Sample rooms and chairs are synthetic examples. Sample planning, scanning, dimension editing, and fit checks need no provider account.

## Optional request interpretation and discovery

After permission and configuration of the relevant personal keys:

- Groq receives up to twelve recent shopping-conversation messages, bounded to 1,500 characters each, and the current structured preferences to generate a reply and refine requirements using a hosted model. The default model is `openai/gpt-oss-20b`, served by Groq; the app does not use the OpenAI API. A clearly labelled limited local conversation fallback is available when Groq is not configured or cannot complete the turn.
- Tavily receives chair-search requirements for retailer discovery through basic search.

Each key is sent only to its respective provider for authentication. Requests are associated with your provider accounts. Neither service receives room coordinate geometry, room counts/fit summaries, or camera images from this pipeline. Pasted listing text and manually entered chair details are processed locally.

Provider policies and account settings govern handling and retention of requests. RoomWise does not promise requests are anonymous or immediately deleted. See [Groq's privacy policy](https://groq.com/privacy-policy), [GroqCloud data handling](https://console.groq.com/docs/your-data), and [Tavily's privacy policy](https://www.tavily.com/privacy).

## Free-tier limits and keys

The automatic workflow is designed for a Groq free-plan account and Tavily Researcher free account. It uses no paid-provider fallback. Tavily requests use basic search with a local monthly cap; no extract, advanced search, or automatic retries are used. Provider account quotas and terms apply. RoomWise cannot control a plan or billing option changed outside the app. If Groq is unavailable, a limited deterministic conversation fallback refines requirements for Tavily search. Changing product pages and local pairing do not make hosted-provider calls. Without a Tavily key or available quota, external retailer links and manual chair entry remain available.

Saved keys are stored in this device's Keychain using device-only, when-unlocked accessibility. They are not sent to a developer-operated server, included in room exports, or intentionally written to app logs. Clear them separately through **Connections**.

## Optional local desktop pairing

When you explicitly start pairing, the desktop companion opens a temporary local HTTP listener and displays a private URL containing a random token. A connected phone polls about every 400 ms and receives the desktop's product list, evidence/provenance, and selected product ID. Selection changes can travel back to the desktop. Neither room coordinates, camera data, chat history, nor provider keys are included in this session.

The phone retains its own room. Pairing does not upload to a RoomWise cloud service or require a RoomWise account. It uses unencrypted HTTP for a trusted local network: someone able to reach the listener and obtain the private URL can read products and change selection. Do not publish the URL, forward the port, or use an untrusted/public network. Stop pairing on desktop to close that session; starting another creates a new token. Disconnecting the phone stops its connection. Backgrounding disconnects the phone; three consecutive polling failures also end its active connection. Desktop chat is session-only, while phone chat is saved locally as described above.

The operating system may ask for local-network permission. Denying it leaves independent local planning available. LAN connection tests and local-network permissions are separate from provider-sharing consent.

## External websites and file sharing

Retailer search/product links open only when you choose to open them. A search URL can contain your requirements. An embedded or external browser and the website then handle the request under their own policies, cookies, account settings, and network practices. RoomWise does not process purchases or receive retailer login credentials.

Exporting a room creates a JSON file for a sharing destination you choose. It contains private room geometry. Copies stored outside RoomWise or sent to another person are managed by that destination.

RoomWise has no developer-operated account service, advertising, cross-app tracking, or analytics SDK.

## Choices and deletion

Use sample/local planning and the local fallback if you prefer not to send conversation or requirements to providers. Start a new chat to clear the active conversation context, and disconnect/stop a paired session when finished. Revoke automatic-search permission in **Help & Privacy**; a later automatic search will ask again. This stops the current app search but cannot undo a request a provider already received.

Choose **Help & Privacy > Delete saved rooms & searches** to remove saved room/search/product/placement data, saved conversation/preferences, and the temporary room-export file. Sample content is then shown again. Clear separately stored provider keys through **Connections**. The local request cap is maintained separately so deleting planning data does not provide extra automatic-search quota.

Exported copies, backups, browser history, and requests already received by providers are managed separately. Use the operating system, browser, sharing destination, retailer, or provider account controls for those records and credential revocation.

## Contact and updates

For support or privacy questions, contact [info.roomwise@gmail.com](mailto:info.roomwise@gmail.com).

If data handling changes, this policy and its update date will be revised. Policy text is also available in the app's **Help & Privacy** screen.
