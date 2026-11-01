#!/usr/bin/env python3
"""Inspect a current checkout, clean source directory, or source ZIP for exposure.

This is a bounded signature/path/metadata check, not a claim of secret absence.
It never scans Git history, contacts a provider, or prints matched values.
"""
from __future__ import annotations

import argparse
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import sys
import zipfile


SIGNATURES = {
    "provider credential signature": re.compile(
        rb"\b(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{35,}|tvly-[A-Za-z0-9_-]{20,}|gsk_[A-Za-z0-9_-]{25,})"
    ),
    "GitHub credential signature": re.compile(
        rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})"
    ),
    "private-key block": re.compile(
        rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----"
    ),
    "AWS access identifier": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "personal absolute path": re.compile(
        rb"(?:/Users/(?!Shared/)[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|[A-Za-z]:\\Users\\[A-Za-z0-9._ -]+\\)"
    ),
}


def forbidden_path(name: str, clean_source: bool) -> str | None:
    parts = PurePosixPath(name).parts
    if name.startswith(("/", "\\")) or ".." in parts:
        return "unsafe archive/source path"
    if clean_source and any(part == ".git" for part in parts):
        return "Git history included in clean source"
    if any(part in {"config.local.properties", ".env", ".env.local"} for part in parts):
        return "local credential configuration included"
    if any(part in {"Generated", "DerivedData", ".gradle", ".kotlin", "xcuserdata", "__pycache__"} for part in parts):
        return "generated/runtime state included"
    if "build" in parts or any(part.endswith((".app", ".xcarchive")) for part in parts):
        return "build artifact included in source"
    if name.lower().endswith((".p12", ".p8", ".mobileprovision", ".pem", ".key")):
        return "signing/private credential file included"
    return None


def inspect_png_metadata(data: bytes) -> list[str]:
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return []
    reasons = []
    offset = 8
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        if offset + 12 + length > len(data):
            reasons.append("malformed PNG chunk")
            break
        if kind in {b"eXIf", b"iTXt", b"tEXt", b"zTXt"}:
            if re.search(rb"(?:GPS|Latitude|Longitude|/Users/|/home/)", payload, re.IGNORECASE):
                reasons.append("potential location/path metadata; inspect privately")
        offset += 12 + length
        if kind == b"IEND":
            break
    return reasons


def inspect(name: str, data: bytes, clean_source: bool) -> list[str]:
    reasons = []
    path_reason = forbidden_path(name, clean_source)
    if path_reason:
        reasons.append(path_reason)
    for label, pattern in SIGNATURES.items():
        if pattern.search(data):
            reasons.append(label)
    reasons.extend(inspect_png_metadata(data))
    return reasons


def repository_files(root: Path):
    output = subprocess.check_output(
        ["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard", "-z"]
    )
    for raw_name in sorted(set(output.split(b"\0"))):
        if not raw_name:
            continue
        name = raw_name.decode("utf-8")
        path = root / name
        if path.is_file():
            yield name, path.read_bytes()


def directory_files(root: Path):
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            # Clean exports should contain ordinary files, not links outside the tree.
            yield path.relative_to(root).as_posix(), b""
            continue
        if path.is_file():
            yield path.relative_to(root).as_posix(), path.read_bytes()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--repository", type=Path, help="current tracked/nonignored source; default is this checkout")
    modes.add_argument("--directory", type=Path, help="isolated clean source export; all files inspected")
    modes.add_argument("--archive", type=Path, help="source ZIP; all members inspected")
    args = parser.parse_args()
    failures = []
    count = 0
    if args.archive:
        with zipfile.ZipFile(args.archive) as archive:
            for item in archive.infolist():
                if item.is_dir():
                    continue
                count += 1
                # File names/categories are emitted; matching values are never emitted.
                for reason in inspect(item.filename, archive.read(item), True):
                    failures.append((item.filename, reason))
    else:
        root = (args.directory or args.repository or Path(__file__).resolve().parents[1]).resolve()
        files = directory_files(root) if args.directory else repository_files(root)
        for name, data in files:
            count += 1
            if args.directory and (root / name).is_symlink():
                failures.append((name, "symlink in clean source export"))
                continue
            for reason in inspect(name, data, bool(args.directory)):
                failures.append((name, reason))
    for name, reason in failures:
        print(f"FAIL: {name}: {reason}", file=sys.stderr)
    if failures:
        print(f"Public-source check found {len(failures)} issue(s) across {count} files. No matched values printed.", file=sys.stderr)
        return 1
    print(f"Public-source checks passed across {count} files: configured credential signatures, paths, source packaging, and PNG metadata markers.")
    print("Current/source-export scope only. This does not scan Git history, prove that all secrets are absent, revoke credentials, verify licence rights, or confirm provider billing status.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError, zipfile.BadZipFile, UnicodeError):
        print("Public-source check could not complete. Inspect the selected repository/export privately.", file=sys.stderr)
        raise SystemExit(2)
