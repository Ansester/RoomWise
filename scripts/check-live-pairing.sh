#!/bin/sh
# Real desktop-JVM host to native iPhone Simulator client, without providers or hardware.
set -eu
cd "$(dirname "$0")/.."
exec python3 - "$@" <<'PY'
import fcntl
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import signal
import subprocess
import sys
import tempfile
import time
import uuid

root = Path.cwd()
sys.dont_write_bytecode = True
sys.path.insert(0, str(root / "scripts"))
import launch

if platform.system() != "Darwin":
    raise SystemExit("This check needs macOS, Xcode, an iPhone Simulator, JDK 21, and Python 3.")

build = root / "build"
build.mkdir(exist_ok=True)
lock = (build / "live-pairing.lock").open("w")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit("A live-pairing check is already running in this checkout.")

java_home, java = launch.find_java()
if not java_home or not (Path(java_home) / "bin/javac").is_file():
    raise SystemExit("A JDK with java and javac is required. Set JAVA_HOME to JDK 21.")
environment = launch.without_provider_secrets(os.environ)
environment["JAVA_HOME"] = java_home
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
environment["FITCHECK_PROVIDER"] = "fixture"
secret_values = []

def interrupted(signum, frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, interrupted)

def stop_process(process):
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()

def redact(value):
    for secret in secret_values:
        value = value.replace(secret, "[temporary pairing secret]")
    return re.sub(r"(?<=/session/)[a-f0-9]{32}", "[temporary pairing secret]", value)

def run_logged(command, log_name, timeout=900):
    process = subprocess.Popen(command, cwd=root, env=environment, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout)
    except KeyboardInterrupt:
        stop_process(process)
        output, _ = process.communicate()
        (build / log_name).write_text(redact(output), encoding="utf-8")
        raise
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            output, _ = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
        output = redact(output)
        (build / log_name).write_text(output, encoding="utf-8")
        print("\n".join(output.splitlines()[-25:]), flush=True)
        raise RuntimeError("A check timed out; inspect build/" + log_name)
    output = redact(output)
    (build / log_name).write_text(output, encoding="utf-8")
    if process.returncode:
        print("\n".join(output.splitlines()[-25:]), flush=True)
        raise RuntimeError("Check failed; inspect build/" + log_name)
    return output

host = None
injected_run = None
try:
    available = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"], env=environment, text=True))
    devices = [device for group in available["devices"].values() for device in group
               if device.get("isAvailable") and device.get("name", "").startswith("iPhone")]
    requested = environment.get("ROOMWISE_SIMULATOR_ID")
    if requested:
        devices = [device for device in devices if device["udid"] == requested]
    if not devices:
        raise RuntimeError("No available iPhone Simulator found.")
    selected_device = next((device for device in devices if device.get("state") == "Booted"), devices[0])
    simulator = selected_device["udid"]
    destination = "platform=iOS Simulator,id=" + simulator
    derived = build / "live-pairing-derived-data"

    print("Preparing the iPhone Simulator before starting the temporary pairing host…", flush=True)
    if selected_device.get("state") != "Booted":
        run_logged(["xcrun", "simctl", "boot", simulator], "live-pairing-simulator-boot.log", timeout=60)
    run_logged(["xcrun", "simctl", "bootstatus", simulator, "-b"], "live-pairing-simulator-ready.log", timeout=300)

    print("Building the real desktop host and native Simulator test…", flush=True)
    run_logged([str(root / "gradlew"), "--no-daemon", ":desktop:packageUberJarForCurrentOS", "--console=plain"],
               "live-pairing-desktop-build.log")
    run_logged(["xcodebuild", "build-for-testing", "-project", "iosApp/FitCheck.xcodeproj", "-scheme", "FitCheckTests",
                "-destination", destination, "-derivedDataPath", str(derived),
                "-only-testing:FitCheckTests/LiveShoppingTests/testActualJVMDesktopPairing"],
               "live-pairing-native-build.log")
    architecture = {"aarch64": "arm64", "arm64": "arm64", "x86_64": "x64"}.get(platform.machine().lower(), platform.machine().lower())
    jars = list((root / "desktop/build/compose/jars").glob("*-macos-" + architecture + "-*.jar"))
    if not jars:
        raise RuntimeError("The desktop application JAR was not produced.")
    jar = max(jars, key=lambda path: path.stat().st_mtime)
    run_files = [path for path in (derived / "Build/Products").glob("*.xctestrun") if not path.name.startswith(".")]
    if not run_files:
        raise RuntimeError("Xcode did not produce an XCTest run configuration.")
    original_run = max(run_files, key=lambda path: path.stat().st_mtime)

    with tempfile.TemporaryDirectory(prefix="roomwise-live-pairing-") as temp:
        temporary = Path(temp)
        os.chmod(temporary, 0o700)
        run_logged([str(Path(java_home) / "bin/javac"), "-cp", str(jar), "-d", str(temporary),
                    str(root / "scripts/LivePairingFixture.java")], "live-pairing-fixture-build.log", timeout=60)
        endpoint_file = temporary / "endpoint"
        with (temporary / "host.log").open("w") as host_log:
            host = subprocess.Popen([java, "-cp", str(jar) + os.pathsep + str(temporary),
                                     "LivePairingFixture", str(endpoint_file)],
                                    cwd=root, env=environment, stdout=host_log, stderr=subprocess.STDOUT,
                                    start_new_session=True)
            deadline = time.monotonic() + 8
            while not endpoint_file.is_file() and host.poll() is None and time.monotonic() < deadline:
                time.sleep(0.05)
            if not endpoint_file.is_file():
                raise RuntimeError("The temporary desktop fixture host did not start.")
            endpoint = endpoint_file.read_text(encoding="utf-8").strip()
            if not re.fullmatch(r"http://127\.0\.0\.1:[0-9]+/session/[a-f0-9]{32}", endpoint):
                raise RuntimeError("The fixture host returned an invalid local endpoint.")
            secret_values.extend([endpoint, endpoint.rsplit("/", 1)[-1]])

            with original_run.open("rb") as handle:
                configuration = plistlib.load(handle)
            updated = []
            def inject(value, key=""):
                if isinstance(value, dict):
                    name = value.get("BlueprintName", key)
                    bundle = value.get("TestBundlePath", "")
                    if name == "FitCheckTests" or str(bundle).endswith("/FitCheckTests.xctest"):
                        value.setdefault("EnvironmentVariables", {})["ROOMWISE_TEST_PAIRING_URL"] = endpoint
                        updated.append(True)
                    for child_key, child in list(value.items()):
                        inject(child, child_key)
                elif isinstance(value, list):
                    for child in value:
                        inject(child)
            inject(configuration)
            if not updated:
                raise RuntimeError("Could not locate the native test target in Xcode's run configuration.")
            # Keep __TESTROOT__ relative paths valid. The injected copy is removed in finally.
            injected_run = original_run.parent / (".RoomWiseLivePairing-" + uuid.uuid4().hex + ".xctestrun")
            descriptor = os.open(injected_run, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "wb") as handle:
                plistlib.dump(configuration, handle)
            print("Checking native receive → phone selection → desktop publish over real local HTTP…", flush=True)
            output = run_logged(["xcodebuild", "test-without-building", "-xctestrun", str(injected_run),
                                 "-destination", destination, "-parallel-testing-enabled", "NO",
                                 "-only-testing:FitCheckTests/LiveShoppingTests/testActualJVMDesktopPairing"],
                                "live-pairing-native-test.log", timeout=600)
            passed = re.search(r"testActualJVMDesktopPairing[^\n]*\bpassed\b", output, re.IGNORECASE)
            if not passed:
                raise RuntimeError("The actual JVM pairing test did not report a pass; inspect build/live-pairing-native-test.log.")
            print("PASS: native client received JVM fixtures, sent selection B, and followed JVM publish C. No providers or physical device used.", flush=True)
except (OSError, RuntimeError, subprocess.SubprocessError) as error:
    print(redact(str(error)), file=sys.stderr)
    sys.exit(1)
except KeyboardInterrupt:
    print("Live-pairing check interrupted; temporary host and session files are being removed.", file=sys.stderr)
    sys.exit(130)
finally:
    if host is not None:
        stop_process(host)
    if injected_run is not None:
        injected_run.unlink(missing_ok=True)
PY
