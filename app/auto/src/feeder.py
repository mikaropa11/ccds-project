import json
import os
import re
import signal
import sys
import time

import requests


def secret(name, default=None):
    path = os.environ.get(name + "_FILE")
    if path:
        with open(path) as f:
            return f.read().strip()
    return os.environ.get(name, default)


CORE_URL = os.environ.get("CORE_URL", "http://core:8000")
INTERVAL = int(os.environ.get("FEED_INTERVAL", "600"))
SLOT = int(os.environ.get("FEEDER_SLOT", "1"))
REPLICAS = int(os.environ.get("FEEDER_REPLICAS", "1"))
URLS = [u.strip() for u in os.environ.get("FEED_URLS", "").split(",") if u.strip()]
FEED_TOKEN = secret("FEED_TOKEN", "dev-token")
HEADERS = {"User-Agent": "ccds-ratings-feeder/1.0 (+lab project)"}

LD_JSON = re.compile(r"<script[^>]*application/ld\+json[^>]*>(.*?)</script>", re.S | re.I)


def find_rating(node):
    if isinstance(node, dict):
        if isinstance(node.get("aggregateRating"), dict):
            return node
        node = list(node.values())
    if isinstance(node, list):
        for child in node:
            item = find_rating(child)
            if item:
                return item
    return None


def number(value):
    return None if value is None else float(str(value).replace(",", "."))


def scrape(url):
    html = requests.get(url, headers=HEADERS, timeout=15).text
    for block in LD_JSON.findall(html):
        try:
            item = find_rating(json.loads(block))
        except json.JSONDecodeError:
            continue
        if item:
            rating = item["aggregateRating"]
            return {
                "url": url,
                "title": item.get("name"),
                "value": number(rating["ratingValue"]),
                "best": number(rating.get("bestRating")),
                "reviews": number(rating.get("reviewCount") or rating.get("ratingCount")),
            }
    return None


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    # Replica k of N (swarm {{.Task.Slot}}) reads URLs k, k+N, k+2N...
    mine = URLS[SLOT - 1::REPLICAS]
    print(f"slot {SLOT}/{REPLICAS}: {len(mine)} of {len(URLS)} urls, every {INTERVAL}s")
    time.sleep(10)
    while True:
        for url in mine:
            try:
                data = scrape(url)
                if data is None:
                    print(f"no rating found: {url}")
                    continue
                requests.post(f"{CORE_URL}/api/ratings", json=data,
                              headers={"X-Feed-Token": FEED_TOKEN}, timeout=10).raise_for_status()
                print(f"{url} -> {data['value']}/{data['best']} ({data['reviews']} reviews)")
            except (requests.RequestException, KeyError, ValueError) as e:
                print(f"failed {url}: {e}")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
