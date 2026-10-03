import Foundation
import XCTest
@testable import SleepToggleCore

private actor 모의실행기: CommandRunning {
    private var results: [CommandResult]
    private var commands: [Command] = []

    init(_ results: [CommandResult]) { self.results = results }

    func run(_ command: Command) async throws -> CommandResult {
        commands.append(command)
        guard !results.isEmpty else { throw NSError(domain: "예상하지_않은_명령", code: 1) }
        return results.removeFirst()
    }

    func 실행명령() -> [Command] { commands }
}

@MainActor
final class SleepControlTests: XCTestCase {
    func test_독립된_키의_허용과_차단을_읽는다() throws {
        XCTAssertEqual(try SleepMode.parse("System-wide power settings:\n SleepDisabled\t0\nCurrently in use:\n sleep 1"), .allowed)
        XCTAssertEqual(try SleepMode.parse("\tSleepDisabled 1\r\n"), .blocked)
        XCTAssertEqual(SleepMode.allowed.opposite, .blocked)
        XCTAssertEqual(SleepMode.blocked.opposite, .allowed)
        XCTAssertEqual(SleepMode.allowed.title, "잠자기 허용")
        XCTAssertEqual(SleepMode.blocked.title, "잠자기 차단")
    }

    func test_없거나_중복되거나_잘못된_값을_거부한다() {
        for output in ["", "OtherSleepDisabled 1", "SleepDisabledExtra 1", "SleepDisabled", "SleepDisabled 2", "SleepDisabled 01", "SleepDisabled 1 extra", "SleepDisabled 0\nSleepDisabled 1", "SleepDisabled 0\nSleepDisabled unknown"] {
            XCTAssertThrowsError(try SleepMode.parse(output), output)
        }
    }

    func test_읽기는_고정된_pmset_조회만_실행한다() async throws {
        let runner = 모의실행기([.init(status: 0, output: "SleepDisabled 1")])
        let mode = try await SleepController(runner: runner).read()
        XCTAssertEqual(mode, .blocked)
        let commands = await runner.실행명령()
        XCTAssertEqual(commands, [Command(executable: "/usr/bin/pmset", arguments: ["-g"])])
    }

    func test_조회_명령의_실패는_유효한_출력이어도_거부한다() async {
        let runner = 모의실행기([.init(status: 1, output: "SleepDisabled 0")])
        do {
            _ = try await SleepController(runner: runner).read()
            XCTFail("실패한 명령이 성공으로 처리됨")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }

    func test_설정은_관리자_명령_후_실제_값을_확인한다() async throws {
        for mode in [SleepMode.allowed, .blocked] {
            let runner = 모의실행기([.init(status: 0, output: ""), .init(status: 0, output: "SleepDisabled \(mode.rawValue)")])
            let actual = try await SleepController(runner: runner).set(mode)
            XCTAssertEqual(actual, mode)
            let commands = await runner.실행명령()
            XCTAssertEqual(commands.count, 2)
            XCTAssertEqual(commands[0].executable, "/usr/bin/osascript")
            XCTAssertEqual(commands[0].arguments.count, 2)
            XCTAssertEqual(commands[0].arguments[0], "-e")
            let script = commands[0].arguments[1]
            XCTAssertTrue(script.contains("do shell script \"/usr/bin/pmset -a disablesleep \(mode.rawValue)\" with administrator privileges"))
            XCTAssertTrue(script.contains("-128"))
            XCTAssertTrue(script.contains("SLEEP_TOGGLE_CANCELLED"))
            XCTAssertTrue(script.contains("on error"))
            XCTAssertEqual(commands[1], Command(executable: "/usr/bin/pmset", arguments: ["-g"]))
        }
    }

    func test_인증_취소는_성공_종료여도_취소로_구분한다() async {
        for status: Int32 in [0, 1] {
            let runner = 모의실행기([.init(status: status, output: "SLEEP_TOGGLE_CANCELLED\n")])
            do {
                _ = try await SleepController(runner: runner).set(.blocked)
                XCTFail("취소가 성공으로 처리됨")
            } catch SleepControlError.cancelled {
                let commands = await runner.실행명령()
                XCTAssertEqual(commands.count, 1)
            } catch { XCTFail("취소 대신 다른 오류 발생: \(error)") }
        }
    }

    func test_설정_실패는_재조회하지_않고_출력을_노출하지_않는다() async {
        let secret = String(repeating: "민감한출력", count: 1000)
        let runner = 모의실행기([.init(status: 1, output: secret)])
        do {
            _ = try await SleepController(runner: runner).set(.blocked)
            XCTFail("실패가 성공으로 처리됨")
        } catch {
            XCTAssertLessThan(error.localizedDescription.count, 300)
            XCTAssertFalse(error.localizedDescription.contains("민감한출력"))
            let commands = await runner.실행명령()
            XCTAssertEqual(commands.count, 1)
        }
    }

    func test_설정_뒤_실제_값이_다르면_실패한다() async {
        let runner = 모의실행기([.init(status: 0, output: ""), .init(status: 0, output: "SleepDisabled 0")])
        do {
            _ = try await SleepController(runner: runner).set(.blocked)
            XCTFail("실제 값 불일치가 성공으로 처리됨")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }

    func test_설정_뒤_조회가_실패하면_성공으로_처리하지_않는다() async {
        let runner = 모의실행기([.init(status: 0, output: ""), .init(status: 1, output: "SleepDisabled 1")])
        do {
            _ = try await SleepController(runner: runner).set(.blocked)
            XCTFail("확인 실패가 성공으로 처리됨")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
}
