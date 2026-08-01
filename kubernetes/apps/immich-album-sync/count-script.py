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
        with urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {path} failed with HTTP {error.code}: {body}") from error


def find_person_id(base_url, api_key, person_name):
    people = request_json("GET", base_url, f"search/person?name={quote(person_name)}", api_key)
    if not people:
        raise RuntimeError(f'Person "{person_name}" was not found')
    return people[0]["id"]


def find_album(base_url, api_key, album_name):
    albums = request_json("GET", base_url, "albums", api_key)
    for album in albums:
        if album.get("albumName") == album_name:
            return album
    raise RuntimeError(f'Album "{album_name}" was not found')


def matching_assets(base_url, api_key, person_id):
    page = 1
    asset_ids = []
    page_counts = []
    pages_loaded = 0
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
        items = assets.get("items", [])
        page_counts.append(len(items))
        pages_loaded += 1
        asset_ids.extend(item["id"] for item in items)
        next_page = assets.get("nextPage")
        page = int(next_page) if next_page is not None else None

    return unique(asset_ids), pages_loaded, page_counts


def unique(items):
    seen = set()
    result = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def main():
    base_url = env("IMMICH_INSTANCE_URL", required=True).rstrip("/") + "/"
    person_name = env("IMMICH_PERSON_NAME", required=True)
    album_name = env("IMMICH_ALBUM_NAME", required=True)

    total_mikaela_pictures = 0
    total_pictures_in_album = None

    for index, key in enumerate(api_keys(), start=1):
        person_id = find_person_id(base_url, key, person_name)
        album = find_album(base_url, key, album_name)
        asset_ids, pages_loaded, page_counts = matching_assets(base_url, key, person_id)

        account_album_count = int(album.get("assetCount", 0))
        account_picture_count = len(asset_ids)
        total_mikaela_pictures += account_picture_count
        if total_pictures_in_album is None:
            total_pictures_in_album = account_album_count
        elif account_album_count != total_pictures_in_album:
            print(
                f"Account {index}: WARNING album count is {account_album_count}, "
                f"but previous account saw {total_pictures_in_album}"
            )

        print(f"Account {index}: {person_name}'s ID: {person_id}")
        print(f"Account {index}: {person_name}'s album ID: {album['id']}")
        print(f"Account {index}: search pages loaded: {pages_loaded}")
        print(f"Account {index}: page item counts: {page_counts}")
        print(f"Account {index}: {person_name}'s photos found: {account_picture_count}")
        print(f"Account {index}: pictures in {album_name}: {account_album_count}")

    print(f"Total pictures of {person_name}: {total_mikaela_pictures}")
    print(f"Total pictures in {album_name}: {total_pictures_in_album}")
    if total_mikaela_pictures == total_pictures_in_album:
        print("Album sync status: OK - totals match")
    elif total_mikaela_pictures > total_pictures_in_album:
        print(
            "Album sync status: MISMATCH - "
            f"{total_mikaela_pictures - total_pictures_in_album} pictures missing from album"
        )
    else:
        print(
            "Album sync status: MISMATCH - "
            f"{total_pictures_in_album - total_mikaela_pictures} extra pictures in album"
        )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
