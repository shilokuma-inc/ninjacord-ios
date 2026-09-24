#!/usr/bin/env python3
"""`AppStore/languages.json` と `AppStore/screenshots.json` を読む共通処理。

スクリーンショットの撮影（capture_screenshots.sh）と App Store Connect への反映
（upload_screenshots.py / upload_metadata.py）、および GitHub Actions のワークフローから使う。
設定は 2 つの JSON が単一の定義で、ここには「読んで整合を確かめる」以上のことは書かない。

シェルから使うときはタブ区切りで出す。

    python3 Tools/app_store_config.py languages [ja,en]   # 言語ごとの撮影・反映の設定
    python3 Tools/app_store_config.py scenes              # 撮る画面
    python3 Tools/app_store_config.py devices APP_IPHONE_67
    python3 Tools/app_store_config.py sizes APP_IPHONE_67
    python3 Tools/app_store_config.py display-types [APP_IPHONE_67,...]  # GitHub Actions の matrix 用 JSON
    python3 Tools/app_store_config.py bundle-id
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import NamedTuple

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES_FILE = ROOT / "AppStore" / "languages.json"
SCREENSHOTS_FILE = ROOT / "AppStore" / "screenshots.json"
PROJECT_FILE = ROOT / "NinjacordApp.xcodeproj" / "project.pbxproj"

#: 1 つの言語・表示サイズに載せられる枚数の上限（App Store Connect の制限）
MAX_SCREENSHOTS = 10


class Language(NamedTuple):
    #: このリポジトリ内での言語コード。metadata の JSON と撮影結果のフォルダ名
    language: str
    #: -AppleLanguages に渡す値
    apple_language: str
    #: -AppleLocale に渡す値
    apple_locale: str
    #: App Store Connect のロケール
    store_locale: str


class Scene(NamedTuple):
    #: 出力するファイル名（拡張子なし）。この順が App Store の並び順
    file: str
    #: -screenshot-scene に渡す値
    scene: str


def languages(selected: list[str] | None = None) -> list[Language]:
    """指定した言語（省略時は全言語）の設定を返す。知らない言語を指定したらその場で止める。"""
    entries = json.loads(LANGUAGES_FILE.read_text(encoding="utf-8"))["languages"]
    known = {entry["language"]: entry for entry in entries}
    targets = [entry["language"] for entry in entries] if selected is None else selected

    unknown = [language for language in targets if language not in known]
    if unknown:
        raise SystemExit(
            f"{LANGUAGES_FILE.name} に無い言語: {', '.join(unknown)}\n"
            f"指定できるのは: {', '.join(known)}"
        )
    return [
        Language(
            language=language,
            apple_language=known[language]["appleLanguage"],
            apple_locale=known[language]["appleLocale"],
            store_locale=known[language]["storeLocale"],
        )
        for language in targets
    ]


def _screenshots_config() -> dict:
    return json.loads(SCREENSHOTS_FILE.read_text(encoding="utf-8"))


def scenes() -> list[Scene]:
    entries = _screenshots_config()["scenes"]
    if len(entries) > MAX_SCREENSHOTS:
        raise SystemExit(
            f"{SCREENSHOTS_FILE.name} の scenes が {len(entries)} 件あります。"
            f"App Store Connect は 1 つの表示サイズにつき {MAX_SCREENSHOTS} 枚までです。"
        )
    return [Scene(file=entry["file"], scene=entry["scene"]) for entry in entries]


def display_type(name: str) -> dict:
    display_types = _screenshots_config()["displayTypes"]
    if name not in display_types:
        raise SystemExit(
            f"{SCREENSHOTS_FILE.name} に無い表示サイズ: {name}\n"
            f"指定できるのは: {', '.join(display_types)}"
        )
    return display_types[name]


def display_type_names(selected: list[str] | None = None) -> list[str]:
    names = list(_screenshots_config()["displayTypes"]) if selected is None else selected
    for name in names:
        display_type(name)
    return names


def bundle_id() -> str:
    """アプリの bundle id を project.pbxproj から読む。ワークフローに書き写すと二重管理になるため。

    構成（Debug / STG / Screenshot / Release）ごとに違う値が入ったら、どれを使うか決められないので止める。
    """
    found = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = \"?([^\";]+)\"?;", PROJECT_FILE.read_text(encoding="utf-8")))
    if len(found) != 1:
        raise SystemExit(
            f"{PROJECT_FILE.name} の PRODUCT_BUNDLE_IDENTIFIER が 1 つに決まりません: {', '.join(sorted(found)) or 'なし'}"
        )
    return found.pop()


def parse_list(raw: str | None) -> list[str] | None:
    """カンマ区切り（または空白区切り）の指定を配列にする。空なら None（＝すべて）。"""
    if raw is None:
        return None
    items = [item.strip() for item in raw.replace(",", " ").split()]
    return items or None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=("languages", "scenes", "devices", "sizes", "display-types", "bundle-id"))
    parser.add_argument("argument", nargs="?", default=None)
    args = parser.parse_args()

    if args.command == "languages":
        for entry in languages(parse_list(args.argument)):
            print("\t".join(entry))
    elif args.command == "scenes":
        for entry in scenes():
            print("\t".join(entry))
    elif args.command in ("devices", "sizes"):
        if not args.argument:
            raise SystemExit("表示サイズ（例: APP_IPHONE_67）を指定してください")
        for value in display_type(args.argument)[args.command]:
            print(value)
    elif args.command == "bundle-id":
        print(bundle_id())
    else:
        names = display_type_names(parse_list(args.argument))
        print(json.dumps([{"display_type": name, "label": display_type(name)["label"]} for name in names],
                         ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
