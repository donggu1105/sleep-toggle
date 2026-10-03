# 상태 모듈 구현 계약

소유 파일은 `Sources/SleepToggleCore/SleepControl.swift`와 `Tests/SleepToggleCoreTests/SleepControlTests.swift` 두 개다.
다른 파일은 루트가 작성한다. 패키지는 Swift 6 / macOS 13이며 외부 의존성이 없다.

공개 인터페이스를 아래와 같이 제공한다.

```swift
public enum SleepMode: Int, Sendable { case allowed = 0, blocked = 1 }
// var opposite: SleepMode
// var title: String ("잠자기 허용" / "잠자기 차단")
// static func parse(_ output: String) throws -> SleepMode
public struct Command: Sendable, Equatable {
  public let executable: String
  public let arguments: [String]
  public init(executable: String, arguments: [String])
}
public struct CommandResult: Sendable {
  public let status: Int32
  public let output: String
  public init(status: Int32, output: String)
}
public protocol CommandRunning: Sendable {
  func run(_ command: Command) async throws -> CommandResult
}
public struct ProcessRunner: CommandRunning { public init() }
public struct SleepController: Sendable {
  public init(runner: any CommandRunning = ProcessRunner())
  public func read() async throws -> SleepMode
  public func set(_ mode: SleepMode) async throws -> SleepMode
}
public enum SleepControlError: Error, LocalizedError, Sendable {
  case cancelled
  // 나머지 오류 형태는 구현자가 결정하되 오류 설명은 한국어.
}
```

파서는 독립된 `SleepDisabled` 키의 정확한 0/1을 읽고 없거나 중복/알 수 없는 값은 오류다.
read는 고정 `/usr/bin/pmset -g`를 실행하고 비정상 종료를 오류로 처리한다.
set은 `/usr/bin/osascript -e <스크립트>`로 `/usr/bin/pmset -a disablesleep 0 또는 1`만 실행한다.
스크립트는 `with administrator privileges`를 사용한다.
AppleScript `try/on error ... number ...`에서 -128 취소를 고유 마커 `SLEEP_TOGGLE_CANCELLED`로 반환하고,
기타 오류는 다시 error로 전달한다. 종료 상태가 0이어도 취소 마커면 .cancelled이다.
성공 후 read로 요청 값과 실제 값이 일치해야 성공한다. 실제 출력 전체를 UI 오류에 무제한 노출하지 않는다.
ProcessRunner는 메인 UI를 막지 않게 비동기로 실행하고 stdout/stderr 파이프 교착을 피한다.
테스트에서는 모의 실행기를 써 실제 전원 설정이나 관리자 인증을 호출하지 않는다.
테스트 이름/모듈 설계 주석은 한국어. 테스트를 먼저 만들어 실패를 확인하고 구현한다.
완료 보고는 구현 파일, 테스트 명령/결과, API 변경/유의점만 간결하게 한다. 추가 위임은 하지 않는다.
