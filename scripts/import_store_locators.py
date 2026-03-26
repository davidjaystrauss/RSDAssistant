#!/usr/bin/env python3

import argparse
import json
import re
from html import unescape
from html.parser import HTMLParser
from pathlib import Path


def clean_text(value: str) -> str:
    value = unescape(value or "")
    value = value.replace("\xa0", " ")
    value = re.sub(r"<br\s*/?>", " ", value, flags=re.I)
    value = re.sub(r"\s+", " ", value)
    return value.strip(" ,;\n\t")


class TableRowParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.in_tbody = False
        self.in_tr = False
        self.in_td = False
        self.current_row: list[dict] = []
        self.current_cell_parts: list[str] = []
        self.current_href = ""
        self.rows: list[list[dict]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_dict = dict(attrs)
        if tag == "tbody":
            self.in_tbody = True
        elif self.in_tbody and tag == "tr":
            self.in_tr = True
            self.current_row = []
        elif self.in_tr and tag == "td":
            self.in_td = True
            self.current_cell_parts = []
            self.current_href = ""
        elif self.in_td and tag == "a":
            self.current_href = clean_text(attrs_dict.get("href") or "")
        elif self.in_td and tag == "img":
            src = clean_text(attrs_dict.get("src") or "")
            if src:
                self.current_cell_parts.append(src)
        elif self.in_td and tag == "br":
            self.current_cell_parts.append(" ")

    def handle_endtag(self, tag: str) -> None:
        if tag == "tbody":
            self.in_tbody = False
        elif self.in_tr and tag == "td":
            value = clean_text("".join(self.current_cell_parts))
            self.current_row.append({"text": value, "href": self.current_href})
            self.in_td = False
            self.current_cell_parts = []
            self.current_href = ""
        elif self.in_tr and tag == "tr":
            if self.current_row:
                self.rows.append(self.current_row)
            self.in_tr = False
            self.current_row = []

    def handle_data(self, data: str) -> None:
        if self.in_td:
            self.current_cell_parts.append(data)


def make_id(prefix: str, name: str, address: str, city: str) -> str:
    slug = "|".join(clean_text(value).lower() for value in [name, address, city])
    slug = re.sub(r"[^a-z0-9]+", "-", slug).strip("-")
    return f"{prefix}-{slug}" if slug else prefix


def strip_tags(value: str) -> str:
    value = re.sub(r"<br\s*/?>", "\n", value, flags=re.I)
    value = re.sub(r"<[^>]+>", "", value)
    return clean_text(value)


def html_to_lines(value: str) -> list[str]:
    value = unescape(value or "")
    value = value.replace("\xa0", " ")
    value = re.sub(r"<br\s*/?>", "\n", value, flags=re.I)
    value = re.sub(r"</li>", "\n", value, flags=re.I)
    value = re.sub(r"<[^>]+>", "", value)
    return [clean_text(part) for part in value.splitlines() if clean_text(part)]


def split_city_state_postal(line: str) -> tuple[str, str, str]:
    line = clean_text(line)
    match = re.match(r"^(?P<city>.+?),\s+(?P<state>[A-Za-zÀ-ÿ .'-]+?)\s+(?P<postal>[A-Z]\d[A-Z]\s?\d[A-Z]\d)$", line)
    if match:
        return (
            clean_text(match.group("city")),
            clean_text(match.group("state")),
            clean_text(match.group("postal")),
        )
    if "," in line:
        city, remainder = line.split(",", 1)
        return clean_text(city), clean_text(remainder), ""
    return "", "", clean_text(line)


def split_uk_address(line: str) -> tuple[str, str, str]:
    parts = [clean_text(part) for part in line.split(",") if clean_text(part)]
    if not parts:
        return "", "", ""
    postcode_match = re.search(r"([A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2})$", parts[-1], flags=re.I)
    if postcode_match:
        postcode = postcode_match.group(1).upper()
        tail = clean_text(parts[-1][: postcode_match.start()])
        if tail:
            parts[-1] = tail
        else:
            parts.pop()
    else:
        postcode = ""
    if len(parts) >= 3:
        city = parts[-2]
        state = parts[-1] if len(parts) >= 4 else ""
        address = ", ".join(parts[:-2])
    elif len(parts) == 2:
        address = parts[0]
        city = parts[1]
        state = ""
    else:
        address = parts[0]
        city = ""
        state = ""
    return clean_text(address), clean_text(city), clean_text(postcode)


def infer_uk_country(address: str) -> str:
    value = clean_text(address)
    ireland_markers = [
        "co dublin",
        "co cork",
        "co galway",
        "co mayo",
        "co wicklow",
        "co waterford",
        "co kerry",
        "co limerick",
        "co clare",
        "co kilkenny",
        "co meath",
        "co louth",
        "co sligo",
        "co donegal",
        "co tipperary",
        "dún laoghaire",
        "dun laoghaire",
        "ireland",
    ]
    lowered = value.lower()
    if any(marker in lowered for marker in ireland_markers):
        return "Ireland"
    return "United Kingdom"


def parse_de_country(country: str) -> tuple[str, str]:
    country = clean_text(country)
    if country == "Österreich":
        return "", "Austria"
    if country == "Deutschland":
        return "", "Germany"
    return "", country or "Germany"


def parse_germany(path: Path) -> list[dict]:
    parser = TableRowParser()
    parser.feed(path.read_text(encoding="utf-8", errors="ignore"))
    stores: list[dict] = []
    for row in parser.rows:
        if len(row) < 6:
            continue
        name = row[1]["text"]
        address = row[2]["text"]
        postal_code = row[3]["text"]
        city = row[4]["text"]
        state, country = parse_de_country(row[5]["text"])
        website = row[1]["href"]
        if not name or not address:
            continue
        stores.append(
            {
                "id": make_id("de", name, address, city),
                "name": name,
                "address": address,
                "city": city,
                "state": state,
                "postalCode": postal_code,
                "country": country,
                "latitude": None,
                "longitude": None,
                "websiteURL": website,
                "googleMapsQuery": ", ".join(part for part in [name, address, postal_code, city, country] if part),
                "viewURL": "",
                "phone": "",
                "email": "",
            }
        )
    return stores


def parse_poland(path: Path) -> list[dict]:
    parser = TableRowParser()
    parser.feed(path.read_text(encoding="utf-8", errors="ignore"))
    stores: list[dict] = []
    for row in parser.rows:
        if len(row) < 4:
            continue
        website = row[0]["href"]
        name = row[1]["text"]
        address = row[2]["text"]
        city = ""
        if "," in address:
            city = clean_text(address.split(",")[-1])
        if not name or not address:
            continue
        stores.append(
            {
                "id": make_id("pl", name, address, city),
                "name": name,
                "address": address,
                "city": city,
                "state": "",
                "postalCode": "",
                "country": "Poland",
                "latitude": None,
                "longitude": None,
                "websiteURL": website,
                "googleMapsQuery": ", ".join(part for part in [name, address, "Poland"] if part),
                "viewURL": "",
                "phone": "",
                "email": "",
            }
        )
    return stores


def parse_canada(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    card_pattern = re.compile(r'<td style="[^"]*width:330px;height:165px[^"]*"[^>]*>(?P<body>.*?)</td>', re.S | re.I)
    stores: list[dict] = []
    for match in card_pattern.finditer(text):
        block = match.group("body")
        detail_match = re.search(r'<a href="(?P<link>store\.php\?store=\d+[^"]*)">', block, re.I)
        if not detail_match:
            continue
        lines = html_to_lines(block)
        if len(lines) < 3:
            continue
        name = clean_text(re.sub(r"^P\s+", "", lines[0]))
        address = lines[1]
        city = ""
        state = ""
        postal_code = ""
        phone = ""
        for line in lines[2:]:
            if re.search(r"\d{3}[- )]\d{3}[- ]\d{4}", line) or re.fullmatch(r"\d{10}", re.sub(r"\D", "", line)):
                phone = line
                break
            city, state, postal_code = split_city_state_postal(line)
            if city or state or postal_code:
                continue
        website_match = re.search(r'<a href="(?P<url>https?://[^"]+)" target="_ext">', block, re.I)
        website = clean_text(website_match.group("url")) if website_match else ""
        if not name or not address:
            continue
        stores.append(
            {
                "id": make_id("ca", name, address, city),
                "name": name,
                "address": address,
                "city": city,
                "state": state,
                "postalCode": postal_code,
                "country": "Canada",
                "latitude": None,
                "longitude": None,
                "websiteURL": website,
                "googleMapsQuery": ", ".join(part for part in [name, address, city, state, postal_code, "Canada"] if part),
                "viewURL": "",
                "phone": phone,
                "email": "",
            }
        )
    return stores


def parse_uk_app(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    pattern = re.compile(
        r'<h3 class="font-semibold text-sm">(?P<name>.*?)</h3>.*?'
        r'<p class="text-muted-foreground text-xs line-clamp-2">(?P<address>.*?)</p>'
        r'(?:</div><p class="text-muted-foreground text-xs">(?P<phone>.*?)</p>)?.*?'
        r'<a href="(?P<link>https://www\.recordstoreday\.co\.uk/record-shop/.*?)"',
        re.S,
    )
    stores: list[dict] = []
    for match in pattern.finditer(text):
        name = strip_tags(match.group("name"))
        raw_address = strip_tags(match.group("address"))
        address, city, postal_code = split_uk_address(raw_address)
        phone = strip_tags(match.group("phone") or "")
        website = clean_text(match.group("link"))
        country = infer_uk_country(raw_address)
        if not name or not raw_address:
            continue
        stores.append(
            {
                "id": make_id("uk", name, address or raw_address, city),
                "name": name,
                "address": address or raw_address,
                "city": city,
                "state": "",
                "postalCode": postal_code,
                "country": country,
                "latitude": None,
                "longitude": None,
                "websiteURL": website,
                "googleMapsQuery": ", ".join(part for part in [name, address or raw_address, city, postal_code, country] if part),
                "viewURL": website,
                "phone": phone,
                "email": "",
            }
        )
    return stores


def parse_hong_kong(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    section_pattern = re.compile(
        r'<h3 class="maxi-text-block__content">(?P<name>[^<]+)</h3>(?P<body>.*?)(?=<h3 class="maxi-text-block__content">|</body>)',
        re.S,
    )
    item_pattern = re.compile(r'<div class="maxi-list-item-block__content">(?P<content>.*?)</div>', re.S)
    stores: list[dict] = []
    for section in section_pattern.finditer(text):
        brand_name = strip_tags(section.group("name"))
        body = section.group("body")
        for item in item_pattern.finditer(body):
            lines = html_to_lines(item.group("content"))
            if not lines:
                continue
            branch = ""
            address = ""
            phone = ""
            if len(lines) >= 3:
                branch = lines[0]
                address = lines[1]
                phone = re.sub(r"^電話[:：]\s*", "", lines[2])
            elif len(lines) == 2:
                address = lines[0]
                phone = re.sub(r"^電話[:：]\s*", "", lines[1])
            else:
                address = lines[0]
            name = f"{brand_name} - {branch}" if branch else brand_name
            city = "Hong Kong" if "香港" in address else ("Kowloon" if "九龍" in address else "")
            stores.append(
                {
                    "id": make_id("hk", name, address, city),
                    "name": name,
                    "address": address,
                    "city": city,
                    "state": "",
                    "postalCode": "",
                    "country": "Hong Kong",
                    "latitude": None,
                    "longitude": None,
                    "websiteURL": "https://recordstoreday.hk/rsdhk/唱片店/",
                    "googleMapsQuery": ", ".join(part for part in [name, address, "Hong Kong"] if part),
                    "viewURL": "https://recordstoreday.hk/rsdhk/唱片店/",
                    "phone": phone,
                    "email": "",
                }
            )
    return stores


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse international Record Store Day locator pages into canonical JSON.")
    parser.add_argument("--canada", type=Path)
    parser.add_argument("--germany", type=Path)
    parser.add_argument("--hong-kong", type=Path)
    parser.add_argument("--poland", type=Path)
    parser.add_argument("--uk-app", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    stores: list[dict] = []
    if args.canada:
        stores.extend(parse_canada(args.canada))
    if args.germany:
        stores.extend(parse_germany(args.germany))
    if args.hong_kong:
        stores.extend(parse_hong_kong(args.hong_kong))
    if args.poland:
        stores.extend(parse_poland(args.poland))
    if args.uk_app:
        stores.extend(parse_uk_app(args.uk_app))

    document = {"schemaVersion": 1, "stores": stores}
    args.output.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(stores)} stores to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
