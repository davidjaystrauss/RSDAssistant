#!/usr/bin/env python3

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


APPLE_MUSIC_API_BASE = "https://api.music.apple.com/v1"

TITLE_NOISE_PATTERNS = [
    r"\[RSD\s*2026\s*EX\]",
    r"\(RSD\s*2026\s*EX\)",
    r"\(RSD EXCLUSIVE 2026\)",
    r"\(RSD EXCLUSIVE\)",
    r"\(RSD 2026\)",
    r"\(LIMITED[^)]*\)",
    r"\(VINYL[^)]*\)",
    r"\(COLOURED VINYL\)",
    r"\(COLORED VINYL\)",
    r"\(TRANSLUCENT[^)]*\)",
    r"\(CLEAR[^)]*\)",
    r"\(WHITE[^)]*\)",
    r"\(BLUE[^)]*\)",
    r"\(RED[^)]*\)",
    r"\(BLACK[^)]*\)",
    r"\(PICTURE DISC[^)]*\)",
    r"\(DELUXE EDITION\)",
    r"\(INDIE EXCLUSIVE[^)]*\)",
    r"\(FIRST TIME ON VINYL\)",
    r"-\s*RSD\s*2026\b",
    r"RSD\s*2026\b",
    r"RSD\s*2026\s*EX\b",
    r"RECORD STORE DAY 2026",
    r"RSD EXCLUSIVE 2026",
    r"LIMITED [A-Z0-9'\"/&+\- ,;:.()]+ VINYL",
    r"TRANSPARENT [A-Z0-9'\"/&+\- ,;:.()]+ VINYL",
    r"[A-Z0-9'\"/&+\- ,;:.()]+ COLOURED VINYL",
    r"FIRST TIME ON VINYL",
]

TRAILING_FORMAT_PATTERNS = [
    r"\b\d+\s*x\s*LP\b",
    r"\b\d+\s*x\s*CD\b",
    r"\bLP(?:\([^)]+\))?\b",
    r"\bCD\b",
    r"\b12\"(?:\s+\w+)?\b",
    r"\b10\"(?:\s+\w+)?\b",
    r"\b7\"(?:\s+\w+)?\b",
    r"\b12in(?:EP)?\b",
    r"\b10in\b",
    r"\b7in\b",
]


def build_search_url(storefront: str, artist: str, title: str) -> str:
    query = f"{artist} {title}"
    params = urllib.parse.urlencode(
        {
            "term": query,
            "types": "albums",
            "limit": "10",
        }
    )
    return f"{APPLE_MUSIC_API_BASE}/catalog/{storefront}/search?{params}"


def normalize(value: str) -> str:
    normalized = value.lower().strip()
    normalized = normalized.replace("&", " and ")
    normalized = re.sub(r"[^a-z0-9]+", " ", normalized)
    return " ".join(normalized.split())


def clean_title(title: str) -> str:
    cleaned = title.strip()
    for pattern in TITLE_NOISE_PATTERNS:
        cleaned = re.sub(pattern, " ", cleaned, flags=re.IGNORECASE)

    for pattern in TRAILING_FORMAT_PATTERNS:
        cleaned = re.sub(rf"(?:\s+|^){pattern}$", "", cleaned, flags=re.IGNORECASE)

    cleaned = re.sub(r"\s+", " ", cleaned)
    cleaned = re.sub(r"\(\s*\)", "", cleaned)
    cleaned = cleaned.strip(" -,:;/")
    return cleaned or title.strip()


def search_title_variants(title: str) -> list[str]:
    variants = [title.strip()]
    cleaned = clean_title(title)
    if cleaned and cleaned not in variants:
        variants.append(cleaned)

    bare = re.sub(r"\([^)]*\)", " ", cleaned).strip(" -,:;/")
    bare = re.sub(r"\s+", " ", bare)
    if bare and bare not in variants:
        variants.append(bare)

    return variants


def request_json(url: str, developer_token: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {developer_token}",
            "Accept": "application/json",
            "Origin": "https://music.apple.com",
        },
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def score_album_match(release: dict, album: dict) -> int:
    attributes = album.get("attributes", {})
    score = 0
    release_artist = normalize(release["artist"])
    release_title = normalize(release["title"])
    cleaned_release_title = normalize(clean_title(release["title"]))
    candidate_artist = normalize(attributes.get("artistName", ""))
    candidate_title = normalize(attributes.get("name", ""))

    if candidate_artist == release_artist:
        score += 3
    elif candidate_artist and release_artist and (candidate_artist in release_artist or release_artist in candidate_artist):
        score += 2

    if candidate_title == release_title:
        score += 5
    elif candidate_title == cleaned_release_title:
        score += 8
    elif cleaned_release_title and candidate_title and (
        candidate_title in cleaned_release_title or cleaned_release_title in candidate_title
    ):
        score += 4

    release_title_tokens = set(cleaned_release_title.split())
    candidate_title_tokens = set(candidate_title.split())
    overlap = len(release_title_tokens & candidate_title_tokens)
    if overlap:
        score += min(overlap, 5)

    if release.get("format"):
        editorial_notes = json.dumps(attributes.get("editorialNotes", {})).lower()
        if normalize(release["format"]).replace('"', "") in editorial_notes:
            score += 1

    return score


def select_best_album_match(release: dict, albums: list[dict]) -> dict | None:
    scored = sorted(albums, key=lambda album: score_album_match(release, album), reverse=True)
    best = scored[0] if scored else None
    if best is None:
        return None

    if score_album_match(release, best) <= 0:
        return None

    return best


def artwork_payload(artwork: dict | None) -> dict | None:
    if artwork is None:
        return None

    return {
        "urlTemplate": artwork.get("url"),
        "width": artwork.get("width"),
        "height": artwork.get("height"),
        "bgColor": artwork.get("bgColor"),
        "textColor1": artwork.get("textColor1"),
        "textColor2": artwork.get("textColor2"),
        "textColor3": artwork.get("textColor3"),
        "textColor4": artwork.get("textColor4"),
    }


def render_artwork_url(artwork: dict | None, width: int = 600, height: int = 600) -> str | None:
    if not artwork:
        return None

    template = artwork.get("url")
    if not template:
        return None

    return template.replace("{w}", str(width)).replace("{h}", str(height))


def enrich_release(release: dict, storefront: str, developer_token: str) -> bool:
    if release.get("appleMusic"):
        return True

    albums: list[dict] = []
    seen_album_ids: set[str] = set()
    for title_variant in search_title_variants(release["title"]):
        url = build_search_url(storefront, release["artist"], title_variant)
        payload = request_json(url, developer_token)
        variant_albums = payload.get("results", {}).get("albums", {}).get("data", [])
        for album in variant_albums:
            album_id = str(album.get("id", ""))
            if album_id and album_id in seen_album_ids:
                continue
            if album_id:
                seen_album_ids.add(album_id)
            albums.append(album)

    match = select_best_album_match(release, albums)
    if match is None:
        return False

    attributes = match.get("attributes", {})
    artist_url = None

    relationships = match.get("relationships", {})
    artists = relationships.get("artists", {}).get("data", [])
    if artists:
        artist_url = artists[0].get("attributes", {}).get("url")

    artwork = artwork_payload(attributes.get("artwork"))
    release["appleMusic"] = {
        "albumID": match.get("id"),
        "albumURL": attributes.get("url"),
        "artistName": attributes.get("artistName"),
        "artistURL": artist_url,
        "artwork": artwork,
    }

    rendered = render_artwork_url(attributes.get("artwork"))
    if rendered:
        release["imageURL"] = rendered

    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Enrich canonical release JSON with Apple Music catalog data")
    parser.add_argument("input", help="Canonical JSON input file")
    parser.add_argument("output", help="Output file path")
    parser.add_argument("--storefront", default="us", help="Apple Music storefront, default: us")
    parser.add_argument(
        "--developer-token-env",
        default="APPLE_MUSIC_DEVELOPER_TOKEN",
        help="Environment variable containing the Apple Music developer token",
    )
    parser.add_argument("--sleep-ms", type=int, default=250, help="Delay between requests")
    args = parser.parse_args()

    developer_token = os.environ.get(args.developer_token_env)
    if not developer_token:
        print(
            f"Missing developer token. Set {args.developer_token_env} in the environment.",
            file=sys.stderr,
        )
        return 2

    input_path = Path(args.input)
    output_path = Path(args.output)
    document = json.loads(input_path.read_text(encoding="utf-8"))
    releases = document.get("releases", [])
    if not isinstance(releases, list):
        print("Input file has invalid 'releases' structure.", file=sys.stderr)
        return 1

    matched = 0
    unmatched = 0

    for release in releases:
        try:
            if enrich_release(release, args.storefront, developer_token):
                matched += 1
            else:
                unmatched += 1
        except urllib.error.HTTPError as exc:
            unmatched += 1
            print(f"WARNING: HTTP {exc.code} while enriching '{release.get('artist')} - {release.get('title')}'")
        except urllib.error.URLError as exc:
            unmatched += 1
            print(f"WARNING: Network error while enriching '{release.get('artist')} - {release.get('title')}': {exc}")

        time.sleep(args.sleep_ms / 1000)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"Enriched releases: {matched}")
    print(f"Unmatched releases: {unmatched}")
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
