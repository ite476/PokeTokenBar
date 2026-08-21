#if os(Windows)
import Foundation
import WinSDK

/// Windows floating pet가 표시할 도메인 상태.
///
/// `CompanionStore` 전체를 Win32 callback에 노출하지 않고, 현재 종/이로치와 이미
/// 내려받은 sprite bytes만 전달한다. 이 경계 덕분에 UI thread는 파일 파싱·네트워크를
/// 수행하지 않고, 오래된 비동기 응답이 새 펫을 덮어쓰는 범위도 좁게 유지된다.
struct WindowsPetSnapshot: Sendable {
    let speciesID: Int?
    let shiny: Bool
    let spriteData: Data?
}

/// 백그라운드 sprite/companion 로더와 Win32 message loop 사이의 단일 mailbox.
final class WindowsPetMailbox: @unchecked Sendable {
    var value = WindowsPetSnapshot(speciesID: nil, shiny: false, spriteData: nil)
}

/// Windows 타깃에서 `CompanionStore`와 PokeAPI sprite를 연결하는 얇은 adapter.
enum WindowsPetSnapshotLoader {
    static func load() async -> WindowsPetSnapshot {
        // Windows의 native GetMessageW 루프는 Swift MainActor executor를 펌프하지
        // 않으므로 `MainActor.run { CompanionStore() }`를 여기서 기다리면 앱 시작 시
        // 영원히 대기할 수 있다. CompanionStore와 동일한 URL/모델을 사용해 저장된
        // 상태의 표시용 최소 필드만 디코드하면 UI actor와 파일 파서의 결합도 줄어든다.
        let companionState = loadCompanionState()
        let spriteData = await SpriteStore.shared.data(
            speciesID: companionState.speciesID,
            shiny: companionState.shiny)
        return WindowsPetSnapshot(
            speciesID: companionState.speciesID,
            shiny: companionState.shiny,
            spriteData: spriteData)
    }

    private static func loadCompanionState() -> (speciesID: Int?, shiny: Bool) {
        guard let data = try? Data(contentsOf: CompanionStore.defaultURL()),
              let state = try? JSONDecoder().decode(CompanionState.self, from: data),
              let active = state.active else {
            return (nil, false)
        }
        // 메타몽 위장 중에는 macOS CompanionStore와 동일하게 shiny를 숨긴다.
        let shiny = active.dittoDisguise != nil && !active.dittoRevealed ? false : active.isShiny
        return (active.currentID, shiny)
    }
}

/// macOS `FloatingPetController`의 Windows 대응 창.
///
/// 화면에 상주하지만 104x104 투명 표면 위에 sprite만 보여주며, 사용자가 드래그한
/// 위치를 `UserDefaults`에 저장한다. 클릭과 드래그를 구분해 짧은 클릭은 상세 카드,
/// 이동은 위치 저장으로 처리한다. 원본 macOS FloatingPetView의 sprite-only 표면에
/// 대응하도록 layered color-key를 사용해 카드 사각형이 화면에 남지 않게 한다.
///
/// 유지보수 주의점:
/// - 창 생명주기와 paint는 Win32 message-loop thread에서만 수행한다.
/// - sprite 다운로드/PNG 디코드는 이 클래스 밖의 async loader가 수행한다.
/// - 원본 macOS의 panel origin이 아니라 펫 자체의 좌표를 저장해 크기 변경에도
///   사용자가 잡아둔 위치가 크게 흔들리지 않게 한다.
final class WindowsFloatingPetWindow: @unchecked Sendable {
    fileprivate static let className = "PokeTokenBar.WindowsFloatingPet"
    private static let width: Int32 = 104
    private static let height: Int32 = 104
    private static let clickThreshold: Int32 = 4
    private static let originXKey = "windowsFloatingPetOriginX"
    private static let originYKey = "windowsFloatingPetOriginY"
    // 원본 macOS FloatingPetView처럼 펫만 떠 보이게 하는 색상 키다. sprite의
    // 팔레트에 거의 등장하지 않는 magenta를 선택해 카드 사각형이 남지 않게 한다.
    private static let transparencyKey = COLORREF(0x00FF00FF) // RGB(255, 0, 255)

    var onClick: (() -> Void)?
    var onRightClick: ((POINT) -> Void)?

    private var instance: HINSTANCE?
    private var window: HWND?
    private var spriteIcon: HICON?
    private var dragStart: POINT?
    private var originAtDragStart: POINT?
    private var didDrag = false

    @discardableResult
    func start(instance: HINSTANCE) -> Bool {
        self.instance = instance
        var windowClass = WNDCLASSEXW()
        windowClass.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        windowClass.style = UINT(CS_HREDRAW | CS_VREDRAW)
        windowClass.lpfnWndProc = windowsFloatingPetWindowProcedure
        windowClass.hInstance = instance
        windowClass.hCursor = LoadCursorW(nil, windowsFloatingResourcePointer(32512))
        windowClass.hbrBackground = nil

        let registered = Self.className.withWindowsString { name in
            windowClass.lpszClassName = name
            return RegisterClassExW(&windowClass) != 0
        }
        guard registered else {
            AppLog.write("Windows floating pet class registration failed")
            return false
        }

        let created = Self.className.withWindowsString { name in
            "PokeTokenBar floating pet".withWindowsString { title in
                CreateWindowExW(
                    DWORD(WS_EX_TOOLWINDOW) | DWORD(WS_EX_TOPMOST) | DWORD(WS_EX_LAYERED),
                    name,
                    title,
                    WS_POPUP,
                    0,
                    0,
                    Self.width,
                    Self.height,
                    nil,
                    nil,
                    instance,
                    nil)
            }
        }
        window = created
        guard let created else {
            UnregisterClassW(Self.className.withWindowsString { $0 }, instance)
            AppLog.write("Windows floating pet creation failed")
            return false
        }

        _ = SetLayeredWindowAttributes(created, Self.transparencyKey, 0, UINT(LWA_COLORKEY))
        activeWindowsFloatingPet = self
        return true
    }

    func close() {
        guard let window else { return }
        ShowWindow(window, SW_HIDE)
        DestroyWindow(window)
        self.window = nil
        if let spriteIcon { DestroyIcon(spriteIcon) }
        spriteIcon = nil
        activeWindowsFloatingPet = nil
        if let instance {
            UnregisterClassW(Self.className.withWindowsString { $0 }, instance)
        }
    }

    func show() {
        guard let window else { return }
        let origin = clampedOrigin(savedOrigin() ?? defaultOrigin())
        SetWindowPos(
            window,
            HWND(bitPattern: -1), // HWND_TOPMOST
            origin.x,
            origin.y,
            Self.width,
            Self.height,
            UINT(SWP_NOACTIVATE | SWP_SHOWWINDOW))
        ShowWindow(window, SW_SHOWNOACTIVATE)
        InvalidateRect(window, nil, false)
    }

    func hide() {
        ShowWindow(window, SW_HIDE)
    }

    var isVisible: Bool { window.map { IsWindowVisible($0) } ?? false }

    func update(snapshot: WindowsPetSnapshot) {
        if let spriteIcon { DestroyIcon(spriteIcon) }
        spriteIcon = WindowsSpriteIconFactory.make(data: snapshot.spriteData)
        InvalidateRect(window, nil, false)
    }

    fileprivate func paint(window: HWND?) {
        var paint = PAINTSTRUCT()
        guard let dc = BeginPaint(window, &paint) else { return }
        defer { EndPaint(window, &paint) }

        var bounds = RECT()
        GetClientRect(window, &bounds)
        let transparencyBrush = CreateSolidBrush(Self.transparencyKey)
        FillRect(dc, &bounds, transparencyBrush)
        DeleteObject(transparencyBrush)

        if let spriteIcon {
            DrawIconEx(dc, 0, 0, spriteIcon, Self.width, Self.height, 0, nil, UINT(DI_NORMAL))
        } else {
            drawFallbackEgg(in: dc)
        }
    }

    fileprivate func mouseDown() {
        var cursor = POINT()
        GetCursorPos(&cursor)
        var rect = RECT()
        GetWindowRect(window, &rect)
        dragStart = cursor
        originAtDragStart = POINT(x: rect.left, y: rect.top)
        didDrag = false
        SetCapture(window)
    }

    fileprivate func mouseMove() {
        guard GetCapture() == window, let dragStart, let origin = originAtDragStart else { return }
        var cursor = POINT()
        GetCursorPos(&cursor)
        let deltaX = cursor.x - dragStart.x
        let deltaY = cursor.y - dragStart.y
        if abs(deltaX) > Self.clickThreshold || abs(deltaY) > Self.clickThreshold { didDrag = true }
        let target = clampedOrigin(POINT(x: origin.x + deltaX, y: origin.y + deltaY))
        SetWindowPos(
            window,
            nil,
            target.x,
            target.y,
            0,
            0,
            UINT(SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE))
    }

    fileprivate func mouseUp() {
        if GetCapture() == window { ReleaseCapture() }
        defer {
            dragStart = nil
            originAtDragStart = nil
            didDrag = false
        }
        saveCurrentOrigin()
        if !didDrag { onClick?() }
    }

    private func savedOrigin() -> POINT? {
        let defaults = UserDefaults.standard
        guard let x = defaults.object(forKey: Self.originXKey) as? Int,
              let y = defaults.object(forKey: Self.originYKey) as? Int else { return nil }
        return POINT(x: Int32(x), y: Int32(y))
    }

    private func defaultOrigin() -> POINT {
        let (screenWidth, screenHeight) = logicalScreenSize()
        return POINT(x: max(12, screenWidth - Self.width - 28), y: max(12, screenHeight - Self.height - 96))
    }

    /// Windows가 non-manifest Swift 실행 파일의 좌표를 system-DPI 논리 단위로
    /// 가상화할 수 있으므로, screen metrics를 현재 창 DPI에 맞춘 논리 bounds로 바꾼다.
    /// 이 보정이 없으면 125% 배율에서 기본 x가 화면 밖(물리 x≈1750)으로 밀린다.
    private func logicalScreenSize() -> (Int32, Int32) {
        let physicalWidth = Double(GetSystemMetrics(SM_CXSCREEN))
        let physicalHeight = Double(GetSystemMetrics(SM_CYSCREEN))
        let dpi = max(96.0, Double(window.map { GetDpiForWindow($0) } ?? 96))
        let scale = dpi / 96.0
        return (Int32(physicalWidth / scale), Int32(physicalHeight / scale))
    }

    private func clampedOrigin(_ origin: POINT) -> POINT {
        let (screenWidth, screenHeight) = logicalScreenSize()
        return POINT(
            x: min(max(12, origin.x), max(12, screenWidth - Self.width - 12)),
            y: min(max(12, origin.y), max(12, screenHeight - Self.height - 12)))
    }

    private func saveCurrentOrigin() {
        var rect = RECT()
        GetWindowRect(window, &rect)
        UserDefaults.standard.set(Int(rect.left), forKey: Self.originXKey)
        UserDefaults.standard.set(Int(rect.top), forKey: Self.originYKey)
    }

    private func drawFallbackEgg(in dc: HDC?) {
        let orange = COLORREF(0x003A72FF)
        let pen = CreatePen(Int32(PS_SOLID), 4, orange)
        let brush = CreateSolidBrush(Self.transparencyKey)
        let oldPen = SelectObject(dc, pen)
        let oldBrush = SelectObject(dc, brush)
        Ellipse(dc, 21, 12, 83, 91)
        SelectObject(dc, oldPen)
        SelectObject(dc, oldBrush)
        DeleteObject(pen)
        DeleteObject(brush)
    }
}

private let windowsFloatingPetWindowProcedure: WNDPROC = { window, message, wParam, lParam in
    switch message {
    case UINT(WM_PAINT):
        activeWindowsFloatingPet?.paint(window: window)
        return 0
    case UINT(WM_ERASEBKGND):
        return 1
    case UINT(WM_LBUTTONDOWN):
        activeWindowsFloatingPet?.mouseDown()
        return 0
    case UINT(WM_MOUSEMOVE):
        activeWindowsFloatingPet?.mouseMove()
        return 0
    case UINT(WM_LBUTTONUP):
        activeWindowsFloatingPet?.mouseUp()
        return 0
    case UINT(WM_RBUTTONUP):
        var point = POINT()
        GetCursorPos(&point)
        activeWindowsFloatingPet?.onRightClick?(point)
        return 0
    case UINT(WM_NCHITTEST):
        return LRESULT(HTCLIENT)
    case UINT(WM_MOUSEACTIVATE):
        return LRESULT(MA_NOACTIVATE)
    case UINT(WM_KEYDOWN):
        if lowWordFloating(wParam) == UINT(VK_ESCAPE) {
            activeWindowsFloatingPet?.hide()
            return 0
        }
        return DefWindowProcW(window, message, wParam, lParam)
    default:
        return DefWindowProcW(window, message, wParam, lParam)
    }
}

private nonisolated(unsafe) var activeWindowsFloatingPet: WindowsFloatingPetWindow?

private func lowWordFloating<T: FixedWidthInteger>(_ value: T) -> UInt32 {
    UInt32(truncatingIfNeeded: value) & 0xffff
}

private func windowsFloatingResourcePointer(_ identifier: UInt16) -> UnsafePointer<WCHAR> {
    UnsafeRawPointer(bitPattern: UInt(identifier))!.assumingMemoryBound(to: WCHAR.self)
}

private extension String {
    func withWindowsString<Result>(_ body: (UnsafePointer<WCHAR>) -> Result) -> Result {
        let values = Array(utf16) + [0]
        return values.withUnsafeBufferPointer { body($0.baseAddress!) }
    }
}
#endif
