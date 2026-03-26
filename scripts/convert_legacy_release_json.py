#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path


def slugify(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"['’]", "", value)
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


def make_release_id(artist: str, title: str, release_format: str, label: str) -> str:
    parts = [slugify(artist), slugify(title), slugify(release_format), slugify(label)]
    return "-".join(part for part in parts if part)


def convert_release(item: dict) -> dict:
    artist = str(item.get("Artist", "")).strip()
    title = str(item.get("Album", "")).strip()
    label = str(item.get("Label", "")).strip()
    release_format = str(item.get("Format", "")).strip()
    image_url = str(item.get("PhotoURL", "")).strip()
    if image_url.startswith("http://"):
        image_url = "https://" + image_url[len("http://") :]

    quantity = item.get("Quantity", "")
    if quantity is None:
        quantity = ""

    return {
        "id": make_release_id(artist, title, release_format, label),
        "artist": artist,
        "title": title,
        "format": release_format,
        "label": label,
        "quantity": str(quantity).strip(),
        "details": str(item.get("More Info", "")).strip(),
        "imageURL": image_url,
        "sourceURL": None,
        "releaseType": None,
        "appleMusic": None,
        "spotify": None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert legacy RSD JSON into the canonical schema")
    parser.add_argument("input", help="Legacy JSON file path")
    parser.add_argument("output", help="Canonical JSON file path")
    parser.add_argument("--slug", required=True, help="Event slug, for example rsd-2026")
    parser.add_argument("--name", required=True, help="Event display name")
    parser.add_argument(
        "--kind",
        default="main",
        choices=["main", "black-friday", "drop", "regional"],
        help="Event kind",
    )
    parser.add_argument("--release-date", required=True, help="Event release date in YYYY-MM-DD format")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    with input_path.open("r", encoding="utf-8") as handle:
        legacy_items = json.load(handle)

    if not isinstance(legacy_items, list):
        raise SystemExit("Legacy input must be a JSON array")

    document = {
        "schemaVersion": 1,
        "event": {
            "slug": args.slug,
            "name": args.name,
            "kind": args.kind,
            "releaseDate": args.release_date,
        },
        "releases": [convert_release(item) for item in legacy_items],
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(document, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    print(f"Converted {len(legacy_items)} releases to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
