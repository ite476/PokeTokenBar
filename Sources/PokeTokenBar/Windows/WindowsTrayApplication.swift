#if os(Windows)
import Foundation
import WinSDK

/// Windows 전용 트레이 애플리케이션 진입점.
///
/// macOS의 `NSStatusItem`/`NSPopover`를 Windows에서 대응시키기 위해 Win32 메시지
/// 루프, Shell 알림 아이콘, 작업표시줄에 붙는 작은 status window를 함께 사용한다.
/// C#이나 별도 런타임 UI 프레임워크가 필요하지 않으며, Core provider는 기존 Swift
/// 구현을 그대로 재사용한다.
@main
struct WindowsTrayApplication {
    static func main() {
        // SwiftPM의 Windows 기본 subsystem은 CUI이므로, 트레이 전용 실행에서는 현재
        // 콘솔 연결만 해제한다. 호출 셸의 창을 숨기거나 종료하지는 않는다.
        _ = FreeConsole()
        WindowsTrayHost().run()
    }
}

/// 숨김 Win32 윈도우, 트레이 아이콘, 상태 표시창의 수명주기를 관리한다.
///
/// 유지보수 주의점:
/// - 모든 Win32 콜백은 이 파일의 전역 함수 포인터를 통해 현재 host 하나로 전달한다.
/// - `statusWindow`는 알림 영역에 텍스트를 삽입할 수 없는 Windows 제약을 보완하는
///   borderless 상태 표시창이다. Explorer가 아이콘을 overflow 영역으로 옮겨도 값은
///   계속 보인다.
/// - provider 스캔은 백그라운드 task에서 수행하고, 결과는 `PostMessageW`로 메시지
///   스레드에 전달한다. UI 객체를 provider task에서 직접 만지지 않는다.
final class WindowsTrayHost: @unchecked Sendable {
    fileprivate static let windowClassName = "PokeTokenBar.WindowsTrayHost"
    fileprivate static let statusWindowClassName = "PokeTokenBar.WindowsStatus"
    fileprivate static let trayCallbackMessage = UINT(WM_APP) + 1
    fileprivate static let snapshotReadyMessage = UINT(WM_APP) + 2
    private static let exitCommand = UINT(0x1001)
    private static let refreshCommand = UINT(0x1002)
    private static let aboutCommand = UINT(0x1003)
    private static let refreshTimerID = UINT_PTR(1)

    private var window: HWND?
    private var statusWindow: HWND?
    private var trayAdded = false
    private var instance: HINSTANCE?
    private var trayIcon: HICON?
    private var snapshot = WindowsUsageSnapshot.empty
    private let mailbox = WindowsUsageMailbox()
    private var refreshTask: Task<Void, Never>?

    func run() {
        instance = GetModuleHandleW(nil)
        guard let instance else {
            AppLog.write("Windows tray startup failed: GetModuleHandleW")
            return
        }

        trayIcon = WindowsTrayIconFactory.make()
        let registered = registerWindowClasses(instance: instance)
        let created = registered && createMessageWindow(instance: instance)
        let statusCreated = created && createStatusWindow(instance: instance)
        guard registered, created, statusCreated else {
            AppLog.write("Windows tray startup failed: window registration or creation")
            return
        }

        activeTrayHost = self
        addTrayIcon()
        positionStatusWindow()
        ShowWindow(statusWindow, SW_SHOWNOACTIVATE)
        SetTimer(window, Self.refreshTimerID, UINT(120_000), nil)
        refreshUsage()

        defer {
            refreshTask?.cancel()
            _ = KillTimer(window, Self.refreshTimerID)
            removeTrayIcon()
            if let trayIcon { DestroyIcon(trayIcon) }
            activeTrayHost = nil
            if let statusWindow { DestroyWindow(statusWindow) }
            if let window { DestroyWindow(window) }
            UnregisterClassW(Self.windowClassName.withWindowsString { $0 }, instance)
            UnregisterClassW(Self.statusWindowClassName.withWindowsString { $0 }, instance)
        }

        var message = MSG()
        while GetMessageW(&message, nil, 0, 0) {
            TranslateMessage(&message)
            DispatchMessageW(&message)
        }
    }

    private func registerWindowClasses(instance: HINSTANCE) -> Bool {
        var trayClass = WNDCLASSEXW()
        trayClass.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        trayClass.style = UINT(CS_HREDRAW | CS_VREDRAW)
        trayClass.lpfnWndProc = windowsTrayWindowProcedure
        trayClass.hInstance = instance
        trayClass.hIcon = trayIcon ?? LoadIconW(nil, windowsResourcePointer(32512))
        trayClass.hCursor = LoadCursorW(nil, windowsResourcePointer(32512))
        trayClass.hbrBackground = GetSysColorBrush(COLOR_WINDOW)

        let trayResult = Self.windowClassName.withWindowsString { name in
            trayClass.lpszClassName = name
            return RegisterClassExW(&trayClass)
        }

        var statusClass = WNDCLASSEXW()
        statusClass.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        statusClass.style = UINT(CS_HREDRAW | CS_VREDRAW)
        statusClass.lpfnWndProc = windowsStatusWindowProcedure
        statusClass.hInstance = instance
        statusClass.hIcon = trayIcon
        statusClass.hCursor = LoadCursorW(nil, windowsResourcePointer(32512))
        statusClass.hbrBackground = nil

        let statusResult = Self.statusWindowClassName.withWindowsString { name in
            statusClass.lpszClassName = name
            return RegisterClassExW(&statusClass)
        }
        return trayResult != 0 && statusResult != 0
    }

    private func createMessageWindow(instance: HINSTANCE) -> Bool {
        let created = Self.windowClassName.withWindowsString { name in
            "PokeTokenBar".withWindowsString { title in
                CreateWindowExW(
                    DWORD(WS_EX_TOOLWINDOW), name, title, WS_POPUP,
                    0, 0, 0, 0, nil, nil, instance, nil)
            }
        }
        window = created
        return created != nil
    }

    private func createStatusWindow(instance: HINSTANCE) -> Bool {
        let style = DWORD(WS_EX_TOOLWINDOW) | DWORD(WS_EX_NOACTIVATE) | DWORD(WS_EX_TOPMOST)
        let created = Self.statusWindowClassName.withWindowsString { name in
            "PokeTokenBar status".withWindowsString { title in
                CreateWindowExW(
                    style, name, title, WS_POPUP,
                    0, 0, 178, 44, nil, nil, instance, nil)
            }
        }
        statusWindow = created
        return created != nil
    }

    /// Windows 작업표시줄의 알림 영역에는 넓은 텍스트를 삽입할 수 없으므로, 작업표시줄
    /// 우측에 작은 상태창을 붙인다. 위치는 고정된 사용자 경로가 아니라 현재 화면의
    /// 작업 영역 크기로 계산해 DPI/해상도 변경에 대응한다.
    fileprivate func positionStatusWindow() {
        guard let statusWindow else { return }
        let screenWidth = Int(GetSystemMetrics(SM_CXSCREEN))
        let screenHeight = Int(GetSystemMetrics(SM_CYSCREEN))
        let width = 178
        let height = 44
        let taskbarTop = max(0, screenHeight - 64)
        let x = max(0, screenWidth - width - 360)
        // 작업표시줄 위에 완전히 놓아 taskbar 자체가 클릭을 가로채지 않게 한다.
        let y = max(0, taskbarTop - height - 8)
        SetWindowPos(
            statusWindow,
            nil,
            Int32(x), Int32(y), Int32(width), Int32(height),
            UINT(SWP_NOACTIVATE | SWP_SHOWWINDOW))
    }

    private func addTrayIcon() {
        guard let window else { return }
        var data = NOTIFYICONDATAW()
        data.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
        data.hWnd = window
        data.uID = UINT(1)
        data.uFlags = UINT(NIF_MESSAGE) | UINT(NIF_ICON) | UINT(NIF_TIP)
        data.uCallbackMessage = Self.trayCallbackMessage
        data.hIcon = trayIcon ?? LoadIconW(nil, windowsResourcePointer(32512))
        data.setTip(snapshot.tooltip)
        trayAdded = Shell_NotifyIconW(DWORD(NIM_ADD), &data)
    }

    private func updateTrayIcon() {
        guard trayAdded, let window else { return }
        var data = NOTIFYICONDATAW()
        data.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
        data.hWnd = window
        data.uID = UINT(1)
        data.uFlags = UINT(NIF_ICON) | UINT(NIF_TIP)
        data.hIcon = trayIcon ?? LoadIconW(nil, windowsResourcePointer(32512))
        data.setTip(snapshot.tooltip)
        _ = Shell_NotifyIconW(DWORD(NIM_MODIFY), &data)
    }

    private func removeTrayIcon() {
        guard trayAdded, let window else { return }
        var data = NOTIFYICONDATAW()
        data.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
        data.hWnd = window
        data.uID = UINT(1)
        _ = Shell_NotifyIconW(DWORD(NIM_DELETE), &data)
        trayAdded = false
    }

    /// provider 스캔은 메시지 루프를 막지 않는다. 결과가 오면 hidden window에 자체
    /// 메시지를 넣어 동일한 스레드에서 status window/tooltip을 갱신한다.
    fileprivate func refreshUsage() {
        refreshTask?.cancel()
        let mailbox = self.mailbox
        let host = self
        refreshTask = Task.detached(priority: .userInitiated) {
            let result = await WindowsUsageSnapshotLoader.load()
            mailbox.value = result
            if let window = host.window {
                PostMessageW(window, WindowsTrayHost.snapshotReadyMessage, 0, 0)
            }
        }
    }

    fileprivate func applySnapshot() {
        snapshot = mailbox.value
        updateTrayIcon()
        positionStatusWindow()
        InvalidateRect(statusWindow, nil, false)
    }

    fileprivate func showDetails() {
        let title = "PokeTokenBar Windows"
        let text = snapshot.detailText
        _ = title.withWindowsString { titlePointer in
            text.withWindowsString { textPointer in
                MessageBoxW(
                    window,
                    textPointer,
                    titlePointer,
                    UINT(MB_OK)
                        | UINT(MB_ICONINFORMATION)
                        | UINT(MB_SETFOREGROUND)
                        | UINT(MB_TOPMOST))
            }
        }
    }

    fileprivate func showMenu(at point: POINT) {
        guard let window, let menu = CreatePopupMenu() else { return }
        defer { DestroyMenu(menu) }

        _ = "새로고침".withWindowsString { label in
            AppendMenuW(menu, UINT(MF_STRING), UINT_PTR(Self.refreshCommand), label)
        }
        AppendMenuW(menu, UINT(MF_SEPARATOR), 0, nil)
        _ = "정보".withWindowsString { label in
            AppendMenuW(menu, UINT(MF_STRING), UINT_PTR(Self.aboutCommand), label)
        }
        _ = "종료".withWindowsString { label in
            AppendMenuW(menu, UINT(MF_STRING), UINT_PTR(Self.exitCommand), label)
        }

        SetForegroundWindow(window)
        TrackPopupMenu(menu, UINT(TPM_RIGHTALIGN), point.x, point.y, 0, window, nil)
        PostMessageW(window, UINT(WM_NULL), 0, 0)
    }

    fileprivate func handleCommand(_ command: UINT) {
        switch command {
        case Self.exitCommand:
            PostQuitMessage(0)
        case Self.refreshCommand:
            refreshUsage()
        case Self.aboutCommand:
            showDetails()
        default:
            break
        }
    }

    fileprivate var currentSnapshot: WindowsUsageSnapshot { snapshot }
}

private let windowsTrayWindowProcedure: WNDPROC = { window, message, wParam, lParam in
    switch message {
    case WindowsTrayHost.trayCallbackMessage:
        let event = lowWord(lParam)
        if event == UINT(WM_LBUTTONUP) || event == UINT(WM_LBUTTONDBLCLK) {
            activeTrayHost?.showDetails()
        } else if event == UINT(WM_RBUTTONUP) || event == UINT(WM_CONTEXTMENU) {
            var point = POINT()
            GetCursorPos(&point)
            activeTrayHost?.showMenu(at: point)
        }
        return 0

    case UINT(WM_COMMAND):
        activeTrayHost?.handleCommand(UINT(lowWord(wParam)))
        return 0

    case WindowsTrayHost.snapshotReadyMessage:
        activeTrayHost?.applySnapshot()
        return 0

    case UINT(WM_TIMER):
        if lowWord(wParam) == 1 { activeTrayHost?.refreshUsage() }
        return 0

    case UINT(WM_SETTINGCHANGE), UINT(WM_DISPLAYCHANGE):
        activeTrayHost?.positionStatusWindow()
        return 0

    case UINT(WM_DESTROY):
        PostQuitMessage(0)
        return 0

    default:
        return DefWindowProcW(window, message, wParam, lParam)
    }
}

private let windowsStatusWindowProcedure: WNDPROC = { window, message, wParam, lParam in
    switch message {
    case UINT(WM_PAINT):
        WindowsStatusPainter.paint(window: window, snapshot: activeTrayHost?.currentSnapshot ?? .empty)
        return 0

    case UINT(WM_LBUTTONUP):
        activeTrayHost?.showDetails()
        return 0

    case UINT(WM_MOUSEACTIVATE):
        return LRESULT(MA_NOACTIVATE)

    case UINT(WM_NCHITTEST):
        return LRESULT(HTCLIENT)

    case UINT(WM_ERASEBKGND):
        return 1

    default:
        return DefWindowProcW(window, message, wParam, lParam)
    }
}

// Win32 콜백은 전역 함수 포인터를 요구한다. 앱은 단일 트레이 호스트만 실행하므로
// 약한 전역 맵 대신 현재 호스트 하나로 제한한다.
nonisolated(unsafe) private var activeTrayHost: WindowsTrayHost?

private func lowWord<T: FixedWidthInteger>(_ value: T) -> UInt32 {
    UInt32(truncatingIfNeeded: value) & 0xffff
}

private func windowsResourcePointer(_ identifier: UInt16) -> UnsafePointer<WCHAR> {
    UnsafeRawPointer(bitPattern: UInt(identifier))!.assumingMemoryBound(to: WCHAR.self)
}

private extension String {
    func withWindowsString<Result>(_ body: (UnsafePointer<WCHAR>) -> Result) -> Result {
        let values = Array(utf16) + [0]
        return values.withUnsafeBufferPointer { body($0.baseAddress!) }
    }
}

private extension NOTIFYICONDATAW {
    mutating func setTip(_ text: String) {
        let values = Array(text.utf16.prefix(127)) + [0]
        withUnsafeMutableBytes(of: &szTip) { rawBuffer in
            rawBuffer.initializeMemory(as: UInt16.self, repeating: 0)
            rawBuffer.copyBytes(from: values.withUnsafeBytes { $0 })
        }
    }
}
#endif
