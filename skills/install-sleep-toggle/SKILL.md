---
name: install-sleep-toggle
description: >-
  macOS 메뉴 막대 앱 Sleep Toggle을 공식 GitHub 소스에서 빌드해 설치하거나 업데이트한다.
  사용자가 해·달 잠자기 토글 앱의 설치를 요청할 때 사용한다.
  기존 전원 설정을 유지하며 설치, 실행, 로그인 자동 실행 등록 상태를 확인한다.
---

# Sleep Toggle 설치

소스: https://github.com/donggu1105/sleep-toggle

기본 설치 위치는 `~/Applications/Sleep Toggle.app`이다. 해는 전역 잠자기 차단, 달은 잠자기 허용이다. 일반 앱 실행 시 로그인 자동 실행이 등록된다.

## 소스와 환경

- macOS 13 이상과 Swift 6 이상이 필요하다. `sw_vers`, `xcrun --find swift`, `swift --version`으로 확인한다. 개발 도구가 없으면 필요한 도구와 실제 오류를 알리고, 설치되지 않은 상태에서 성공으로 보고하지 않는다.
- 사용자가 이 저장소의 로컬 작업본을 지정했다면 그 경로를 사용한다. 변경 사항을 덮어쓰거나 강제로 최신화하지 않는다. 업데이트가 필요할 때는 깨끗한 작업본에서 `git pull --ff-only`를 사용한다.
- 작업본을 지정하지 않았다면 공식 저장소를 새 임시 작업 디렉터리에 복제한다. 이 스킬만 별도로 설치할 수 있으므로 `SKILL.md`의 상위 폴더에 앱 소스가 있다고 가정하지 않는다.

```bash
sleep_toggle_workspace="$(mktemp -d "${TMPDIR:-/tmp}/sleep-toggle.XXXXXX")"
git clone --depth 1 https://github.com/donggu1105/sleep-toggle.git "$sleep_toggle_workspace/source"
```

## 설치

1. `/usr/bin/pmset -g`에서 기존 `SleepDisabled` 값을 기록한다. 앱에서 관리자 인증·전환이 진행 중이라면 완료된 뒤 설치한다.
2. 소스 작업본의 `scripts/install.sh`를 읽고 `bash scripts/install.sh`를 실행한다. 스크립트가 빌드·서명 확인·백업·교체·실행을 담당한다. 현재 전원 설정은 변경하지 않는다. 사용자가 설치 위치를 지정했다면 `--destination`에 절대 `.app` 경로를 전달하고 이후 진단도 그 경로에서 수행한다.
3. 사용자가 실행 없이 설치만 요청했다면 `--no-launch`를 사용한다. 이 경우 로그인 항목은 첫 일반 실행 때 등록되므로 아직 등록됐다고 보고하지 않는다.

다른 폴더의 동일 앱이 실행 중이면 자동 실행 설치가 중단된다. 해당 앱을 임의로 종료하지 않고 사용자가 지정한 실행·설치 범위를 따른다. 기존 앱이 정상 종료되지 않으면 강제 종료하거나 파일을 덮어쓰지 않는다. 설치 실패 시 스크립트가 출력한 오류와 백업 경로를 확인한다. 관리자 암호를 수집하지 않고, `sudoers`, TCC, Gatekeeper 설정을 바꾸지 않는다.

## 확인과 보고

기본 설치 위치에서 읽기 전용 진단을 실행한다.

```bash
"$HOME/Applications/Sleep Toggle.app/Contents/MacOS/SleepToggle" --status
```

- `sleepDisabled`가 설치 전과 같은지 확인한다. 다르면 원인을 조사하고, 설치를 이유로 `pmset` 값을 되돌리거나 시험 삼아 토글하지 않는다.
- 앱을 실행했다면 `launchAtLoginEnabled: true`로 로그인 등록 완료를 확인한다. `loginStatus: 2`는 macOS 승인 필요 상태다. 앱 메뉴의 로그인 항목 설정에서 처리하고 실제 상태를 다시 읽는다. `false`를 성공으로 보고하거나 시스템의 승인 요구를 우회하지 않는다.
- 실행 프로세스와 실제 메뉴 막대 아이콘을 확인할 수 있으면 확인한다. 화면을 볼 수 없다면 프로세스·진단 확인과 화면 확인을 구분해 보고한다.
- `--smoke-test`는 임시 메뉴 항목을 만들므로 일반 앱과 동시에 실행하지 않는다. 설치 확인에는 `--status`면 충분하다.

설치 경로, 현재 해·달 상태, 로그인 등록 결과를 짧게 보고한다. 아이콘이 숨겨졌다면 Spotlight에서 Sleep Toggle을 다시 열어 메뉴에 접근할 수 있음을 안내한다. 실제 재로그인을 하지 않았다면 다음 로그인 실행까지 시험했다고 말하지 않는다.
