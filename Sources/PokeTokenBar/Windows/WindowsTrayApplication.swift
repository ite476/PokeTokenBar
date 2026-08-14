#if os(Windows)
import Foundation
import WinSDK

/// Windows 전용 트레이 호스트.
///
/// macOS의 `NSStatusItem`/`NSPopover`를 Windows에서 흉내 내기 위해 별도 UI
/// 프레임워크를 끌어오지 않고 Win32 메시지 루프와 Shell_NotifyIconW만 사용한다.
/// 숨김 윈도우는 트레이 콜백을 받을 핸들 역할만 하며, 실제 기능은 이후 Core
/// provider를 이 호스트에 연결한다. 이 클래스는 종료 시 트레이 아이콘을 반드시
/// 제거해야 하므로 `run()`의 모든 정상 종료 경로에서 `removeTrayIcon()`을 호출한다.
@main
struct WindowsTrayApplication {
    static func main() {
        // SwiftPM의 Windows 기본 subsystem은 CUI이므로, 새 콘솔을 소유하거나
        // 셸 콘솔에 붙은 상태를 트레이 전용 실행으로 전환한다. 기존 셸 창 자체를
        // 숨기지 않고 프로세스만 분리하므로 터미널에서 실행해도 사용자 콘솔은 보존된다.
        _ = FreeConsole()
        WindowsTrayHost().run()
    }
}

/// 숨김 Win32 윈도우와 알림 영역 아이콘의 수명주기를 관리한다.
///
/// 유지보수 주의점:
/// - 윈도우 프로시저는 C 콜백이므로 인스턴스 상태를 직접 캡처하지 않는다.
/// - 트레이 아이콘을 추가한 뒤에는 `NIM_DELETE`를 호출해야 Explorer가 재시작될
///   때 중복 아이콘이 남지 않는다.
/// - 메시지 루프를 Task/Timer로 대체하지 않는다. Win32 콜백은 이 루프의 스레드
///   affinity를 전제로 하며, 앱 종료 명령도 같은 루프에서 처리한다.
final class WindowsTrayHost {
    private static let windowClassName = "PokeTokenBar.WindowsTrayHost"
    fileprivate static let trayCallbackMessage = UINT(WM_APP) + 1
    private static let exitCommand = UINT(0x1001)
    private static let aboutCommand = UINT(0x1002)

    private var window: HWND?
    private var trayAdded = false
    private var instance: HINSTANCE?

    func run() {
        instance = GetModuleHandleW(nil)
        guard let instance else {
            AppLog.write("Windows tray startup failed: GetModuleHandleW")
            return
        }

        let registered = registerWindowClass(instance: instance)
        let created = registered && createMessageWindow(instance: instance)
        guard registered, created else {
            AppLog.write("Windows tray startup failed: window registration")
            return
        }

        activeTrayHost = self
        addTrayIcon()
        defer {
            removeTrayIcon()
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

        let result = Self.windowClassName.withWindowsString { name in
            windowClass.lpszClassName = name
            windowClass.hIcon = LoadIconW(nil, windowsResourcePointer(32512))
            windowClass.hCursor = LoadCursorW(nil, windowsResourcePointer(32512))
            windowClass.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
            return RegisterClassExW(&windowClass)
        }
        return result != 0
    }

    private func createMessageWindow(instance: HINSTANCE) -> Bool {
        let style = DWORD(WS_EX_TOOLWINDOW)
        let windowStyle = WS_POPUP
        let created = Self.windowClassName.withWindowsString { name in
            "PokeTokenBar".withWindowsString { title in
                CreateWindowExW(
                    style,
                    name,
                    title,
                    windowStyle,
                    0, 0, 0, 0,
                    nil,
                    nil,
                    instance,
                    nil
                )
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
        data.hIcon = LoadIconW(nil, windowsResourcePointer(32512))
        data.setTip("PokeTokenBar Windows")
        trayAdded = Shell_NotifyIconW(DWORD(NIM_ADD), &data)
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

    fileprivate func showMenu(at point: POINT) {
        guard let window, let menu = CreatePopupMenu() else { return }
        defer { DestroyMenu(menu) }

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
        case Self.aboutCommand:
            AppLog.write("PokeTokenBar Windows tray is running")
        default:
            break
        }
    }
}

private let windowsTrayWindowProcedure: WNDPROC = { window, message, wParam, lParam in
    switch message {
    case WindowsTrayHost.trayCallbackMessage:
        guard let window else { return 0 }
        let event = lowWord(lParam)
        if event == UINT(WM_RBUTTONUP) || event == UINT(WM_CONTEXTMENU) {
            var point = POINT()
            GetCursorPos(&point)
            if let host = activeTrayHost {
                host.showMenu(at: point)
            }
        }
        return 0

    case UINT(WM_COMMAND):
        if let host = activeTrayHost {
            host.handleCommand(UINT(lowWord(wParam)))
        }
        return 0

    case UINT(WM_DESTROY):
        PostQuitMessage(0)
        return 0

    default:
        return DefWindowProcW(window, message, wParam, lParam)
    }
}

// Win32 콜백은 전역 함수 포인터를 요구한다. 이 앱은 단일 트레이 호스트만
// 실행하므로 콜백 연결은 약한 전역 맵 대신 현재 호스트 하나로 제한한다.
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
