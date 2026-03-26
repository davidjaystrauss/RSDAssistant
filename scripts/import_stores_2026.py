#!/usr/bin/env python3

import argparse
import html
import json
import subprocess
from pathlib import Path


def extract_html_from_rtf(path: Path) -> str:
    result = subprocess.run(
        ["textutil", "-convert", "txt", "-stdout", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def extract_raw_venues(path: Path) -> list[dict]:
    node_script = r"""
const cp=require('child_process');
const fs=require('fs');
const text=cp.execFileSync('textutil',['-convert','txt','-stdout',process.argv[1]],{encoding:'utf8',maxBuffer:32*1024*1024});
const match=text.match(/var\s+venues\s*=\s*(\[[\s\S]*?\])\s*;/);
if(!match){
  throw new Error('venues array not found');
}
const venues=Function('return (' + match[1] + ')')();
process.stdout.write(JSON.stringify(venues));
"""
    result = subprocess.run(
        ["node", "-e", node_script, str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def clean_value(value):
    if isinstance(value, str):
        return html.unescape(html.unescape(value)).strip()
    if isinstance(value, list):
        return [clean_value(item) for item in value]
    if isinstance(value, dict):
        return {key: clean_value(item) for key, item in value.items()}
    return value


def canonical_store(raw_store: dict) -> dict | None:
    store = clean_value(raw_store)
    latitude = store.get("latitude", "")
    longitude = store.get("longitude", "")
    if not latitude or not longitude:
        return None

    website = store.get("website_address", "")
    if website.lower() in {"http://", "https://", "n/a"}:
        website = ""

    return {
        "id": str(store.get("id") or store.get("venue_id") or ""),
        "name": store.get("name", ""),
        "address": store.get("address", ""),
        "city": store.get("city", ""),
        "state": store.get("state", ""),
        "postalCode": store.get("zipcode", ""),
        "country": store.get("country", "United States of America"),
        "latitude": float(latitude),
        "longitude": float(longitude),
        "websiteURL": website,
        "googleMapsQuery": store.get("google_maps_searchstring", ""),
        "viewURL": store.get("view_url", ""),
        "phone": store.get("phone", ""),
        "email": store.get("email_address", ""),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract the Record Store Day 2026 stores payload from a captured HTML/RTF file.")
    parser.add_argument("input", help="Path to the captured RTF file")
    parser.add_argument("output", help="Path to the canonical JSON output")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    raw_stores = extract_raw_venues(input_path)
    stores = [store for store in (canonical_store(item) for item in raw_stores) if store]

    document = {
        "schemaVersion": 1,
        "stores": stores,
    }
    output_path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(stores)} stores to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
