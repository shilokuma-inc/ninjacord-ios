#!/usr/bin/env python3
"""ソース中の文言が String Catalog（`NinjacordApp/Localizable.xcstrings`）に載っているか確かめる。

アプリのコードはローカル Swift Package（NinjacordFeature）にあるため、Xcode のビルドでは
文言が `NinjacordApp` ターゲットの String Catalog に自動で抽出されない（#361 で 10 件漏れた）。
載っていない文言は、英語でも日本語のまま表示されてしまう。

どの文字列がローカライズ対象かは、コンパイラに判定させる。`SWIFT_EMIT_LOC_STRINGS=YES` で
ビルドすると、`Text("…")` / `LocalizedStringKey` / `String(localized:)` などに渡した
リテラルが、ソースファイルごとの `.stringsdata`（JSON）に書き出される。ログや識別子など
ローカライズ API を通らない文字列は含まれないので、許可リストはいらない。

    xcodebuild build -project NinjacordApp.xcodeproj -scheme NinjacordApp \\
        -destination "generic/platform=iOS Simulator" \\
        -derivedDataPath build/DerivedData SWIFT_EMIT_LOC_STRINGS=YES
    python3 Tools/check_localizations.py --derived-data build/DerivedData

- カタログに無い文言があれば、場所を出して終了コード 1 で落とす。
- カタログにあってソースから使われていない文言は、警告だけ出す（手で足したキーは
  `extractionState` が `manual` になるので対象外）。

ブランド名など翻訳しない文言も、カタログに `shouldTranslate: false` で載せる。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

#: 文言を集めるターゲット。`<名前>.build` / `<名前>-t.build` の下の `.stringsdata` を読む
TARGETS = ("NinjacordFeature", "NinjacordApp")

#: App Intents 用に Xcode が書き出すもので、ソースの文言ではない
IGNORED_STRINGSDATA = {"ExtractedAppShortcutsMetadata.stringsdata"}

#: String Catalog を置いているディレクトリ。テーブル名 = ファイル名
CATALOG_DIR = REPO_ROOT / "NinjacordApp"


@dataclass(frozen=True)
class Location:
    source: str
    line: int
    column: int


def github_actions() -> bool:
    return os.environ.get("GITHUB_ACTIONS") == "true"


def relative(path: str) -> str:
    try:
        return str(Path(path).resolve().relative_to(REPO_ROOT))
    except ValueError:
        return path


def find_stringsdata(derived_data: Path) -> dict[str, list[Path]]:
    """ターゲット名 → そのターゲットの `.stringsdata`"""
    intermediates = derived_data / "Build" / "Intermediates.noindex"
    files: dict[str, list[Path]] = {}
    for target in TARGETS:
        target_files: list[Path] = []
        for build_dir in ("{}.build", "{}-t.build"):
            target_files += intermediates.glob(f"**/{build_dir.format(target)}/**/*.stringsdata")
        files[target] = sorted(f for f in set(target_files) if f.name not in IGNORED_STRINGSDATA)
    return files


def collect_keys(files: list[Path]) -> dict[str, dict[str, set[Location]]]:
    """テーブル名 → キー → 使っている場所。アーキテクチャごとに同じものが出るのでまとめる"""
    tables: dict[str, dict[str, set[Location]]] = {}
    for file in files:
        data = json.loads(file.read_text(encoding="utf-8"))
        source = relative(data.get("source", str(file)))
        for table, entries in data.get("tables", {}).items():
            keys = tables.setdefault(table, {})
            for entry in entries:
                location = entry.get("location", {})
                keys.setdefault(entry["key"], set()).add(
                    Location(source, location.get("startingLine", 0), location.get("startingColumn", 0))
                )
    return tables


def load_catalog(table: str) -> dict[str, dict] | None:
    path = CATALOG_DIR / f"{table}.xcstrings"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))["strings"]


def report(level: str, message: str, location: Location | None = None) -> None:
    if github_actions():
        where = f" file={location.source},line={location.line},col={location.column}" if location else ""
        print(f"::{level}{where}::{message}")
    else:
        where = f"{location.source}:{location.line}: " if location else ""
        print(f"{level}: {where}{message}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--derived-data",
        type=Path,
        required=True,
        help="SWIFT_EMIT_LOC_STRINGS=YES でビルドしたときの -derivedDataPath",
    )
    args = parser.parse_args()

    files_by_target = find_stringsdata(args.derived_data)
    # ビルドし忘れ・フラグの付け忘れで素通りしないよう、どれかのターゲットで見つからなければ落とす
    missing_targets = [target for target in TARGETS if not files_by_target[target]]
    if missing_targets:
        report(
            "error",
            f"{args.derived_data} に {', '.join(missing_targets)} の .stringsdata がありません。"
            "SWIFT_EMIT_LOC_STRINGS=YES でビルドしてください",
        )
        return 1
    files = [file for target in TARGETS for file in files_by_target[target]]

    tables = collect_keys(files)
    missing_count = 0
    unused_count = 0

    for table, keys in sorted(tables.items()):
        catalog = load_catalog(table)
        if catalog is None:
            for key, locations in sorted(keys.items()):
                report("error", f"String Catalog {table}.xcstrings がありません: \"{key}\"", min(locations, key=str))
            missing_count += len(keys)
            continue

        for key, locations in sorted(keys.items()):
            if key in catalog:
                continue
            missing_count += 1
            for location in sorted(locations, key=lambda l: (l.source, l.line)):
                report("error", f"{table}.xcstrings に載っていない文言です: \"{key}\"", location)

        for key, entry in sorted(catalog.items()):
            if key in keys or entry.get("extractionState") == "manual":
                continue
            unused_count += 1
            report("warning", f"{table}.xcstrings の \"{key}\" はソースから使われていません")

    print(
        f"{len(files)} 個の .stringsdata から {sum(len(k) for k in tables.values())} 件の文言を確認しました"
        f"（未登録 {missing_count} 件 / 未使用 {unused_count} 件）"
    )
    return 1 if missing_count else 0


if __name__ == "__main__":
    sys.exit(main())
