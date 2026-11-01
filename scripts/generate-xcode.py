#!/usr/bin/env python3
"""Validate the checked-in Xcode project without replacing it.

This command previously generated a prototype project and silently deleted later
source references, test targets and signing configuration. The checked-in project
is now authoritative; edit it in Xcode and retain the resulting diff.
"""
from pathlib import Path
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
project = root / "iosApp/FitCheck.xcodeproj/project.pbxproj"
result = subprocess.run(
    ["plutil", "-convert", "json", "-o", "-", str(project)],
    capture_output=True, text=True, check=True,
)
objects = json.loads(result.stdout)["objects"]
app = objects["A00000000000000000000005"]
tests = objects["A00000000000000000000046"]
assert app["productType"] == "com.apple.product-type.application"
assert tests["productType"] == "com.apple.product-type.bundle.unit-test"
assert "$(SRCROOT)/Generated/LocalDebugSecrets.generated.swift" in objects["A00000000000000000000015"]["outputPaths"], "Declare the generated compatibility source so clean Xcode builds schedule its producer"
for config in ("A00000000000000000000012", "A00000000000000000000013"):
    assert str(objects[config]["buildSettings"]["TARGETED_DEVICE_FAMILY"]) == "1", "App release scope is iPhone only"
for item in objects.values():
    if item.get("isa") == "PBXFileReference" and item.get("sourceTree") == "<group>":
        source = root / "iosApp" / item["path"]
        if item["path"].startswith("Generated/"):
            continue  # The build phase creates these locally.
        if not source.exists():
            sys.exit(f"Missing Xcode source/resource: {item['path']}")
for name in ("FitCheck", "FitCheckTests"):
    ET.parse(project.parent / "xcshareddata/xcschemes" / f"{name}.xcscheme")
print("Xcode project and shared schemes are valid. No files were regenerated.")
