#if os(Windows)
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

typealias OSStatus = Int32

/// Windows 빌드에서 macOS 전용 SQLite 기반 Antigravity 리더를 대체하는 빈 캐시.
///
/// Windows의 사용자별 저장 위치/DB 스키마가 확인되기 전에는 다른 플랫폼의
/// 경로를 추측해서 읽지 않는다. 이 경계는 provider registry를 깨지 않으면서
/// 나중에 Windows 전용 reader를 추가할 수 있게 한다.
actor LocalAntigravityUsageCache {
    static let shared = LocalAntigravityUsageCache()

    func entries() async -> [LocalUsageReader.Entry] { [] }
}

/// Companion 상태 판정이 사용하는 순수 burn-rate 분류.
///
/// macOS에서는 `UsageStore`가 이 enum을 소유하지만, Windows 트레이 빌드는
/// AppKit 의존성을 제외하므로 동일한 도메인 타입을 플랫폼 어댑터에 둔다.
enum BurnTier: Sendable {
    case idle, normal, fast, blazing
}

/// Core 파서가 macOS autorelease 최적화 래퍼를 호출해도 Windows에서 동일한
/// 순수 클로저 실행 semantics를 유지하도록 하는 no-op 호환 함수.
@inline(__always)
func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
    try body()
}

/// SwiftUI sprite view가 macOS에서 노출하는 순수 reload 판정의 Windows 대응.
/// 렌더러는 아직 없지만 도메인 테스트와 향후 트레이 확장에서 동일한 키 규칙을
/// 유지한다.
enum SpriteView {
    static func needsReload(loadedID: Int?, loadedShiny: Bool, id: Int, shiny: Bool) -> Bool {
        loadedID != id || loadedShiny != shiny
    }
}

/// Windows floating pet가 사용하는 PokeAPI sprite data 저장소.
///
/// macOS `SpriteStore`의 URL 규칙과 캐시 키를 유지하되, `NSImage`를 반환하지 않고
/// 원본 PNG bytes만 반환한다. Windows 렌더러는 이 bytes를 Windows Imaging
/// Component(WIC)로 `HICON`으로 변환하므로 AppKit/CoreGraphics에 의존하지 않는다.
actor SpriteStore {
    static let shared = SpriteStore()
    private let base = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
    private let directory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeTokenBar/sprites")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func cacheKey(speciesID: Int, animated: Bool, shiny: Bool) -> String {
        "\(speciesID)-\(shiny ? "sh" : "")\(animated ? "a" : "s")"
    }

    /// 정적 포켓몬/알 스프라이트를 다운로드하고 원자적으로 캐시한다.
    /// animated 인자는 Windows의 첫 렌더러가 정적 PNG만 지원한다는 사실을 호출부에
    /// 명확히 하기 위한 호환 인자이며, true 요청도 정적 이미지로 폴백한다.
    func data(speciesID: Int?, shiny: Bool = false) async -> Data? {
        let key: String
        let urlString: String
        if let speciesID {
            key = Self.cacheKey(speciesID: speciesID, animated: false, shiny: shiny)
            urlString = shiny ? "\(base)/shiny/\(speciesID).png" : "\(base)/\(speciesID).png"
        } else {
            key = "egg"
            urlString = "\(base)/egg.png"
        }

        let file = directory.appendingPathComponent("\(key).png")
        if let cached = try? Data(contentsOf: file), !cached.isEmpty { return cached }
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              !data.isEmpty else { return nil }

        try? data.write(to: file, options: .atomic)
        return data
    }
}

/// Foundation's relative formatter is not included in the Windows Foundation
/// overlay. The app only needs stable localized smoke-test output at this layer.
final class RelativeDateTimeFormatter {
    var locale = Locale.current

    func localizedString(for date: Date, relativeTo referenceDate: Date) -> String {
        let hours = max(1, Int(abs(referenceDate.timeIntervalSince(date)) / 3600))
        switch locale.language.languageCode?.identifier {
        case "ko": return "\(hours)시간 전"
        case "ja": return "\(hours)時間前"
        default: return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }
}
#endif
