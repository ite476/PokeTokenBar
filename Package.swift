// swift-tools-version: 6.0
import PackageDescription

#if os(Windows)
let executableSources = [
    "PokeTokenBarApp.swift",
    "Core/AppEnv.swift",
    "Core/AppLog.swift",
    "Core/BinaryLocator.swift",
    "Core/CodexRateLimitsProvider.swift",
    "Core/CompanionModel.swift",
    "Core/CompanionStore.swift",
    "Core/KeychainAccess.swift",
    "Core/Localization.swift",
    "Core/LocalUsageCache.swift",
    "Core/LocalUsageProvider.swift",
    "Core/LocalUsageReader.swift",
    "Core/ModelPricing.swift",
    "Core/Models.swift",
    "Core/OAuthLimitsProvider.swift",
    "Core/PokeAPIClient.swift",
    "Core/ProcessRunner.swift",
    "Core/ProviderStatusChecker.swift",
    "Core/SaveTransfer.swift",
    "Core/SupportMail.swift",
    "Core/TokenFormatter.swift",
    "Core/UsageProvider.swift",
    "Windows/WindowsSupport.swift",
    "Windows/WindowsTrayApplication.swift",
]
let executableExcludes = [
    "Core/CrashReporter.swift",
    "Core/LocalAdditionalUsageProvider.swift",
    "Core/LocalAntigravityUsageReader.swift",
    "Core/LoginItem.swift",
    "Core/UpdateChecker.swift",
    "Core/UsageStore.swift",
    "UI",
]
#else
let executableSources: [String]? = nil
let executableExcludes: [String] = []
#endif

#if os(Windows)
let executableLinkerSettings: [LinkerSetting]? = nil
#else
let executableLinkerSettings: [LinkerSetting] = [.linkedLibrary("sqlite3")]
#endif

#if os(Windows)
let testSources = [
    "BinaryLocatorTests.swift",
    "CompanionDisplayStateTests.swift",
    "CompanionTests.swift",
    "DittoTests.swift",
    "FreshEggTests.swift",
    "GeminiUsageTests.swift",
    "LocalUsageReaderTests.swift",
    "MintTests.swift",
    "ModelLogicTests.swift",
    "PremiumEggTests.swift",
    "SaveTransferTests.swift",
    "ShinyCharmTests.swift",
    "ShopTests.swift",
    "WindowsXCTestManifests.swift",
]
let testExcludes = [
    "AntigravityUsageTests.swift",
    "CopilotUsageTests.swift",
    "CursorUsageTests.swift",
    "EvoLineLayoutTests.swift",
    "GrokUsageTests.swift",
    "LocalAdditionalUsageTests.swift",
    "LocalUsageCacheTests.swift",
    "LocalUsageParityTests.swift",
    "PerformanceTests.swift",
    "PopoverNavigationTests.swift",
    "PokeTokenBarTests.swift",
    "ProviderTabLayoutTests.swift",
    "RareCandyTests.swift",
    "SpriteSubjectTests.swift",
    "UpdateCheckerTests.swift",
    "UsageStoreTests.swift",
]
let testSwiftSettings = [SwiftSetting.swiftLanguageMode(.v5)]
#else
let testSources: [String]? = nil
let testExcludes: [String] = []
let testSwiftSettings: [SwiftSetting] = []
#endif

let package = Package(
    name: "PokeTokenBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PokeTokenBar",
            path: "Sources/PokeTokenBar",
            exclude: executableExcludes,
            sources: executableSources,
            linkerSettings: executableLinkerSettings
        ),
        .testTarget(
            name: "PokeTokenBarTests",
            dependencies: ["PokeTokenBar"],
            path: "Tests/PokeTokenBarTests",
            exclude: testExcludes,
            sources: testSources,
            resources: [
                .copy("Fixtures/CodexFork"),
                .copy("Fixtures/CodexSubagent"),
            ],
            swiftSettings: testSwiftSettings
        ),
    ]
)
