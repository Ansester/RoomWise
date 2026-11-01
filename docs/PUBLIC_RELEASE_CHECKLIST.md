# Public source release

RoomWise can be presented as a software prototype with source and reproducible engineering checks. Public source availability, an open-source licence, live-provider verification, and App Store distribution are separate states.

## Published copy

| Item | Verified state |
| --- | --- |
| Canonical source | [Ansester/RoomWise](https://github.com/Ansester/RoomWise) |
| Visibility | Public; accessible without authentication |
| Default branch | `main` |
| Initial public history | Independent source snapshot; initial commit `dbe4f3e` has no parent |
| Private history | Not imported; original team repository remains separate |
| Earlier tested source revision | `8da670f`; this predates the contextual-chat/pairing expansion. See [current validation](VALIDATION.md) for later evidence. |
| Earlier public verification | [GitHub Actions passed](https://github.com/Ansester/RoomWise/actions/runs/41286710634), including 41 iOS tests and shared/desktop checks |
| Portfolio material | [CV and website copy](PORTFOLIO.md), [case study](CASE_STUDY.md), and [claim ledger](CLAIMS.md) |

The public source tree and every public commit snapshot present during the release audit passed the configured source-export checks. Contributors remain credited. No permissive reuse licence, App Store release, live-provider evaluation, or user-outcome result is implied by publication.

## Current release route

The original repository contains historical demo credentials. Deleting `config.local.properties` from the latest source does not remove that file from earlier commits. This audit did not read or test the old credential values, and their revocation status is unknown.

For a public portfolio copy, export the reviewed current commit into a new directory and initialise a new repository there. Do not copy the original `.git` directory, ignored local configuration, generated Swift secrets, build outputs, or local app data. Preserve the project contributors' credit in the public copy. The original private repository can remain intact; this avoids an uncoordinated history rewrite and does not expose its historical credential blobs through the new repository.

This route does not revoke credentials or erase copies of the old history. Their owner should still revoke/rotate the historical keys. GitHub recommends revocation/rotation as the first response to committed credentials and documents the limitations and collaborator impact of history rewriting. [GitHub sensitive-data guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

Changing the original repository's visibility requires repository administration permission. A push-capable collaborator may prepare commits but cannot assume control over the owner's visibility setting. [GitHub repository roles and visibility](https://docs.github.com/en/repositories/creating-and-managing-repositories/about-repositories).

## Reusable source checks

Run these against the finished documentation/source state:

```sh
python3 scripts/check-public-source.py
sh scripts/release-check.sh

# Run the same bounded inspection on an isolated export or source ZIP.
python3 scripts/check-public-source.py --directory /absolute/path/to/clean-source
python3 scripts/check-public-source.py --archive /absolute/path/to/RoomWise-source.zip
```

The public-source checker inspects current tracked and nonignored files by default. In export modes it inspects all supplied files, rejects included history/local configuration/build artifacts, and reports configured credential signatures, personal absolute paths, and location/path markers in PNG metadata. It prints file paths and categories, never matched values. It does not contact providers or inspect Git history. It is a bounded aid, not proof that every possible secret or sensitive fact has been found.

## Inspection performed on November 1, 2026

- Current tracked text/binary files contained no matches for the configured provider-token, GitHub-token, private-key, AWS-access-ID, or personal absolute-path signatures.
- The two committed UI images show synthetic sample data or empty provider settings. Their PNG EXIF/XMP metadata contained generic screenshot descriptors, with no observed GPS, personal path, email, or author fields. The generated icons contained no textual metadata chunks.
- The Xcode project retains a development-team identifier and original device bundle identifier. These identifiers are not provider credentials. Simulator/unsigned verification does not depend on that team's signing profile; installing on a physical device uses the installer's own signing setup.
- The user-approved support address, `info.roomwise@gmail.com`, is intentionally public contact information.
- Git author names identify multiple contributors. Public documentation should preserve that credit and avoid claiming sole authorship without a separately established contribution account.
- No project `LICENSE` file was present at audit time. Do not describe the project as permissively licensed or choose a licence for other contributors without authority. GitHub distinguishes public visibility from an open-source licence. [GitHub licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

## Portfolio evidence boundaries

Use the current [validation record](VALIDATION.md) and [claim ledger](CLAIMS.md) for test counts, source anchors, and limitations. Automated provider checks use HTTP mocks; they are not live model, retailer-coverage, or pricing validation. Hosted UI renders are not physical LiDAR/AR acceptance tests. The existing archive is an unsigned build artifact, not a published app or signed installable IPA.

The table above records the initial publication checks and earlier public CI outcome. It does not establish that later contextual-chat, carousel, and pairing changes passed; their current evidence belongs in [validation](VALIDATION.md). Repeat the current-source/export checks for later releases and keep remote results separate from local evidence. Documentation-only updates after the tested source revision do not change its application code.
