---
name: build-run-simulator
description: Ninjacord iOS アプリを iOS Simulator でビルド・インストール・起動し、手元で目視確認できる状態にする。ビルドエラーの抽出、Simulator の boot、アプリの install/launch、スクリーンショット取得までを扱う。"Simulator でビルド", "手元で確認", "アプリを起動", "ビルドが通るか" などの要求で参照する。
---

# build-run-simulator

Ninjacord iOS を Simulator 上で動かして手元確認するための手順。scheme・bundle ID・`.app` パスは**ハードコードせず** `xcodebuild -showBuildSettings` から取得すること（構成変更に強くするため）。

## 前提

- 作業ディレクトリ: リポジトリルート（`NinjacordApp.xcodeproj` がある場所）
- `.xcodeproj` 直（`-project NinjacordApp.xcodeproj`）
- Scheme: 開発確認は `NinjacordApp-STG` を優先。本番確認時のみ `NinjacordApp`
- 依存は SPM。初回は解決に時間がかかる

## 手順

### 1. ターゲット Simulator を選ぶ

利用可能な iPhone を1台選ぶ（起動済みがあればそれを使う）。

```sh
xcrun simctl list devices available | grep -i iphone
# 例: "iPhone 17 Pro" を使う
```

### 2. ビルド

```sh
SCHEME="NinjacordApp-STG"   # 本番確認なら NinjacordApp
DEVICE="iPhone 17 Pro"

xcodebuild build \
  -project NinjacordApp.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath ./DerivedData \
  | tee /tmp/ninjacord-build.log | xcbeautify 2>/dev/null || cat /tmp/ninjacord-build.log
```

`xcbeautify` が無ければ生ログでよい。**失敗時は `/tmp/ninjacord-build.log` から `error:` 行を抽出**して原因を報告する。

```sh
grep -n "error:" /tmp/ninjacord-build.log | head -20
```

### 3. `.app` パスと Bundle ID を取得

```sh
SETTINGS=$(xcodebuild -showBuildSettings \
  -project NinjacordApp.xcodeproj -scheme "$SCHEME" -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" 2>/dev/null)

BUILT_DIR=$(echo "$SETTINGS" | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
APP_NAME=$(echo "$SETTINGS" | awk -F' = ' '/ FULL_PRODUCT_NAME /{print $2; exit}')
BUNDLE_ID=$(echo "$SETTINGS" | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER /{print $2; exit}')
APP_PATH="$BUILT_DIR/$APP_NAME"
echo "APP_PATH=$APP_PATH"; echo "BUNDLE_ID=$BUNDLE_ID"
```

### 4. Simulator を起動して install / launch

```sh
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$DEVICE" "$APP_PATH"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
```

### 5. スクリーンショットで確認

```sh
xcrun simctl io "$DEVICE" screenshot /tmp/ninjacord-screen.png
```

取得した `/tmp/ninjacord-screen.png` を Read して UI を目視確認し、Issue の要件を満たしているか報告する。

## 報告フォーマット

- ビルド: 成功 / 失敗（失敗なら `error:` 行と該当ファイル）
- 起動: 成功 / 失敗
- 目視: スクリーンショットを見て、変更点が期待通りか（差分の該当画面に言及）

## 注意

- SPM 解決で固まる場合は `-derivedDataPath ./DerivedData` を消して再試行、または Xcode を一度開いて解決させる。
- コード署名は Simulator では不要（`CODE_SIGNING_ALLOWED=NO` は付けない — Debug/Simulator は既定で通る）。
- 破壊的な `simctl erase` は勝手に実行しない。
