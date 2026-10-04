import AppKit
import ServiceManagement
import SleepToggleCore

// 전역 설정은 앱 수명과 무관하게 유지된다. 아이콘은 로컬 토글 값이 아니라
// pmset의 실제 값을 표시하며, 인증·재조회가 끝나기 전에는 성공으로 그리지 않는다.
@main
struct SleepToggleApplication {
    @MainActor
    static func main() {
        let diagnostics = CommandLine.arguments.contains("--status")
            || CommandLine.arguments.contains("--smoke-test")
        if !diagnostics, let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = SleepController()
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "상태 확인 중…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "상태 확인 중…", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "로그인 시 자동 실행", action: nil, keyEquivalent: "")
    private let loginSettingsItem = NSMenuItem(title: "로그인 항목 설정 열기…", action: nil, keyEquivalent: "")
    private let refreshItem = NSMenuItem(title: "상태 새로고침", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "종료", action: nil, keyEquivalent: "q")
    private var mode: SleepMode?
    private var isChanging = false
    private var isRefreshing = false
    private var generation = 0
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--status") {
            Task { await runDiagnostics(includeMenu: false) }
            return
        }
        buildMenu()
        if CommandLine.arguments.contains("--smoke-test") {
            Task { await runDiagnostics(includeMenu: true) }
            return
        }
        enableLoginAtLaunch()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(wokeUp), name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    private func buildMenu() {
        menu.autoenablesItems = false
        menu.delegate = self
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        configure(toggleItem, action: #selector(toggleSleep))
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        loginItem.isEnabled = false
        menu.addItem(loginItem)
        configure(loginSettingsItem, action: #selector(openLoginSettings))
        menu.addItem(loginSettingsItem)
        configure(refreshItem, action: #selector(refreshClicked))
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        let persistence = NSMenuItem(title: "앱을 종료해도 전역 설정은 유지됩니다", action: nil, keyEquivalent: "")
        persistence.isEnabled = false
        menu.addItem(persistence)
        configure(quitItem, action: #selector(quit))
        menu.addItem(quitItem)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.autosaveName = "SleepToggleStatusItem"
        statusItem?.isVisible = true
        statusItem?.button?.imagePosition = .imageOnly
        statusItem?.menu = menu
        render()
    }

    private func configure(_ item: NSMenuItem, action: Selector) {
        item.target = self
        item.action = action
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateLoginItem()
        Task { await refresh() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 전체 화면이나 메뉴 막대 공간 부족으로 아이콘이 숨겨져도
        // Finder/Spotlight에서 앱을 다시 열면 설정 메뉴에 접근할 수 있게 한다.
        Task {
            await refresh()
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
        return false
    }

    @objc private func wokeUp() { Task { await refresh() } }
    @objc private func refreshClicked() { Task { await refresh() } }

    private func refresh() async {
        guard !isChanging, !isRefreshing else { return }
        isRefreshing = true
        let requestGeneration = generation
        defer { isRefreshing = false }
        do {
            let actual = try await controller.read()
            guard requestGeneration == generation, !isChanging else { return }
            mode = actual
        } catch {
            guard requestGeneration == generation, !isChanging else { return }
            mode = nil
            statusItem?.button?.toolTip = "전역 잠자기 상태를 읽지 못했습니다. 메뉴에서 다시 확인해 주세요."
        }
        render()
    }

    @objc private func toggleSleep() {
        guard let mode, !isChanging else { return }
        // 클릭 당시 메뉴에 표시한 목표를 지킨다. 외부 변경이 있더라도 반대로 뒤집지 않는다.
        let target = mode.opposite
        generation += 1
        isChanging = true
        render()
        Task {
            do {
                let before = try await controller.read()
                self.mode = before == target ? before : try await controller.set(target)
                isChanging = false
                render()
            } catch SleepControlError.cancelled {
                self.mode = try? await controller.read()
                isChanging = false
                render()
            } catch {
                self.mode = try? await controller.read()
                isChanging = false
                render()
                showError(title: "잠자기 설정을 바꾸지 못했습니다", message: error.localizedDescription)
            }
        }
    }

    private func render() {
        let label = mode?.title ?? "상태 확인 필요"
        stateItem.title = isChanging ? "관리자 인증 및 적용 중…" : "전역 \(label)"
        toggleItem.title = mode.map { "\($0.opposite.title)으로 전환" } ?? "먼저 상태를 확인해 주세요"
        toggleItem.isEnabled = mode != nil && !isChanging
        refreshItem.isEnabled = !isChanging
        quitItem.isEnabled = !isChanging
        let image = StatusIcon.make(mode: mode)
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = "Sleep Toggle — \(isChanging ? "설정 적용 중" : label)"
        statusItem?.button?.setAccessibilityLabel("Sleep Toggle, \(label)")
        updateLoginItem()
    }

    private func updateLoginItem() {
        let status = SMAppService.mainApp.status
        loginItem.state = status == .enabled ? .on : status == .requiresApproval ? .mixed : .off
        switch status {
        case .enabled:
            loginItem.title = "로그인 시 자동 실행"
        case .requiresApproval:
            loginItem.title = "로그인 시 자동 실행: 승인 필요"
        default:
            loginItem.title = "로그인 시 자동 실행: 설정 필요"
        }
        loginSettingsItem.isHidden = status == .enabled
        loginSettingsItem.isEnabled = !isChanging
    }

    private func enableLoginAtLaunch() {
        // 자동 실행은 기본 동작이다. 읽기 전용 진단에서는 등록하지 않으며,
        // macOS가 승인을 요구하면 반복 등록하지 않고 시스템 설정으로 안내한다.
        do {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval:
                break
            default:
                try SMAppService.mainApp.register()
            }
            updateLoginItem()
        } catch {
            showError(title: "로그인 시 자동 실행을 등록하지 못했습니다", message: error.localizedDescription)
            updateLoginItem()
        }
    }

    @objc private func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func quit() {
        guard !isChanging else { return }
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 설치 프로그램의 정상 종료 요청도 관리자 인증·상태 재조회가 끝날 때까지 거절한다.
        isChanging ? .terminateCancel : .terminateNow
    }

    private func showError(title: String, message: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    // 설치본 자체의 파서·상태와 메뉴/아이콘 구성을 확인하는 읽기 전용 진입점이다.
    private func runDiagnostics(includeMenu: Bool) async {
        do {
            mode = try await controller.read()
            if includeMenu { render() }
            var result: [String: Any] = [
                "sleepDisabled": mode!.rawValue,
                "state": mode!.title,
                "bundleIdentifier": Bundle.main.bundleIdentifier ?? "패키지 실행",
                "loginStatus": SMAppService.mainApp.status.rawValue,
                "launchAtLoginEnabled": SMAppService.mainApp.status == .enabled,
            ]
            if includeMenu {
                let allowed = StatusIcon.make(mode: .allowed)
                let blocked = StatusIcon.make(mode: .blocked)
                let idleTermination = applicationShouldTerminate(NSApplication.shared)
                isChanging = true
                let busyTermination = applicationShouldTerminate(NSApplication.shared)
                isChanging = false
                guard statusItem?.button?.image != nil, statusItem?.button?.title == "",
                      !loginItem.isEnabled, loginItem.action == nil, toggleItem.isEnabled,
                      idleTermination == .terminateNow, busyTermination == .terminateCancel,
                      toggleItem.title == "\(mode!.opposite.title)으로 전환",
                      allowed.tiffRepresentation != blocked.tiffRepresentation else {
                    throw NSError(domain: "SleepToggle", code: 1, userInfo: [NSLocalizedDescriptionKey: "메뉴 또는 아이콘 검증에 실패했습니다."])
                }
                result["menuItems"] = menu.items.filter { !$0.isSeparatorItem && !$0.isHidden }.map(\.title)
                result["statusIcon"] = "검증 완료"
                result["terminationGuard"] = "검증 완료"
            }
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
            NSApplication.shared.terminate(nil)
        } catch {
            FileHandle.standardError.write(Data("확인 실패: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

@MainActor
enum StatusIcon {
    static func make(mode: SleepMode?) -> NSImage {
        // 해는 깨어 있음(차단), 달은 잠자기 허용이다. 인증 중에도 확인된 상태를 유지한다.
        let name = mode == nil ? "questionmark.circle" : mode == .blocked ? "sun.max.fill" : "moon.fill"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))!
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }
}
