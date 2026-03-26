#!/usr/bin/env python3

import argparse
import base64
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


EVENT_DATE = "2026-04-18"
SCHEMA_VERSION = 1
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"
APPLE_MUSIC_API_BASE = "https://api.music.apple.com/v1"

REGION_CONFIG = {
    "us": {
        "name": "Record Store Day US 2026",
        "kind": "official",
        "source_url": "https://recordstoreday.s3.us-east-1.amazonaws.com/2026/RSD+2026_v2/2026_RSD_PUBLIC_PDF.pdf",
    },
    "canada": {
        "name": "Record Store Day Canada 2026",
        "kind": "regional",
        "source_url": "https://recordstoredaycanada.ca/record-store-day-2026/index.php",
    },
    "germany": {
        "name": "Record Store Day Germany 2026",
        "kind": "regional",
        "source_url": "https://www.recordstoredaygermany.de/exklusive-releases/releases-zum-rsd-2026/",
    },
    "uk": {
        "name": "Record Store Day UK 2026",
        "kind": "regional",
        "source_url": "https://www.recordstoreday.co.uk/rsd-list",
    },
    "australia": {
        "name": "Record Store Day Australia 2026",
        "kind": "regional",
        "source_url": "https://recordstoreday.com.au/releases/",
    },
}

PROJECT_ROOT = Path(__file__).resolve().parents[1]
LABEL_SOURCE_DIR = PROJECT_ROOT / "data" / "releases"


def fetch_text(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    origin = f"{parsed.scheme}://{parsed.netloc}"
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Referer": origin + "/",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read().decode("utf-8", errors="ignore")
    except urllib.error.HTTPError as error:
        if error.code != 406:
            raise

    curl_result = subprocess.run(
        [
            "curl",
            "-L",
            "--max-time",
            "60",
            "-A",
            USER_AGENT,
            url,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return curl_result.stdout


def request_json(url: str, headers: dict[str, str]) -> dict:
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def build_apple_music_search_url(storefront: str, term: str) -> str:
    params = urllib.parse.urlencode(
        {
            "term": term,
            "types": "albums",
            "limit": "10",
        }
    )
    return f"{APPLE_MUSIC_API_BASE}/catalog/{storefront}/search?{params}"


def normalize_match_text(value: str) -> str:
    normalized = html.unescape(value).lower().strip()
    normalized = re.sub(r"[^a-z0-9]+", " ", normalized)
    return normalized.strip()


def apple_artwork_payload(artwork: dict | None) -> dict | None:
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


def render_apple_artwork_url(artwork: dict | None, width: int = 600, height: int = 600) -> str | None:
    if not artwork:
        return None
    template = artwork.get("url")
    if not template:
        return None
    return template.replace("{w}", str(width)).replace("{h}", str(height))


def read_or_fetch(cache_path: Path | None, url: str, refresh: bool) -> str:
    if cache_path and cache_path.exists() and not refresh:
        return cache_path.read_text(encoding="utf-8", errors="ignore")

    text = fetch_text(url)
    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(text, encoding="utf-8")
    return text


def strip_tags(value: str) -> str:
    no_breaks = re.sub(r"<br\s*/?>", "\n", value, flags=re.IGNORECASE)
    no_tags = re.sub(r"<[^>]+>", "", no_breaks)
    normalized = html.unescape(no_tags)
    normalized = re.sub(r"\r", "", normalized)
    normalized = re.sub(r"[ \t]+", " ", normalized)
    normalized = re.sub(r"\n{3,}", "\n\n", normalized)
    return normalized.strip()


def slugify(value: str) -> str:
    lowered = html.unescape(value).lower()
    lowered = lowered.replace("&", " and ")
    lowered = re.sub(r"['\"`’“”]", "", lowered)
    lowered = re.sub(r"[^a-z0-9]+", "-", lowered)
    lowered = re.sub(r"-{2,}", "-", lowered).strip("-")
    return lowered or "release"


def release_id(artist: str, title: str, fmt: str, label: str) -> str:
    return "-".join(
        [
            slugify(artist),
            slugify(title),
            slugify(fmt),
            slugify(label),
        ]
    )


def release_document(region: str, releases: list[dict]) -> dict:
    config = REGION_CONFIG[region]
    return {
        "schemaVersion": SCHEMA_VERSION,
        "event": {
            "slug": f"rsd-2026-{region}",
            "name": config["name"],
            "kind": config["kind"],
            "releaseDate": EVENT_DATE,
        },
        "releases": releases,
    }


def base_release(
    *,
    artist: str,
    title: str,
    fmt: str,
    label: str,
    details: str,
    image_url: str,
    source_url: str | None,
    release_type: str | None = None,
    release_category: str | None = None,
    quantity: str = "",
) -> dict:
    normalized_label = label.strip() or "Unknown"
    normalized_details = details.strip() or "Details unavailable."
    normalized_format = fmt.strip() or "Unknown"
    return {
        "id": release_id(artist, title, normalized_format, normalized_label),
        "artist": artist.strip(),
        "title": title.strip(),
        "format": normalized_format,
        "label": normalized_label,
        "quantity": quantity.strip(),
        "releaseCategory": release_category.strip() if release_category else None,
        "details": normalized_details,
        "imageURL": image_url.strip(),
        "sourceURL": source_url,
        "releaseType": release_type.strip() if release_type else None,
        "appleMusic": None,
        "spotify": None,
    }


def release_completeness_score(release: dict) -> tuple[int, int, int, int, int, int]:
    return (
        0 if release.get("format") in ("", "Unknown") else 1,
        0 if release.get("label") in ("", "Unknown") else 1,
        0 if release.get("details") in ("", "Details unavailable.") else 1,
        1 if release.get("imageURL") else 0,
        1 if release.get("sourceURL") else 0,
        len(release.get("details", "")),
    )


def merge_release_records(existing: dict, candidate: dict) -> dict:
    merged = dict(existing)

    for key in ("format", "label", "details", "imageURL", "sourceURL", "releaseType", "quantity"):
        existing_value = merged.get(key)
        candidate_value = candidate.get(key)
        if not candidate_value:
            continue
        if existing_value in ("", None, "Unknown", "Details unavailable."):
            merged[key] = candidate_value

    if release_completeness_score(candidate) > release_completeness_score(merged):
        for key in ("sourceURL", "imageURL"):
            if candidate.get(key):
                merged[key] = candidate[key]

    return merged


def dedupe_releases(releases: list[dict]) -> list[dict]:
    deduped: dict[str, dict] = {}
    order: list[str] = []

    for release in releases:
        release_key = release["id"]
        if release_key not in deduped:
            deduped[release_key] = release
            order.append(release_key)
            continue
        deduped[release_key] = merge_release_records(deduped[release_key], release)

    return [deduped[key] for key in order]


def reconcile_with_apple_music(
    raw_segment: str,
    release: dict,
    developer_token: str,
    storefront: str = "us",
) -> dict:
    search_url = build_apple_music_search_url(storefront, raw_segment)
    payload = request_json(
        search_url,
        headers={
            "Authorization": f"Bearer {developer_token}",
            "Accept": "application/json",
            "Origin": "https://music.apple.com",
        },
    )
    albums = payload.get("results", {}).get("albums", {}).get("data", [])
    if not albums:
        return release

    segment_key = normalize_match_text(raw_segment)
    current_artist_key = normalize_match_text(release["artist"])
    current_title_key = normalize_match_text(release["title"])
    current_combined_key = normalize_match_text(f"{release['artist']} {release['title']}")

    def score(album: dict) -> int:
        attributes = album.get("attributes", {})
        artist_name = attributes.get("artistName", "")
        album_name = attributes.get("name", "")
        candidate_artist = normalize_match_text(artist_name)
        candidate_title = normalize_match_text(album_name)
        candidate_combined = normalize_match_text(f"{artist_name} {album_name}")

        total = 0
        if candidate_artist and candidate_artist in segment_key:
            total += 8
        if candidate_title and candidate_title in segment_key:
            total += 8
        if candidate_combined and candidate_combined in segment_key:
            total += 10
        if segment_key and segment_key in candidate_combined:
            total += 4
        if candidate_artist == current_artist_key:
            total += 4
        if candidate_title == current_title_key:
            total += 4
        if candidate_combined == current_combined_key:
            total += 6
        return total

    match = max(albums, key=score)
    if score(match) < 12:
        return release

    attributes = match.get("attributes", {})
    relationships = match.get("relationships", {})
    artists = relationships.get("artists", {}).get("data", [])
    artist_url = None
    if artists:
        artist_url = artists[0].get("attributes", {}).get("url")

    artwork = attributes.get("artwork")
    rendered_artwork = render_apple_artwork_url(artwork)

    release["artist"] = attributes.get("artistName", release["artist"])
    release["title"] = attributes.get("name", release["title"])
    if rendered_artwork:
        release["imageURL"] = rendered_artwork
    release["appleMusic"] = {
        "albumID": match.get("id"),
        "albumURL": attributes.get("url"),
        "artistName": attributes.get("artistName"),
        "artistURL": artist_url,
        "artwork": apple_artwork_payload(artwork),
    }
    return release


def extract_pdf_lines(pdf_path: Path) -> list[str]:
    script = f"""
import Foundation
import PDFKit

let url = URL(fileURLWithPath: {json.dumps(str(pdf_path))})
guard let document = PDFDocument(url: url) else {{
    fputs("Failed to open PDF\\n", stderr)
    exit(1)
}}

var pages: [[String]] = []
for pageIndex in 0..<document.pageCount {{
    guard let page = document.page(at: pageIndex) else {{
        pages.append([])
        continue
    }}
    let lines = (page.string ?? "")
        .components(separatedBy: CharacterSet.newlines)
        .map {{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }}
    pages.append(lines)
}}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted]
let data = try! encoder.encode(pages)
FileHandle.standardOutput.write(data)
"""
    result = subprocess.run(
        ["xcrun", "swift", "-e", script],
        check=True,
        capture_output=True,
        text=True,
    )
    pages = json.loads(result.stdout)
    return [line for page in pages for line in page]


US_HEADER_PREFIXES = (
    "These titles will be released on the dates below",
    "The RSD website does NOT sell them.",
    "Key: E = Exclusive Release",
    "THESE TITLES WILL BE RELEASED ON RECORD STORE DAY",
)

US_CATEGORY_MAP = {
    "E": "Exclusive Release",
    "F": "RSD First Release",
    "L": "Limited Run / Regional Focus Release",
}

US_MANUAL_SPLITS_RAW = {
    "jhene aiko trip": ("Jhene Aiko", "Trip"),
    "johnny blue skies & the dark clouds castaways": ("Johnny Blue Skies & The Dark Clouds", "Castaways"),
    "james carter, cyrus chestnut, ali jackson, & reginald veal gold soundz: a jazz tribute to pavement": ("James Carter, Cyrus Chestnut, Ali Jackson, & Reginald Veal", "Gold Soundz: A Jazz Tribute To Pavement"),
    "tyler childers live from dinosaur world": ("Tyler Childers", "Live From Dinosaur World"),
    "the db's cycles per second: us tour 2024": ("The dB's", "Cycles Per Second: US Tour 2024"),
    "dog's eye view happy nowhere (30th anniversary deluxe edition)": ("Dog's Eye View", "Happy Nowhere (30th Anniversary Deluxe Edition)"),
    "dropkick murphys/outlets knock me down": ("Dropkick Murphys/Outlets", "Knock Me Down"),
    "james brandon lewis these are soulful days": ("James Brandon Lewis", "These Are Soulful Days"),
    "gaby moreno live from kcrw morning becomes eclectic cosmica": ("Gaby Moreno", "Live From KCRW Morning Becomes Eclectic"),
    "charlie patton primeval blues rags and gospel songs": ("Charlie Patton", "Primeval Blues, Rags, And Gospel Songs"),
    "ma rainey ma raineys black bottom": ("Ma Rainey", "Ma Rainey's Black Bottom"),
    "various artists operation irie": ("Various Artists", "Operation Irie"),
    "various artists panama latin treasures": ("Various Artists", "Panama Latin Treasures"),
    "masayoshi takanaka all of me": ("Masayoshi Takanaka", "All Of Me"),
    "masayoshi takanaka on guitar": ("Masayoshi Takanaka", "On Guitar"),
    "mccoy tyner the seeker": ("McCoy Tyner", "The Seeker"),
    "christopher young sinister ost": ("Christopher Young", "Sinister OST"),
    "the mighty rootsmen strike back volume 2": ("The Mighty Rootsmen", "Strike Back (Volume 2)"),
    "runt w todd rundgren the necessary cosmic frenzy": ("RUNT w/Todd Rundgren", "The Necessary Cosmic Frenzy"),
    "the radha krsna temple london the radha krsna temple": ("The Radha Krsna Temple (London)", "The Radha Krsna Temple"),
    "prince buster the blue beat label presents prince buster on tour": ("Prince Buster", "THE BLUE BEAT LABEL Presents PRINCE BUSTER ON TOUR"),
    "ruel what it sounds like": ("Ruel", "What It Sounds Like"),
    "slint untitled albini rough mixes": ("Slint", "untitled (albini rough mixes)"),
}

US_MANUAL_SPLITS = {
    normalize_match_text(key): value
    for key, value in US_MANUAL_SPLITS_RAW.items()
}

US_FORMAT_PATTERNS = [
    r"\d+\s*x\s*7\"\s+Box\s+Set",
    r"\d+\s*x\s*12\"\s+Vinyl",
    r"\d+\s*x\s*LP(?:\s+Picture\s+Disc|\s+Import)?",
    r"\d+\s*x\s*CD(?:\s+Import)?",
    r"LP\s+\+\s+7\"\s+Single",
    r"LP(?:\s+Picture\s+Disc|\s+Import)?",
    r"CD(?:\s+Import)?",
    r"12\"\s+(?:EP|Single|Vinyl|Shaped\s+Vinyl)",
    r"10\"\s+(?:LP|EP)",
    r"7\"\s+(?:Vinyl(?:\s+Single)?|Picture\s+Disc|Box\s+Set)",
    r"3\"\s+(?:Single|Turntable\s+Package)",
    r"Vinyl\s+Figure",
]
US_FORMAT_REGEX = re.compile(rf"(?P<head>.*?)(?P<format>{'|'.join(US_FORMAT_PATTERNS)})$", re.IGNORECASE)

LABEL_HINT_WORDS = {
    "records",
    "recordings",
    "music",
    "rhino",
    "bmg",
    "atlantic",
    "republic",
    "legacy",
    "demon",
    "craft",
    "columbia",
    "capitol",
    "interscope",
    "warner",
    "mercury",
    "geffen",
    "nonesuch",
    "sub",
    "pop",
    "anti-",
    "island",
    "reprise",
    "polydor",
    "umr",
    "epitaph",
    "matador",
    "jalopy",
    "resonance",
    "real",
    "gone",
    "org",
}


def normalize_label_key(value: str) -> str:
    normalized = html.unescape(value).lower().strip()
    normalized = re.sub(r"\s+", " ", normalized)
    normalized = normalized.replace(" / ", "/")
    normalized = normalized.replace(" ,", ",")
    normalized = normalized.replace(" .", ".")
    return normalized


def load_known_labels() -> dict[str, str]:
    labels: dict[str, str] = {}
    for path in LABEL_SOURCE_DIR.glob("*.json"):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        for release in payload.get("releases", []):
            label = str(release.get("label", "")).strip()
            if not label:
                continue
            labels.setdefault(normalize_label_key(label), label)
    return labels


def load_known_artists() -> set[str]:
    artists: set[str] = set()
    for path in LABEL_SOURCE_DIR.glob("*.json"):
        if path.name == "rsd-2026-us.json":
            continue
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        for release in payload.get("releases", []):
            artist = str(release.get("artist", "")).strip()
            if artist:
                artists.add(normalize_artist_sort_key(artist))
    return artists


def normalize_artist_sort_key(value: str) -> str:
    normalized = value.strip().lower()
    normalized = re.sub(r"^(the|a|an)\s+", "", normalized)
    normalized = re.sub(r"[^a-z0-9]+", " ", normalized)
    return normalized.strip()


def local_artist_score(artist_tokens: list[str], title_tokens: list[str], known_artists: set[str]) -> int:
    score = 0
    artist_len = len(artist_tokens)
    title_len = len(title_tokens)

    if 1 <= artist_len <= 4:
        score += 4
    elif artist_len <= 6:
        score += 2
    else:
        score -= 2

    if title_len >= 2:
        score += 2
    elif title_len == 1:
        score -= 1

    if artist_tokens[-1].lower() in {"&", "and", "with", "w/", "+", "/", "featuring", "feat.", "feat"}:
        score -= 4

    if artist_tokens[0].lower() in {"live", "best", "greatest", "deluxe"}:
        score -= 2

    artist_key = normalize_artist_sort_key(" ".join(artist_tokens))
    if artist_key in known_artists:
        score += 12

    if artist_len >= 2 and normalize_artist_sort_key(" ".join(artist_tokens[:-1])) in known_artists:
        score -= 3

    if title_tokens[0].lower() in {"records", "recordings", "music", "rhino", "bmg"}:
        score -= 6

    return score


def choose_artist_title_splits(segments: list[str], known_artists: set[str]) -> list[tuple[str, str]]:
    tokenized = [segment.split() for segment in segments]
    candidates_per_row: list[list[tuple[str, str, str, int]]] = []

    for tokens in tokenized:
        row_candidates: list[tuple[str, str, str, int]] = []
        known_matches: list[tuple[str, str, str, int]] = []
        max_prefix = max(1, min(7, len(tokens) - 1))
        for prefix_len in range(1, max_prefix + 1):
            artist_tokens = tokens[:prefix_len]
            title_tokens = tokens[prefix_len:]
            if not title_tokens:
                continue
            artist = " ".join(artist_tokens).strip()
            title = " ".join(title_tokens).strip()
            key = normalize_artist_sort_key(artist)
            score = local_artist_score(artist_tokens, title_tokens, known_artists)
            candidate = (artist, title, key, score)
            row_candidates.append(candidate)
            if key in known_artists:
                known_matches.append((artist, title, key, score + 100))

        if not row_candidates:
            artist = tokens[0] if tokens else ""
            title = " ".join(tokens[1:]).strip()
            row_candidates = [(artist, title, normalize_artist_sort_key(artist), -10)]
        elif known_matches:
            row_candidates = known_matches + [max(row_candidates, key=lambda item: item[3])]

        candidates_per_row.append(row_candidates)

    states: list[list[tuple[int, int, int]]] = []
    for row_index, row_candidates in enumerate(candidates_per_row):
        row_states: list[tuple[int, int, int]] = []
        for candidate_index, (_, _, key, score) in enumerate(row_candidates):
            if row_index == 0:
                row_states.append((score, -1, candidate_index))
                continue

            best_total = -10**9
            best_prev = 0
            for prev_state_index, (prev_total, _, prev_candidate_index) in enumerate(states[row_index - 1]):
                prev_key = candidates_per_row[row_index - 1][prev_candidate_index][2]
                transition = 0 if key >= prev_key else -6
                if key == prev_key:
                    transition += 2
                total = prev_total + score + transition
                if total > best_total:
                    best_total = total
                    best_prev = prev_state_index
            row_states.append((best_total, best_prev, candidate_index))
        states.append(row_states)

    last_row = states[-1]
    best_state_index = max(range(len(last_row)), key=lambda index: last_row[index][0])
    chosen: list[tuple[str, str]] = []

    for row_index in range(len(states) - 1, -1, -1):
        total, previous_state_index, candidate_index = states[row_index][best_state_index]
        artist, title, _, _ = candidates_per_row[row_index][candidate_index]
        chosen.append((artist, title))
        best_state_index = previous_state_index
        if best_state_index < 0:
            break

    chosen.reverse()
    return chosen


def extract_us_format(line_body: str) -> tuple[str, str]:
    cleaned = re.sub(r"\s+", " ", line_body).strip()
    match = US_FORMAT_REGEX.match(cleaned)
    if not match:
        return cleaned, "Unknown"
    head = match.group("head").strip()
    fmt = re.sub(r"\s+", " ", match.group("format")).strip()
    return head, fmt


def choose_label(head_without_format: str, known_labels: dict[str, str]) -> tuple[str, str]:
    tokens = head_without_format.split()
    if len(tokens) < 2:
        return head_without_format.strip(), "Unknown"

    max_suffix = min(8, len(tokens) - 1)
    for suffix_len in range(max_suffix, 0, -1):
        label_candidate = " ".join(tokens[-suffix_len:]).strip()
        normalized = normalize_label_key(label_candidate)
        if normalized in known_labels:
            title_or_artist = " ".join(tokens[:-suffix_len]).strip()
            return title_or_artist, known_labels[normalized]

    for suffix_len in range(max_suffix, 0, -1):
        label_candidate = " ".join(tokens[-suffix_len:]).strip()
        label_key_tokens = re.split(r"[\s/,&()-]+", label_candidate.lower())
        if any(token in LABEL_HINT_WORDS for token in label_key_tokens if token):
            title_or_artist = " ".join(tokens[:-suffix_len]).strip()
            return title_or_artist, label_candidate

    return " ".join(tokens[:-1]).strip(), tokens[-1].strip()


def clean_us_lines(lines: list[str]) -> list[str]:
    cleaned: list[str] = []
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        line = line.replace("Shop Indie record stores at RSDMRKT.com", " ")
        line = re.sub(r"\b\d+\s+\(v\.[^)]+\)", " ", line)
        line = re.sub(r"\s{2,}", " ", line).strip()
        if line.startswith(US_HEADER_PREFIXES):
            continue

        parts = re.split(r"(?=\b[EFL]\s)", line)
        for part in [part.strip() for part in parts if part.strip()]:
            if re.match(r"^[EFL]\s", part):
                cleaned.append(part)
            elif cleaned:
                cleaned[-1] = f"{cleaned[-1]} {part}".strip()

    return cleaned


def import_us_pdf(source_path: Path) -> list[dict]:
    lines = clean_us_lines(extract_pdf_lines(source_path))
    known_labels = load_known_labels()
    developer_token = os.environ.get("APPLE_MUSIC_DEVELOPER_TOKEN", "").strip()
    intermediate_rows = []

    for line in lines:
        category_code = line[:1]
        category = US_CATEGORY_MAP.get(category_code, "")
        body = line[2:].strip()
        head_without_format, fmt = extract_us_format(body)
        artist_and_title, label = choose_label(head_without_format, known_labels)
        manual_key = normalize_match_text(artist_and_title)
        manual_split = US_MANUAL_SPLITS.get(manual_key)
        intermediate_rows.append(
            {
                "category": category,
                "artist_and_title": artist_and_title,
                "manual_split": manual_split,
                "format": fmt,
                "label": label,
            }
        )

    known_artists = load_known_artists()
    artist_title_pairs = choose_artist_title_splits([row["artist_and_title"] for row in intermediate_rows], known_artists)
    releases = []
    for row, (artist, title) in zip(intermediate_rows, artist_title_pairs):
        if row["manual_split"]:
            artist, title = row["manual_split"]
        details = (
            f"{row['category']}.\n\n"
            f"Official Record Store Day US 2026 release imported from the public PDF list."
        )
        release = base_release(
            artist=artist,
            title=title,
            fmt=row["format"],
            label=row["label"],
            details=details,
            image_url="",
            source_url=REGION_CONFIG["us"]["source_url"],
            release_category=row["category"],
        )
        if developer_token:
            try:
                release = reconcile_with_apple_music(row["artist_and_title"], release, developer_token)
            except Exception:
                pass
        releases.append(
            release
        )
    return dedupe_releases(releases)


def parse_canada_list(html_text: str) -> list[dict]:
    row_pattern = re.compile(
        r'<tr[^>]*>\s*<td></td>\s*'
        r'<td[^>]*><a href="(?P<href>entry\.php\?id=\d+&t=rsd_list_images&y=2026)"[^>]*>(?P<title>.*?)</a></td>\s*'
        r'<td[^>]*><a href="[^"]+"[^>]*>(?P<artist>.*?)</a></td>\s*'
        r'<td[^>]*><a href="[^"]+"[^>]*>(?P<label>.*?)</a></td>\s*'
        r'<td[^>]*><a href="[^"]+"[^>]*>(?P<format>.*?)</a></td>\s*'
        r'<td[^>]*><a href="[^"]+"[^>]*><img src="(?P<image>[^"]+)"',
        re.IGNORECASE,
    )

    rows = []
    seen = set()
    for match in row_pattern.finditer(html_text):
        href = html.unescape(match.group("href"))
        if href in seen:
            continue
        seen.add(href)
        rows.append(
            {
                "title": strip_tags(match.group("title")),
                "artist": strip_tags(match.group("artist")),
                "label": strip_tags(match.group("label")),
                "format": strip_tags(match.group("format")),
                "image": html.unescape(match.group("image")),
                "source_url": urllib.parse.urljoin("https://recordstoredaycanada.ca/blog/", href),
            }
        )
    return rows


def parse_canada_detail(html_text: str) -> dict:
    title_match = re.search(r'<span[^>]*>([^<]+)</span></td></tr></table></td></tr><tr><td valign="top" style="background-color: rgb\(255,255,255\);"><table><tr><td><table border="0" cellspacing="0" cellpadding="25"><tr><td><span style="font-weight:100;">', html_text)
    if title_match:
        detail_title = strip_tags(title_match.group(1))
    else:
        detail_title = ""

    content_match = re.search(r'<span style="font-weight:100;">(.*?)</span></td></tr></table>', html_text, re.DOTALL)
    if not content_match:
        return {"title": detail_title, "label": "", "format": "", "details": ""}

    content = content_match.group(1)
    label_match = re.search(r"Label:\s*(.*?)<br\s*/?>", content, re.IGNORECASE | re.DOTALL)
    format_match = re.search(r"Format:\s*(.*?)<br\s*/?>", content, re.IGNORECASE | re.DOTALL)
    description = re.sub(r'^.*?<iframe[^>]*></iframe><br\s*/?><br\s*/?>', "", content, flags=re.IGNORECASE | re.DOTALL)
    description = re.sub(r'^.*?Format:.*?<br\s*/?><br\s*/?>', "", description, flags=re.IGNORECASE | re.DOTALL)

    return {
        "title": detail_title,
        "label": strip_tags(label_match.group(1)) if label_match else "",
        "format": strip_tags(format_match.group(1)) if format_match else "",
        "details": strip_tags(description),
    }


def import_canada(source_text: str, cache_dir: Path | None, refresh: bool, sleep_ms: int) -> list[dict]:
    releases = []
    for row in parse_canada_list(source_text):
        detail_cache_path = None
        if cache_dir:
            detail_id = row["source_url"].split("id=")[-1].split("&", 1)[0]
            detail_cache_path = cache_dir / f"canada-detail-{detail_id}.html"
        detail_text = read_or_fetch(detail_cache_path, row["source_url"], refresh)
        detail = parse_canada_detail(detail_text)
        releases.append(
            base_release(
                artist=row["artist"],
                title=row["title"],
                fmt=detail["format"] or row["format"],
                label=detail["label"] or row["label"],
                details=detail["details"],
                image_url=row["image"],
                source_url=row["source_url"],
            )
        )
        if sleep_ms:
            time.sleep(sleep_ms / 1000)
    return releases


def import_germany(source_text: str) -> list[dict]:
    row_pattern = re.compile(r"<tr\b[^>]*>\s*(.*?)\s*</tr>", re.DOTALL | re.IGNORECASE)
    cell_pattern = re.compile(r"<td[^>]*>(.*?)</td>", re.DOTALL | re.IGNORECASE)
    releases = []
    for row_match in row_pattern.finditer(source_text):
        row_html = row_match.group(1)
        cells = cell_pattern.findall(row_html)
        if len(cells) != 10:
            continue
        image_match = re.search(r'src="([^"]+)"', cells[0], re.IGNORECASE)
        if not image_match:
            continue
        image_url = html.unescape(image_match.group(1))
        artist = strip_tags(cells[1])
        title = strip_tags(cells[2])
        details = strip_tags(cells[3])
        fmt = strip_tags(cells[4])
        quantity = strip_tags(cells[5])
        label = strip_tags(cells[6])
        genre = strip_tags(cells[7])
        releases.append(
            base_release(
                artist=artist,
                title=title,
                fmt=fmt,
                label=label,
                details=details,
                image_url=image_url,
                source_url=REGION_CONFIG["germany"]["source_url"],
                release_type=genre,
                quantity=quantity,
            )
        )
    return releases


def parse_uk_cards(source_text: str) -> list[dict]:
    card_pattern = re.compile(
        r'<div class="rsd-card"[^>]*data-item-name="(?P<title>[^"]*)"[^>]*data-item-artist="(?P<artist>[^"]*)"[^>]*data-item-genre="(?P<genre>[^"]*)"[^>]*>'
        r'<img src="(?P<image>[^"]+)"[^>]*>'
        r'.*?<a href="(?P<href>/record/[^"]+)" class="rsd-card-link">',
        re.DOTALL | re.IGNORECASE,
    )
    cards = []
    seen = set()
    for match in card_pattern.finditer(source_text):
        href = html.unescape(match.group("href"))
        if href in seen:
            continue
        seen.add(href)
        cards.append(
            {
                "title": strip_tags(match.group("title")),
                "artist": strip_tags(match.group("artist")).replace("<br>", ", ").replace("<br/>", ", "),
                "genre": strip_tags(match.group("genre")),
                "image": html.unescape(match.group("image")),
                "source_url": urllib.parse.urljoin("https://www.recordstoreday.co.uk", href),
            }
        )
    return cards


def parse_uk_detail(source_text: str) -> dict:
    embedded_match = re.search(r"base64JsonRowData:\s*'([^']+)'", source_text, re.IGNORECASE)
    if embedded_match:
        try:
            payload = json.loads(base64.b64decode(embedded_match.group(1)).decode("utf-8"))
            return {
                "title": strip_tags(str(payload.get("Title", ""))),
                "label": strip_tags(str(payload.get("Label", ""))),
                "format": strip_tags(str(payload.get("Format", ""))),
                "release_date": strip_tags(str(payload.get("Release Date", ""))),
                "image": html.unescape(str(payload.get("ServedImage", "") or payload.get("Image", ""))),
                "details": strip_tags(str(payload.get("More Information", ""))),
            }
        except Exception:
            pass

    title_match = re.search(r"<h1>(.*?)</h1>", source_text, re.DOTALL | re.IGNORECASE)
    label_match = re.search(r"LABEL\s*:\s*&nbsp;\s*([^<]+)", source_text, re.IGNORECASE)
    format_match = re.search(r"FORMAT:\s*(.*?)</p>", source_text, re.IGNORECASE | re.DOTALL)
    release_date_match = re.search(r"RELEASE DATE:\s*&nbsp;\s*([^<]+)", source_text, re.IGNORECASE)
    image_match = re.search(r'Image:\s*([^"]+)"', source_text)
    if not image_match:
        image_match = re.search(r'<img[^>]+alt="[^"]*"[^>]+src="([^"]+)"', source_text, re.IGNORECASE)

    detail_match = re.search(r'<img[^>]*>\s*(.*?)\s*<h4>OUR PARTNERS</h4>', source_text, re.DOTALL | re.IGNORECASE)
    details = strip_tags(detail_match.group(1)) if detail_match else ""

    return {
        "title": strip_tags(title_match.group(1)) if title_match else "",
        "label": strip_tags(label_match.group(1)) if label_match else "",
        "format": strip_tags(format_match.group(1)) if format_match else "",
        "release_date": strip_tags(release_date_match.group(1)) if release_date_match else "",
        "image": html.unescape(image_match.group(1)) if image_match else "",
        "details": details,
    }


def import_uk(source_text: str, cache_dir: Path | None, refresh: bool, sleep_ms: int) -> list[dict]:
    releases = []
    for card in parse_uk_cards(source_text):
        detail_cache_path = None
        if cache_dir:
            detail_key = card["source_url"].rstrip("/").split("/")[-1]
            detail_cache_path = cache_dir / f"uk-detail-{detail_key}.html"
        detail_text = read_or_fetch(detail_cache_path, card["source_url"], refresh)
        detail = parse_uk_detail(detail_text)
        releases.append(
            base_release(
                artist=card["artist"],
                title=card["title"],
                fmt=detail["format"],
                label=detail["label"],
                details=detail["details"],
                image_url=detail["image"] or card["image"],
                source_url=card["source_url"],
                release_type=card["genre"],
            )
        )
        if sleep_ms:
            time.sleep(sleep_ms / 1000)
    return dedupe_releases(releases)


def parse_australia_embedded_json(source_text: str) -> list[dict]:
    marker = "const rsd_item_list = JSON.parse('"
    start = source_text.find(marker)
    if start == -1:
        raise ValueError("Could not find embedded Australia release JSON.")
    start += len(marker)
    end = source_text.find("');", start)
    if end == -1:
        raise ValueError("Could not find end of embedded Australia release JSON.")
    payload = source_text[start:end]
    decoded = bytes(payload, "utf-8").decode("unicode_escape")
    return json.loads(decoded)


def import_australia(source_text: str) -> list[dict]:
    items = parse_australia_embedded_json(source_text)
    releases = []
    for item in items:
        releases.append(
            base_release(
                artist=str(item.get("artist", "")).strip(),
                title=str(item.get("title", "")).strip(),
                fmt=str(item.get("release_type", "")).strip(),
                label=str(item.get("record_label", "")).strip() or "Independent",
                details=str(item.get("intro", "")).strip(),
                image_url=str(item.get("image", "")).strip(),
                source_url=str(item.get("url", "")).strip() or None,
                release_type="australian-release" if item.get("australian_release") else None,
            )
        )
    return releases


def main() -> int:
    parser = argparse.ArgumentParser(description="Import Record Store Day 2026 regional lists into canonical JSON.")
    parser.add_argument("region", choices=sorted(REGION_CONFIG.keys()))
    parser.add_argument("source", help="Path to cached source HTML")
    parser.add_argument("output", help="Output canonical JSON path")
    parser.add_argument("--cache-dir", help="Optional cache directory for fetched detail pages")
    parser.add_argument("--refresh", action="store_true", help="Ignore cached detail pages and refetch them")
    parser.add_argument("--sleep-ms", type=int, default=0, help="Delay between detail requests")
    args = parser.parse_args()

    source_path = Path(args.source)
    output_path = Path(args.output)
    cache_dir = Path(args.cache_dir) if args.cache_dir else None
    source_text = ""
    if args.region != "us":
        source_text = source_path.read_text(encoding="utf-8", errors="ignore")

    if args.region == "us":
        releases = import_us_pdf(source_path)
    elif args.region == "canada":
        releases = import_canada(source_text, cache_dir, args.refresh, args.sleep_ms)
    elif args.region == "germany":
        releases = import_germany(source_text)
    elif args.region == "uk":
        releases = import_uk(source_text, cache_dir, args.refresh, args.sleep_ms)
    elif args.region == "australia":
        releases = import_australia(source_text)
    else:
        raise ValueError(f"Unsupported region: {args.region}")

    document = release_document(args.region, releases)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {output_path}")
    print(f"Releases: {len(releases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
