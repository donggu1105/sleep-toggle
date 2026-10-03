# Sleep Toggle

macOS 메뉴 막대에서 **전역 잠자기 차단**을 켜고 끄는 개인용 앱이다.
일시적인 caffeinate 대신 `pmset`의 `SleepDisabled`를 실제로 변경한다.

- **해:** 전역 잠자기 차단 (`1`).
- **달:** 전역 잠자기 허용 (`0`).
- 메뉴 막대에는 글자 없이 해 또는 달 아이콘만 표시한다. 아이콘을 누른 뒤 **잠자기 허용/차단으로 전환**을 선택한다.
- 아이콘이 숨겨졌다면 Finder나 Spotlight에서 **Sleep Toggle**을 다시 열면 메뉴가 나타난다.
- 변경에는 macOS 관리자 인증이 필요하다. 인증을 취소하면 설정을 바꾸지 않는다.
- 앱을 처음 실행하면 **로그인 시 자동 실행**을 등록한다. 이후 로그인할 때 자동으로 실행되며, 앱 안에는 이를 끄는 토글이 없다. macOS가 별도 허용을 요구하면 메뉴에 설정을 여는 항목이 나타난다.

앱 시작·종료는 전역 설정을 바꾸지 않는다. **종료해도 차단 설정은 유지된다.**
화면 꺼짐 시간은 별도 설정이며, 잠자기 허용 상태에서도 도크·외부 모니터 연결에 따른
클램셸 모드나 다른 앱의 잠자기 방지 요청이 작동할 수 있다.

## 빌드와 검증

Xcode/Command Line Tools의 Swift 6 이상, macOS 13 이상이 필요하다. 외부 의존성은 없다.

```bash
swift test
bash scripts/build.sh
"dist/Sleep Toggle.app/Contents/MacOS/SleepToggle" --status
"dist/Sleep Toggle.app/Contents/MacOS/SleepToggle" --smoke-test
```

`--status`, `--smoke-test`는 읽기 전용이며 로그인 항목도 등록하지 않는다.
`--smoke-test`는 임시 메뉴 항목을 생성하므로 일반 앱이 종료된 상태에서 실행한다.
테스트도 모의 명령 실행기를 사용하므로 전원 설정을 바꾸거나 관리자 인증을 띄우지 않는다.

결과 앱을 `~/Applications/Sleep Toggle.app`으로 복사해 사용한다.
로컬용 ad-hoc 서명이므로 다른 Mac에 배포하는 공증된 앱은 아니다.

## 삭제

전역 차단도 해제하려면 먼저 메뉴에서 **잠자기 허용으로 전환**한다.
앱을 종료하고 **시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램**에서
Sleep Toggle의 자동 실행을 제거한 다음 앱 파일을 삭제한다.
앱 파일 삭제만으로 시스템 전역 설정은 복구되지 않는다.

## 구현 근거

- [NSStatusItem.menu](https://developer.apple.com/documentation/appkit/nsstatusitem/menu)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [AppleScript do shell script와 관리자 인증](https://developer.apple.com/library/archive/technotes/tn2065/_index.html)

관리자 암호·별도 root helper·sudoers 규칙은 저장하거나 설치하지 않는다.
