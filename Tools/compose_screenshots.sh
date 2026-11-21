#!/bin/bash
set -euo pipefail

# 撮った画面を、App Store に載せるスクリーンショット（Discord のチャンネル画面とメンバーの会話の構図）に書き出す（Issue #662）。
#
#   Tools/compose_screenshots.sh APP_IPHONE_67 [ja,en]
#
# 元は AppStore/screenshots/src/frame.html。撮った画面は Tools/capture_screenshots.sh の出力
# （$SCREENSHOTS_DIR/<表示サイズ>/<言語>/01_send.png …）を使う。
# Google Chrome をヘッドレスで開いて撮った画面と同じ寸法で撮り、アルファを落として
# $APP_STORE_SCREENSHOTS_DIR/<表示サイズ>/<言語>/ に同じファイル名で保存する。App Store Connect にはこちらを上げる。
# ほかの言語の画像を流用する言語（languages.json の assetsFrom）は書き出さない（反映のときに流用元の画像を使う）。

DISPLAY_TYPE="${1:?表示サイズ（例: APP_IPHONE_67）を指定してください}"
LANGUAGES="${2:-}"

ROOT_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$ROOT_DIR/build/screenshots}"
APP_STORE_SCREENSHOTS_DIR="${APP_STORE_SCREENSHOTS_DIR:-$ROOT_DIR/build/app-store-screenshots}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
FRAME="AppStore/screenshots/src/frame.html"

CONFIG="python3 Tools/app_store_config.py"

if [ ! -x "$CHROME" ]; then
    echo "Google Chrome が見つかりません（CHROME で場所を指定できます）: $CHROME" >&2
    exit 1
fi

# 言語と画面の一覧は先に取る。プロセス置換（< <(…)）でループに渡すと、取れなくてもループが 0 回で終わり、
# 1 枚も書き出さずに成功で終わるため
LANGUAGE_LIST="$($CONFIG asset-languages "$LANGUAGES")"
SCENE_LIST="$($CONFIG scenes)"
if [ -z "$LANGUAGE_LIST" ] || [ -z "$SCENE_LIST" ]; then
    echo "言語か画面の一覧を取れませんでした（AppStore/languages.json / AppStore/screenshots.json）。" >&2
    exit 1
fi

# 途中の言語で止まると、一部だけ書き出された状態になるので、描画を始める前に文言と撮った画面を確かめる
missing=()
while IFS=$'\t' read -r language _ _ _; do
    # frame.html の copy に、その言語の文言が無いと崩れた画像になる
    if ! grep -Eq "^    ${language}: \{" "$FRAME"; then
        echo "${FRAME} の copy に ${language} の文言がありません。" >&2
        exit 1
    fi
    while IFS=$'\t' read -r file scene; do
        if ! grep -Fq "\"${scene}\": {" "$FRAME"; then
            echo "${FRAME} の copy に ${scene} の文言がありません。" >&2
            exit 1
        fi
        if [ ! -f "$SCREENSHOTS_DIR/$DISPLAY_TYPE/$language/$file.png" ]; then
            missing+=("$SCREENSHOTS_DIR/$DISPLAY_TYPE/$language/$file.png")
        fi
    done <<< "$SCENE_LIST"
done <<< "$LANGUAGE_LIST"
if [ "${#missing[@]}" -gt 0 ]; then
    echo "撮った画面がありません。先に Tools/capture_screenshots.sh ${DISPLAY_TYPE} で撮ってください。" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$FRAME" "$WORK/frame.html"

REMOVE_ALPHA="$WORK/remove_alpha"
xcrun swiftc -O Tools/remove_alpha.swift -o "$REMOVE_ALPHA"

while IFS=$'\t' read -r -u 3 language _ _ _; do
    destination="$APP_STORE_SCREENSHOTS_DIR/$DISPLAY_TYPE/$language"
    # 書き出し直すたびに古い画像が混ざらないよう、言語ごとに作り直す
    rm -rf "$destination"
    mkdir -p "$destination" "$WORK/screens/$language"
    cp "$SCREENSHOTS_DIR/$DISPLAY_TYPE/$language"/*.png "$WORK/screens/$language/"

    while IFS=$'\t' read -r -u 4 file scene; do
        source="$SCREENSHOTS_DIR/$DISPLAY_TYPE/$language/$file.png"
        output="$destination/$file.png"
        # 撮った画面と同じ寸法で書き出す（表示サイズの中で機種が替わっても、寸法は撮れた機種に合う）
        size="$(sips -g pixelWidth -g pixelHeight "$source" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w "x" h}')"
        width="${size%x*}"
        height="${size#*x}"
        "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
            --allow-file-access-from-files --virtual-time-budget=5000 \
            --window-size="$width,$height" --screenshot="$output" \
            "file://$WORK/frame.html?scene=$scene&file=$file&lang=$language&width=$width&height=$height" >/dev/null 2>&1
        "$REMOVE_ALPHA" "$output"
        echo "  ${language}/${file}.png（${size}）"
    done 4<<< "$SCENE_LIST"
done 3<<< "$LANGUAGE_LIST"

# App Store Connect は寸法が 1px でも違えば弾く。アップロードまで進んでから落ちると原因が遠くなるので、ここで確かめる
python3 Tools/verify_screenshots.py \
    --directory "$APP_STORE_SCREENSHOTS_DIR/$DISPLAY_TYPE" \
    --sizes "$($CONFIG sizes "$DISPLAY_TYPE" | paste -sd, -)"

echo "$APP_STORE_SCREENSHOTS_DIR/$DISPLAY_TYPE に保存しました"
