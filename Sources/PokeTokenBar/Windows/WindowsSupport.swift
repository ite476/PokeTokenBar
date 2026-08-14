#if os(Windows)
import Foundation

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

enum SpriteStore {
    static func cacheKey(speciesID: Int, animated: Bool, shiny: Bool) -> String {
        "\(speciesID)-\(shiny ? "sh" : "")\(animated ? "a" : "s")"
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
