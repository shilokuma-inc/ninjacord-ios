#!/bin/bash
set -euo pipefail

# App Store のクリエイティブアセット（プロダクトページのヘッダー / 検索結果）を書き出す。
#
#   Tools/render_creative_assets.sh [6.9 inch のスクリーンショットのフォルダ]
#
# 元は AppStore/creative/src/creative.html。画面の画像には 6.9 inch のスクリーンショット
# （Tools/capture_screenshots.sh APP_IPHONE_67 の出力。既定は build/screenshots/APP_IPHONE_67）を使う。
# Google Chrome をヘッドレスで開いて実寸で撮り、アルファを落として AppStore/creative/<言語>/ に保存する。
# 書き出したら差分を見てコミットし、Creative assets/App Store ワークフローで反映する。

ROOT_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SCREENSHOTS="${1:-build/screenshots/APP_IPHONE_67}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUTPUT_DIR="AppStore/creative"

if [ ! -x "$CHROME" ]; then
    echo "Google Chrome が見つかりません（CHROME で場所を指定できます）: $CHROME" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp AppStore/creative/src/creative.html "$WORK/"
cp NinjacordApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png "$WORK/icon.png"

REMOVE_ALPHA="$WORK/remove_alpha"
xcrun swiftc -O Tools/remove_alpha.swift -o "$REMOVE_ALPHA"

# 書き出す種類: <type> <ファイル名> <幅> <高さ>（寸法は AppStore/creative_assets.json の説明を参照）
TARGETS="header header.png 3840 1646
search search_results.png 3840 2560"

while IFS=$'\t' read -r -u 3 language _ _ _; do
    if [ ! -d "$SCREENSHOTS/$language" ]; then
        echo "$SCREENSHOTS/$language がありません。先に Tools/capture_screenshots.sh APP_IPHONE_67 で撮ってください。" >&2
        exit 1
    fi
    mkdir -p "$WORK/screens/$language" "$OUTPUT_DIR/$language"
    cp "$SCREENSHOTS/$language"/*.png "$WORK/screens/$language/"

    while read -r type file width height; do
        output="$OUTPUT_DIR/$language/$file"
        "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
            --allow-file-access-from-files --virtual-time-budget=3000 \
            --window-size="$width,$height" --screenshot="$ROOT_DIR/$output" \
            "file://$WORK/creative.html?type=$type&lang=$language" >/dev/null 2>&1
        "$REMOVE_ALPHA" "$output"
        actual="$(sips -g pixelWidth -g pixelHeight "$output" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w "x" h}')"
        if [ "$actual" != "${width}x${height}" ]; then
            echo "$output の寸法が ${width}x${height} ではありません（$actual）" >&2
            exit 1
        fi
        echo "$output（$actual）"
    done <<< "$TARGETS"
done 3< <(python3 Tools/app_store_config.py languages)
