#if os(Windows)
import Foundation
import WinSDK

/// macOS `PopoverView`의 Windows 대응 표면.
///
/// Windows에는 SwiftUI/AppKit의 `NSPopover`가 없으므로, 사용자가 트레이 아이콘을
/// 클릭했을 때만 생성되는 작은 Win32 popup을 직접 그린다. 이 창은 상시 표시되는
/// floating widget이 아니다. 포커스를 잃으면 즉시 숨기고, provider 데이터는
/// `WindowsUsageSnapshot` 하나만 받아 표시 계층과 수집 계층을 분리한다.
///
/// 유지보수 주의점:
/// - 이 클래스는 Windows message-loop thread에서만 접근한다.
/// - GDI 객체는 paint 호출마다 만들고 반드시 해제한다. 누수 방지를 위해 stock object를
///   삭제하지 않고, 직접 만든 brush/pen/font만 `DeleteObject`한다.
/// - 레이아웃은 macOS `PopoverMetrics.width`의 360pt 카드 비율을 기준으로 하되, Windows
///   DPI와 셸 테마를 고려해 고정된 시스템 대화상자보다 여유 있는 380x300 client area를 쓴다.
final class WindowsDetailsWindow: @unchecked Sendable {
    fileprivate static let className = "PokeTokenBar.WindowsDetails"
    private static let width: Int32 = 380
    private static let height: Int32 = 300
    private static let buttonRect = RECT(left: 294, top: 253, right: 356, bottom: 284)

    private var instance: HINSTANCE?
    private var window: HWND?
    private var snapshot = WindowsUsageSnapshot.empty

    @discardableResult
    func start(instance: HINSTANCE) -> Bool {
        self.instance = instance

        var windowClass = WNDCLASSEXW()
        windowClass.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        windowClass.style = UINT(CS_HREDRAW | CS_VREDRAW)
        windowClass.lpfnWndProc = windowsDetailsWindowProcedure
        windowClass.hInstance = instance
        windowClass.hCursor = LoadCursorW(nil, windowsDetailsResourcePointer(32512))
        windowClass.hbrBackground = nil

        let registered = Self.className.withWindowsString { name in
            windowClass.lpszClassName = name
            return RegisterClassExW(&windowClass) != 0
        }
        guard registered else {
            AppLog.write("Windows details window class registration failed")
            return false
        }

        let created = Self.className.withWindowsString { name in
            "PokeTokenBar usage".withWindowsString { title in
                CreateWindowExW(
                    DWORD(WS_EX_TOOLWINDOW) | DWORD(WS_EX_TOPMOST),
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
        guard created != nil else {
            UnregisterClassW(Self.className.withWindowsString { $0 }, instance)
            AppLog.write("Windows details window creation failed")
            return false
        }

        activeWindowsDetailsWindow = self
        return true
    }

    func close() {
        guard let window else { return }
        ShowWindow(window, SW_HIDE)
        DestroyWindow(window)
        self.window = nil
        activeWindowsDetailsWindow = nil
        if let instance {
            UnregisterClassW(Self.className.withWindowsString { $0 }, instance)
        }
    }

    func update(snapshot: WindowsUsageSnapshot) {
        self.snapshot = snapshot
        InvalidateRect(window, nil, false)
    }

    func show(snapshot: WindowsUsageSnapshot, near anchor: POINT) {
        guard let window else { return }
        self.snapshot = snapshot

        let screenWidth = Int32(GetSystemMetrics(SM_CXSCREEN))
        let screenHeight = Int32(GetSystemMetrics(SM_CYSCREEN))
        var x = anchor.x - Self.width + 22
        var y = anchor.y - Self.height - 12
        if x < 12 { x = 12 }
        if x + Self.width > screenWidth - 12 { x = screenWidth - Self.width - 12 }
        if y < 12 { y = anchor.y + 12 }
        if y + Self.height > screenHeight - 12 { y = screenHeight - Self.height - 12 }

        SetWindowPos(
            window,
            nil,
            x,
            y,
            Self.width,
            Self.height,
            UINT(SWP_SHOWWINDOW))
        ShowWindow(window, SW_SHOW)
        SetForegroundWindow(window)
        SetFocus(window)
        InvalidateRect(window, nil, false)
    }

    fileprivate func hide() {
        ShowWindow(window, SW_HIDE)
    }

    fileprivate func handleClick(x: Int32, y: Int32) {
        if x >= Self.buttonRect.left, x <= Self.buttonRect.right,
           y >= Self.buttonRect.top, y <= Self.buttonRect.bottom {
            hide()
        }
    }

    fileprivate func paint(window: HWND?) {
        var paint = PAINTSTRUCT()
        guard let dc = BeginPaint(window, &paint) else { return }
        defer { EndPaint(window, &paint) }

        var bounds = RECT()
        GetClientRect(window, &bounds)
        let card = windowsDetailsColor(red: 250, green: 248, blue: 252)
        let border = windowsDetailsColor(red: 224, green: 218, blue: 229)
        let primary = windowsDetailsColor(red: 31, green: 27, blue: 36)
        let secondary = windowsDetailsColor(red: 108, green: 101, blue: 115)
        let accent = windowsDetailsColor(red: 246, green: 87, blue: 58)

        let backgroundBrush = CreateSolidBrush(card)
        let borderPen = CreatePen(Int32(PS_SOLID), 1, border)
        let oldBrush = SelectObject(dc, backgroundBrush)
        let oldPen = SelectObject(dc, borderPen)
        RoundRect(dc, bounds.left, bounds.top, bounds.right, bounds.bottom, 18, 18)
        SelectObject(dc, oldBrush)
        SelectObject(dc, oldPen)
        DeleteObject(backgroundBrush)
        DeleteObject(borderPen)

        drawBrandBadge(in: dc, x: 25, y: 24, color: accent, background: card)
        drawText("오늘 사용량", in: RECT(left: 82, top: 23, right: 350, bottom: 48), dc: dc,
                 size: 17, weight: FW_SEMIBOLD, color: primary)
        drawText("PokeTokenBar", in: RECT(left: 82, top: 48, right: 350, bottom: 66), dc: dc,
                 size: 11, weight: FW_NORMAL, color: secondary)

        drawText(snapshot.tokenText, in: RECT(left: 25, top: 78, right: 215, bottom: 122), dc: dc,
                 size: 31, weight: FW_BOLD, color: primary)
        drawText("토큰", in: RECT(left: 25, top: 119, right: 100, bottom: 140), dc: dc,
                 size: 11, weight: FW_NORMAL, color: secondary)
        drawText(snapshot.costText, in: RECT(left: 225, top: 82, right: 350, bottom: 116), dc: dc,
                 size: 20, weight: FW_SEMIBOLD, color: primary, flags: UINT(DT_RIGHT | DT_SINGLELINE))
        drawText("비용", in: RECT(left: 225, top: 119, right: 350, bottom: 140), dc: dc,
                 size: 11, weight: FW_NORMAL, color: secondary, flags: UINT(DT_RIGHT | DT_SINGLELINE))

        let separatorPen = CreatePen(Int32(PS_SOLID), 1, border)
        let oldSeparatorPen = SelectObject(dc, separatorPen)
        MoveToEx(dc, 25, 151, nil)
        LineTo(dc, 355, 151)
        SelectObject(dc, oldSeparatorPen)
        DeleteObject(separatorPen)

        if snapshot.providers.isEmpty {
            drawText("사용량 데이터가 없습니다.", in: RECT(left: 25, top: 169, right: 355, bottom: 193), dc: dc,
                     size: 13, weight: FW_NORMAL, color: secondary)
        } else {
            var rowTop: Int32 = 165
            for provider in snapshot.providers.prefix(3) {
                drawText(provider.displayName, in: RECT(left: 25, top: rowTop, right: 235, bottom: rowTop + 22), dc: dc,
                         size: 13, weight: FW_SEMIBOLD, color: primary)
                let value = provider.reportsCost
                    ? "\(TokenFormatter.compact(provider.totalTokens)) · \(TokenFormatter.cost(provider.totalCost))"
                    : TokenFormatter.compact(provider.totalTokens)
                drawText(value, in: RECT(left: 190, top: rowTop, right: 355, bottom: rowTop + 22), dc: dc,
                         size: 12, weight: FW_NORMAL, color: secondary, flags: UINT(DT_RIGHT | DT_SINGLELINE))
                rowTop += 24
            }
            if snapshot.providers.count > 3 {
                drawText("+\(snapshot.providers.count - 3)개 서비스", in: RECT(left: 25, top: rowTop, right: 355, bottom: rowTop + 20), dc: dc,
                         size: 11, weight: FW_NORMAL, color: secondary)
            }
        }

        if !snapshot.errors.isEmpty {
            drawText("일부 서비스 데이터를 읽지 못했습니다.", in: RECT(left: 25, top: 220, right: 355, bottom: 239), dc: dc,
                     size: 11, weight: FW_NORMAL, color: windowsDetailsColor(red: 190, green: 83, blue: 42))
        }

        let time = DateFormatter.localizedString(from: snapshot.generatedAt, dateStyle: .none, timeStyle: .short)
        drawText("갱신 \(time)", in: RECT(left: 25, top: 258, right: 180, bottom: 280), dc: dc,
                 size: 11, weight: FW_NORMAL, color: secondary)

        let buttonBrush = CreateSolidBrush(windowsDetailsColor(red: 239, green: 232, blue: 243))
        let buttonPen = CreatePen(Int32(PS_SOLID), 1, border)
        let oldButtonBrush = SelectObject(dc, buttonBrush)
        let oldButtonPen = SelectObject(dc, buttonPen)
        RoundRect(dc, Self.buttonRect.left, Self.buttonRect.top, Self.buttonRect.right, Self.buttonRect.bottom, 9, 9)
        SelectObject(dc, oldButtonBrush)
        SelectObject(dc, oldButtonPen)
        DeleteObject(buttonBrush)
        DeleteObject(buttonPen)
        drawText("확인", in: Self.buttonRect, dc: dc, size: 12, weight: FW_SEMIBOLD, color: primary,
                 flags: UINT(DT_CENTER | DT_VCENTER | DT_SINGLELINE))
    }

    private func drawBrandBadge(in dc: HDC?, x: Int32, y: Int32, color: COLORREF, background: COLORREF) {
        let pen = CreatePen(Int32(PS_SOLID), 3, color)
        let brush = CreateSolidBrush(background)
        let oldPen = SelectObject(dc, pen)
        let oldBrush = SelectObject(dc, brush)
        Ellipse(dc, x, y, x + 42, y + 42)
        MoveToEx(dc, x + 8, y + 23, nil)
        LineTo(dc, x + 15, y + 17)
        LineTo(dc, x + 22, y + 25)
        LineTo(dc, x + 30, y + 15)
        LineTo(dc, x + 36, y + 21)
        SelectObject(dc, oldPen)
        SelectObject(dc, oldBrush)
        DeleteObject(pen)
        DeleteObject(brush)
    }

    private func drawText(
        _ value: String,
        in rect: RECT,
        dc: HDC?,
        size: Int32,
        weight: Int32,
        color: COLORREF,
        flags: UINT = UINT(DT_LEFT | DT_VCENTER | DT_SINGLELINE)) {
        let font = "Segoe UI".withWindowsString { name in
            CreateFontW(
                -size,
                0,
                0,
                0,
                weight,
                0,
                0,
                0,
                UINT(DEFAULT_CHARSET),
                UINT(OUT_DEFAULT_PRECIS),
                UINT(CLIP_DEFAULT_PRECIS),
                UINT(CLEARTYPE_QUALITY),
                UINT(DEFAULT_PITCH | FF_DONTCARE),
                name)
        }
        guard let font else { return }
        let oldFont = SelectObject(dc, font)
        var drawRect = rect
        SetBkMode(dc, Int32(TRANSPARENT))
        SetTextColor(dc, color)
        _ = value.withWindowsString { text in
            DrawTextW(dc, text, -1, &drawRect, flags)
        }
        SelectObject(dc, oldFont)
        DeleteObject(font)
    }
}

private let windowsDetailsWindowProcedure: WNDPROC = { window, message, wParam, lParam in
    switch message {
    case UINT(WM_PAINT):
        activeWindowsDetailsWindow?.paint(window: window)
        return 0

    case UINT(WM_ERASEBKGND):
        return 1

    case UINT(WM_LBUTTONUP):
        let x = Int32(Int16(truncatingIfNeeded: lowWordDetails(lParam)))
        let y = Int32(Int16(truncatingIfNeeded: highWordDetails(lParam)))
        activeWindowsDetailsWindow?.handleClick(x: x, y: y)
        return 0

    case UINT(WM_KEYDOWN):
        if lowWordDetails(wParam) == UINT(VK_ESCAPE) {
            activeWindowsDetailsWindow?.hide()
            return 0
        }
        return DefWindowProcW(window, message, wParam, lParam)

    case UINT(WM_ACTIVATE):
        if lowWordDetails(wParam) == UINT(WA_INACTIVE) {
            activeWindowsDetailsWindow?.hide()
        }
        return 0

    case UINT(WM_NCHITTEST):
        return LRESULT(HTCLIENT)

    case UINT(WM_MOUSEACTIVATE):
        return LRESULT(MA_ACTIVATE)

    default:
        return DefWindowProcW(window, message, wParam, lParam)
    }
}

private nonisolated(unsafe) var activeWindowsDetailsWindow: WindowsDetailsWindow?

private func windowsDetailsColor(red: UInt32, green: UInt32, blue: UInt32) -> COLORREF {
    COLORREF(red | (green << 8) | (blue << 16))
}

private func lowWordDetails<T: FixedWidthInteger>(_ value: T) -> UInt32 {
    UInt32(truncatingIfNeeded: value) & 0xffff
}

private func highWordDetails<T: FixedWidthInteger>(_ value: T) -> UInt32 {
    (UInt32(truncatingIfNeeded: value) >> 16) & 0xffff
}

private func windowsDetailsResourcePointer(_ identifier: UInt16) -> UnsafePointer<WCHAR> {
    UnsafeRawPointer(bitPattern: UInt(identifier))!.assumingMemoryBound(to: WCHAR.self)
}

private extension String {
    func withWindowsString<Result>(_ body: (UnsafePointer<WCHAR>) -> Result) -> Result {
        let values = Array(utf16) + [0]
        return values.withUnsafeBufferPointer { body($0.baseAddress!) }
    }
}
#endif
