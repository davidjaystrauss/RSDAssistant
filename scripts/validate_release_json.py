#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


REQUIRED_TOP_LEVEL_KEYS = {"schemaVersion", "event", "releases"}
REQUIRED_RELEASE_KEYS = {"id", "artist", "title", "format", "label", "details", "imageURL"}
APPLE_MUSIC_REQUIRED_KEYS = {"albumID", "albumURL", "artistName", "artistURL", "artwork"}
APPLE_MUSIC_ARTWORK_KEYS = {
    "urlTemplate",
    "width",
    "height",
    "bgColor",
    "textColor1",
    "textColor2",
    "textColor3",
    "textColor4",
}


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def validate_top_level(document: dict, errors: list[str]) -> None:
    missing = REQUIRED_TOP_LEVEL_KEYS - set(document.keys())
    if missing:
        errors.append(f"Missing top-level keys: {', '.join(sorted(missing))}")

    releases = document.get("releases")
    if releases is not None and not isinstance(releases, list):
        errors.append("Top-level 'releases' must be an array")

    event = document.get("event")
    if event is not None and not isinstance(event, dict):
        errors.append("Top-level 'event' must be an object")


def validate_releases(releases: list[dict], errors: list[str], warnings: list[str]) -> None:
    seen_ids = set()
    seen_release_keys = set()

    for index, release in enumerate(releases):
        label = f"releases[{index}]"

        if not isinstance(release, dict):
            errors.append(f"{label} must be an object")
            continue

        missing = REQUIRED_RELEASE_KEYS - set(release.keys())
        if missing:
            errors.append(f"{label} missing keys: {', '.join(sorted(missing))}")
            continue

        for key in sorted(REQUIRED_RELEASE_KEYS):
            value = release.get(key)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{label}.{key} must be a non-empty string")

        release_id = release.get("id")
        if isinstance(release_id, str):
            if release_id in seen_ids:
                errors.append(f"Duplicate id: {release_id}")
            seen_ids.add(release_id)

        image_url = release.get("imageURL")
        if isinstance(image_url, str) and image_url and not image_url.startswith("https://"):
            warnings.append(f"{label}.imageURL should use https: {image_url}")

        apple_music = release.get("appleMusic")
        if apple_music is not None:
            validate_apple_music(apple_music, label, errors)

        artist = release.get("artist")
        title = release.get("title")
        release_format = release.get("format")
        if all(isinstance(v, str) and v.strip() for v in (artist, title, release_format)):
            dedupe_key = (
                normalize(artist),
                normalize(title),
                normalize(release_format),
            )
            if dedupe_key in seen_release_keys:
                warnings.append(
                    f"Possible duplicate release tuple: artist='{artist}', title='{title}', format='{release_format}'"
                )
            seen_release_keys.add(dedupe_key)


def validate_apple_music(apple_music: dict, label: str, errors: list[str]) -> None:
    if not isinstance(apple_music, dict):
        errors.append(f"{label}.appleMusic must be an object or null")
        return

    missing = APPLE_MUSIC_REQUIRED_KEYS - set(apple_music.keys())
    if missing:
        errors.append(f"{label}.appleMusic missing keys: {', '.join(sorted(missing))}")
        return

    artwork = apple_music.get("artwork")
    if artwork is not None:
        if not isinstance(artwork, dict):
            errors.append(f"{label}.appleMusic.artwork must be an object or null")
            return

        missing_artwork = APPLE_MUSIC_ARTWORK_KEYS - set(artwork.keys())
        if missing_artwork:
            errors.append(
                f"{label}.appleMusic.artwork missing keys: {', '.join(sorted(missing_artwork))}"
            )


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_release_json.py <path-to-json>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"File not found: {path}", file=sys.stderr)
        return 2

    try:
        with path.open("r", encoding="utf-8") as handle:
            document = json.load(handle)
    except json.JSONDecodeError as exc:
        print(f"Invalid JSON: {exc}", file=sys.stderr)
        return 1

    if not isinstance(document, dict):
        print("Top-level JSON document must be an object", file=sys.stderr)
        return 1

    errors: list[str] = []
    warnings: list[str] = []

    validate_top_level(document, errors)
    releases = document.get("releases")
    if isinstance(releases, list):
        validate_releases(releases, errors, warnings)

    for warning in warnings:
        print(f"WARNING: {warning}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Validated {path}")
    print(f"Releases: {len(releases) if isinstance(releases, list) else 0}")
    print(f"Warnings: {len(warnings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
