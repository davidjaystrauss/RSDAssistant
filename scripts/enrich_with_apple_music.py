#!/usr/bin/env python3

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


APPLE_MUSIC_API_BASE = "https://api.music.apple.com/v1"


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
    return " ".join(value.lower().strip().split())


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

    if normalize(attributes.get("artistName", "")) == normalize(release["artist"]):
        score += 3

    if normalize(attributes.get("name", "")) == normalize(release["title"]):
        score += 5

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
    url = build_search_url(storefront, release["artist"], release["title"])
    payload = request_json(url, developer_token)
    albums = payload.get("results", {}).get("albums", {}).get("data", [])
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
