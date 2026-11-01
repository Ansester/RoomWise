#!/usr/bin/env python3
"""Build RoomWise without provider keys, then launch a keyless sample or own-key session."""

import getpass
import os
from pathlib import Path
import platform
import subprocess
import sys

PROVIDER_SECRET_NAMES = {
    "GROQ_API_KEY", "TAVILY_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
    "FITCHECK_LLM_KEY", "FITCHECK_TAVILY_KEY",
}


def find_java():
    candidates = [
        os.environ.get("JAVA_HOME", ""),
        "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home",
        "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home",
        "/Applications/IntelliJ IDEA.app/Contents/jbr/Contents/Home",
    ]
    for candidate in candidates:
        executable = Path(candidate) / "bin/java"
        if candidate and executable.is_file() and os.access(executable, os.X_OK):
            return candidate, str(executable)
    return "", "java"


def without_provider_secrets(environment):
    return {key: value for key, value in environment.items()
            if key not in PROVIDER_SECRET_NAMES and not key.endswith("_API_KEY")}


def read_local_config(path):
    allowed = {"GROQ_API_KEY", "GROQ_MODEL", "TAVILY_API_KEY"}
    result = {}
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = (part.strip() for part in line.split("=", 1))
            value = value.strip("\"'").strip()
            if key in allowed and value:
                result[key] = value
    except (OSError, UnicodeError):
        pass
    return result


def choose_mode():
    # Noninteractive launches and Enter both open the completely offline sample.
    if not sys.stdin.isatty():
        return "fixture"
    try:
        choice = input("Mode [fixture / local / groq] (default: fixture): ").strip().lower()
    except EOFError:
        return "fixture"
    choice = choice or "fixture"
    if choice not in {"fixture", "local", "groq"}:
        raise ValueError("Choose fixture, local, or groq.")
    return choice


def own_key(name, local_config):
    value = os.environ.get(name, "").strip() or local_config.get(name, "")
    if not value and sys.stdin.isatty():
        value = getpass.getpass(f"{name} (hidden; Enter to configure in the app): ").strip()
    return value


def main():
    repo_root = Path(__file__).resolve().parents[1]
    java_home, java_bin = find_java()
    print("RoomWise Desktop")
    print("Sample mode needs no keys. Optional live search uses your own free-plan Groq/Tavily accounts.")
    print("Provider keys are excluded from the build process and are never printed.")

    build_environment = without_provider_secrets(os.environ)
    if java_home:
        build_environment["JAVA_HOME"] = java_home
    result = subprocess.run(
        ["./gradlew", ":desktop:packageUberJarForCurrentOS", "--console=plain"],
        cwd=repo_root, env=build_environment,
    )
    if result.returncode:
        return result.returncode

    system = {"Darwin": "macos", "Windows": "windows"}.get(platform.system(), "linux")
    architecture = {"aarch64": "arm64", "x86_64": "x64", "amd64": "x64"}.get(platform.machine().lower(), platform.machine().lower())
    jars = list((repo_root / "desktop/build/compose/jars").glob(f"*-{system}-{architecture}-*.jar"))
    if not jars:
        print("No application JAR for this platform was produced.", file=sys.stderr)
        return 1
    jar_path = max(jars, key=lambda path: path.stat().st_mtime)
    mode = choose_mode()
    child_environment = without_provider_secrets(os.environ)
    child_environment["FITCHECK_PROVIDER"] = mode
    # Ignore stale settings from older paid-provider launches.
    child_environment.pop("FITCHECK_MODEL", None)
    if mode != "fixture":
        local_config = read_local_config(repo_root / "config.local.properties")
        tavily_key = own_key("TAVILY_API_KEY", local_config)
        if tavily_key:
            child_environment["TAVILY_API_KEY"] = tavily_key
        if mode == "groq":
            groq_key = own_key("GROQ_API_KEY", local_config)
            if groq_key:
                child_environment["GROQ_API_KEY"] = groq_key
            child_environment["GROQ_MODEL"] = os.environ.get("GROQ_MODEL", "").strip() or local_config.get("GROQ_MODEL", "openai/gpt-oss-20b")
        print("Your provider's free-plan quotas apply. RoomWise does not enable paid plans or retry quota failures indefinitely.")
    try:
        return subprocess.run(
            [java_bin, "--enable-native-access=ALL-UNNAMED", "-jar", str(jar_path)],
            cwd=repo_root, env=child_environment,
        ).returncode
    finally:
        child_environment.clear()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nCancelled.")
        sys.exit(130)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
