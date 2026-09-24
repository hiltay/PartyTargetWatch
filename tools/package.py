#!/usr/bin/env python3
"""Build the addon's release ZIP using only Python's standard library."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import zipfile

ADDON = "PartyTargetWatch"
REPO = Path(os.path.abspath(Path(__file__).parent.parent))
DOCUMENTS = ("README.md", "LICENSE", "CHANGELOG.md")


def reject_links(path: Path) -> None:
    """Reject symlinks and Windows reparse points, including path ancestors."""
    path = Path(os.path.abspath(path))
    for candidate in reversed((path, *path.parents)):
        try:
            info = candidate.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(info.st_mode) or (
            getattr(info, "st_file_attributes", 0)
            & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
        ):
            raise ValueError(f"Refusing symlink/reparse point: {candidate}")


def regular_files(root: Path) -> list[Path]:
    """List regular files without accepting redirected or special entries."""
    reject_links(root)
    if not root.is_dir():
        raise ValueError(f"Expected a directory: {root}")
    result: list[Path] = []
    def fail_walk(error: OSError) -> None:
        raise error

    for directory, directories, filenames in os.walk(root, followlinks=False, onerror=fail_walk):
        for name in sorted(directories + filenames):
            entry = Path(directory) / name
            reject_links(entry)
            if entry.is_file():
                result.append(entry)
            elif not entry.is_dir():
                raise ValueError(f"Refusing non-regular filesystem entry: {entry}")
    return sorted(result)


def release_payload() -> tuple[str, str, dict[str, bytes]]:
    """Validate TOC paths and freeze exactly the files included in a release."""
    source = REPO / ADDON
    files = regular_files(source)
    toc = source / f"{ADDON}.toc"
    reject_links(toc)
    text = toc.read_text(encoding="utf-8-sig")
    metadata: dict[str, str] = {}
    entries: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("##"):
            key, separator, value = line[2:].partition(":")
            if separator:
                metadata[key.strip()] = value.strip()
        elif line and not line.startswith("#"):
            entry = line.replace("\\", "/")
            relative = PurePosixPath(entry)
            if (relative.is_absolute() or ":" in entry or
                    any(part in ("", ".", "..") for part in entry.split("/")) or
                    relative.suffix.lower() != ".lua"):
                raise ValueError(f"TOC must list relative Lua paths only: {line!r}")
            if entry.casefold() in {item.casefold() for item in entries}:
                raise ValueError(f"Duplicate TOC entry: {entry}")
            entries.append(entry)
    version = metadata.get("Version", "")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?", version):
        raise ValueError("TOC has no safe semantic Version value")
    interface = metadata.get("Interface", "")
    if not re.fullmatch(r"\d+(?:\s*,\s*\d+)*", interface):
        raise ValueError("TOC has no valid Interface value")
    if not entries:
        raise ValueError("TOC does not list any Lua files")
    listed = {f"{ADDON}.toc", *entries}
    actual = {path.relative_to(source).as_posix() for path in files
              if path.suffix.lower() in (".lua", ".toc")}
    if listed != actual:
        raise ValueError(f"TOC/source mismatch; missing={sorted(listed - actual)}, "
                         f"unlisted={sorted(actual - listed)}")
    payload: dict[str, bytes] = {}
    for relative in sorted(listed):
        path = source / relative
        reject_links(path)
        payload[relative] = path.read_bytes()
    for name in DOCUMENTS:
        path = REPO / name
        reject_links(path)
        if not path.is_file():
            raise ValueError(f"Missing release document: {path}")
        payload[name] = path.read_bytes()
    return version, interface, payload


def main() -> int:
    version, interface, payload = release_payload()
    destination = REPO / "dist" / f"{ADDON}-{version}.zip"
    reject_links(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for relative, content in sorted(payload.items()):
            info = zipfile.ZipInfo(f"{ADDON}/{relative}", date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, content)
    with zipfile.ZipFile(destination) as archive:
        expected = {f"{ADDON}/{relative}" for relative in payload}
        if set(archive.namelist()) != expected or archive.testzip() is not None:
            raise ValueError("Release ZIP validation failed")
        for relative, content in payload.items():
            if archive.read(f"{ADDON}/{relative}") != content:
                raise ValueError(f"Release ZIP content mismatch: {relative}")
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    print(f"Created: {destination}")
    print(f"Version: {version}; Interface: {interface}; files: {len(payload)}")
    print(f"SHA256: {digest}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"Packaging failed: {error}", file=sys.stderr)
        raise SystemExit(1)
