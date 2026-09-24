#!/usr/bin/env python3
"""撮ったスクリーンショットが App Store Connect に通る形か確かめる。

App Store Connect は寸法が 1 px でも違えば弾き、アルファ付きの PNG も受け付けない。
アップロードまで進んでから落ちると原因が遠くなるので、撮った時点で落とす。

    python3 Tools/verify_screenshots.py \\
        --directory build/screenshots/APP_IPHONE_67 \\
        --sizes 1320x2868,1290x2796

`<directory>/<言語>/*.png` をすべて見る。枚数が `AppStore/screenshots.json` の scenes と
揃っているかも確かめる（途中の画面だけ撮れていない、に気づくため）。
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from app_store_config import scenes

#: PNG の色タイプ。2 = RGB（アルファ無し）、6 = RGBA
PNG_COLOR_TYPE_RGB = 2


def read_png_header(path: Path) -> tuple[int, int, int]:
    """PNG の幅・高さ・色タイプを IHDR から読む。"""
    raw = path.read_bytes()[:26]
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("PNG ではありません")
    width, height, _depth, color_type = struct.unpack(">IIBB", raw[16:26])
    return width, height, color_type


def parse_sizes(raw: str) -> set[tuple[int, int]]:
    sizes = set()
    for item in raw.split(","):
        width, height = item.strip().lower().split("x")
        sizes.add((int(width), int(height)))
    return sizes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--directory", type=Path, required=True, help="<ここ>/<言語>/*.png を見る")
    parser.add_argument("--sizes", required=True, help="受け付ける寸法（カンマ区切り。例: 1320x2868,1290x2796）")
    args = parser.parse_args()

    accepted = parse_sizes(args.sizes)
    expected_files = [f"{scene.file}.png" for scene in scenes()]

    problems: list[str] = []
    languages = sorted(p for p in args.directory.iterdir() if p.is_dir()) if args.directory.is_dir() else []
    if not languages:
        problems.append(f"{args.directory} にスクリーンショットがありません")

    for language_dir in languages:
        files = sorted(p.name for p in language_dir.glob("*.png"))
        missing = [name for name in expected_files if name not in files]
        if missing:
            problems.append(f"{language_dir.name}: 撮れていない画面があります: {', '.join(missing)}")
        for name in files:
            path = language_dir / name
            try:
                width, height, color_type = read_png_header(path)
            except ValueError as error:
                problems.append(f"{language_dir.name}/{name}: {error}")
                continue
            print(f"{language_dir.name}/{name}  {width}x{height}")
            if (width, height) not in accepted:
                problems.append(
                    f"{language_dir.name}/{name}: {width}x{height} は受け付けられない寸法です"
                    f"（{args.sizes}）。撮影に使った Simulator の機種が想定と違う可能性があります。"
                )
            if color_type != PNG_COLOR_TYPE_RGB:
                problems.append(
                    f"{language_dir.name}/{name}: PNG の色タイプが {color_type} です。"
                    "App Store Connect はアルファ付きの画像を受け付けません。"
                )

    if problems:
        raise SystemExit("\n".join(problems))
    print(f"問題なし: {len(languages)} 言語 × {len(expected_files)} 枚")
    return 0


if __name__ == "__main__":
    sys.exit(main())
