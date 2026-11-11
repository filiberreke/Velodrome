"""Reject bundles containing Mach-O files or app plists requiring newer macOS."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess

MACHO = {bytes.fromhex(value) for value in (
    "feedface", "cefaedfe", "feedfacf", "cffaedfe",
    "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}


def version(value):
    parts = tuple(map(int, value.split(".")))
    return (parts + (0, 0, 0))[:3]


def deployment_versions(output):
    versions = []
    for block in re.split(r"^Load command \d+\s*$", output, flags=re.M):
        if re.search(r"^\s*cmd LC_BUILD_VERSION\s*$", block, re.M):
            field = "minos"
        elif re.search(r"^\s*cmd LC_VERSION_MIN_MACOSX\s*$", block, re.M):
            field = "version"
        else:
            continue
        versions.extend(re.findall(r"^\s*" + field + r"\s+(\d+(?:\.\d+){1,2})\s*$", block, re.M))
    return versions


def verify(root, maximum):
    entries = []
    errors = []
    seen = set()
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.resolve() in seen:
            continue
        seen.add(path.resolve())
        if path.name == "Info.plist":
            with path.open("rb") as source:
                info = plistlib.load(source)
            versions = []
            if info.get("LSMinimumSystemVersion"):
                versions.append(info["LSMinimumSystemVersion"])
            versions.extend(info.get("LSMinimumSystemVersionByArchitecture", {}).values())
            if versions:
                entries.append({"path": str(path.relative_to(root)), "kind": "plist", "minimum_versions": versions})
                if any(version(v) > version(maximum) for v in versions):
                    errors.append(f"{path}: app minimum {versions} exceeds {maximum}")
        with path.open("rb") as source:
            if source.read(4) not in MACHO:
                continue
        output = subprocess.check_output(["otool", "-arch", "all", "-l", str(path)], text=True)
        versions = deployment_versions(output)
        if not versions:
            errors.append(f"{path}: no macOS deployment target found")
        if any(version(v) > version(maximum) for v in versions):
            errors.append(f"{path}: binary minimum {versions} exceeds {maximum}")
        entries.append({"path": str(path.relative_to(root)), "kind": "Mach-O", "minimum_versions": versions})
    if not any(entry["kind"] == "Mach-O" for entry in entries):
        errors.append("No Mach-O binaries found")
    return {"maximum": maximum, "files": entries, "errors": errors}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--maximum", default="12.0")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.root, args.maximum)
    args.report.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"Audited {len(result['files'])} binaries/plists for macOS {args.maximum}")
    for error in result["errors"]:
        print(error)
    if result["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
