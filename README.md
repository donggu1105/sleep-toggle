<p align="center">
  <img src="docs/assets/app-icon.png" width="88" alt="Sleep Toggle 앱 아이콘">
</p>

<h1 align="center">Sleep Toggle</h1>

<p align="center">해로 깨어 있게, 달로 잠들 수 있게.<br>macOS 전역 잠자기를 제어하는 작은 메뉴 막대 앱.</p>

| 메뉴 막대 | 상태 |
| :---: | --- |
| ☀️ 해 | 잠자기 차단 |
| 🌙 달 | 잠자기 허용 |

아이콘을 클릭해 상태를 전환합니다. 메뉴 막대에는 글자 없이 아이콘만 표시하고, 로그인하면 자동으로 실행됩니다. 설정을 바꿀 때는 macOS 관리자 인증을 사용합니다.

## 설치

**macOS 13 이상**, **Swift 6 이상**이 필요합니다. Xcode 또는 Command Line Tools가 설치되어 있어야 하며, 외부 패키지 의존성은 없습니다.

```bash
git clone https://github.com/donggu1105/sleep-toggle.git
cd sleep-toggle
bash scripts/install.sh
```

현재 Mac에서 소스를 빌드하고 서명을 확인한 뒤 `~/Applications/Sleep Toggle.app`에 설치해 실행합니다. 기존 앱이 있으면 정상 종료 후 백업하고 교체합니다. **설치와 업데이트는 현재 잠자기 설정을 바꾸지 않습니다.**

설치만 하고 바로 실행하지 않으려면:

```bash
bash scripts/install.sh --no-launch
```

설치 옵션은 `bash scripts/install.sh --help`에서 확인할 수 있습니다. 공증된 배포 파일을 다운로드하는 방식이 아니라, 자신의 Mac에서 빌드하고 로컬 서명하는 방식입니다.

## Codex 설치 스킬

[install-sleep-toggle](skills/install-sleep-toggle/SKILL.md) 스킬을 동봉했습니다. Codex가 소스를 받아 빌드·설치하고, 잠자기 상태와 로그인 자동 실행 등록을 확인합니다.

Codex에 다음과 같이 요청해 스킬을 설치합니다.

```text
$skill-installer https://github.com/donggu1105/sleep-toggle/tree/main/skills/install-sleep-toggle
```

설치 후 다음 턴에 요청합니다.

```text
$install-sleep-toggle 이 Mac에 Sleep Toggle을 설치하고 실행해 줘.
```

스킬 설치만으로 앱이 실행되거나 전원 설정이 바뀌지는 않습니다.

## 사용법

1. 메뉴 막대의 **해 또는 달 아이콘**을 클릭합니다.
2. **잠자기 허용으로 전환** 또는 **잠자기 차단으로 전환**을 선택합니다.
3. macOS 관리자 인증을 완료하면 실제 설정을 다시 읽어 아이콘에 반영합니다. 인증을 취소하면 설정을 바꾸지 않습니다.

- **자동 실행:** 앱을 처음 실행할 때 등록합니다. 승인이 필요한 경우 메뉴에서 로그인 항목 설정을 열 수 있습니다.
- **아이콘이 안 보일 때:** Spotlight에서 `Sleep Toggle`을 다시 열면 전환 메뉴가 나타납니다. 메뉴 막대 공간이 부족하면 ⌘ 키를 누른 채 아이콘을 오른쪽으로 옮길 수 있습니다.
- **앱을 종료할 때:** 설정은 그대로 유지됩니다. 차단을 해제하려면 먼저 달 상태로 전환하세요.

잠자기 허용은 전원 종료가 아닙니다. 화면 꺼짐 시간은 별도이며, 외부 모니터를 사용하는 클램셸 모드나 다른 앱의 잠자기 방지 요청도 영향을 줄 수 있습니다.

## 업데이트와 삭제

업데이트는 소스 폴더에서 실행합니다.

```bash
git pull --ff-only
bash scripts/install.sh
```

삭제하려면 앱을 종료하고 **시스템 설정 → 일반 → 로그인 항목**에서 Sleep Toggle을 제거한 뒤 앱 파일을 휴지통으로 옮깁니다. 앱 삭제만으로 전역 잠자기 설정이 복구되지는 않습니다.

## 개발과 검증

Swift 6 · AppKit · ServiceManagement. 전역 상태는 `pmset`의 `SleepDisabled`로 확인하며, 상태 변경은 `0` 또는 `1`만 사용합니다. 관리자 암호를 저장하거나 별도 권한 도우미를 설치하지 않습니다.

```bash
swift test
bash scripts/build.sh
"dist/Sleep Toggle.app/Contents/MacOS/SleepToggle" --status
```

`--status`는 현재 잠자기 상태와 로그인 등록 상태를 JSON으로 출력합니다. 메뉴·아이콘 검증은 일반 앱을 종료한 뒤 실행합니다.

```bash
"dist/Sleep Toggle.app/Contents/MacOS/SleepToggle" --smoke-test
```

두 진단 명령은 전원 설정을 변경하거나 로그인 항목을 등록하지 않습니다. 테스트도 모의 실행기를 사용해 관리자 인증 없이 검증합니다.

| 경로 | 역할 |
| --- | --- |
| `Sources/SleepToggle` | 메뉴 막대 UI, 해·달 아이콘, 자동 실행 |
| `Sources/SleepToggleCore` | 상태 조회, 관리자 인증, 변경 후 검증 |
| `scripts` | 빌드, 앱 아이콘 생성, 설치 |
| `skills/install-sleep-toggle` | Codex용 설치 스킬 |
| `Tests` | 상태 파싱과 전환·취소·오류 처리 테스트 |
