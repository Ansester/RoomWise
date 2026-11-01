#!/usr/bin/env python3
"""Generate a nil-only compatibility stub for every iOS build configuration.

The historical prototype embedded repository demo credentials in Debug builds.
Current builds never read config.local.properties and never embed API keys.
Users may enter optional personal Groq and Tavily keys in the app's secure connection
screen. The legacy type remains so historical service regression tests compile.
"""
from pathlib import Path
import os
import tempfile


def main():
    generated_dir = Path(__file__).resolve().parents[1] / "iosApp" / "Generated"
    generated_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    output_path = generated_dir / "LocalDebugSecrets.generated.swift"
    content = """// Generated compatibility stub. No credentials are embedded in any build.
import Foundation

enum LocalDebugSecrets {
    static let openAIKey: String? = nil
    static let tavilyKey: String? = nil
}
"""
    descriptor, temporary_path = tempfile.mkstemp(dir=generated_dir, prefix="secrets_", suffix=".tmp")
    try:
        os.chmod(temporary_path, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, output_path)
        os.chmod(output_path, 0o600)
    finally:
        if os.path.exists(temporary_path):
            os.remove(temporary_path)
    print("Generated nil-only iOS credential compatibility stub (all configurations).")


if __name__ == "__main__":
    main()
