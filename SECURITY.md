# Security and private data

For a suspected security issue, contact **info.roomwise@gmail.com**. Describe the affected commit, component, reproduction steps, and impact. Do not post real API keys, signing credentials, personal room files, private pairing links, chat transcripts, or other private data in a public issue or pull request.

RoomWise is a software prototype. Its current checks and data boundaries are documented in [privacy](docs/PRIVACY.md), [architecture](docs/ARCHITECTURE.md), and [validation](docs/VALIDATION.md). There is no claim of a security certification, guaranteed response time, or production hardening.

The public repository starts from a reviewed source snapshot rather than importing the earlier private Git history. It excludes local provider configuration and generated Swift credential sources. This does not revoke credentials that were shared during earlier development. Credential owners should revoke/rotate those keys through the relevant provider accounts.

Before contributing, run:

```sh
python3 scripts/check-public-source.py
sh scripts/release-check.sh
```

The public-source scanner reports configured credential signatures, personal paths, and selected image metadata markers without printing matched values. It inspects current files or explicitly supplied source exports, not Git history or provider account status. A passing result is bounded inspection evidence, not proof that every possible secret has been found.

Do not embed a shared provider key to make a public demo work. Use the account-free samples, or supply personal free-tier keys at runtime. Private room geometry belongs in user-controlled files, not test fixtures or public screenshots.

## Optional local pairing

Desktop pairing starts a temporary built-in HTTP listener only when the user chooses **Start pairing**. The phone connects using a private URL containing a random 128-bit bearer token. The endpoint shares the current product list, evidence/provenance, selected product ID, and revision. It supports selecting a known session product ID. It does not expose room coordinates, camera data, chat history, provider keys, filesystem access, a shell, or an arbitrary URL proxy.

This is **plain HTTP for a trusted local network**, not encrypted internet transport. Anyone able to reach the listener and obtain the bearer link can read product state and change selection; a compromised network/device can observe or alter traffic. Do not post the URL in public issues, screenshots, logs, or recordings. Do not forward its port, publish a tunnel, or use an untrusted Wi-Fi network.

The host accepts local/private peers, validates the token, bounds state to 50 distinct products and selection bodies to 4 KiB, and rejects unknown product IDs and browser-origin mutations. The native phone validates local pairing URLs and does not follow redirects that could send the token to another host. These checks reduce the exposed interface; they do not provide encryption, device identity, resistance to every denial of service, or a comprehensive security guarantee.

**Stop pairing** closes the listener and invalidates its token. A restarted desktop session has a new link. Disconnecting the phone stops its polling; backgrounding and repeated polling failures also end the phone connection. Disconnecting one phone does not stop a desktop session that is still enabled. The phone retains its own accepted room, so pairing is not a room-transfer or AR-alignment mechanism. See [the protocol and user workflow](docs/LIVE_SHOPPING.md).

## Chat, browsing, and credentials

Hosted Groq conversation receives bounded recent messages and accepted shopping preferences, not room geometry, catalog excerpts, or fit results. On iPhone, up to 40 recent chat messages/preferences are saved locally and cleared by New chat or local planning-data deletion; at most twelve recent messages, bounded to 1,500 characters each, are sent per turn. Desktop chat is session-only. Treat a user-supplied transcript as potentially private even though the model does not receive room data automatically.

Retailer pages load explicitly. The iPhone uses an ephemeral web-data store; following another retailer page, variant-related URL query/fragment change, or same-document navigation pauses the preview rather than treating unvalidated browsing as known product dimensions. External browsers and retailer websites have their own cookies, account, and security boundaries. RoomWise does not observe arbitrary browser tabs or process checkout.

Provider keys authenticate only to their respective services. iPhone keys use Keychain; local desktop configuration, if supplied, is plaintext controlled by its owner. Keys are excluded from room files and pairing snapshots. Neither removing a key from a current source tree nor clearing a local app key revokes a credential already issued by a provider; revoke exposed values in the provider account.
