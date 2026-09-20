#!/usr/bin/env python3
"""Upload 6.5inch App Store screenshots via App Store Connect API."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import jwt

API_BASE = "https://api.appstoreconnect.apple.com"
DISPLAY_TYPE = "APP_IPHONE_65"
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
    "WAITING_FOR_REVIEW",
    "READY_FOR_REVIEW",
}


def make_token(issuer_id: str, key_id: str, private_key: str) -> str:
    now = int(time.time())
    token = jwt.encode(
        {
            "iss": issuer_id,
            "iat": now,
            "exp": now + 20 * 60,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )
    if isinstance(token, bytes):
        return token.decode("utf-8")
    return token


def api_request(token: str, method: str, path: str, body: dict | None = None) -> dict | None:
    url = path if path.startswith("http") else f"{API_BASE}{path}"
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            if not raw:
                return None
            return json.loads(raw)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {url} failed ({error.code}): {detail}") from error


def upload_chunk(operation: dict, file_bytes: bytes) -> None:
    offset = int(operation["offset"])
    length = int(operation["length"])
    chunk = file_bytes[offset : offset + length]
    headers = {item["name"]: item["value"] for item in operation.get("requestHeaders", [])}
    request = urllib.request.Request(
        operation["url"],
        data=chunk,
        headers=headers,
        method=operation.get("method", "PUT"),
    )
    try:
        with urllib.request.urlopen(request):
            return
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"chunk upload failed ({error.code}): {detail}") from error


def find_app(token: str, bundle_id: str, app_id: str | None) -> str:
    if app_id:
        return app_id
    encoded = urllib.parse.quote(bundle_id)
    payload = api_request(token, "GET", f"/v1/apps?filter[bundleId]={encoded}&limit=1")
    items = payload.get("data") if payload else []
    if not items:
        raise RuntimeError(f"bundle id {bundle_id} のアプリが見つかりません")
    return items[0]["id"]


def find_version(token: str, app_id: str) -> dict:
    payload = api_request(
        token,
        "GET",
        f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=50",
    )
    versions = payload.get("data") if payload else []
    for version in versions:
        state = version.get("attributes", {}).get("appStoreState")
        if state in EDITABLE_STATES:
            return version
    states = [
        f"{v.get('attributes', {}).get('versionString')}={v.get('attributes', {}).get('appStoreState')}"
        for v in versions
    ]
    raise RuntimeError(
        "スクリーンショットを更新できる App Store バージョンがありません。"
        f" 既存バージョン: {', '.join(states) or '(なし)'}"
    )


def find_localization(token: str, version_id: str, locale: str) -> str:
    payload = api_request(
        token,
        "GET",
        f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50",
    )
    items = payload.get("data") if payload else []
    for item in items:
        if item.get("attributes", {}).get("locale") == locale:
            return item["id"]
    created = api_request(
        token,
        "POST",
        "/v1/appStoreVersionLocalizations",
        {
            "data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {"locale": locale},
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    }
                },
            }
        },
    )
    return created["data"]["id"]


def find_or_create_screenshot_set(token: str, localization_id: str) -> str:
    payload = api_request(
        token,
        "GET",
        f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=50",
    )
    items = payload.get("data") if payload else []
    for item in items:
        if item.get("attributes", {}).get("screenshotDisplayType") == DISPLAY_TYPE:
            return item["id"]
    created = api_request(
        token,
        "POST",
        "/v1/appScreenshotSets",
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "id": localization_id,
                        }
                    }
                },
            }
        },
    )
    return created["data"]["id"]


def clear_screenshots(token: str, set_id: str) -> None:
    payload = api_request(
        token,
        "GET",
        f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=50",
    )
    items = payload.get("data") if payload else []
    for item in items:
        api_request(token, "DELETE", f"/v1/appScreenshots/{item['id']}")


def wait_for_complete(token: str, screenshot_id: str) -> None:
    for _ in range(30):
        payload = api_request(token, "GET", f"/v1/appScreenshots/{screenshot_id}")
        state = (
            payload.get("data", {})
            .get("attributes", {})
            .get("assetDeliveryState", {})
            .get("state")
        )
        if state == "COMPLETE":
            return
        if state == "FAILED":
            errors = (
                payload.get("data", {})
                .get("attributes", {})
                .get("assetDeliveryState", {})
                .get("errors")
            )
            raise RuntimeError(f"screenshot {screenshot_id} の処理に失敗しました: {errors}")
        time.sleep(2)
    raise RuntimeError(f"screenshot {screenshot_id} が COMPLETE になりませんでした")


def upload_screenshot(token: str, set_id: str, path: Path) -> None:
    file_bytes = path.read_bytes()
    reserved = api_request(
        token,
        "POST",
        "/v1/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {
                    "fileName": path.name,
                    "fileSize": len(file_bytes),
                },
                "relationships": {
                    "appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": set_id}
                    }
                },
            }
        },
    )
    screenshot_id = reserved["data"]["id"]
    operations = reserved["data"]["attributes"].get("uploadOperations") or []
    for operation in operations:
        upload_chunk(operation, file_bytes)

    checksum = hashlib.md5(file_bytes).hexdigest()
    api_request(
        token,
        "PATCH",
        f"/v1/appScreenshots/{screenshot_id}",
        {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": checksum,
                },
            }
        },
    )
    wait_for_complete(token, screenshot_id)
    print(f"uploaded {path.name}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--bundle-id", default="ml.mrs1669.discord-bot-helper")
    parser.add_argument("--app-id", default=os.environ.get("APP_STORE_APP_ID", "6498937487"))
    parser.add_argument("--locale", default="ja")
    parser.add_argument("--issuer-id", default=os.environ["APPLE_API_ISSUER_ID"])
    parser.add_argument("--key-id", default=os.environ["APPLE_API_KEY_ID"])
    parser.add_argument("--private-key-path", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    directory = Path(args.directory)
    pngs = sorted(path for path in directory.iterdir() if path.suffix.lower() == ".png")
    if not pngs:
        raise RuntimeError(f"{directory} に PNG がありません")

    private_key = Path(args.private_key_path).read_text()
    token = make_token(args.issuer_id, args.key_id, private_key)
    app_id = find_app(token, args.bundle_id, args.app_id)
    version = find_version(token, app_id)
    version_string = version["attributes"]["versionString"]
    localization_id = find_localization(token, version["id"], args.locale)
    set_id = find_or_create_screenshot_set(token, localization_id)
    clear_screenshots(token, set_id)
    for png in pngs:
        upload_screenshot(token, set_id, png)
    print(
        f"App Store Connect へ {args.locale} / {DISPLAY_TYPE} のスクリーンショットを "
        f"バージョン {version_string} にアップロードしました"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # noqa: BLE001
        print(error, file=sys.stderr)
        sys.exit(1)
