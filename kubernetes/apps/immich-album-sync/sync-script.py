#!/usr/bin/env python3
import json
import os
import sys
from urllib.error import HTTPError
from urllib.parse import quote, urljoin
from urllib.request import Request, urlopen


def env(name, default=None, required=False):
    value = os.environ.get(name, default)
    if required and not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def api_keys():
    keys = [
        value.strip()
        for name, value in sorted(os.environ.items())
        if name.startswith("IMMICH_API_KEY_") and value.strip()
    ]
    if not keys:
        raise SystemExit("No IMMICH_API_KEY_* environment variables were provided")
    return keys


def request_json(method, base_url, path, api_key, payload=None):
    data = None
    headers = {"Accept": "application/json", "x-api-key": api_key}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = Request(urljoin(base_url, path), data=data, headers=headers, method=method)
    try:
        with urlopen(request, timeout=60) as response:
            body = response.read().decode("utf-8")
            return json.loads(body) if body else None
    except HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {path} failed with HTTP {error.code}: {body}") from error


def find_person_id(base_url, api_key, person_name):
    people = request_json("GET", base_url, f"search/person?name={quote(person_name)}", api_key)
    if not people:
        raise RuntimeError(f'Person "{person_name}" was not found')
    return people[0]["id"]


def find_album_id(base_url, api_key, album_name):
    albums = request_json("GET", base_url, "albums", api_key)
    for album in albums:
        if album.get("albumName") == album_name:
            return album["id"]
    raise RuntimeError(f'Album "{album_name}" was not found')


def matching_asset_ids(base_url, api_key, person_id):
    page = 1
    asset_ids = []
    page_size = int(env("IMMICH_PAGE_SIZE", "1000"))
    created_after = env("IMMICH_CREATED_AFTER", "")
    query = env("IMMICH_SEARCH_QUERY", "does not work without it")

    while page is not None:
        payload = {
            "isNotInAlbum": False,
            "personIds": [person_id],
            "query": query,
            "size": page_size,
            "page": page,
        }
        if created_after:
            payload["createdAfter"] = created_after

        result = request_json("POST", base_url, "search/smart", api_key, payload)
        assets = result.get("assets", {})
        asset_ids.extend(item["id"] for item in assets.get("items", []))
        page = assets.get("nextPage")

    return asset_ids


def chunks(items, size):
    for index in range(0, len(items), size):
        yield items[index : index + size]


def add_assets_to_album(base_url, api_key, album_id, asset_ids):
    batch_size = int(env("IMMICH_BATCH_SIZE", "100"))
    added = 0

    for batch in chunks(asset_ids, batch_size):
        response = request_json("PUT", base_url, f"albums/{album_id}/assets", api_key, {"ids": batch})
        for item in response or []:
            if item.get("success"):
                added += 1
    return added


def main():
    base_url = env("IMMICH_INSTANCE_URL", required=True).rstrip("/") + "/"
    person_name = env("IMMICH_PERSON_NAME", required=True)
    album_name = env("IMMICH_ALBUM_NAME", required=True)

    for index, key in enumerate(api_keys(), start=1):
        person_id = find_person_id(base_url, key, person_name)
        album_id = find_album_id(base_url, key, album_name)
        asset_ids = matching_asset_ids(base_url, key, person_id)

        if not asset_ids:
            print(f"Account {index}: no matching assets found")
            continue

        added = add_assets_to_album(base_url, key, album_id, asset_ids)
        print(f"Account {index}: requested={len(asset_ids)} added_or_already_present={added}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
