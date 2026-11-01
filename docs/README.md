# RoomWise documentation

RoomWise is a collaborative software prototype for checking a chair's floor footprint against captured room geometry. The public source includes iPhone and desktop frontends, shared Kotlin contracts, an account-free sample workflow, and optional free-tier provider setup.

## Choose a starting point

| You want to… | Read |
| --- | --- |
| Run and use the app | [User guide](USER_GUIDE.md) |
| Build a clone or troubleshoot a toolchain | [Development guide](DEVELOPMENT.md) |
| Present a short demonstration | [Demo walkthrough](DEMO.md) |
| Understand the component/data boundaries | [Architecture](ARCHITECTURE.md) |
| Inspect geometry, placement, and mathematical limits | [Geometry](GEOMETRY.md) |
| Import/export or generate a room file | [Room JSON contract](ROOM_FORMAT.md) |
| Understand free-tier LLM and retailer requests | [Shopping pipeline](SHOPPING_PIPELINE.md) |
| Review actual test/build evidence | [Validation record](VALIDATION.md) |
| Read a project-level technical narrative | [Case study](CASE_STUDY.md) |
| Feature RoomWise on a CV or portfolio | [Prepared portfolio copy](PORTFOLIO.md) and [claim ledger](CLAIMS.md) |
| Identify the team and public source provenance | [Contributors](CONTRIBUTORS.md) |
| Review data handling and public release checks | [Privacy](PRIVACY.md) and [public-release notes](PUBLIC_RELEASE_CHECKLIST.md) |
| Contribute a change or report a security issue | [Contributing](../CONTRIBUTING.md) and [security](../SECURITY.md) |
| Consider later store distribution | [Future App Store packet](APP_STORE.md) and [optional hardware acceptance](DEVICE_ACCEPTANCE.md) |

## Evidence conventions

Implementation descriptions refer to the current source. Test counts refer to the recorded engineering suite, with provider behavior checked using local HTTP mocks. Hosted screenshots show synthetic samples and empty settings; they are not evidence of live catalog results or physical scanning accuracy. The claim ledger links specific technical statements to source/tests and separates unsupported impact or deployment claims.

No Apple Intelligence-capable phone, private author account, or paid subscription is needed to build and demonstrate the sample. Camera/LiDAR requirements apply to the optional physical capture/AR workflows. Live search uses each user's own Groq and Tavily free-tier keys, within provider quotas.
