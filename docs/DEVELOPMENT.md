# Development and reproducibility

This repository can be built and demonstrated without the author's phone, credentials, server, or an App Store account. Samples and geometry tests do not call live providers. Hosted AI/search are optional integrations configured by each user.

Start with [architecture](ARCHITECTURE.md) for the module boundaries, [user guide](USER_GUIDE.md) for the app workflow, and [validation](VALIDATION.md) for the evidence actually collected. Instructions below describe the checked-in tooling, not a guarantee of support for every host platform.

## Toolchain and platform scope

| Component | Required for | Current repository configuration |
| --- | --- | --- |
| JDK 21 | Kotlin/JVM, desktop, shared framework build | `JAVA_HOME` or locally discovered Homebrew/IDE JDK |
| Gradle | All Kotlin tasks | Checked-in wrapper, Gradle 9.3.0 |
| Kotlin | Shared/JVM/native compilation | 2.3.21, declared in the root build |
| Compose Multiplatform | Desktop UI | 1.11.1 |
| Koog | Optional desktop Groq requirements agent | 1.2.0 |
| Python 3 | Desktop launcher and project/release validation | No third-party Python package required by these scripts |
| Xcode and iOS Simulator runtime | iPhone compile/test | Local verification used Xcode 27.1; deployment target is iOS 17 |
| Apple-silicon native target | Checked-in iPhone framework paths | `iosArm64` and `iosSimulatorArm64` |

The native build scripts currently select ARM64 Simulator output. An Intel-only Mac would need an added Kotlin `iosX64` target and matching Xcode/framework-script configuration; that path is not implemented or verified. The Compose/JVM desktop source uses the current host's Compose artifact, but the recorded desktop verification was on macOS. Do not infer Windows/Linux distribution testing from a JVM compile or a macOS smoke test.

The shared module additionally declares `macosArm64`; the desktop companion itself consumes the shared JVM artifact, not that native framework.

## Initial checkout

Clone the canonical repository URL shown in the README and enter its root. Dependency downloads require network access on the first build. Use the included wrapper rather than a separately installed Gradle version.

```sh
java -version
python3 --version
./gradlew --version
```

The shell helpers discover common Homebrew JDK locations when `JAVA_HOME` is unset or missing. A valid but older `JAVA_HOME` is not automatically upgraded, so explicitly select a JDK 21 installation if `java -version` reports an older runtime. Keep `JAVA_HOME` as the JDK root rather than its `bin` directory.

For Xcode tools, the scripts default to `/Applications/Xcode.app/Contents/Developer`. Override `DEVELOPER_DIR` for another installed Xcode without changing the machine's global developer-tool selection:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun simctl list devices available
```

## Run the iPhone frontend

Open `iosApp/FitCheck.xcodeproj`, select the shared **FitCheck** scheme, choose an available ARM64 iPhone Simulator, and Run. The app/product identifiers retain the historical internal `FitCheck` name; the display name is RoomWise.

Xcode invokes `scripts/framework-for-xcode.sh` before compiling Swift. The script selects the Kotlin device/simulator target and Debug/Release framework. The linked framework is `FitCheckShared`; the project contains the matching search path and linker configuration. It also runs `generate-local-secrets.py`, which always writes a nil-only compatibility stub in every configuration. No local API credentials are bundled.

The shell phase declares the generated compatibility source as an output. This dependency is required for a clean checkout: the file does not need to exist before Xcode plans the build. Keep that output declaration when editing the project rather than checking the generated file into Git.

The iPhone app defaults to labelled sample mode. Use Connections to save personal keys when exercising automatic search. `config.local.properties` is **not** an iPhone credential loader.

Physical-device signing is optional for the repository workflow. If you choose to install on your own iPhone, use a team/bundle identifier your account can sign; Simulator and unsigned compile checks do not establish that a device provisioning profile exists. LiDAR and AR acceptance are documented separately in [device acceptance](DEVICE_ACCEPTANCE.md).

## Run the desktop companion

The recommended entry point is:

```sh
sh scripts/run-desktop.sh
```

It delegates to `scripts/launch.py`, which builds the host-specific application JAR before collecting keys, removes provider-secret environment values from the Gradle child, and then starts the desktop process with only the selected session's credentials. Interactive launches offer `fixture`, `local`, or `groq`; Enter/noninteractive input defaults to the offline fixture mode. The JAR selection follows the current operating system and architecture.

For development, `./gradlew :desktop:run` directly runs the Compose app. This bypasses the Python launcher's environment isolation: do not use a direct Gradle run with provider keys exported if you want to keep those values outside the Gradle process.

The desktop initially shows an import/sample choice. Choose **Explore sample room** to populate the room and chairs. A default launch does not perform live shopping automatically.

## Own-key configuration

The free workflow uses a personal Groq key for request interpretation and a personal Tavily key for retailer discovery. The supported model is `openai/gpt-oss-20b` hosted by Groq. No developer-shared key is needed. See [shopping](SHOPPING_PIPELINE.md) for provider boundaries, quotas, and differences between platforms.

| Configuration source | Applies to | Persistence |
| --- | --- | --- |
| iPhone Connections | Groq and Tavily fields | Device Keychain when saved |
| Desktop Connections | Provider/model/key fields | Current app session memory |
| Desktop environment | `GROQ_API_KEY`, `GROQ_MODEL`, `TAVILY_API_KEY`; optional `FITCHECK_PROVIDER` | Managed by the caller's environment |
| Ignored `config.local.properties` | Desktop runtime only | Local plaintext file controlled by the developer |

```sh
cp config.example.properties config.local.properties
```

Edit the ignored copy locally if you choose file-based desktop configuration. Do not add real values to the example or tracked source. Desktop environment values take precedence over local configuration. The runtime supports explicit configuration paths through `ROOMWISE_CONFIG_PATH` or the `roomwise.config` JVM property; read `Shopping.kt` before extending precedence rules.

Free provider plans are external account settings. Choose their free plans and do not enable paid billing for a zero-cost setup. A repository's local request cap cannot determine whether a supplied key belongs to a paid account or how much quota other applications used.

## Verification commands

Run checks appropriate to the changed behavior:

```sh
sh scripts/check.sh
sh scripts/check-ios.sh
sh scripts/release-check.sh
```

| Command | What it checks | What it does not establish |
| --- | --- | --- |
| `check.sh` | Shared JVM tests, desktop shopping tests, Compose UI smoke tests, desktop Kotlin compilation | Device behavior, authenticated provider success, or cross-platform distribution |
| `check-ios.sh` | Unsigned Debug device compilation, available iPhone Simulator selection, XCTest and hosted SwiftUI render tests | Signed installation, full touch-driven navigation, camera/LiDAR accuracy, or App Store acceptance |
| `release-check.sh` | Checked-in Xcode references/schemes, app resources/version/privacy expectations, current-source credential patterns | Complete historical secret removal or provider credential revocation |

The XCTest provider tests inject `HTTPTransport` responses; do not supply real keys to run them. Hosted render tests attach compact/large screenshots to the `.xcresult`. Images verify renderability/layout within their covered views, not physical AR tracking or a full interactive UI test.

Gradle reports are written under each module's ignored `build/` directory. Xcode reports and `.xcresult` bundles appear under its DerivedData output. Consult `docs/VALIDATION.md` rather than assuming a previous test count or result still applies after code changes.

## Optional local archive

```sh
sh scripts/archive-ios.sh --unsigned
```

The command first performs source checks, then creates a Release `.xcarchive` without uploading. Supply a different archive path when one already exists; the script preserves existing archives. Its post-build checks inspect required version/icon metadata, privacy resources, and the nil-only compatibility stub. An unsigned archive is a build artifact, not an installable signed IPA or an App Store submission.

Without `--unsigned`, normal Xcode signing requirements apply. Future store materials are in [App Store preparation](APP_STORE.md); they are separate from source-publication and local development.

## CI

`.github/workflows/verify.yml` runs source checks, shared/desktop checks, and unsigned iPhone/XCTest verification on its configured macOS runner. It uses no provider secrets. The job explicitly skips private repositories to avoid private macOS runner billing. A prepared workflow and local success are different from an observed remote CI run; the validation record states which has occurred.

## Troubleshooting

| Symptom | Likely boundary and next check |
| --- | --- |
| Java/Gradle compatibility error | Confirm a JDK 21 `JAVA_HOME`; a valid old JDK may prevent autodiscovery |
| `xcodebuild` uses Command Line Tools only | Set `DEVELOPER_DIR` to a full Xcode installation and check its version |
| No iPhone Simulator found | Install an iOS runtime in Xcode and confirm `xcrun simctl list devices available` |
| Missing `FitCheckShared` module | Inspect the framework build phase output and the target/configuration-specific `shared/build/bin/` folder |
| Intel Simulator link failure | Only ARM64 iPhone Simulator framework wiring is implemented |
| Device provisioning failure | Use Simulator/unsigned verification, or configure signing for your own account/device |
| Room import rejected | Check the [schema](ROOM_FORMAT.md), UTF-8 JSON, units, coordinate marker, transform agreement, and geometry bounds |
| Unknown price/dimensions | Inspect explicit source evidence; add assembled dimensions manually rather than weakening ambiguity rules |
| Groq model/key/quota error | Verify your own free account; local interpretation is the intended fallback |
| Tavily key/quota error | Use browser/manual entry; do not add retries or paid escalation merely to hide the limit |
| Tests pass but hardware behavior differs | Hosted rendering and mocks have narrower coverage; record and reproduce the hardware issue separately |

## Extension points

- **New retailer:** extend `Retailer` and URL tests, both provider implementations, iPhone's explicit store list and browser URL builder, then reconsider its three-call reservation and privacy disclosure. Do not assume an added enum automatically updates every frontend.
- **New product category:** update requirements validation, category filters, evidence rules, UI copy, preview geometry, and tests. The current category and illustrative mesh are chair-specific.
- **New model/provider:** add a validated, tested interpretation adapter with an explicit data boundary. Preserve local product facts and fit calculations. A different provider needs updated consent and privacy documentation.
- **Geometry improvements:** add adversarial tests for a concrete failure first. Clearance buffers, spatial indexing, mesh-aware collision, and layout optimization are possible future work, not present features.
- **Persistence/schema changes:** preserve old version handling or explicitly version the room contract; keep `USER_ENTERED`, fixture, and retrieved provenance distinct.

See [contributing](../CONTRIBUTING.md) for pull-request expectations and evidence handling.
