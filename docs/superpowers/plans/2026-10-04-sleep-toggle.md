# Sleep Toggle 구현 계획

**Goal:** 실제 전역 잠자기 차단 상태를 표시하고 관리자 인증으로 전환하는 메뉴 막대 앱을 설치한다.
**Architecture:** 순수 상태·명령 모듈과 AppKit UI를 나누고, 변경 후에는 pmset을 다시 조회한다.
**Tech Stack:** Swift 6, AppKit, ServiceManagement, Swift Testing, macOS 13 이상.
**Spec:** `../specs/2026-10-04-sleep-toggle-design.md`

## 공통 제약

- UI·주석·테스트 이름·문서는 한국어다. 외부 의존성은 없다.
- 빌드·설치·테스트는 실행 전의 전역 잠자기 상태를 변경하지 않는다.
- 상태 변경은 사용자 클릭 뒤 macOS 인증으로 두 고정 명령만 실행한다.
- 암호 저장·권한 정책 변경은 하지 않는다.

## 작업 1: 상태와 권한 명령

- [x] `Sources/SleepToggleCore/SleepControl.swift` 구현.
- [x] `Tests/SleepToggleCoreTests/SleepControlTests.swift`에 의미 있는 실패·취소·검증 테스트 작성과 실행.
- [x] `CommandRunning`을 주입해 실제 관리자 명령 없이 테스트.
- [x] 상태 0/1 이외 출력은 실패 처리하고, 취소와 실패를 구분.

## 작업 2: 메뉴와 패키징

- [x] `Sources/SleepToggle/App.swift`: 상태 메뉴, 아이콘, 중복 전환 방지, 외부 상태 갱신, 로그인 항목.
- [x] `scripts/make-icon.swift`: 달과 스위치 모티프의 앱 아이콘 생성.
- [x] `scripts/build.sh`: release 빌드, Info.plist, icns, ad-hoc 서명.
- [x] `README.md`: 사용법, 인증, 전역 설정 유지, 재빌드·삭제 방법.

## 작업 3: 통합 검증과 설치

- [x] `swift test`와 `swift build -c release` 검증.
- [x] `codesign --verify --strict`와 설치 앱 `--status`, `--smoke-test` 검증.
- [x] 독립 코드 검토에서 중요한 문제 해결.
- [x] `~/Applications/Sleep Toggle.app` 설치·실행.
- [x] 실행 프로세스, 상태 아이콘, 실제 전역 값 1 확인 후 결과 보고.

## 후속 변경: 해·달 아이콘과 자동 실행, GitHub 보관

- [x] 글자와 빗금 표시를 없애고 해(차단)·달(허용) 아이콘으로 변경.
- [x] 일반 실행 시 로그인 항목 자동 등록, 앱 안의 끄기 토글 제거.
- [x] 상태를 바꾸지 않고 테스트·빌드·실제 메뉴 표시와 로그인 등록 상태 확인.
- [ ] 개인 GitHub 계정의 비공개 `sleep-toggle` 저장소에 소스 업로드 및 원격 커밋 확인.
