#if os(Windows)
import Foundation
import WinSDK

/// Windows 전용 트레이 애플리케이션 진입점.
///
/// Windows 알림 영역은 macOS 메뉴바처럼 폭이 있는 텍스트를 안정적으로 삽입하는
/// 확장 지점을 제공하지 않는다. 따라서 항상 떠 있는 별도 창은 만들지 않고, 커스텀
/// 아이콘·동적 tooltip·클릭 정보창으로 native tray UX를 구성한다.
@main
struct WindowsTrayApplication {
    static func main() {
        // SwiftPM의 Windows 기본 subsystem은 CUI이므로, 트레이 전용 실행에서는 현재
        // 콘솔 연결만 해제한다. 호출 셸의 창을 숨기거나 종료하지는 않는다.
        _ = FreeConsole()
        WindowsTrayHost().run()
    }
}

/// 숨김 Win32 윈도우와 알림 영역 아이콘의 수명주기를 관리한다.
///
/// 유지보수 주의점:
/// - 실제 표시 표면은 Explorer가 관리하는 tray icon 하나다. 사용자 설정에 따라
///   overflow 영역으로 이동할 수 있으며, 앱이 이를 강제로 바꾸지 않는다.
/// - provider 스캔은 백그라운드 task에서 수행하고, 결과는 `PostMessageW`로 메시지
///   스레드에 전달한다. Win32 callback에서 파일 파싱을 직접 수행하지 않는다.
/// - left click은 foreground 정보창, right click은 native popup menu로 연결한다.
final class WindowsTrayHost: @unchecked Sendable {
    fileprivate static let windowClassName = "PokeTokenBar.WindowsTrayHost"
    fileprivate static let trayCallbackMessage = UINT(WM_APP) + 1
    fileprivate static let snapshotReadyMessage = UINT(WM_APP) + 2
    private static let exitCommand = UINT(0x1001)
    private static let refreshCommand = UINT(0x1002)
    private static let aboutCommand = UINT(0x1003)
    private static let refreshTimerID = UINT_PTR(1)

    private var window: HWND?
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
        let registered = registerWindowClass(instance: instance)
        let created = registered && createMessageWindow(instance: instance)
        guard registered, created else {
            AppLog.write("Windows tray startup failed: window registration")
            return
        }

        activeTrayHost = self
        addTrayIcon()
        SetTimer(window, Self.refreshTimerID, UINT(120_000), nil)
        refreshUsage()

        defer {
            refreshTask?.cancel()
            _ = KillTimer(window, Self.refreshTimerID)
            removeTrayIcon()
            if let trayIcon { DestroyIcon(trayIcon) }
            activeTrayHost = nil
            if let window { DestroyWindow(window) }
            UnregisterClassW(Self.windowClassName.withWindowsString { $0 }, instance)
        }

        var message = MSG()
        while GetMessageW(&message, nil, 0, 0) {
            TranslateMessage(&message)
            DispatchMessageW(&message)
        }
    }

    private func registerWindowClass(instance: HINSTANCE) -> Bool {
        var windowClass = WNDCLASSEXW()
        windowClass.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        windowClass.style = UINT(CS_HREDRAW | CS_VREDRAW)
        windowClass.lpfnWndProc = windowsTrayWindowProcedure
        windowClass.hInstance = instance
        windowClass.hIcon = trayIcon ?? LoadIconW(nil, windowsResourcePointer(32512))
        windowClass.hCursor = LoadCursorW(nil, windowsResourcePointer(32512))
        windowClass.hbrBackground = GetSysColorBrush(COLOR_WINDOW)

        let result = Self.windowClassName.withWindowsString { name in
            windowClass.lpszClassName = name
            return RegisterClassExW(&windowClass)
        }
        return result != 0
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
    /// 메시지를 넣어 동일한 스레드에서 tooltip을 갱신한다.
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

    case UINT(WM_DESTROY):
        PostQuitMessage(0)
        return 0

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
