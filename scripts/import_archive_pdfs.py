#!/usr/bin/env python3

import argparse
import csv
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

from import_rsd_2026 import (
    base_release,
    choose_artist_title_splits,
    choose_label,
    dedupe_releases,
    extract_us_format,
    normalize_match_text,
    release_document,
    release_id,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_SOURCE_DIR = PROJECT_ROOT / "data" / "archive_sources"
ARCHIVE_MANIFEST_DIR = PROJECT_ROOT / "data" / "archive_manifests"
RELEASES_DIR = PROJECT_ROOT / "data" / "releases"
SCHEMA_VERSION = 1

US_CATEGORY_MAP = {
    "E": "Exclusive Release",
    "F": "RSD First Release",
    "L": "Limited Run / Regional Focus Release",
    "¢": "Exclusive Release",
    "•": "Exclusive Release",
}

FORMAT_PATTERNS = [
    r"(?<!\d)\d+\s*x\s*7[\"'”″]?\s*Box\s*Set",
    r"(?<!\d)\d+\s*x\s*12[\"'”″]?\s*(?:vinyl|LP|LPs)?",
    r"(?<!\d)\d+\s*x\s*LP(?:s)?(?:\s*[\w/&+\- ]+)?",
    r"(?<!\d)\d+\s*x\s*CD(?:s)?(?:\s*[\w/&+\- ]+)?",
    r"(?<!\d)\d{1,2}\s*LP(?:s)?(?:\s*[\w/&+\- ]+)?",
    r"(?<!\d)\d{1,2}\s*CD(?:s)?(?:\s*[\w/&+\- ]+)?",
    r"LP\s*\+\s*7[\"'”″]?",
    r"LP\s*/\s*7in",
    r"LP\s*Picture\s*Disc",
    r"Picture\s*Disc(?:\s*LP)?",
    r"Box\s*Set",
    r"Double\s*Cassette",
    r"Cassette",
    r"CD(?:\s*EP)?",
    r"EP",
    r"12[\"'”″]?\s*(?:vinyl|single|EP|Picture\s*Disc|LP)?",
    r"10[\"'”″]?\s*(?:vinyl|single|EP|LP)?",
    r"7[\"'”″]?\s*(?:vinyl|single|Picture\s*Disc|Flexi)?",
    r"Vinyl\s*(?:Album|Longplay)?",
    r"LP",
]
FORMAT_REGEX = re.compile(rf"(?P<format>{'|'.join(FORMAT_PATTERNS)})$", re.IGNORECASE)

PRICE_REGEX = re.compile(r"£\d+(?:\.\d{2})?$")
DATE_SLASH_REGEX = re.compile(r"\d{1,2}/\d{1,2}/\d{4}$")
DATE_DOT_REGEX = re.compile(r"\d{2}\.\d{2}\.\d{4}$")
QUANTITY_REGEX = re.compile(r"(?P<body>.*?)(?P<quantity>\d{3,6})$")
LABEL_TERMINAL_WORDS = {
    "records",
    "recordings",
    "music",
    "musique",
    "entertainment",
    "audiogram",
    "legacy",
    "rhino",
    "elektra",
    "parlophone",
    "concord",
    "empire",
    "sony",
    "warner",
    "unidisc",
    "aquarius",
    "island",
    "interscope",
    "capitol",
    "virgin",
    "reprise",
    "sundazed",
    "elemental",
    "mnrk",
    "craft",
    "bmg",
    "demon",
    "verve",
    "atlantic",
}
GENERIC_LABEL_VALUES = {"records", "music", "vinyl", "musique", "entertainment"}
LABEL_STOPWORDS = {"of", "from", "the", "in", "with", "and", "for", "to"}
MONTH_WORDS = {
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
}
GENRE_START_WORDS = {
    "pop", "rock", "jazz", "metal", "soul", "funk", "dub", "reggae", "country",
    "alternative", "electronic", "dance", "hip", "rap", "classical", "ost",
    "soundtrack", "k-pop", "folk", "blues", "stoner", "progressive", "international",
    "deutschpop", "hard", "heavy", "musical", "latin", "mpb/jazz/bossa",
}
VARIANT_TAIL_TOKENS = {
    "black", "blue", "red", "white", "green", "orange", "yellow", "pink", "purple", "gold", "silver",
    "clear", "opaque", "colour", "colored", "coloured", "translucent", "splatter", "marble", "marbled",
    "vinyl", "picture", "disc", "die", "cut", "gatefold", "bio", "smoke", "solid", "tbc", "ltd", "limited",
}
TRUSTED_RELEASE_PATTERNS = (
    re.compile(r"^rsd-2017(?:\.enriched)?\.json$"),
    re.compile(r"^rsd-2018(?:\.enriched)?\.json$"),
    re.compile(r"^rsd-black-friday-2017(?:\.enriched)?\.json$"),
    re.compile(r"^rsd-black-friday-2019(?:\.enriched)?\.json$"),
    re.compile(r"^rsd-2026-.*\.json$"),
)


@dataclass
class ManifestItem:
    source_file: str
    event_slug: str
    year: int
    country: str
    season: str
    event_name: str

    @property
    def output_name(self) -> str:
        return f"{self.event_slug}.json"

    @property
    def release_date(self) -> str:
        return f"{self.year:04d}-01-01"

    @property
    def event_kind(self) -> str:
        if self.season.lower() == "black friday":
            return "black-friday"
        if self.country.lower() == "us":
            return "official"
        return "regional"


def extract_pdf_pages(pdf_path: Path) -> list[list[str]]:
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

let data = try! JSONEncoder().encode(pages)
FileHandle.standardOutput.write(data)
"""
    result = subprocess.run(
        ["xcrun", "swift", "-e", script],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def extract_pdf_layout_pages(pdf_path: Path) -> list[list[str]]:
    result = subprocess.run(
        ["pdftotext", "-layout", str(pdf_path), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    pages: list[list[str]] = []
    for page_text in result.stdout.split("\f"):
        lines = [line.rstrip("\n").rstrip("\r") for line in page_text.splitlines()]
        pages.append(lines)
    return pages


def extract_pdf_tsv_rows(pdf_path: Path) -> list[dict[str, str | int | float]]:
    result = subprocess.run(
        ["pdftotext", "-tsv", str(pdf_path), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    rows: list[dict[str, str | int | float]] = []
    reader = csv.DictReader(result.stdout.splitlines(), delimiter="\t")
    for row in reader:
        try:
            level = int(row["level"])
        except (KeyError, TypeError, ValueError):
            continue
        if level != 5:
            continue
        text = (row.get("text") or "").strip()
        if not text or text.startswith("###"):
            continue
        rows.append(
            {
                "page": int(row["page_num"]),
                "block": int(row["block_num"]),
                "paragraph": int(row["par_num"]),
                "line": int(row["line_num"]),
                "left": float(row["left"]),
                "top": float(row["top"]),
                "text": text,
            }
        )
    return rows


def normalize_line(line: str) -> str:
    line = line.replace("\u00a0", " ")
    line = line.replace("…", " ")
    line = line.replace("–", "-")
    line = line.replace("—", "-")
    line = re.sub(r"\s+", " ", line)
    return line.strip()


def load_manifest(path: Path) -> list[ManifestItem]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return [
        ManifestItem(
            source_file=item["sourceFile"],
            event_slug=item["eventSlug"],
            year=int(item["year"]),
            country=str(item["country"]),
            season=str(item["season"]),
            event_name=str(item["eventName"]),
        )
        for item in payload["items"]
    ]


def archive_release_document(item: ManifestItem, releases: list[dict]) -> dict:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "event": {
            "slug": item.event_slug,
            "name": item.event_name,
            "kind": item.event_kind,
            "releaseDate": item.release_date,
        },
        "releases": releases,
    }


def output_resource_name(item: ManifestItem) -> str:
    return item.output_name.removesuffix(".json")


def trusted_release_files() -> list[Path]:
    files: list[Path] = []
    for path in RELEASES_DIR.glob("*.json"):
        if any(pattern.match(path.name) for pattern in TRUSTED_RELEASE_PATTERNS):
            files.append(path)
    return files


def load_known_labels() -> dict[str, str]:
    labels: dict[str, str] = {}
    for path in trusted_release_files():
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        for release in payload.get("releases", []):
            label = str(release.get("label", "")).strip()
            if label:
                labels.setdefault(label.lower(), label)
    return labels


def load_known_artists() -> set[str]:
    artists: set[str] = set()
    for path in trusted_release_files():
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        for release in payload.get("releases", []):
            artist = str(release.get("artist", "")).strip()
            if artist:
                normalized = re.sub(r"^(the|a|an)\s+", "", artist.lower())
                normalized = re.sub(r"[^a-z0-9]+", " ", normalized).strip()
                artists.add(normalized)
    return artists


def classify_family(item: ManifestItem, first_page_lines: list[str]) -> str:
    sample = " ".join(first_page_lines[:12]).lower()
    country = item.country.lower()
    if "interpret" in sample or "interpret:in" in sample or "wunschzettel" in sample:
        return "germany"
    if "artist title description format price" in sample or "record store day list" in sample:
        return "uk"
    if "drop artist title format" in sample:
        return "canada-drop"
    if "release date" in sample and country == "australia":
        return "australia-2022"
    if country == "canada":
        return "canada"
    if country == "italy":
        return "italy"
    if country == "us":
        return "us"
    return country


def clean_pages(pages: list[list[str]]) -> list[list[str]]:
    return [
        [normalize_line(line) for line in page if normalize_line(line)]
        for page in pages
    ]


def extract_trailing_quantity(text: str) -> tuple[str, str]:
    match = QUANTITY_REGEX.match(text.strip())
    if not match:
        return text.strip(), ""
    return match.group("body").strip(), match.group("quantity")


def looks_like_header(line: str) -> bool:
    lowered = line.lower()
    prefixes = (
        "these titles will",
        "the rsd website",
        "the record day australia website",
        "key:",
        "artist title",
        "these releases will",
        "record store day list",
        "for the most up to date info",
        "stand:",
        "interpret",
        "release date",
        "drop artist title format",
        "local artist title format label",
        "international artist title format label",
    )
    if lowered.startswith(prefixes):
        return True
    if re.fullmatch(r"\d+\s*\(v\.[^)]+\)", lowered):
        return True
    if re.fullmatch(r"\d+", lowered):
        return True
    if re.fullmatch(r"\d{2}[./]\d{2}[./]\d{4}", lowered):
        return True
    return False


def maybe_extract_format(text: str) -> tuple[str, str]:
    candidate = re.sub(r"\s+", " ", text).strip()
    match = FORMAT_REGEX.search(candidate)
    if not match:
        return candidate, ""
    head = candidate[: match.start("format")].strip()
    fmt = match.group("format").strip()
    return head, fmt


def longest_known_artist_prefix(text: str, known_artists: set[str]) -> tuple[str, str] | None:
    tokens = text.split()
    best: tuple[str, str] | None = None
    for prefix_len in range(min(8, len(tokens)), 0, -1):
        artist = " ".join(tokens[:prefix_len]).strip()
        title = " ".join(tokens[prefix_len:]).strip()
        normalized = re.sub(r"^(the|a|an)\s+", "", artist.lower())
        normalized = re.sub(r"[^a-z0-9]+", " ", normalized).strip()
        if normalized in known_artists:
            best = (artist, title)
            break
    return best


def longest_known_label_prefix(text: str, known_labels: dict[str, str]) -> str:
    candidate = re.sub(r"\s+", " ", text).strip()
    best = ""
    for known in sorted(known_labels.values(), key=len, reverse=True):
        if len(known.strip()) < 3:
            continue
        pattern = re.escape(known)
        if re.match(pattern + r"(\b|[^A-Za-z0-9])", candidate, re.IGNORECASE):
            best = known
            break
    return best


def longest_known_label_suffix(text: str, known_labels: dict[str, str]) -> str:
    candidate = re.sub(r"\s+", " ", text).strip()
    best = ""
    for known in sorted(known_labels.values(), key=len, reverse=True):
        if len(known.strip()) < 3:
            continue
        pattern = re.escape(known)
        if re.search(r"(^|[^A-Za-z0-9])" + pattern + r"$", candidate, re.IGNORECASE):
            best = known
            break
    return best


def strip_variant_tail(text: str) -> str:
    tokens = text.split()
    while tokens:
        token = re.sub(r"[^A-Za-z0-9\"']", "", tokens[-1]).lower()
        if token in VARIANT_TAIL_TOKENS or re.fullmatch(r'\d+[xX]?(?:lp|cd)?', token) or re.fullmatch(r'\d+[\"\'”″]?', token):
            tokens.pop()
            continue
        break
    return " ".join(tokens).strip()


def hinted_label_suffix(text: str) -> str:
    tokens = text.split()
    if not tokens:
        return ""
    suffix_sizes = [size for size in (2, 1, 3, 4) if size <= len(tokens)]
    for size in suffix_sizes:
        candidate_tokens = tokens[-size:]
        last = re.sub(r"[^A-Za-z]", "", candidate_tokens[-1]).lower()
        if last not in LABEL_TERMINAL_WORDS:
            continue
        normalized_tokens = [re.sub(r"[^A-Za-z0-9&/+.'-]", "", token) for token in candidate_tokens]
        if any(not token for token in normalized_tokens):
            continue
        if any(token[0].islower() for token in normalized_tokens if token[0].isalpha()):
            continue
        first = re.sub(r"[^A-Za-z]", "", normalized_tokens[0]).lower()
        if first in LABEL_STOPWORDS:
            continue
        if normalized_tokens[0][0].isdigit() or normalized_tokens[0][0] in "([{" :
            continue
        return " ".join(candidate_tokens)
    return ""


def extend_generic_label(candidate: str, label: str) -> str:
    if label.lower() not in GENERIC_LABEL_VALUES:
        return label
    tokens = candidate.split()
    label_tokens = label.split()
    if len(tokens) <= len(label_tokens):
        return label
    previous = tokens[-len(label_tokens)-1]
    if previous and previous[0].isupper():
        return f"{previous} {label}"
    return label


def fallback_artist_title_from_body(body: str, *, allow_titlecase_pair: bool = True) -> tuple[str, str]:
    tokens = body.split()
    if len(tokens) < 2:
        return body.strip(), ""

    if len(tokens) >= 3 and tokens[1].lower() in {"and", "&", "feat", "featuring", "with"}:
        return " ".join(tokens[:3]).strip(), " ".join(tokens[3:]).strip()

    if len(tokens) >= 2 and re.search(r"\d", tokens[0]) and tokens[1][0].isupper():
        return " ".join(tokens[:2]).strip(), " ".join(tokens[2:]).strip()

    if allow_titlecase_pair and len(tokens) >= 2 and all(token and token[0].isupper() for token in tokens[:2]):
        return " ".join(tokens[:2]).strip(), " ".join(tokens[2:]).strip()

    return tokens[0], " ".join(tokens[1:]).strip()


def split_by_known_artist_and_label(
    text: str,
    known_artists: set[str],
    known_labels: dict[str, str],
    *,
    allow_titlecase_pair: bool = True,
) -> tuple[str, str, str]:
    candidate = re.sub(r"\s+", " ", text).strip()
    candidate = strip_variant_tail(candidate)
    hinted = hinted_label_suffix(candidate)
    label = hinted or longest_known_label_suffix(candidate, known_labels)
    label = extend_generic_label(candidate, label)
    body = candidate
    if label:
        body = re.sub(re.escape(label) + r"$", "", candidate, flags=re.IGNORECASE).strip(" -/")

    artist_match = longest_known_artist_prefix(body, known_artists)
    if artist_match:
        artist, title = artist_match
        return artist.strip(), title.strip(), label or "Unknown"

    if label:
        artist_title, fallback_label = choose_label(candidate, known_labels)
        direct = longest_known_artist_prefix(artist_title, known_artists)
        if direct:
            return direct[0].strip(), direct[1].strip(), label or fallback_label or "Unknown"

    artist_title, fallback_label = choose_label(candidate, known_labels)
    direct = longest_known_artist_prefix(artist_title, known_artists)
    if direct:
        return direct[0].strip(), direct[1].strip(), label or fallback_label or "Unknown"
    artist_result, title_result = fallback_artist_title_from_body(body, allow_titlecase_pair=allow_titlecase_pair)
    label_result = label or fallback_label or "Unknown"
    if not title_result:
        artist_result, title_result, label_result = artist_title.strip(), "", label or fallback_label or "Unknown"

    normalized_label = re.sub(r"[^a-z0-9]+", " ", label_result.lower()).strip()
    normalized_title = re.sub(r"[^a-z0-9]+", " ", title_result.lower()).strip()
    if normalized_label in MONTH_WORDS or normalized_label == normalized_title:
        label_result = "Unknown"

    return artist_result, title_result, label_result


def finalize_split_records(rows: list[dict], known_artists: set[str]) -> list[dict]:
    if not rows:
        return []
    split_inputs = [row["artist_title"] for row in rows]
    pairs = choose_artist_title_splits(split_inputs, known_artists)
    releases: list[dict] = []
    for row, (artist, title) in zip(rows, pairs):
        if row.get("artist_override") and row.get("title_override") is not None:
            artist = row["artist_override"]
            title = row["title_override"]
        else:
            direct_match = longest_known_artist_prefix(row["artist_title"], known_artists)
            if direct_match and direct_match[1]:
                artist, title = direct_match
        release = base_release(
            artist=artist,
            title=title,
            fmt=row["format"],
            label=row["label"],
            details=row["details"],
            image_url="",
            source_url=row["source_url"],
            release_category=row.get("release_category") or None,
            quantity=row.get("quantity", ""),
        )
        release["id"] = release_id(release["artist"], release["title"], release["format"], release["label"])
        releases.append(release)
    return dedupe_releases(releases)


def parse_us_family(item: ManifestItem, pages: list[list[str]]) -> list[dict]:
    known_labels = load_known_labels()
    known_artists = load_known_artists()
    rows: list[dict] = []

    marker_pattern = re.compile(r"^(?P<prefix>[EFL¢•])\s+")
    for page in pages:
        cleaned: list[str] = []
        for line in page:
            if looks_like_header(line):
                continue
            cleaned.append(line)

        buffered = ""
        for line in cleaned:
            match = marker_pattern.match(line)
            if match:
                if buffered:
                    parsed = parse_us_like_row(buffered, item, known_labels)
                    if parsed:
                        rows.append(parsed)
                buffered = line
            else:
                if buffered:
                    buffered = f"{buffered} {line}".strip()
                else:
                    buffered = line
        if buffered:
            parsed = parse_us_like_row(buffered, item, known_labels)
            if parsed:
                rows.append(parsed)

    return finalize_split_records(rows, known_artists)


def parse_us_like_row(text: str, item: ManifestItem, known_labels: dict[str, str]) -> dict | None:
    body = re.sub(r"\s+", " ", text).strip()
    if not body:
        return None

    release_category = ""
    marker_match = re.match(r"^(?P<marker>[EFL¢•])\s+(?P<body>.*)$", body)
    if marker_match:
        release_category = US_CATEGORY_MAP.get(marker_match.group("marker"), "")
        body = marker_match.group("body").strip()
    elif item.country.lower() == "italy":
        release_category = "Exclusive Release"

    body, quantity = extract_trailing_quantity(body)
    head_without_format, fmt = extract_us_format(body)
    if fmt == "Unknown":
        head_without_format, fmt2 = maybe_extract_format(body)
        fmt = fmt2 or fmt

    artist_title, label = choose_label(head_without_format, known_labels)
    if not artist_title:
        return None

    details_lines = [
        f"Imported from {item.event_name} PDF.",
        f"Source row: {body}",
    ]
    if release_category:
        details_lines.insert(0, release_category + ".")

    return {
        "artist_title": artist_title,
        "format": fmt or "Unknown",
        "label": label or "Unknown",
        "quantity": quantity,
        "release_category": release_category,
        "details": "\n\n".join(details_lines),
        "source_url": None,
    }


def parse_germany_family(item: ManifestItem, pages: list[list[str]]) -> list[dict]:
    releases: list[dict] = []
    release_date_pattern = re.compile(r"\d{2}\.\d{2}\.\d{4}")
    known_artists = load_known_artists()
    known_labels = load_known_labels()
    header_tokens = {
        "Stand:",
        "Interpret",
        "INTERPRET:IN",
        "Titel",
        "TITEL",
        "Format",
        "FORMAT",
        "Inhalt",
        "INHALT",
        "Label",
        "LABEL",
        "Release",
        "RELEASE",
        "RELEASDATUM",
        "Genre",
        "GENRE",
        "LÄNDER",
        "Nachlistung",
        "NACHLISTUNG",
        "Wunschzettel",
        "WUNSCHZETTEL",
        "WUNSCHLISTE",
    }
    words = sorted(
        extract_pdf_tsv_rows(ARCHIVE_SOURCE_DIR / item.source_file),
        key=lambda row: (
            int(row["page"]),
            int(row["block"]),
            int(row["paragraph"]),
            int(row["line"]),
            float(row["left"]),
        ),
    )

    def build_release_doc(current: dict[str, str]) -> None:
        artist = clean(current.get("artist", ""))
        title = clean(current.get("title", ""))
        fmt = clean(current.get("format", ""))
        quantity = clean(current.get("quantity", ""))
        label = clean(current.get("label", "")) or "Unknown"
        genre = clean(current.get("genre", ""))
        release_value = clean(current.get("release", ""))

        if not (artist and title and fmt):
            return
        if not release_date_pattern.search(release_value):
            return

        title_without_format, title_format = maybe_extract_format(title)
        if title_format:
            title = title_without_format
            fmt = normalize_line(" ".join(part for part in [title_format, fmt] if part))

        combined_artist_title = normalize_line(f"{artist} {title}")
        artist_split = longest_known_artist_prefix(combined_artist_title, known_artists)
        if artist_split:
            split_artist, split_title = artist_split
            if normalize_match_text(split_artist) != normalize_match_text(artist):
                artist, title = split_artist, split_title

        if label != "Unknown":
            combined_label = normalize_line(" ".join(part for part in [label, genre] if part))
            snapped_label = longest_known_label_prefix(combined_label, known_labels)
            if snapped_label:
                label = snapped_label

        details = f"Imported from {item.event_name} PDF."
        if genre:
            details += f"\n\nGenre: {genre}"

        release_doc = base_release(
            artist=artist,
            title=title,
            fmt=fmt,
            label=label,
            details=details,
            image_url="",
            source_url=None,
            release_category="",
            quantity=quantity,
        )
        release_doc["id"] = release_id(release_doc["artist"], release_doc["title"], release_doc["format"], release_doc["label"])
        releases.append(release_doc)

    def parse_line_grouped(boundaries: list[tuple[str, float]]) -> list[dict]:
        line_groups: dict[tuple[int, int, int, int], list[dict[str, str | int | float]]] = {}
        for word in words:
            text = normalize_line(str(word["text"]))
            if not text or text in {"[", "]"}:
                continue
            if int(word["page"]) == 1 and float(word["top"]) < 130:
                continue
            if text in header_tokens:
                continue
            key = (int(word["page"]), int(word["block"]), int(word["paragraph"]), int(word["line"]))
            line_groups.setdefault(key, []).append(word)

        structured_lines: list[dict[str, str]] = []
        for key in sorted(line_groups):
            group = sorted(line_groups[key], key=lambda item: float(item["left"]))
            row = {field: "" for field, _ in boundaries}
            for word in group:
                text = clean(str(word["text"]))
                if not text:
                    continue
                left = float(word["left"])
                for field, max_left in boundaries:
                    if left < max_left:
                        row[field] = normalize_line(" ".join(part for part in [row[field], text] if part))
                        break
            structured_lines.append(row)

        current = {field: "" for field, _ in boundaries}

        def append_value(key: str, value: str) -> None:
            value = clean(value)
            if not value:
                return
            current[key] = normalize_line(" ".join(part for part in [current[key], value] if part))

        def current_complete() -> bool:
            return bool(
                clean(current.get("artist", "")) and
                clean(current.get("title", "")) and
                clean(current.get("format", "")) and
                clean(current.get("quantity", "")) and
                release_date_pattern.search(clean(current.get("release", "")))
            )

        for line in structured_lines:
            if not any(clean(value) for value in line.values()):
                continue
            if line.get("artist") and current_complete():
                build_release_doc(current)
                for key in current:
                    current[key] = ""
            for key in current:
                if line.get(key):
                    append_value(key, line[key])

        build_release_doc(current)
        return dedupe_releases(releases)

    if item.year == 2023:
        boundaries = [
            ("artist", 150),
            ("title", 300),
            ("format", 340),
            ("quantity", 365),
            ("label", 433),
            ("release", 520),
        ]
    elif item.year == 2024:
        boundaries = [
            ("artist", 130),
            ("title", 238),
            ("format", 282),
            ("quantity", 304),
            ("label", 357),
            ("genre", 398),
            ("countries", 442),
            ("release", 530),
        ]
    else:
        boundaries = [
            ("artist", 120),
            ("title", 278),
            ("format", 358),
            ("quantity", 396),
            ("release", 442),
            ("genre", 530),
        ]

    field_names = [name for name, _ in boundaries]

    def clean(value: str) -> str:
        cleaned = normalize_line(value)
        cleaned = cleaned.replace("[ ]", "").strip()
        cleaned = re.sub(r"\bWUNSCHLISTE\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bWUNSCHZETTEL\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bNACHLISTUNG\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bRELEASDATUM\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bRELEASE\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bLÄNDER\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bGENRE\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bLABEL\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bINHALT\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bFORMAT\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bTITEL\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bINTERPRET(?::IN)?\b", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bStand:\s*\d{2}\.\d{2}\.\d{4}\b", "", cleaned, flags=re.IGNORECASE)
        return normalize_line(cleaned)

    if item.year == 2024:
        return parse_line_grouped(
            [
                ("artist", 120),
                ("title", 236),
                ("format", 278),
                ("quantity", 304),
                ("label", 352),
                ("genre", 398),
                ("countries", 442),
                ("release", 530),
            ]
        )

    if item.year == 2025:
        return parse_line_grouped(
            [
                ("artist", 130),
                ("title", 290),
                ("format", 350),
                ("quantity", 396),
                ("release", 440),
                ("genre", 530),
            ]
        )

    current = {name: "" for name in field_names}

    def append_value(key: str, value: str) -> None:
        value = clean(value)
        if not value:
            return
        current[key] = normalize_line(" ".join(part for part in [current[key], value] if part))

    def flush_current() -> None:
        artist = clean(current.get("artist", ""))
        title = clean(current.get("title", ""))
        fmt = clean(current.get("format", ""))
        quantity = clean(current.get("quantity", ""))
        label = clean(current.get("label", "")) or "Unknown"
        genre = clean(current.get("genre", ""))
        release_value = clean(current.get("release", ""))

        if not (artist and title and fmt):
            return
        if not release_date_pattern.search(release_value):
            return

        title_without_format, title_format = maybe_extract_format(title)
        if title_format:
            title = title_without_format
            fmt = normalize_line(" ".join(part for part in [title_format, fmt] if part))

        details = f"Imported from {item.event_name} PDF."
        if genre:
            details += f"\n\nGenre: {genre}"

        release_doc = base_release(
            artist=artist,
            title=title,
            fmt=fmt,
            label=label,
            details=details,
            image_url="",
            source_url=None,
            release_category="",
            quantity=quantity,
        )
        release_doc["id"] = release_id(release_doc["artist"], release_doc["title"], release_doc["format"], release_doc["label"])
        releases.append(release_doc)
        for key in current:
            current[key] = ""

    for word in words:
        text = normalize_line(str(word["text"]))
        left = float(word["left"])
        top = float(word["top"])
        page = int(word["page"])
        if not text:
            continue
        if text in {"[", "]"} and left > 500:
            if text == "]":
                flush_current()
            continue
        if page == 1 and top < 130:
            continue
        if text in header_tokens:
            continue

        assigned = False
        for field, max_left in boundaries:
            if left < max_left:
                append_value(field, text)
                assigned = True
                break
        if not assigned:
            append_value(field_names[-1], text)

    flush_current()
    return dedupe_releases(releases)


def parse_canada_family(item: ManifestItem, pages: list[list[str]]) -> list[dict]:
    known_labels = load_known_labels()
    known_artists = load_known_artists()
    rows: list[dict] = []
    blocks = collect_canada_blocks(pages)

    for block in blocks:
        body = " ".join(block)
        body = re.sub(r"\s+", " ", body).strip()
        body = re.sub(r"^\w+\s+\d{1,2}\s+", "", body).strip()
        if not body:
            continue

        artist_prefix = ""
        maple_match = re.match(r"^(?P<artist>.+?)\s+🍁\s+(?P<body>.+)$", body)
        if maple_match:
            artist_prefix = maple_match.group("artist").strip()
            body = maple_match.group("body").strip()

        head_without_format, fmt = maybe_extract_format(body)
        if not fmt:
            continue

        if artist_prefix:
            normalized_head = strip_variant_tail(head_without_format)
            label = longest_known_label_suffix(normalized_head, known_labels) or hinted_label_suffix(normalized_head)
            if label:
                title = re.sub(re.escape(label) + r"\s*$", "", normalized_head, flags=re.IGNORECASE).strip()
            else:
                title = normalized_head
                label = "Unknown"
            artist = artist_prefix
        else:
            artist, title, label = split_by_known_artist_and_label(head_without_format, known_artists, known_labels)
            if not title:
                continue
        rows.append(
            {
                "artist_title": f"{artist} {title}".strip(),
                "artist_override": artist,
                "title_override": title,
                "format": fmt,
                "label": label or "Unknown",
                "quantity": "",
                "release_category": "",
                "details": f"Imported from {item.event_name} PDF.\n\nSource row: {body}",
                "source_url": None,
            }
        )

    return finalize_split_records(rows, known_artists)


def collect_canada_blocks(pages: list[list[str]]) -> list[list[str]]:
    blocks: list[list[str]] = []
    current: list[str] = []

    for page in pages:
        for line in page:
            if looks_like_header(line):
                continue
            if "🍁" in line:
                if current:
                    blocks.append(current)
                current = [line]
                continue
            if line.lower().startswith("june 18 "):
                if current:
                    blocks.append(current)
                current = [line]
                continue

            if current and likely_new_record_line(line):
                current_text = " ".join(current)
                _, current_fmt = maybe_extract_format(current_text)
                if current_fmt:
                    blocks.append(current)
                    current = [line]
                    continue

            current.append(line)
        if current:
            blocks.append(current)
            current = []

    return [block for block in blocks if block]


def likely_new_record_line(line: str) -> bool:
    if not line:
        return False
    lowered = line.lower()
    if PRICE_REGEX.search(line) or DATE_SLASH_REGEX.search(line) or DATE_DOT_REGEX.search(line):
        return False
    if re.match(r"^(lp|cd|cassette|vinyl|picture|single|box|2x|3x|4x|7[\"']|10[\"']|12[\"'])", lowered):
        return False
    return bool(re.match(r"^[A-Z0-9][^\d]{1,}", line))


def split_uppercase_artist_prefix(text: str) -> tuple[str, str]:
    tokens = text.split()
    if len(tokens) < 2:
        return text, ""

    if len(tokens) > 2 and re.fullmatch(r"[\d,.]+", tokens[2]):
        return " ".join(tokens[:2]).strip(), " ".join(tokens[2:]).strip()

    boundary = 1
    saw_lowercase = False
    for index, token in enumerate(tokens):
        if index > 0 and re.fullmatch(r"[\d,.]+", token):
            break
        normalized = re.sub(r"[^A-Za-zÄÖÜäöüß]", "", token)
        if not normalized:
            boundary = index + 1
            continue
        if normalized.upper() == normalized:
            boundary = index + 1
            continue
        saw_lowercase = True
        break

    if not saw_lowercase and len(tokens) > 2:
        comma_indexes = [idx for idx, token in enumerate(tokens[:4]) if "," in token]
        if comma_indexes:
            boundary = min(len(tokens) - 1, comma_indexes[-1] + 2)
        else:
            boundary = 2

    boundary = max(1, min(boundary, len(tokens) - 1))
    return " ".join(tokens[:boundary]).strip(), " ".join(tokens[boundary:]).strip()


def probable_row_start(line: str) -> bool:
    if not line or looks_like_header(line):
        return False
    lowered = line.lower()
    if re.match(r"^(lp|cd|cassette|vinyl|picture|single|box|2x|3x|4x|7[\"']|10[\"']|12[\"']|\d+lp|\d+cd)", lowered):
        return False
    if lowered.startswith(("for the most up to date", "* please contact")):
        return False
    if re.fullmatch(r"(recordings|records|music|musique|entertainment|vinyl|independent)", lowered):
        return False
    return bool(re.match(r"^[A-Z0-9][A-Za-z0-9'\"’‘&./,+:;()!\- ]+$", line))


def row_looks_complete(text: str) -> bool:
    normalized = re.sub(r"\s+", " ", text).strip()
    if not normalized:
        return False
    _, fmt = maybe_extract_format(normalized)
    if fmt:
        return True
    if hinted_label_suffix(normalized) or hinted_label_prefix(normalized):
        return True
    return False


def collect_grouped_rows(pages: list[list[str]]) -> list[str]:
    rows: list[str] = []
    current: list[str] = []
    for page in pages:
        for line in page:
            if looks_like_header(line):
                continue
            if probable_row_start(line) and current and row_looks_complete(" ".join(current)):
                rows.append(" ".join(current).strip())
                current = [line]
            else:
                current.append(line)
        if current:
            rows.append(" ".join(current).strip())
            current = []
    return [re.sub(r"\s+", " ", row).strip() for row in rows if row.strip()]


def parse_row_label_before_format(row: str, known_artists: set[str], known_labels: dict[str, str], *, allow_titlecase_pair: bool = True) -> tuple[str, str, str, str] | None:
    head_without_format, fmt = maybe_extract_format(row)
    if not fmt:
        return None
    artist, title, label = split_by_known_artist_and_label(
        head_without_format,
        known_artists,
        known_labels,
        allow_titlecase_pair=allow_titlecase_pair,
    )
    if not title:
        return None
    return artist, title, label, fmt


def parse_row_format_before_label(row: str, known_artists: set[str], known_labels: dict[str, str], *, allow_titlecase_pair: bool = True) -> tuple[str, str, str, str] | None:
    normalized = re.sub(r"\s+", " ", row).strip()
    label = hinted_label_suffix(normalized) or longest_known_label_suffix(normalized, known_labels)
    if not label:
        return None
    body_without_label = re.sub(re.escape(label) + r"$", "", normalized, flags=re.IGNORECASE).strip(" -/")
    head_without_format, fmt = maybe_extract_format(body_without_label)
    if not fmt:
        return None
    artist, title = fallback_artist_title_from_body(head_without_format, allow_titlecase_pair=allow_titlecase_pair)
    if not title:
        return None
    return artist, title, label, fmt


def hinted_label_prefix(text: str) -> str:
    tokens = text.split()
    if not tokens:
        return ""
    for index, token in enumerate(tokens):
        normalized = re.sub(r"[^A-Za-z/-]", "", token).lower()
        if normalized in GENRE_START_WORDS:
            prefix = " ".join(tokens[:index]).strip()
            if prefix:
                return prefix
            break
    return ""


def find_column_breaks(line: str, labels: tuple[str, ...]) -> tuple[int, ...] | None:
    positions: list[int] = []
    lower = line.lower()
    for label in labels:
        index = lower.find(label.lower())
        if index < 0:
            return None
        positions.append(index)
    return tuple(positions)


def append_field_value(current: dict[str, str], key: str, value: str) -> None:
    value = normalize_line(value)
    if not value:
        return
    existing = current.get(key, "").strip()
    current[key] = f"{existing} {value}".strip() if existing else value


def split_multispace_columns(line: str) -> list[str]:
    return [segment.strip() for segment in re.split(r"\s{2,}", line.strip()) if segment.strip()]


def split_multispace_segments(line: str) -> list[tuple[int, str]]:
    segments: list[tuple[int, str]] = []
    for match in re.finditer(r"\S(?:.*?\S)?(?=\s{2,}|$)", line):
        segments.append((match.start(), match.group(0).strip()))
    return segments


def looks_like_format_text(text: str) -> bool:
    candidate = normalize_line(text)
    if not candidate:
        return False
    _, fmt = maybe_extract_format(candidate)
    if fmt:
        return True
    lowered = candidate.lower()
    return any(
        token in lowered
        for token in ("vinyl", "lp", "2lp", "7in", "12in", "10in", '7"', '12"', '10"', "cd", "boxset", "picture disc")
    )


def looks_like_label_text(text: str, known_labels: dict[str, str]) -> bool:
    candidate = normalize_line(text)
    if not candidate:
        return False
    if candidate.lower() in known_labels:
        return True
    lowered = candidate.lower()
    if any(word in lowered for word in ("records", "recordings", "music", "rec.", "rhino", "sony", "warner", "concord")):
        return True
    letters = [char for char in candidate if char.isalpha()]
    uppercase_ratio = sum(1 for char in letters if char.isupper()) / max(1, len(letters))
    return uppercase_ratio > 0.75


def parse_fixed_column_rows(
    pages: list[list[str]],
    header_labels: tuple[str, ...],
    *,
    skip_prefixes: tuple[str, ...] = (),
    skip_contains: tuple[str, ...] = (),
) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    boundaries: tuple[int, int, int, int] | None = None

    def flush() -> None:
        nonlocal current
        if not current:
            return
        normalized = {key: normalize_line(value) for key, value in current.items() if normalize_line(value)}
        if normalized.get("artist") and normalized.get("title"):
            rows.append(normalized)
        current = None

    for page in pages:
        for raw_line in page:
            line = raw_line.rstrip()
            stripped = line.strip()
            lowered = stripped.lower()
            if not stripped:
                flush()
                continue
            if any(lowered.startswith(prefix.lower()) for prefix in skip_prefixes):
                continue
            if any(fragment.lower() in lowered for fragment in skip_contains):
                continue
            if re.fullmatch(r"\d+\s*", stripped):
                continue

            header_breaks = find_column_breaks(line, header_labels)
            if header_breaks:
                flush()
                boundaries = header_breaks
                continue

            if boundaries is None:
                continue

            if len(boundaries) == 4:
                _artist_start, title_start, label_start, format_start = boundaries
                artist = line[:title_start].strip()
                title = line[title_start:label_start].strip()
                label = line[label_start:format_start].strip()
                fmt = line[format_start:].strip()
            elif len(boundaries) == 3:
                title_start, format_start, label_start = boundaries
                artist = line[:title_start].strip()
                title = line[title_start:format_start].strip()
                fmt = line[format_start:label_start].strip()
                label = line[label_start:].strip()
            else:
                raise ValueError(f"Unsupported header boundary count: {len(boundaries)}")

            if artist:
                flush()
                current = {"artist": artist, "title": title, "label": label, "format": fmt}
                continue

            if current is None:
                continue

            append_field_value(current, "title", title)
            append_field_value(current, "label", label)
            append_field_value(current, "format", fmt)

        flush()

    return rows


def parse_australia_layout_rows(pages: list[list[str]], known_labels: dict[str, str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    pending_title: list[str] = []
    pending_label: list[str] = []
    pending_format: list[str] = []
    artist_boundary = 24
    title_boundary = 50
    format_boundary = 77

    def flush(*, clear_pending: bool = True) -> None:
        nonlocal current, pending_title, pending_label, pending_format
        if current and current.get("artist") and current.get("title") and current.get("format"):
            current["title"] = normalize_line(current.get("title", ""))
            current["label"] = normalize_line(current.get("label", "")) or "Unknown"
            current["format"] = normalize_line(current.get("format", ""))
            rows.append(current)
        current = None
        if clear_pending:
            pending_title = []
            pending_label = []
            pending_format = []

    for page in pages:
        for raw_line in page:
            line = raw_line.rstrip()
            stripped = line.strip()
            lowered = stripped.lower()
            if not stripped:
                continue
            if lowered.startswith((
                "these titles will",
                "the record day australia website",
                "* please contact",
                "local artist",
                "international artist",
            )):
                continue
            if "physical record stores in australia" in lowered:
                continue

            if "title" in lowered and "format" in lowered and "label" in lowered and "artist" in lowered:
                title_index = lowered.find("title")
                format_index = lowered.find("format")
                label_index = lowered.find("label")
                artist_boundary = max(20, (title_index + max(0, lowered.find("artist"))) // 2)
                title_boundary = max(artist_boundary + 8, (title_index + format_index) // 2)
                format_boundary = max(title_boundary + 8, (format_index + label_index) // 2)
                continue

            bucketed = {"artist": [], "title": [], "format": [], "label": []}
            for start, text in split_multispace_segments(line):
                if start < artist_boundary:
                    bucketed["artist"].append(text)
                elif start < title_boundary:
                    bucketed["title"].append(text)
                elif start < format_boundary:
                    bucketed["format"].append(text)
                else:
                    bucketed["label"].append(text)

            has_artist = bool(bucketed["artist"])
            if has_artist:
                flush(clear_pending=False)
                current = {
                    "artist": normalize_line(" ".join(bucketed["artist"])),
                    "title": normalize_line(" ".join(pending_title + bucketed["title"])),
                    "format": normalize_line(" ".join(pending_format + bucketed["format"])),
                    "label": normalize_line(" ".join(pending_label + bucketed["label"])),
                }
                pending_title = []
                pending_label = []
                pending_format = []
                continue

            if current:
                append_field_value(current, "title", " ".join(bucketed["title"]))
                append_field_value(current, "format", " ".join(bucketed["format"]))
                append_field_value(current, "label", " ".join(bucketed["label"]))
                continue

            pending_title.extend(bucketed["title"])
            pending_format.extend(bucketed["format"])
            pending_label.extend(bucketed["label"])

        flush()

    return rows


def parse_australia_coordinate_rows(pdf_path: Path) -> list[dict[str, str]]:
    words = extract_pdf_tsv_rows(pdf_path)
    grouped: dict[tuple[int, int, int, int], list[dict[str, str | int | float]]] = {}
    for row in words:
        key = (int(row["page"]), int(row["block"]), int(row["paragraph"]), int(row["line"]))
        grouped.setdefault(key, []).append(row)

    segments_by_page: dict[int, list[dict[str, str | float | int]]] = {}
    for (page, _block, _paragraph, _line), items in grouped.items():
        items.sort(key=lambda item: float(item["left"]))
        text = normalize_line(" ".join(str(item["text"]) for item in items))
        if not text or text == "​":
            continue
        segments_by_page.setdefault(page, []).append({
            "page": page,
            "top": min(float(item["top"]) for item in items),
            "left": min(float(item["left"]) for item in items),
            "text": text,
        })

    rows: list[dict[str, str]] = []
    for page in sorted(segments_by_page):
        page_segments = sorted(segments_by_page[page], key=lambda segment: (float(segment["top"]), float(segment["left"])))
        content_segments: list[dict[str, str | float]] = []
        started = page != 1

        for segment in page_segments:
            text = str(segment["text"]).strip()
            lowered = text.lower()
            if not text or text == "​":
                continue
            if lowered.startswith((
                "these titles will",
                "the record day australia website",
                "* please contact",
            )):
                continue
            if "physical record stores in australia" in lowered:
                continue
            if text in {"TITLE", "FORMAT", "LABEL"}:
                continue
            if text in {"LOCAL ARTIST", "INTERNATIONAL ARTIST"}:
                started = True
                continue
            if not started:
                continue
            content_segments.append(segment)

        def is_artist_segment(segment: dict[str, str | float]) -> bool:
            left = float(segment["left"])
            if left >= 200:
                return False
            text = str(segment["text"])
            if len(text) <= 1:
                return False
            nearby_non_artist = any(
                other is not segment
                and abs(float(other["top"]) - float(segment["top"])) <= 8
                and float(other["left"]) >= 200
                for other in content_segments
            )
            return nearby_non_artist

        anchor_indices = [
            index
            for index, segment in enumerate(content_segments)
            if is_artist_segment(segment)
        ]
        if not anchor_indices:
            continue

        grouped_rows: dict[int, list[dict[str, str | float]]] = {index: [] for index in anchor_indices}
        for index, segment in enumerate(content_segments):
            if index in grouped_rows:
                grouped_rows[index].append(segment)
                continue

            previous = max((anchor for anchor in anchor_indices if anchor < index), default=None)
            next_anchor = min((anchor for anchor in anchor_indices if anchor > index), default=None)
            if previous is None and next_anchor is None:
                continue
            if previous is None:
                grouped_rows[next_anchor].append(segment)
                continue
            if next_anchor is None:
                grouped_rows[previous].append(segment)
                continue

            top = float(segment["top"])
            prev_distance = abs(top - float(content_segments[previous]["top"]))
            next_distance = abs(float(content_segments[next_anchor]["top"]) - top)
            target = previous if prev_distance <= next_distance else next_anchor
            grouped_rows[target].append(segment)

        for anchor in anchor_indices:
            assigned = sorted(grouped_rows[anchor], key=lambda row: float(row["top"]))
            columns = {"artist": [], "title": [], "format": [], "label": []}
            for segment in assigned:
                left = float(segment["left"])
                text = str(segment["text"])
                if left < 200:
                    columns["artist"].append(text)
                elif left < 335:
                    columns["title"].append(text)
                elif left < 448:
                    columns["format"].append(text)
                else:
                    columns["label"].append(text)

            artist = normalize_line(" ".join(columns["artist"]))
            title = normalize_line(" ".join(columns["title"]))
            fmt = normalize_line(" ".join(columns["format"]))
            label = normalize_line(" ".join(columns["label"]))
            if artist and title and fmt:
                rows.append({
                    "artist": artist,
                    "title": title,
                    "format": fmt,
                    "label": label or "Unknown",
                })

    return rows


def parse_uk_family(item: ManifestItem, pages: list[list[str]]) -> list[dict]:
    known_labels = load_known_labels()
    known_artists = load_known_artists()
    rows: list[dict] = []

    layout_rows = parse_fixed_column_rows(
        pages,
        ("Artist", "Title", "Label", "Format"),
        skip_prefixes=("For the most up to date info",),
        skip_contains=("record store day list",),
    )

    for row in layout_rows:
        artist = row.get("artist", "").strip()
        title = row.get("title", "").strip()
        label = row.get("label", "").strip() or "Unknown"
        fmt = row.get("format", "").strip()
        if not artist or not title or not fmt:
            continue
        if artist.lower() in {"artist", "title", "label", "format"}:
            continue
        label = known_labels.get(label.lower(), label)
        if label.lower() in MONTH_WORDS:
            label = "Unknown"
        if not title or len(artist.strip()) < 2 or artist in {"You", "Who's", "The", "A", "An"}:
            continue
        rows.append(
            {
                "artist_title": f"{artist} {title}".strip(),
                "artist_override": artist,
                "title_override": title,
                "format": fmt,
                "label": label or "Unknown",
                "quantity": "",
                "release_category": "",
                "details": f"Imported from {item.event_name} PDF.\n\nSource row: {artist} | {title} | {label} | {fmt}",
                "source_url": None,
            }
        )

    return finalize_split_records(rows, known_artists)


def parse_australia_2022_family(item: ManifestItem, pages: list[list[str]]) -> list[dict]:
    known_labels = load_known_labels()
    known_artists = load_known_artists()
    rows: list[dict] = []
    buffer = ""

    for page in pages:
        for line in page:
            if looks_like_header(line):
                continue
            buffer = f"{buffer} {line}".strip()
            if DATE_SLASH_REGEX.search(buffer):
                row_text = DATE_SLASH_REGEX.sub("", buffer).strip()
                head_without_format, fmt = maybe_extract_format(row_text)
                if fmt:
                    artist_title, label = choose_label(head_without_format, known_labels)
                    rows.append(
                        {
                            "artist_title": artist_title,
                            "format": fmt,
                            "label": label or "Unknown",
                            "quantity": "",
                            "release_category": "",
                            "details": f"Imported from {item.event_name} PDF.\n\nSource row: {row_text}",
                            "source_url": None,
                        }
                    )
                buffer = ""

    return finalize_split_records(rows, known_artists)


def parse_australia_family(item: ManifestItem, pages: list[list[str]]) -> list[dict]:
    known_labels = load_known_labels()
    known_artists = load_known_artists()
    rows: list[dict] = []
    pdf_path = ARCHIVE_SOURCE_DIR / item.source_file
    layout_rows = parse_australia_coordinate_rows(pdf_path)

    for row in layout_rows:
        artist = row.get("artist", "").strip()
        title = row.get("title", "").strip()
        label = row.get("label", "").strip() or "Unknown"
        fmt = row.get("format", "").strip()
        if not artist or not title or not fmt:
            continue
        if artist.lower() in {"local artist", "international artist"}:
            continue
        rows.append(
            {
                "artist_title": f"{artist} {title}".strip(),
                "artist_override": artist,
                "title_override": title,
                "format": fmt,
                "label": label or "Unknown",
                "quantity": "",
                "release_category": "",
                "details": f"Imported from {item.event_name} PDF.\n\nSource row: {artist} | {title} | {label} | {fmt}",
                "source_url": None,
            }
        )

    return finalize_split_records(rows, known_artists)


def import_item(item: ManifestItem) -> tuple[dict, str]:
    pdf_path = ARCHIVE_SOURCE_DIR / item.source_file
    if item.country.lower() in {"uk", "australia", "germany"}:
        pages = extract_pdf_layout_pages(pdf_path)
    else:
        pages = clean_pages(extract_pdf_pages(pdf_path))
    family = classify_family(item, pages[0] if pages else [])

    if family in {"us", "italy"}:
        releases = parse_us_family(item, pages)
    elif family == "germany":
        releases = parse_germany_family(item, pages)
    elif family in {"canada", "canada-drop"}:
        releases = parse_canada_family(item, pages)
    elif family == "uk":
        releases = parse_uk_family(item, pages)
    elif family == "australia" and item.year != 2022:
        releases = parse_australia_family(item, pages)
    elif family in {"australia-2022", "australia"} and item.year == 2022:
        releases = parse_australia_2022_family(item, pages)
    else:
        raise ValueError(f"No parser family for {item.event_slug}: {family}")

    return archive_release_document(item, releases), family


def main() -> int:
    parser = argparse.ArgumentParser(description="Import archived Record Store Day PDFs into canonical JSON.")
    parser.add_argument(
        "--manifest",
        default=str(ARCHIVE_MANIFEST_DIR / "archive-pdfs-2020-2025.json"),
        help="Manifest JSON path",
    )
    parser.add_argument("--slug", action="append", help="Specific event slug(s) to import")
    parser.add_argument("--output-dir", default=str(RELEASES_DIR), help="Output directory")
    args = parser.parse_args()

    manifest_items = load_manifest(Path(args.manifest))
    if args.slug:
        requested = set(args.slug)
        manifest_items = [item for item in manifest_items if item.event_slug in requested]

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for item in manifest_items:
        document, family = import_item(item)
        output_path = output_dir / item.output_name
        output_path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"{item.event_slug}: {len(document['releases'])} releases [{family}] -> {output_path.name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
