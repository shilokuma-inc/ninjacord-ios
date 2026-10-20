#!/usr/bin/env python3
"""ユニットテストを流す iPhone の Simulator を選び、UDID を出力する。

    UDID="$(python3 Tools/select_test_simulator.py)"
    xcodebuild test-without-building ... -destination "platform=iOS Simulator,id=$UDID"

Simulator の名前（"iPhone 17 Pro" など）は、ランナーのイメージや OS の更新で変わったり
"iPhone 17 Pro (6.3inch/1206x2622)" のように改名されたりして、`name=` の指定が壊れる。
そのため名前では選ばず、`xcrun simctl list devices available` にある iPhone から選ぶ。
ビルドに使う SDK より新しいランタイム（ベータなど）には入れられないので、SDK 以下で一番新しいランタイムのものを使う。
"""

import json
import subprocess
import sys


def version(text):
    return [int(part) for part in text.split(".")]


def simctl_list(kind):
    output = subprocess.check_output(["xcrun", "simctl", "list", "-j", kind, "available"], text=True)
    return json.loads(output)[kind]


def main():
    sdk_version = subprocess.check_output(
        ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], text=True
    ).strip()
    runtimes = [
        runtime for runtime in simctl_list("runtimes")
        if "SimRuntime.iOS" in runtime.get("identifier", "")
        and runtime.get("isAvailable")
        and version(runtime["version"])[:2] <= version(sdk_version)[:2]
    ]
    runtimes.sort(key=lambda runtime: version(runtime["version"]), reverse=True)

    devices = simctl_list("devices")
    for runtime in runtimes:
        for device in devices.get(runtime["identifier"], []):
            if device.get("isAvailable") and ".iPhone-" in device.get("deviceTypeIdentifier", ""):
                print(f"Simulator: {device['name']} / iOS {runtime['version']}（SDK {sdk_version}）", file=sys.stderr)
                print(device["udid"])
                return 0

    print(f"iOS {sdk_version} 以下のランタイムの iPhone の Simulator が見つかりません", file=sys.stderr)
    subprocess.run(["xcrun", "simctl", "list", "devices", "available"], stdout=sys.stderr, check=False)
    return 1


if __name__ == "__main__":
    sys.exit(main())
