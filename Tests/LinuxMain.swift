#if os(Windows)
import XCTest
@testable import PokeTokenBarTests

XCTMain([
    testCase(BinaryLocatorTests.allTests),
    testCase(CompanionDisplayStateTests.allTests),
    testCase(PokemonBalanceTests.allTests),
    testCase(CompanionStoreTests.allTests),
    testCase(DisplayLocaleTests.allTests),
    testCase(DexSortingTests.allTests),
    testCase(CompanionIdentityTests.allTests),
    testCase(PokeAPIGuardTests.allTests),
    testCase(DittoDisguiseRollTests.allTests),
    testCase(DittoRevealTests.allTests),
    testCase(FreshEggTests.allTests),
    testCase(GeminiUsageTests.allTests),
    testCase(LocalUsageReaderTests.allTests),
    testCase(MintTests.allTests),
    testCase(EvoLineNameTests.allTests),
    testCase(EvoLineAssetTests.allTests),
    testCase(EvoNodeTests.allTests),
    testCase(RarityBoundaryTests.allTests),
    testCase(OAuthExpiresAtTests.allTests),
    testCase(ISO8601ParserTests.allTests),
    testCase(CodexLimitDerivationTests.allTests),
    testCase(StatePersistenceLogicTests.allTests),
    testCase(PremiumEggTests.allTests),
    testCase(SaveTransferTests.allTests),
    testCase(ShinyCharmTests.allTests),
    testCase(SpriteShinyReloadTests.allTests),
    testCase(ShopTests.allTests),
])
#endif
