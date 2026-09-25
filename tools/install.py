#!/usr/bin/env python3
"""Install only PartyTargetWatch; preserve and hash all other addons."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import uuid

from package import ADDON, REPO, regular_files, reject_links, release_payload

# These files belonged to removed addon features and must not survive an upgrade.
RETIRED_FILES = ("Bindings.xml",)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def other_addon_hashes(addons: Path) -> dict[str, str]:
    """Read other addon bytes solely to produce an integrity inventory."""
    hashes: dict[str, str] = {}
    for entry in sorted(addons.iterdir()):
        reject_links(entry)
        if entry.name.casefold() == ADDON.casefold():
            continue
        files = regular_files(entry) if entry.is_dir() else [entry]
        for path in files:
            if not path.is_file():
                raise ValueError(f"Refusing non-regular file: {path}")
            hashes[path.relative_to(addons).as_posix()] = sha256(path)
    return hashes


def write_report(path: Path, report: dict) -> None:
    reject_links(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def install(addons: Path) -> None:
    addons = Path(os.path.abspath(addons.expanduser()))
    reject_links(addons)
    if (addons.name.casefold() != "addons" or
            addons.parent.name.casefold() != "interface" or not addons.is_dir()):
        raise ValueError("--addons-dir must be an existing Interface/AddOns directory")
    if addons.is_relative_to(REPO) or REPO.is_relative_to(addons):
        raise ValueError("Repository and game AddOns directory must not overlap")
    version, interface, payload = release_payload()
    matching = [path for path in addons.iterdir() if path.name.casefold() == ADDON.casefold()]
    if len(matching) > 1:
        raise ValueError("Multiple case variants of the addon directory exist")
    target = matching[0] if matching else addons / ADDON
    reject_links(target)
    if target.exists():
        regular_files(target)
    retired = [name for name in RETIRED_FILES if name not in payload]
    for relative in (*payload, *retired):
        destination = target / relative
        reject_links(destination)
        if destination.exists() and not destination.is_file():
            raise ValueError(f"Install file is occupied by a directory: {destination}")
        if destination.is_file() and destination.stat().st_nlink > 1:
            raise ValueError(f"Refusing hard-linked install file: {destination}")
    report_path = REPO / "validation" / "local-install.json"
    reject_links(report_path)
    backup_root = REPO / "local-backups"
    reject_links(backup_root)
    before = other_addon_hashes(addons)
    report = {
        "addon": ADDON, "version": version, "interface": interface,
        "started_at_utc": datetime.now(timezone.utc).isoformat(),
        "addons_directory": str(addons), "target_directory": str(target),
        "status": "started", "backup_directory": None,
        "other_addon_hashes_before": before,
    }
    write_report(report_path, report)
    failure: Exception | None = None
    try:
        if target.exists():
            suffix = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ") + "-" + uuid.uuid4().hex[:8]
            backup = backup_root / f"{ADDON}-{suffix}"
            reject_links(backup)
            backup_root.mkdir(parents=True, exist_ok=True)
            original = {path.relative_to(target).as_posix(): sha256(path)
                        for path in regular_files(target)}
            shutil.copytree(target, backup)
            copied = {path.relative_to(backup).as_posix(): sha256(path)
                      for path in regular_files(backup)}
            if copied != original:
                raise ValueError("Backup verification failed; installation was not started")
            report["backup_directory"] = str(backup)
            write_report(report_path, report)
        target.mkdir(parents=True, exist_ok=True)
        installed = {}
        for relative, content in sorted(payload.items()):
            destination = target / relative
            reject_links(destination)
            if destination.is_file() and destination.stat().st_nlink > 1:
                raise ValueError(f"Refusing hard-linked install file: {destination}")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
            expected = hashlib.sha256(content).hexdigest()
            if sha256(destination) != expected:
                raise ValueError(f"Installed content verification failed: {relative}")
            installed[relative] = expected
        report["installed_files_sha256"] = installed
        # Only remove explicitly retired files, after the old installation has
        # been backed up and the new payload verified. Preserve other local files.
        removed = []
        for relative in retired:
            destination = target / relative
            reject_links(destination)
            if destination.is_file():
                destination.unlink()
                removed.append(relative)
        report["removed_obsolete_files"] = removed
    except (OSError, ValueError) as error:
        failure = error
        report["error"] = str(error)
    finally:
        try:
            after = other_addon_hashes(addons)
            report["other_addon_hashes_after"] = after
            report["other_addons_unchanged"] = before == after
            if before != after:
                report["other_addon_changes"] = {
                    "added": sorted(after.keys() - before.keys()),
                    "removed": sorted(before.keys() - after.keys()),
                    "modified": sorted(name for name in before.keys() & after.keys()
                                       if before[name] != after[name]),
                }
                failure = ValueError("Other addon inventory changed; see local-install.json")
        except (OSError, ValueError) as error:
            report["other_addons_unchanged"] = False
            report["integrity_check_error"] = str(error)
            failure = error
        report["status"] = "failed" if failure else "success"
        report["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        write_report(report_path, report)
    if failure:
        raise failure
    print(f"Installed {ADDON} {version}: {target}")
    print(f"Verified unchanged other addon files: {len(before)}")
    if report["backup_directory"]:
        print(f"Previous installation backup: {report['backup_directory']}")
    print(f"Local verification report: {report_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addons-dir", required=True, type=Path,
                        help="Existing game Interface/AddOns directory (explicit path required)")
    arguments = parser.parse_args()
    install(arguments.addons_dir)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"Installation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
