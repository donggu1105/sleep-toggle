#!/bin/bash
# 지정한 앱만 정상 종료하고 같은 파일시스템에서 교체한다. 권한·전원 설정은 변경하지 않는다.
set -euo pipefail

usage() {
  cat <<'HELP'
사용법: bash scripts/install.sh [--no-launch] [--destination /전체/경로/이름.app]

로컬 소스를 빌드해 기본 ~/Applications/Sleep Toggle.app에 설치하고 실행합니다.
  --no-launch          설치 후 실행하지 않습니다.
  --destination PATH   설치할 앱의 절대 경로(.app)를 지정합니다.
  -h, --help           도움말을 표시합니다.

기존 앱은 같은 폴더의 .sleep-toggle-backup.XXXXXX/ 아래 보관합니다.
정상 종료가 거부되거나 10초 안에 끝나지 않으면 교체하지 않습니다.
다른 경로의 동일 앱이 실행 중이면 --no-launch로 실행 없이 설치할 수 있습니다.
HELP
}
fail() { printf '오류: %s\n' "$*" >&2; exit 1; }

project_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
destination="$HOME/Applications/Sleep Toggle.app"
launch=true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-launch) launch=false; shift ;;
    --destination)
      [ "$#" -ge 2 ] || fail '--destination에는 절대 경로가 필요합니다.'
      destination="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "알 수 없는 옵션: $1" ;;
  esac
done
[ "$(uname -s)" = Darwin ] || fail 'macOS에서만 설치할 수 있습니다.'
case "$destination" in /*.app) ;; *) fail '설치 경로는 .app으로 끝나는 절대 경로여야 합니다.' ;; esac
[ ! -L "$destination" ] || fail '앱 자체가 심볼릭 링크인 경로에는 설치하지 않습니다.'
mkdir -p "$(dirname "$destination")"
parent_dir="$(cd "$(dirname "$destination")" && pwd -P)"
destination="$parent_dir/$(basename "$destination")"
source_app="$project_dir/dist/Sleep Toggle.app"
[ "$destination" != "$source_app" ] || fail '빌드 산출물 경로를 설치 경로로 사용할 수 없습니다.'
bundle_id='com.joeykang.sleep-toggle'
check_destination() {
  [ ! -L "$destination" ] || fail '설치 경로가 심볼릭 링크로 바뀌었습니다.'
  if [ -e "$destination" ]; then
    [ -d "$destination" ] || fail '설치 경로에 앱이 아닌 파일이 있습니다.'
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)"
    [ "$existing_id" = "$bundle_id" ] || fail '다른 앱 또는 식별할 수 없는 앱은 덮어쓰지 않습니다.'
  fi
}
check_destination
lock_dir="${destination}.install-lock"
mkdir "$lock_dir" 2>/dev/null || fail "설치 잠금이 있습니다: $lock_dir"
staging_dir=''
backup_dir=''
installed=false
completed=false
cleanup() {
  result=$?
  trap - EXIT
  if [ "$completed" = false ]; then
    if [ "$installed" = true ]; then
      if ! mv "$destination" "$staging_dir/failed.app"; then
        printf '새 앱 이동 실패. 수동 복구용 백업: %s\n' "$backup_dir" >&2
        result=1
      fi
    fi
    if [ -n "$backup_dir" ] && [ -e "$backup_dir/$(basename "$destination")" ]; then
      if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        mv "$backup_dir/$(basename "$destination")" "$destination" || result=1
      else
        printf '기존 앱은 백업에 보존했습니다: %s\n' "$backup_dir" >&2
        result=1
      fi
    fi
  fi
  [ -z "$staging_dir" ] || rm -rf "$staging_dir"
  [ -z "$backup_dir" ] || rmdir "$backup_dir" 2>/dev/null || true
  rmdir "$lock_dir" 2>/dev/null || true
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

bash "$project_dir/scripts/build.sh"
check_destination
staging_dir="$(mktemp -d "$parent_dir/.sleep-toggle-install.XXXXXX")"
/usr/bin/ditto "$source_app" "$staging_dir/new.app"
/usr/bin/codesign --verify --strict "$staging_dir/new.app"

# 앱 이름이나 전역 bundle ID만으로 종료하면 다른 설치본까지 종료될 수 있다.
# terminate()는 정상 종료 요청이며 인증 중 거부·지연될 때 강제 종료하지 않는다.
check_app_processes() {
swift - "$destination" "$bundle_id" "$1" "$launch" <<'SWIFT'
import AppKit
let target = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
func running() -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments[2]).filter { !$0.isTerminated }
}
func isTarget(_ application: NSRunningApplication) -> Bool {
    application.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == target
}
if CommandLine.arguments[3] == "verify" {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        if let application = running().first(where: isTarget) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            if !application.isTerminated { exit(0) }
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    fputs("설치한 경로에서 앱 실행을 확인하지 못했습니다. 기존 설치본 복구를 시도합니다.\n", stderr)
    exit(1)
}
let allApplications = running()
if CommandLine.arguments[4] == "true" {
    let otherApplications = allApplications.filter { !isTarget($0) }
    if !otherApplications.isEmpty {
        for application in otherApplications {
            fputs("다른 설치본이 실행 중입니다: \(application.bundleURL?.path ?? "경로 확인 불가")\n", stderr)
        }
        fputs("해당 앱을 종료한 뒤 다시 설치하거나 --no-launch로 실행 없이 설치해 주세요.\n", stderr)
        exit(1)
    }
}
let applications = allApplications.filter(isTarget)
for application in applications {
    guard application.terminate() else {
        fputs("앱이 정상 종료를 거부했습니다. 진행 중인 작업이 끝난 뒤 다시 설치해 주세요.\n", stderr)
        exit(1)
    }
}
let deadline = Date().addingTimeInterval(10)
while applications.contains(where: { !$0.isTerminated }) && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
guard applications.allSatisfy({ $0.isTerminated }) else {
    fputs("앱 종료 대기 시간이 지났습니다. 강제 종료하지 않고 설치를 중단합니다.\n", stderr)
    exit(1)
}
SWIFT
}
check_app_processes prepare

check_destination
if [ -e "$destination" ]; then
  backup_dir="$(mktemp -d "$parent_dir/.sleep-toggle-backup.XXXXXX")"
  mv "$destination" "$backup_dir/$(basename "$destination")"
fi
mv "$staging_dir/new.app" "$destination"
installed=true
if [ "$launch" = true ]; then
  /usr/bin/open "$destination"
  check_app_processes verify
fi
completed=true
printf '설치 완료: %s\n' "$destination"
if [ -n "$backup_dir" ]; then
  printf '이전 설치본 백업: %s\n' "$backup_dir/$(basename "$destination")"
fi
