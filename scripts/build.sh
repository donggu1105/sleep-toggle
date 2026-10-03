#!/bin/bash
# 재현 가능한 로컬 빌드. 설치와 전원 설정 변경은 이 스크립트의 역할이 아니다.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_dir/dist/Sleep Toggle.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/SleepToggle" "$app_dir/Contents/MacOS/SleepToggle"
iconset_dir="$project_dir/.build/SleepToggle.iconset"
swift scripts/make-icon.swift "$iconset_dir"
iconutil -c icns "$iconset_dir" -o "$app_dir/Contents/Resources/AppIcon.icns"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>SleepToggle</string>
  <key>CFBundleIdentifier</key><string>com.joeykang.sleep-toggle</string>
  <key>CFBundleName</key><string>Sleep Toggle</string>
  <key>CFBundleDisplayName</key><string>Sleep Toggle</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>LSMultipleInstancesProhibited</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.joeykang.sleep-toggle "$app_dir"
codesign --verify --strict --verbose=2 "$app_dir"
printf '빌드 완료: %s\n' "$app_dir"
