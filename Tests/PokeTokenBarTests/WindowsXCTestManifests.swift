#if os(Windows)
import XCTest

/// Explicit Windows XCTest manifest; avoids Swift 6 AST discovery DLL lookup issues.
private func runWindowsAsyncTest(_ operation: @escaping () async throws -> Void) throws {
    let expectation = XCTestExpectation(description: "Windows async XCTest")
    var thrownError: Error?
    Task {
        do { try await operation() } catch { thrownError = error }
        expectation.fulfill()
    }
    let result = XCTWaiter.wait(for: [expectation], timeout: 24 * 60 * 60)
    if result != .completed {
        throw NSError(domain: "PokeTokenBar.WindowsTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "async XCTest timed out"])
    }
    if let thrownError { throw thrownError }
}

extension BinaryLocatorTests {
    static let allTests: [(String, (BinaryLocatorTests) -> () throws -> Void)] = [
        ("testAugmentedEnvironmentPrependsToolPaths", { test in { test.testAugmentedEnvironmentPrependsToolPaths() } }),
        ("testAugmentedEnvironmentWithoutBasePath", { test in { test.testAugmentedEnvironmentWithoutBasePath() } }),
        ("testParsesCleanMarkedPath", { test in { test.testParsesCleanMarkedPath() } }),
        ("testIgnoresProfileNoiseAroundMarker", { test in { test.testIgnoresProfileNoiseAroundMarker() } }),
        ("testEmptyPathReturnsNil", { test in { test.testEmptyPathReturnsNil() } }),
        ("testMissingMarkersReturnsNil", { test in { test.testMissingMarkersReturnsNil() } }),
        ("testTrimsWhitespace", { test in { test.testTrimsWhitespace() } }),
        ("testCommonPathsIncludeManagersForBinary", { test in { test.testCommonPathsIncludeManagersForBinary() } }),
    ]
}

extension CompanionDisplayStateTests {
    static let allTests: [(String, (CompanionDisplayStateTests) -> () throws -> Void)] = [
        ("testEggWhenNoUsageData", { test in { test.testEggWhenNoUsageData() } }),
        ("testLevelUpDuringEventWindow", { test in { try runWindowsAsyncTest { await test.testLevelUpDuringEventWindow() } } }),
        ("testWorkingAfterEventExpires", { test in { try runWindowsAsyncTest { await test.testWorkingAfterEventExpires() } } }),
        ("testFocusOnHighBurn", { test in { try runWindowsAsyncTest { await test.testFocusOnHighBurn() } } }),
        ("testTiredWhenLimitWarning", { test in { try runWindowsAsyncTest { await test.testTiredWhenLimitWarning() } } }),
        ("testSleepWhenZeroUsageToday", { test in { try runWindowsAsyncTest { await test.testSleepWhenZeroUsageToday() } } }),
        ("testEvolveStatusSurvivesUpdateWithinEventWindow", { test in { try runWindowsAsyncTest { await test.testEvolveStatusSurvivesUpdateWithinEventWindow() } } }),
        ("testEggProgressAndTokensToHatch", { test in { test.testEggProgressAndTokensToHatch() } }),
    ]
}

extension PokemonBalanceTests {
    static let allTests: [(String, (PokemonBalanceTests) -> () throws -> Void)] = [
        ("testGraduationTotalIsConstantPerRarityRegardlessOfStages", { test in { test.testGraduationTotalIsConstantPerRarityRegardlessOfStages() } }),
        ("testHigherStageCostsMore", { test in { test.testHigherStageCostsMore() } }),
        ("testRarerCostsMore", { test in { test.testRarerCostsMore() } }),
        ("testRarityDerivation", { test in { test.testRarityDerivation() } }),
    ]
}

extension CompanionStoreTests {
    static let allTests: [(String, (CompanionStoreTests) -> () throws -> Void)] = [
        ("testCorruptDexEntryDroppedWhileRestSurvives", { test in { try test.testCorruptDexEntryDroppedWhileRestSurvives() } }),
        ("testCorruptStateFileBackedUpBeforeReset", { test in { try test.testCorruptStateFileBackedUpBeforeReset() } }),
        ("testCorruptActiveFallsBackToEggWhileRestSurvives", { test in { try test.testCorruptActiveFallsBackToEggWhileRestSurvives() } }),
        ("testDexStoredChainNamesResolvePerLanguage", { test in { test.testDexStoredChainNamesResolvePerLanguage() } }),
        ("testDexResolveChainNamesFetchesWhenUnstored", { test in { try runWindowsAsyncTest { await test.testDexResolveChainNamesFetchesWhenUnstored() } } }),
        ("testGraduationStoresChainNames", { test in { try runWindowsAsyncTest { await test.testGraduationStoresChainNames() } } }),
        ("testDexResolveChainNamesBackfillsLegacyEntry", { test in { try runWindowsAsyncTest { await test.testDexResolveChainNamesBackfillsLegacyEntry() } } }),
        ("testDexSpeciesFoldsDuplicateLinesToOneCellPerSpecies", { test in { try test.testDexSpeciesFoldsDuplicateLinesToOneCellPerSpecies() } }),
        ("testDexSpeciesCountsOnlyReachedStagesOfActive", { test in { try test.testDexSpeciesCountsOnlyReachedStagesOfActive() } }),
        ("testDexSpeciesMarksShinyAcrossTheChain", { test in { try test.testDexSpeciesMarksShinyAcrossTheChain() } }),
        ("testDexSpeciesHidesShinyWhileDittoIsDisguised", { test in { try test.testDexSpeciesHidesShinyWhileDittoIsDisguised() } }),
        ("testDexSpeciesNamesActiveSpeciesFromLoadedLine", { test in { try runWindowsAsyncTest { await test.testDexSpeciesNamesActiveSpeciesFromLoadedLine() } } }),
        ("testBackfillFillsNamesForEntriesSavedBeforeNamesExisted", { test in { try runWindowsAsyncTest { try await test.testBackfillFillsNamesForEntriesSavedBeforeNamesExisted() } } }),
        ("testBackfillDoesNotFetchWhenNamesAreAlreadyStored", { test in { try runWindowsAsyncTest { try await test.testBackfillDoesNotFetchWhenNamesAreAlreadyStored() } } }),
        ("testBackfillRetriesAfterAnOfflineAttempt", { test in { try runWindowsAsyncTest { try await test.testBackfillRetriesAfterAnOfflineAttempt() } } }),
        ("testDexSpeciesMarksEveryUnsecuredStageAsRaising", { test in { try runWindowsAsyncTest { await test.testDexSpeciesMarksEveryUnsecuredStageAsRaising() } } }),
        ("testAlreadyGraduatedSpeciesIsNotMarkedWhileRaisedAgain", { test in { try test.testAlreadyGraduatedSpeciesIsNotMarkedWhileRaisedAgain() } }),
        ("testGraduatedOnlyDexHasNoRaisingMark", { test in { try test.testGraduatedOnlyDexHasNoRaisingMark() } }),
        ("testDexResolveChainNamesOfflineFallback", { test in { try runWindowsAsyncTest { await test.testDexResolveChainNamesOfflineFallback() } } }),
        ("testInstallBaselineExcludesPreInstallUsage", { test in { test.testInstallBaselineExcludesPreInstallUsage() } }),
        ("testUsageIncreaseAfterValidDropContinuesEggProgress", { test in { test.testUsageIncreaseAfterValidDropContinuesEggProgress() } }),
        ("testEmptyUsageSnapshotDoesNotRebaseDailyLedger", { test in { test.testEmptyUsageSnapshotDoesNotRebaseDailyLedger() } }),
        ("testProviderLedgerDoesNotRecreditMissingProviderAfterPartialSnapshotLoss", { test in { test.testProviderLedgerDoesNotRecreditMissingProviderAfterPartialSnapshotLoss() } }),
        ("testCarrierWithoutTodayDataDoesNotRebaseProviderLedger", { test in { test.testCarrierWithoutTodayDataDoesNotRebaseProviderLedger() } }),
        ("testDateRolloverCreditsCurrentDayUsage", { test in { test.testDateRolloverCreditsCurrentDayUsage() } }),
        ("testLateProviderRecoveryAfterDateRolloverCreditsCurrentDayUsage", { test in { test.testLateProviderRecoveryAfterDateRolloverCreditsCurrentDayUsage() } }),
        ("testStaleSnapshotDoesNotConsumeDateBoundary", { test in { test.testStaleSnapshotDoesNotConsumeDateBoundary() } }),
        ("testLegacyAggregateLedgerSeedsProviderMapWithoutRetrospectiveCredit", { test in { try test.testLegacyAggregateLedgerSeedsProviderMapWithoutRetrospectiveCredit() } }),
        ("testEggDoesNotHatchBelowThreshold", { test in { try runWindowsAsyncTest { await test.testEggDoesNotHatchBelowThreshold() } } }),
        ("testEggHatchesAtThreshold", { test in { try runWindowsAsyncTest { await test.testEggHatchesAtThreshold() } } }),
        ("testActiveCompanionAppearsInDexBeforeGraduationWithoutDuplicate", { test in { try runWindowsAsyncTest { await test.testActiveCompanionAppearsInDexBeforeGraduationWithoutDuplicate() } } }),
        ("testLoadedActiveCompanionPreventsEmptyDexState", { test in { try test.testLoadedActiveCompanionPreventsEmptyDexState() } }),
        ("testActiveCompanionPinnedBeforeGraduatedEntries", { test in { try test.testActiveCompanionPinnedBeforeGraduatedEntries() } }),
        ("testDexRaisingLabelLocalized", { test in { test.testDexRaisingLabelLocalized() } }),
        ("testUnknownNextEvolutionAccessibilityLabelLocalized", { test in { test.testUnknownNextEvolutionAccessibilityLabelLocalized() } }),
        ("testEggOverflowCarriesToHatchedMon", { test in { try runWindowsAsyncTest { await test.testEggOverflowCarriesToHatchedMon() } } }),
        ("testEggHatchesViaRESTFallbackWhenIndexDown", { test in { try runWindowsAsyncTest { await test.testEggHatchesViaRESTFallbackWhenIndexDown() } } }),
        ("testNewEggAfterGraduationReincubates", { test in { try runWindowsAsyncTest { await test.testNewEggAfterGraduationReincubates() } } }),
        ("testStateDecodesWithoutEggUsage", { test in { try test.testStateDecodesWithoutEggUsage() } }),
        ("testEvolvesThroughLineAndGraduatesWithFullChain", { test in { try runWindowsAsyncTest { await test.testEvolvesThroughLineAndGraduatesWithFullChain() } } }),
        ("testNoEvolutionGraduatesAtSingleThreshold", { test in { try runWindowsAsyncTest { await test.testNoEvolutionGraduatesAtSingleThreshold() } } }),
        ("testLineNodesPreviewsCompleteLinearEvolution", { test in { try runWindowsAsyncTest { await test.testLineNodesPreviewsCompleteLinearEvolution() } } }),
        ("testRealizedLineItemsUsesStageIndexForCurrentMarker", { test in { test.testRealizedLineItemsUsesStageIndexForCurrentMarker() } }),
        ("testRepairedPlanAppendsFallbackRouteToCurrentPath", { test in { test.testRepairedPlanAppendsFallbackRouteToCurrentPath() } }),
        ("testLineNodesHidesUnresolvedWurmpleBranchAsSingleMystery", { test in { try runWindowsAsyncTest { await test.testLineNodesHidesUnresolvedWurmpleBranchAsSingleMystery() } } }),
        ("testLineNodesShowsKnownPrefixBeforeDownstreamBranchAsMystery", { test in { try runWindowsAsyncTest { await test.testLineNodesShowsKnownPrefixBeforeDownstreamBranchAsMystery() } } }),
        ("testLineNodesRevealsChosenWurmpleBranchAfterEvolution", { test in { try runWindowsAsyncTest { try await test.testLineNodesRevealsChosenWurmpleBranchAfterEvolution() } } }),
        ("testBranchingPrefersUncollectedFinals", { test in { try runWindowsAsyncTest { await test.testBranchingPrefersUncollectedFinals() } } }),
        ("testHatchPreselectsWurmpleRouteAndEvolutionDoesNotConsumeRNG", { test in { try runWindowsAsyncTest { await test.testHatchPreselectsWurmpleRouteAndEvolutionDoesNotConsumeRNG() } } }),
        ("testPersistenceRoundTrip", { test in { try runWindowsAsyncTest { await test.testPersistenceRoundTrip() } } }),
        ("testReloadPreservesCompleteShortPlannedRouteLength", { test in { try runWindowsAsyncTest { await test.testReloadPreservesCompleteShortPlannedRouteLength() } } }),
        ("testReloadLegacyIncompletePlanMigratesToPersistedCompleteRoute", { test in { try runWindowsAsyncTest { try await test.testReloadLegacyIncompletePlanMigratesToPersistedCompleteRoute() } } }),
        ("testReloadRepairsInvalidPlanSuffixWithoutRewindingRealizedPath", { test in { try runWindowsAsyncTest { try await test.testReloadRepairsInvalidPlanSuffixWithoutRewindingRealizedPath() } } }),
        ("testReloadWrongRootNormalizesPathWithoutChangingIdentityOrDisguise", { test in { try runWindowsAsyncTest { try await test.testReloadWrongRootNormalizesPathWithoutChangingIdentityOrDisguise() } } }),
        ("testReloadLeafCurrentPlanDoesNotConsumeRNG", { test in { try runWindowsAsyncTest { try await test.testReloadLeafCurrentPlanDoesNotConsumeRNG() } } }),
        ("testLineLoadPreservesUpdatesMadeWhileProviderIsSuspended", { test in { try runWindowsAsyncTest { try await test.testLineLoadPreservesUpdatesMadeWhileProviderIsSuspended() } } }),
        ("testLocalizedName", { test in { try runWindowsAsyncTest { await test.testLocalizedName() } } }),
        ("testAsymmetricBranchGraduatesSafely", { test in { try runWindowsAsyncTest { await test.testAsymmetricBranchGraduatesSafely() } } }),
    ]
}

extension DisplayLocaleTests {
    static let allTests: [(String, (DisplayLocaleTests) -> () throws -> Void)] = [
        ("testDisplayLocaleMatchesLanguageCode", { test in { test.testDisplayLocaleMatchesLanguageCode() } }),
        ("testRelativeTimeFollowsAppLanguageNotSystem", { test in { test.testRelativeTimeFollowsAppLanguageNotSystem() } }),
    ]
}

extension DexSortingTests {
    static let allTests: [(String, (DexSortingTests) -> () throws -> Void)] = [
        ("testSortRankOrdersRarityAscendingByValue", { test in { test.testSortRankOrdersRarityAscendingByValue() } }),
        ("testDexEntriesSortedByRecencyRegardlessOfRarity", { test in { try runWindowsAsyncTest { await test.testDexEntriesSortedByRecencyRegardlessOfRarity() } } }),
    ]
}

extension CompanionIdentityTests {
    static let allTests: [(String, (CompanionIdentityTests) -> () throws -> Void)] = [
        ("testHatchAssignsDeterministicShinyAndNature", { test in { try runWindowsAsyncTest { await test.testHatchAssignsDeterministicShinyAndNature() } } }),
        ("testShinyPathReachable", { test in { try runWindowsAsyncTest { await test.testShinyPathReachable() } } }),
        ("testGraduateCarriesIdentityToDex", { test in { try runWindowsAsyncTest { await test.testGraduateCarriesIdentityToDex() } } }),
        ("testBackwardCompatibleDecode", { test in { try test.testBackwardCompatibleDecode() } }),
        ("testEmptyPathIDsActiveFallsBackToNilPreservingRest", { test in { test.testEmptyPathIDsActiveFallsBackToNilPreservingRest() } }),
        ("testCurrentIDFallsBackToBaseWhenPathEmpty", { test in { test.testCurrentIDFallsBackToBaseWhenPathEmpty() } }),
        ("testSystemDefaultLanguageResolves", { test in { test.testSystemDefaultLanguageResolves() } }),
        ("testCelebrationFiresOnHatchAndEvolve", { test in { try runWindowsAsyncTest { await test.testCelebrationFiresOnHatchAndEvolve() } } }),
        ("testUsageAccruesWhileLineUnloadedThenEvolvesOnLoad", { test in { try runWindowsAsyncTest { await test.testUsageAccruesWhileLineUnloadedThenEvolvesOnLoad() } } }),
        ("testLineLoadMigratesPersistedUnsupportedEvolution", { test in { try runWindowsAsyncTest { try await test.testLineLoadMigratesPersistedUnsupportedEvolution() } } }),
        ("testShinyBurstSurvivesOverflowEvolve", { test in { try runWindowsAsyncTest { await test.testShinyBurstSurvivesOverflowEvolve() } } }),
        ("testHatchCelebrationSkippedOnInstantGraduate", { test in { try runWindowsAsyncTest { await test.testHatchCelebrationSkippedOnInstantGraduate() } } }),
        ("testSamplerWeightedPickDeterministic", { test in { try runWindowsAsyncTest { await test.testSamplerWeightedPickDeterministic() } } }),
        ("testSamplerCaptureRateIsWeight", { test in { try runWindowsAsyncTest { await test.testSamplerCaptureRateIsWeight() } } }),
        ("testSamplerHalvesCollectedWeight", { test in { try runWindowsAsyncTest { await test.testSamplerHalvesCollectedWeight() } } }),
        ("testEggPrefetchStoresPendingAndHatchUsesIt", { test in { try runWindowsAsyncTest { await test.testEggPrefetchStoresPendingAndHatchUsesIt() } } }),
        ("testPrefetchOfflineFallsBackToHatchTimeRoll", { test in { try runWindowsAsyncTest { await test.testPrefetchOfflineFallsBackToHatchTimeRoll() } } }),
        ("testSamplerOfflineKeepsEgg", { test in { try runWindowsAsyncTest { await test.testSamplerOfflineKeepsEgg() } } }),
        ("testSpriteCacheKeyScheme", { test in { test.testSpriteCacheKeyScheme() } }),
        ("testNatureNamesComplete", { test in { test.testNatureNamesComplete() } }),
    ]
}

extension PokeAPIGuardTests {
    static let allTests: [(String, (PokeAPIGuardTests) -> () throws -> Void)] = [
        ("testValidatedChainURLAcceptsPokeapiHttps", { test in { test.testValidatedChainURLAcceptsPokeapiHttps() } }),
        ("testValidatedChainURLRejectsUntrusted", { test in { test.testValidatedChainURLRejectsUntrusted() } }),
    ]
}

extension DittoDisguiseRollTests {
    static let allTests: [(String, (DittoDisguiseRollTests) -> () throws -> Void)] = [
        ("testHitCommonMultiFormOnMultipleOfDenominator", { test in { test.testHitCommonMultiFormOnMultipleOfDenominator() } }),
        ("testMissWhenRollNotMultipleOfDenominator", { test in { test.testMissWhenRollNotMultipleOfDenominator() } }),
        ("testExcludesSingleForm", { test in { test.testExcludesSingleForm() } }),
        ("testExcludesNonCommon", { test in { test.testExcludesNonCommon() } }),
        ("testDenominatorIs128", { test in { test.testDenominatorIs128() } }),
    ]
}

extension DittoRevealTests {
    static let allTests: [(String, (DittoRevealTests) -> () throws -> Void)] = [
        ("testShinyHiddenDuringDisguise", { test in { test.testShinyHiddenDuringDisguise() } }),
        ("testRevealAtFirstEvolution", { test in { try runWindowsAsyncTest { await test.testRevealAtFirstEvolution() } } }),
        ("testPrunedLeafDisguiseRevealsBeforeGraduation", { test in { try runWindowsAsyncTest { try await test.testPrunedLeafDisguiseRevealsBeforeGraduation() } } }),
        ("testDelayedRevealDoesNotConvertSameBaseReplacementDisguise", { test in { try runWindowsAsyncTest { try await test.testDelayedRevealDoesNotConvertSameBaseReplacementDisguise() } } }),
        ("testShinyUnmaskedAfterReveal", { test in { try runWindowsAsyncTest { await test.testShinyUnmaskedAfterReveal() } } }),
        ("testNoRevealBelowThreshold", { test in { try runWindowsAsyncTest { await test.testNoRevealBelowThreshold() } } }),
        ("testBackwardCompatDecodeNoDittoFields", { test in { test.testBackwardCompatDecodeNoDittoFields() } }),
        ("testDittoExcludedFromRestFallback", { test in { try runWindowsAsyncTest { try await test.testDittoExcludedFromRestFallback() } } }),
    ]
}

extension FreshEggTests {
    static let allTests: [(String, (FreshEggTests) -> () throws -> Void)] = [
        ("testPriceIsOneBillion", { test in { test.testPriceIsOneBillion() } }),
        ("testBuyFreshEggDiscardsWithoutDexOrProbabilityImpact", { test in { test.testBuyFreshEggDiscardsWithoutDexOrProbabilityImpact() } }),
        ("testDiscardedSpeciesNotCollected", { test in { test.testDiscardedSpeciesNotCollected() } }),
        ("testCannotRerollWhenEgg", { test in { test.testCannotRerollWhenEgg() } }),
        ("testCannotRerollWithoutFunds", { test in { test.testCannotRerollWithoutFunds() } }),
        ("testShinyCanBeRerolled", { test in { test.testShinyCanBeRerolled() } }),
    ]
}

extension GeminiUsageTests {
    static let allTests: [(String, (GeminiUsageTests) -> () throws -> Void)] = [
        ("testParseNewJSONLMappingAndUpdate", { test in { try test.testParseNewJSONLMappingAndUpdate() } }),
        ("testParseLegacyJSON", { test in { try test.testParseLegacyJSON() } }),
        ("testCacheCollectsBothExtensions", { test in { try runWindowsAsyncTest { try await test.testCacheCollectsBothExtensions() } } }),
        ("testFileWithoutTokensYieldsNothing", { test in { try test.testFileWithoutTokensYieldsNothing() } }),
        ("testGeminiPricing", { test in { test.testGeminiPricing() } }),
    ]
}

extension LocalUsageReaderTests {
    static let allTests: [(String, (LocalUsageReaderTests) -> () throws -> Void)] = [
        ("testPricingExactAndFallbackAndZero", { test in { test.testPricingExactAndFallbackAndZero() } }),
        ("testClaudeDedupKeepsMaxOutput", { test in { test.testClaudeDedupKeepsMaxOutput() } }),
        ("testClaudeDailyAndCost", { test in { test.testClaudeDailyAndCost() } }),
        ("testEmbeddedRootsFindHiddenClaudeProjectsDirs", { test in { test.testEmbeddedRootsFindHiddenClaudeProjectsDirs() } }),
        ("testEmbeddedRootsIgnoreMissingBaseAndDepthLimit", { test in { test.testEmbeddedRootsIgnoreMissingBaseAndDepthLimit() } }),
        ("testEmbeddedRootsDepthBoundaryMatchesRealLayoutWithHeadroom", { test in { test.testEmbeddedRootsDepthBoundaryMatchesRealLayoutWithHeadroom() } }),
        ("testEmbeddedRootsDoNotDescendIntoBulkDirectories", { test in { test.testEmbeddedRootsDoNotDescendIntoBulkDirectories() } }),
        ("testEmbeddedRootsFindRootsUnderWorkDirectoryNames", { test in { test.testEmbeddedRootsFindRootsUnderWorkDirectoryNames() } }),
        ("testConfigDirParsingHandlesCommasWhitespaceAndTilde", { test in { test.testConfigDirParsingHandlesCommasWhitespaceAndTilde() } }),
        ("testNormalizedRootsFoldSymlinkedDuplicates", { test in { try test.testNormalizedRootsFoldSymlinkedDuplicates() } }),
        ("testNormalizedRootsDropsDuplicatesAndNestedRootsKeepingOrder", { test in { test.testNormalizedRootsDropsDuplicatesAndNestedRootsKeepingOrder() } }),
        ("testMultipleRootsSumButShareGlobalDedup", { test in { test.testMultipleRootsSumButShareGlobalDedup() } }),
        ("testDefaultRootsContainCLIPathAndAreUnique", { test in { test.testDefaultRootsContainCLIPathAndAreUnique() } }),
        ("testDefaultProjectsPathHasSingleSource", { test in { test.testDefaultProjectsPathHasSingleSource() } }),
        ("testCodexParsing", { test in { test.testCodexParsing() } }),
        ("testCodexNonForkResolverPreservesParsedEntriesExceptCanonicalIDs", { test in { test.testCodexNonForkResolverPreservesParsedEntriesExceptCanonicalIDs() } }),
        ("testCodexDropsConsecutiveSameStateRerecordsAndMatchesCumulativeTotal", { test in { test.testCodexDropsConsecutiveSameStateRerecordsAndMatchesCumulativeTotal() } }),
        ("testCodexSameScalarTotalsWithDifferentFullVectorsArePreserved", { test in { test.testCodexSameScalarTotalsWithDifferentFullVectorsArePreserved() } }),
        ("testCodexUnchangedCumulativeWithDifferentLastVectorIsPreserved", { test in { test.testCodexUnchangedCumulativeWithDifferentLastVectorIsPreserved() } }),
        ("testCodexSessionChangeResetsSameStateComparison", { test in { test.testCodexSessionChangeResetsSameStateComparison() } }),
        ("testCodexMissingCumulativeUsagePreservesRepeatedRecords", { test in { test.testCodexMissingCumulativeUsagePreservesRepeatedRecords() } }),
        ("testCodexManualForkFallsBackWhenParentUsageStateIsUnavailable", { test in { test.testCodexManualForkFallsBackWhenParentUsageStateIsUnavailable() } }),
        ("testCodexManualForkFallsBackWhenFoundParentPrefixDoesNotMatch", { test in { test.testCodexManualForkFallsBackWhenFoundParentPrefixDoesNotMatch() } }),
        ("testCodexCumulativeUsageClampsOutOfRangeNumber", { test in { test.testCodexCumulativeUsageClampsOutOfRangeNumber() } }),
        ("testCodexForkTrimsReplayBeforeDroppingActualSameStateRerecord", { test in { test.testCodexForkTrimsReplayBeforeDroppingActualSameStateRerecord() } }),
        ("testCodexForkedRolloutDropsLeadingReplayBurst", { test in { test.testCodexForkedRolloutDropsLeadingReplayBurst() } }),
        ("testCodexForkDropsReplayBurstThatStartsAfterMetadataDelay", { test in { test.testCodexForkDropsReplayBurstThatStartsAfterMetadataDelay() } }),
        ("testCodexForkKeepsRealTurnsAfterReplayBurstWhenTheyAreLessThanTwoSecondsApart", { test in { test.testCodexForkKeepsRealTurnsAfterReplayBurstWhenTheyAreLessThanTwoSecondsApart() } }),
        ("testCodexForkDetectsMetadataAfterLeadingNonTokenRecord", { test in { test.testCodexForkDetectsMetadataAfterLeadingNonTokenRecord() } }),
        ("testCodexProbeReadsSessionIDWhenMetadataLineExceedsChunk", { test in { try test.testCodexProbeReadsSessionIDWhenMetadataLineExceedsChunk() } }),
        ("testCodexProbeDecodesMultibyteStraddlingChunkBoundary", { test in { test.testCodexProbeDecodesMultibyteStraddlingChunkBoundary() } }),
        ("testCodexProbeScansManyLinesAcrossChunks", { test in { test.testCodexProbeScansManyLinesAcrossChunks() } }),
        ("testCodexProbeStopsAtByteLimit", { test in { test.testCodexProbeStopsAtByteLimit() } }),
        ("testCodexProbeStopsAtInvalidUTF8BeforeSessionMeta", { test in { try test.testCodexProbeStopsAtInvalidUTF8BeforeSessionMeta() } }),
        ("testCodexProbeStopsAtTokenCountBeforeSessionMeta", { test in { test.testCodexProbeStopsAtTokenCountBeforeSessionMeta() } }),
        ("testCodexProbeFindsMetadataAfterLeadingNonTokenRecord", { test in { test.testCodexProbeFindsMetadataAfterLeadingNonTokenRecord() } }),
        ("testCodexManualForkFixtureKeepsOnlyPostReplayUsage", { test in { try test.testCodexManualForkFixtureKeepsOnlyPostReplayUsage() } }),
        ("testCodexManualForkFixtureKeepsParentAndChildUsageOnTheirOwnDays", { test in { try test.testCodexManualForkFixtureKeepsParentAndChildUsageOnTheirOwnDays() } }),
        ("testCodexSiblingForkFixturesKeepIndependentPostReplayUsage", { test in { try test.testCodexSiblingForkFixturesKeepIndependentPostReplayUsage() } }),
        ("testCodexSubagentFixturesKeepAllOwnUsageWithoutReplayPrefix", { test in { try test.testCodexSubagentFixturesKeepAllOwnUsageWithoutReplayPrefix() } }),
        ("testCodexSubagentChildFixturesKeepFirstTurnWhenParentIsMissing", { test in { try test.testCodexSubagentChildFixturesKeepFirstTurnWhenParentIsMissing() } }),
        ("testCodexForkOfForkReusesResolvedAncestorHistory", { test in { test.testCodexForkOfForkReusesResolvedAncestorHistory() } }),
        ("testCodexSiblingForksWithIdenticalOwnUsageKeepDistinctIDs", { test in { test.testCodexSiblingForksWithIdenticalOwnUsageKeepDistinctIDs() } }),
        ("testCodexCumulativeResetStartsNewCanonicalEpoch", { test in { test.testCodexCumulativeResetStartsNewCanonicalEpoch() } }),
        ("testCodexCanonicalIDCollapsesSameSessionStateAcrossFilesKeepingEarliestDate", { test in { test.testCodexCanonicalIDCollapsesSameSessionStateAcrossFilesKeepingEarliestDate() } }),
        ("testPeriodAndActiveBlock", { test in { test.testPeriodAndActiveBlock() } }),
        ("testEnrichmentScanStartCoversAllWindows", { test in { try test.testEnrichmentScanStartCoversAllWindows() } }),
        ("testClaudeParsingClampsAbsurdTokenCountsInsteadOfTrapping", { test in { test.testClaudeParsingClampsAbsurdTokenCountsInsteadOfTrapping() } }),
        ("testCodexLastUsageClampsAbsurdTokenCountsInsteadOfTrapping", { test in { test.testCodexLastUsageClampsAbsurdTokenCountsInsteadOfTrapping() } }),
        ("testGeminiParsingClampsAndItsAdditionsStayInRange", { test in { test.testGeminiParsingClampsAndItsAdditionsStayInRange() } }),
        ("testParsingStillFoldsMissingAndNegativeToZero", { test in { test.testParsingStillFoldsMissingAndNegativeToZero() } }),
        ("testDegenerateParentHintIsNotUsedToNarrowCandidates", { test in { test.testDegenerateParentHintIsNotUsedToNarrowCandidates() } }),
        ("testDegenerateParentHintStillResolvesUsageCorrectly", { test in { test.testDegenerateParentHintStillResolvesUsageCorrectly() } }),
        ("testForkReplayIsTrimmedAgainstTheParentRollout", { test in { test.testForkReplayIsTrimmedAgainstTheParentRollout() } }),
    ]
}

extension MintTests {
    static let allTests: [(String, (MintTests) -> () throws -> Void)] = [
        ("testUseMintChangesNatureToDifferent", { test in { test.testUseMintChangesNatureToDifferent() } }),
        ("testMintNeverRepeatsCurrentAcrossUses", { test in { test.testMintNeverRepeatsCurrentAcrossUses() } }),
        ("testUseMintFromNilNatureSetsValid", { test in { test.testUseMintFromNilNatureSetsValid() } }),
        ("testUseMintDoesNotAffectGrowthOrIdentity", { test in { test.testUseMintDoesNotAffectGrowthOrIdentity() } }),
        ("testCannotUseMintOnEgg", { test in { test.testCannotUseMintOnEgg() } }),
        ("testCannotUseMintWithoutStock", { test in { test.testCannotUseMintWithoutStock() } }),
        ("testMintFeedbackSetAndConsumed", { test in { test.testMintFeedbackSetAndConsumed() } }),
        ("testUseMintPersistsAcrossRestart", { test in { test.testUseMintPersistsAcrossRestart() } }),
        ("testMintShopPriceAndPurchasable", { test in { test.testMintShopPriceAndPurchasable() } }),
        ("testBuyMintDebitsWalletAndCredits", { test in { test.testBuyMintDebitsWalletAndCredits() } }),
        ("testCannotBuyMintBelowPrice", { test in { test.testCannotBuyMintBelowPrice() } }),
    ]
}

extension EvoLineNameTests {
    static let allTests: [(String, (EvoLineNameTests) -> () throws -> Void)] = [
        ("testPicksLanguageSpecificThenFallsBackToEnglishThenID", { test in { test.testPicksLanguageSpecificThenFallsBackToEnglishThenID() } }),
        ("testJaFallsBackFromHrktToPlainJa", { test in { test.testJaFallsBackFromHrktToPlainJa() } }),
    ]
}

extension EvoLineAssetTests {
    static let allTests: [(String, (EvoLineAssetTests) -> () throws -> Void)] = [
        ("testKeepsOnlyFormsWithAnimatedAssets", { test in { test.testKeepsOnlyFormsWithAnimatedAssets() } }),
    ]
}

extension EvoNodeTests {
    static let allTests: [(String, (EvoNodeTests) -> () throws -> Void)] = [
        ("testDepthIsLongestPath", { test in { test.testDepthIsLongestPath() } }),
        ("testNodeLookupByID", { test in { test.testNodeLookupByID() } }),
        ("testFinalIDsAreLeaves", { test in { test.testFinalIDsAreLeaves() } }),
    ]
}

extension RarityBoundaryTests {
    static let allTests: [(String, (RarityBoundaryTests) -> () throws -> Void)] = [
        ("testCaptureRateBoundaries", { test in { test.testCaptureRateBoundaries() } }),
        ("testLegendaryAndMythicalOverrideCaptureRate", { test in { test.testLegendaryAndMythicalOverrideCaptureRate() } }),
    ]
}

extension OAuthExpiresAtTests {
    static let allTests: [(String, (OAuthExpiresAtTests) -> () throws -> Void)] = [
        ("testSecondsFormNotTreatedAsMillis", { test in { test.testSecondsFormNotTreatedAsMillis() } }),
        ("testMillisFormDividedByThousand", { test in { test.testMillisFormDividedByThousand() } }),
        ("testStringFormParsed", { test in { test.testStringFormParsed() } }),
        ("testZeroOrMissingExpiryNeverExpires", { test in { test.testZeroOrMissingExpiryNeverExpires() } }),
        ("testRejectsMissingOrEmptyToken", { test in { test.testRejectsMissingOrEmptyToken() } }),
    ]
}

extension ISO8601ParserTests {
    static let allTests: [(String, (ISO8601ParserTests) -> () throws -> Void)] = [
        ("testParsesMicroMilliAndPlainSeconds", { test in { test.testParsesMicroMilliAndPlainSeconds() } }),
        ("testReturnsNilForGarbage", { test in { test.testReturnsNilForGarbage() } }),
        ("testMicroAndMilliResolveToSameInstant", { test in { test.testMicroAndMilliResolveToSameInstant() } }),
    ]
}

extension CodexLimitDerivationTests {
    static let allTests: [(String, (CodexLimitDerivationTests) -> () throws -> Void)] = [
        ("testWindowDisplayName", { test in { test.testWindowDisplayName() } }),
        ("testSpendControlUsedPercentClamped", { test in { test.testSpendControlUsedPercentClamped() } }),
        ("testHasVisibleLimitReflectsWindows", { test in { test.testHasVisibleLimitReflectsWindows() } }),
    ]
}

extension StatePersistenceLogicTests {
    static let allTests: [(String, (StatePersistenceLogicTests) -> () throws -> Void)] = [
        ("testCurrentIDClampsToPath", { test in { test.testCurrentIDClampsToPath() } }),
        ("testMonStateDecodeClampsStageIndexToRealizedPathBounds", { test in { try test.testMonStateDecodeClampsStageIndexToRealizedPathBounds() } }),
        ("testMonStateRoundTripPreservesDistinctPlannedPath", { test in { try test.testMonStateRoundTripPreservesDistinctPlannedPath() } }),
        ("testMonStateLegacyDecodeUsesRealizedPathAsPlan", { test in { try test.testMonStateLegacyDecodeUsesRealizedPathAsPlan() } }),
        ("testMonStateEmptySavedPlanUsesRealizedPath", { test in { try test.testMonStateEmptySavedPlanUsesRealizedPath() } }),
        ("testMonStateEmptyInitialPlanUsesRealizedPath", { test in { test.testMonStateEmptyInitialPlanUsesRealizedPath() } }),
        ("testCompanionStateEncodeDecodeRoundTrip", { test in { try test.testCompanionStateEncodeDecodeRoundTrip() } }),
    ]
}

extension PremiumEggTests {
    static let allTests: [(String, (PremiumEggTests) -> () throws -> Void)] = [
        ("testCaptureRateCeilingIsTheSameThresholdAsClassification", { test in { test.testCaptureRateCeilingIsTheSameThresholdAsClassification() } }),
        ("testLegendaryHasNoCaptureRateCeilingButPassesLowerTierFilters", { test in { test.testLegendaryHasNoCaptureRateCeilingButPassesLowerTierFilters() } }),
        ("testPricesFollowGraduationTotalRatio", { test in { test.testPricesFollowGraduationTotalRatio() } }),
        ("testRareEggIsNotDominatedAtMeasuredPoolComposition", { test in { test.testRareEggIsNotDominatedAtMeasuredPoolComposition() } }),
        ("testBuyPremiumEggRecordsGuaranteeAndDebitsTierPrice", { test in { test.testBuyPremiumEggRecordsGuaranteeAndDebitsTierPrice() } }),
        ("testCannotBuyAnyEggWhileIncubating", { test in { test.testCannotBuyAnyEggWhileIncubating() } }),
        ("testFundsAreCheckedAgainstTierPrice", { test in { test.testFundsAreCheckedAgainstTierPrice() } }),
        ("testPurchaseStartsFromCleanRollState", { test in { test.testPurchaseStartsFromCleanRollState() } }),
        ("testGuaranteeSurvivesRestart", { test in { test.testGuaranteeSurvivesRestart() } }),
        ("testWeightedRollNeverGoesBelowGuarantee", { test in { try runWindowsAsyncTest { await test.testWeightedRollNeverGoesBelowGuarantee() } } }),
        ("testUncommonEggHatchesUncommonAndExcludesOnlyCommon", { test in { try runWindowsAsyncTest { await test.testUncommonEggHatchesUncommonAndExcludesOnlyCommon() } } }),
        ("testLegendaryStillReachableFromPremiumEgg", { test in { try runWindowsAsyncTest { await test.testLegendaryStillReachableFromPremiumEgg() } } }),
        ("testRestFallbackRespectsGuarantee", { test in { try runWindowsAsyncTest { await test.testRestFallbackRespectsGuarantee() } } }),
        ("testRestFallbackHonoursUncommonTierWithoutOverFiltering", { test in { try runWindowsAsyncTest { await test.testRestFallbackHonoursUncommonTierWithoutOverFiltering() } } }),
        ("testRestFallbackWithoutGuaranteeCanHatchCommon", { test in { try runWindowsAsyncTest { await test.testRestFallbackWithoutGuaranteeCanHatchCommon() } } }),
        ("testHatchDiscardsSpeciesBelowGuaranteeWhenIndexIsStale", { test in { try runWindowsAsyncTest { await test.testHatchDiscardsSpeciesBelowGuaranteeWhenIndexIsStale() } } }),
        ("testSameSpeciesHatchesNormallyWithoutGuarantee", { test in { try runWindowsAsyncTest { await test.testSameSpeciesHatchesNormallyWithoutGuarantee() } } }),
        ("testHatchConsumesGuarantee", { test in { try runWindowsAsyncTest { await test.testHatchConsumesGuarantee() } } }),
        ("testGuaranteeDoesNotSurviveIntoTheNextEgg", { test in { try runWindowsAsyncTest { await test.testGuaranteeDoesNotSurviveIntoTheNextEgg() } } }),
        ("testGuaranteeTravelsWithSave", { test in { test.testGuaranteeTravelsWithSave() } }),
        ("testSanitizedDropsGuaranteeAndItsPreRollWhenActiveExists", { test in { test.testSanitizedDropsGuaranteeAndItsPreRollWhenActiveExists() } }),
        ("testUnsatisfiableGuaranteeIsNormalizedAwayAndEggStillHatches", { test in { try runWindowsAsyncTest { await test.testUnsatisfiableGuaranteeIsNormalizedAwayAndEggStillHatches() } } }),
        ("testCannotBuyTierThatIsNotSold", { test in { test.testCannotBuyTierThatIsNotSold() } }),
        ("testUnknownGuaranteeDecodesAsNoGuarantee", { test in { try test.testUnknownGuaranteeDecodesAsNoGuarantee() } }),
    ]
}

extension SaveTransferTests {
    static let allTests: [(String, (SaveTransferTests) -> () throws -> Void)] = [
        ("testRoundTripPreservesProgress", { test in { try test.testRoundTripPreservesProgress() } }),
        ("testForeignJSONIsRejectedRatherThanImportedAsEmptyState", { test in { try test.testForeignJSONIsRejectedRatherThanImportedAsEmptyState() } }),
        ("testValidEnvelopeWithWrongFormatIDIsRejected", { test in { try test.testValidEnvelopeWithWrongFormatIDIsRejected() } }),
        ("testNewerSchemaIsRejected", { test in { try test.testNewerSchemaIsRejected() } }),
        ("testTransferDayTokensStillCountAfterRebase", { test in { try test.testTransferDayTokensStillCountAfterRebase() } }),
        ("testImportWithoutUsageDataDefersBaselineInsteadOfCreditingWholeDay", { test in { try test.testImportWithoutUsageDataDefersBaselineInsteadOfCreditingWholeDay() } }),
        ("testImportWithStaleOnlyUsageDefersBaselineInsteadOfSeedingEmptyLedger", { test in { try test.testImportWithStaleOnlyUsageDefersBaselineInsteadOfSeedingEmptyLedger() } }),
        ("testImportKeepsProgressAndCandyGrantLedger", { test in { try test.testImportKeepsProgressAndCandyGrantLedger() } }),
        ("testPreviousStateIsBackedUpBeforeOverwrite", { test in { try test.testPreviousStateIsBackedUpBeforeOverwrite() } }),
        ("testImportDuringHatchDiscardsTheHatch", { test in { try runWindowsAsyncTest { try await test.testImportDuringHatchDiscardsTheHatch() } } }),
        ("testImportDuringSpeciesRollDiscardsTheHatch", { test in { try runWindowsAsyncTest { try await test.testImportDuringSpeciesRollDiscardsTheHatch() } } }),
        ("testImportDuringHatchStillLoadsTheImportedLine", { test in { try runWindowsAsyncTest { try await test.testImportDuringHatchStillLoadsTheImportedLine() } } }),
        ("testImportedCompanionIsNotShownAsEggBeforeUsageArrives", { test in { try test.testImportedCompanionIsNotShownAsEggBeforeUsageArrives() } }),
        ("testExtremeValuesAreClampedAtTheTrustBoundary", { test in { try test.testExtremeValuesAreClampedAtTheTrustBoundary() } }),
        ("testCorruptStateOnDiskIsClampedOnLoadNotJustOnImport", { test in { try test.testCorruptStateOnDiskIsClampedOnLoadNotJustOnImport() } }),
        ("testEveryCompanionStateFieldIsClassifiedForTransfer", { test in { test.testEveryCompanionStateFieldIsClassifiedForTransfer() } }),
        ("testImportKeepsThisDevicesLanguage", { test in { try test.testImportKeepsThisDevicesLanguage() } }),
        ("testCandyGrantLedgerMergesInsteadOfBeingReplacedByAnOlderSave", { test in { try test.testCandyGrantLedgerMergesInsteadOfBeingReplacedByAnOlderSave() } }),
        ("testImportAbortsWhenBackupCannotBeWritten", { test in { try test.testImportAbortsWhenBackupCannotBeWritten() } }),
        ("testSecondImportDoesNotDestroyTheOriginalBackup", { test in { try test.testSecondImportDoesNotDestroyTheOriginalBackup() } }),
        ("testCancelIsTheDefaultButtonOnTheImportConfirmation", { test in { test.testCancelIsTheDefaultButtonOnTheImportConfirmation() } }),
        ("testApplySaveSetsDisplayStateFromWhetherACompanionCameIn", { test in { try test.testApplySaveSetsDisplayStateFromWhetherACompanionCameIn() } }),
        ("testOversizedFileIsRejectedBeforeParsing", { test in { test.testOversizedFileIsRejectedBeforeParsing() } }),
        ("testNewerSchemaIsReportedEvenWhenTheBodyIsUnreadable", { test in { try test.testNewerSchemaIsReportedEvenWhenTheBodyIsUnreadable() } }),
        ("testImportErrorMessagesAreLocalizedNotRawSwiftText", { test in { test.testImportErrorMessagesAreLocalizedNotRawSwiftText() } }),
        ("testSuggestedFileNameCarriesDate", { test in { test.testSuggestedFileNameCarriesDate() } }),
    ]
}

extension ShinyCharmTests {
    static let allTests: [(String, (ShinyCharmTests) -> () throws -> Void)] = [
        ("testRollsShinyFlipsWithCharm", { test in { test.testRollsShinyFlipsWithCharm() } }),
        ("testConstantsAndPassiveFlag", { test in { test.testConstantsAndPassiveFlag() } }),
        ("testBuyDeductsAndOwns", { test in { test.testBuyDeductsAndOwns() } }),
        ("testBuyOnceNoRepurchase", { test in { test.testBuyOnceNoRepurchase() } }),
        ("testCanBuyNeedsEnoughTokens", { test in { test.testCanBuyNeedsEnoughTokens() } }),
        ("testOwnsReflectsInventory", { test in { test.testOwnsReflectsInventory() } }),
        ("testHatchWorksWithCharmOwned", { test in { try runWindowsAsyncTest { await test.testHatchWorksWithCharmOwned() } } }),
    ]
}

extension SpriteShinyReloadTests {
    static let allTests: [(String, (SpriteShinyReloadTests) -> () throws -> Void)] = [
        ("testShinyFlipReloadsSpriteForSameSpecies", { test in { test.testShinyFlipReloadsSpriteForSameSpecies() } }),
        ("testUnchangedSpriteSkipsReload", { test in { test.testUnchangedSpriteSkipsReload() } }),
        ("testSpeciesChangeReloadsRegardlessOfShiny", { test in { test.testSpeciesChangeReloadsRegardlessOfShiny() } }),
    ]
}

extension ShopTests {
    static let allTests: [(String, (ShopTests) -> () throws -> Void)] = [
        ("testAvailableEqualsUsedWhenNothingSpent", { test in { test.testAvailableEqualsUsedWhenNothingSpent() } }),
        ("testAvailableSubtractsSpent", { test in { test.testAvailableSubtractsSpent() } }),
        ("testAvailableNeverNegative", { test in { test.testAvailableNeverNegative() } }),
        ("testDecodesWithoutSpentTokens", { test in { try test.testDecodesWithoutSpentTokens() } }),
        ("testSpentTokensRoundTrip", { test in { try test.testSpentTokensRoundTrip() } }),
        ("testCanBuyAtExactPrice", { test in { test.testCanBuyAtExactPrice() } }),
        ("testCannotBuyOneBelowPrice", { test in { test.testCannotBuyOneBelowPrice() } }),
        ("testBuyDebitsWalletAndCreditsInventory", { test in { test.testBuyDebitsWalletAndCreditsInventory() } }),
        ("testBuyInsufficientIsNoOp", { test in { test.testBuyInsufficientIsNoOp() } }),
        ("testMultipleBuysUntilBroke", { test in { test.testMultipleBuysUntilBroke() } }),
        ("testBuyAddsToExistingStock", { test in { test.testBuyAddsToExistingStock() } }),
        ("testBuyPersistsAcrossRestart", { test in { test.testBuyPersistsAcrossRestart() } }),
        ("testItemsSortedByPriceAscending", { test in { test.testItemsSortedByPriceAscending() } }),
        ("testOwnedPassiveSinksToBottom", { test in { test.testOwnedPassiveSinksToBottom() } }),
        ("testShopEntriesInterleavesFreshEggByPrice", { test in { test.testShopEntriesInterleavesFreshEggByPrice() } }),
        ("testShopEntriesOmitsFreshEggWhenNoActive", { test in { test.testShopEntriesOmitsFreshEggWhenNoActive() } }),
    ]
}

#endif
