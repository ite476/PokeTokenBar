#if os(Windows)
import Foundation
import WinSDK

/// Windows 트레이 표면에 표시할 사용량 요약.
///
/// macOS 구현의 `UsageStore.menuLines`와 같은 표시 목적을 갖지만 SwiftUI/Observation에
/// 의존하지 않는다. Windows에서는 로컬 usage provider를 백그라운드에서 읽은 뒤 Win32
/// 메시지 루프가 소비할 수 있는 불변 스냅샷으로 변환한다.
struct WindowsProviderUsage: Sendable {
    let id: String
    let displayName: String
    let totalTokens: Int
    let totalCost: Double
}

struct WindowsUsageSnapshot: Sendable {
    let generatedAt: Date
    let providers: [WindowsProviderUsage]
    let totalTokens: Int
    let totalCost: Double
    let errors: [String]

    static let empty = WindowsUsageSnapshot(
        generatedAt: Date(), providers: [], totalTokens: 0, totalCost: 0, errors: [])

    var tokenText: String { TokenFormatter.compact(totalTokens) }
    var costText: String { TokenFormatter.cost(totalCost) }
    var tooltip: String { "PokeTokenBar\n\(tokenText)\n\(costText)" }

    /// 정보 메뉴와 클릭 팝업에서 공유하는 상세 텍스트.
    var detailText: String {
        var lines = [
            "오늘 사용량",
            "토큰: \(TokenFormatter.grouped(totalTokens)) (\(tokenText))",
            "비용: \(costText)",
            "",
        ]

        if providers.isEmpty {
            lines.append("사용량 데이터가 없습니다.")
        } else {
            lines.append(contentsOf: providers.map { provider in
                "\(provider.displayName): \(TokenFormatter.compact(provider.totalTokens)) · \(TokenFormatter.cost(provider.totalCost))"
            })
        }

        if !errors.isEmpty {
            lines.append("")
            lines.append("읽지 못한 Provider: \(errors.joined(separator: ", "))")
        }

        let time = DateFormatter.localizedString(
            from: generatedAt, dateStyle: .none, timeStyle: .short)
        lines.append("")
        lines.append("갱신: \(time)")
        return lines.joined(separator: "\n")
    }
}

/// Windows에서 현재 빌드에 포함된 로컬 provider를 사용량 표시용으로 읽는다.
///
/// 전체 macOS `UsageStore`를 억지로 Windows에 포함하지 않는다. 그 객체는 SwiftUI,
/// UserNotifications, macOS workspace 생명주기까지 함께 소유하기 때문이다. 대신 같은
/// `UsageProvider` 계약을 재사용해 표시 계층과 수집 계층의 equivalency를 유지한다.
enum WindowsUsageSnapshotLoader {
    static func load() async -> WindowsUsageSnapshot {
        let providers: [any UsageProvider] = [
            LocalClaudeProvider(),
            LocalCodexProvider(),
            LocalGeminiProvider(),
            LocalAntigravityProvider(),
            LocalGrokProvider(),
        ]

        var values: [WindowsProviderUsage] = []
        var errors: [String] = []

        for provider in providers {
            do {
                guard let daily = try await provider.fetchDaily() else { continue }
                values.append(WindowsProviderUsage(
                    id: provider.id,
                    displayName: provider.displayName,
                    totalTokens: daily.totalTokens,
                    totalCost: provider.reportsCost ? daily.totalCost : 0))
            } catch {
                errors.append(provider.displayName)
                AppLog.write("windows status provider failed id=(provider.id) error=\(error)")
            }
        }

        return WindowsUsageSnapshot(
            generatedAt: Date(),
            providers: values,
            totalTokens: values.reduce(0) { $0 + $1.totalTokens },
            totalCost: values.reduce(0) { $0 + $1.totalCost },
            errors: errors)
    }
}

/// 비동기 provider task와 단일 Win32 메시지 스레드 사이의 한 칸짜리 mailbox.
///
/// 호스트는 단일 인스턴스이고, producer가 값을 기록한 뒤 `PostMessageW`로 소비를
/// 통지한다. `@unchecked Sendable`은 이 좁은 hand-off 경계를 문서화하기 위한 것이며,
/// snapshot 자체는 값 타입이라 부분 변경이 없다.
final class WindowsUsageMailbox: @unchecked Sendable {
    var value = WindowsUsageSnapshot.empty
}

/// 프로젝트 식별이 가능한 1비트 트레이 아이콘.
///
/// 외부 ICO/PNG 리소스에 의존하지 않고 실행 파일에서 생성하므로 SwiftPM Windows
/// 빌드·디버그 실행·향후 패키징 경로가 달라져도 아이콘이 사라지지 않는다. 16x16
/// 알 모양과 중앙 pulse를 사용해 Windows 기본 애플리케이션 아이콘과 구분한다.
enum WindowsTrayIconFactory {
    static func make() -> HICON? {
        let width = 16
        let height = 16
        let rowBytes = (width + 7) / 8
        let andBits = Array(repeating: UInt8(0), count: rowBytes * height)
        var xorBits = Array(repeating: UInt8(0), count: rowBytes * height)

        func setPixel(_ x: Int, _ y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            xorBits[y * rowBytes + x / 8] |= UInt8(0x80 >> (x % 8))
        }

        for y in 0..<height {
            for x in 0..<width {
                let dx = Double(x) - 7.5
                let dy = Double(y) - 7.5
                let radius = sqrt(dx * dx + dy * dy)
                if radius >= 5.7 && radius <= 7.2 { setPixel(x, y) }
            }
        }

        // 중앙 pulse — 작은 크기에서도 브랜드 형태가 남도록 직선 구간으로 단순화한다.
        for x in 4...11 {
            let y: Int
            switch x {
            case 4, 5: y = 8 - (x - 4)
            case 6, 7: y = 7 + (x - 6)
            case 8, 9: y = 8 - (x - 8)
            default: y = 7 + (x - 10)
            }
            setPixel(x, y)
        }

        return andBits.withUnsafeBufferPointer { andPointer in
            xorBits.withUnsafeBufferPointer { xorPointer in
                CreateIcon(
                    nil,
                    Int32(width),
                    Int32(height),
                    BYTE(1),
                    BYTE(1),
                    andPointer.baseAddress,
                    xorPointer.baseAddress)
            }
        }
    }
}

/// 상태 표시창의 GDI 렌더링 헬퍼.
enum WindowsStatusPainter {
    static let background = COLORREF(0x00211A16)
    static let border = COLORREF(0x00604A3C)
    static let accent = COLORREF(0x005B6BFF)
    static let text = COLORREF(0x00F4F4F4)
    static let secondaryText = COLORREF(0x00B9B9B9)

    static func paint(window: HWND?, snapshot: WindowsUsageSnapshot) {
        var paint = PAINTSTRUCT()
        guard let dc = BeginPaint(window, &paint) else { return }
        defer { EndPaint(window, &paint) }

        var bounds = RECT()
        GetClientRect(window, &bounds)
        let backgroundBrush = CreateSolidBrush(background)
        FillRect(dc, &bounds, backgroundBrush)
        DeleteObject(backgroundBrush)

        let borderBrush = CreateSolidBrush(border)
        FrameRect(dc, &bounds, borderBrush)
        DeleteObject(borderBrush)

        SetBkMode(dc, Int32(TRANSPARENT))
        drawBadge(in: dc)
        drawText(snapshot.tokenText, in: RECT(left: 35, top: 3, right: bounds.right - 6, bottom: 22),
                 dc: dc, color: text, flags: UINT(DT_LEFT | DT_VCENTER | DT_SINGLELINE))
        drawText(snapshot.costText, in: RECT(left: 35, top: 21, right: bounds.right - 6, bottom: 41),
                 dc: dc, color: secondaryText, flags: UINT(DT_LEFT | DT_VCENTER | DT_SINGLELINE))
    }

    private static func drawText(_ value: String, in rect: RECT, dc: HDC?, color: COLORREF, flags: UINT) {
        var rect = rect
        SetTextColor(dc, color)
        _ = value.withWindowsString { pointer in
            DrawTextW(dc, pointer, -1, &rect, flags)
        }
    }

    /// 작은 status window에서도 텍스트 글꼴/로케일에 영향받지 않는 브랜드 배지.
    /// 외부 이미지 로더를 사용하지 않고 Win32 GDI 기본 도형만 사용한다.
    private static func drawBadge(in dc: HDC?) {
        let pen = CreatePen(Int32(PS_SOLID), 3, accent)
        let brush = CreateSolidBrush(background)
        let oldPen = SelectObject(dc, pen)
        let oldBrush = SelectObject(dc, brush)
        Ellipse(dc, 8, 8, 30, 36)
        MoveToEx(dc, 12, 23, nil)
        LineTo(dc, 15, 20)
        LineTo(dc, 19, 24)
        LineTo(dc, 23, 19)
        LineTo(dc, 27, 23)
        SelectObject(dc, oldPen)
        SelectObject(dc, oldBrush)
        DeleteObject(pen)
        DeleteObject(brush)
    }
}

private extension String {
    func withWindowsString<Result>(_ body: (UnsafePointer<WCHAR>) -> Result) -> Result {
        let values = Array(utf16) + [0]
        return values.withUnsafeBufferPointer { body($0.baseAddress!) }
    }
}
#endif
