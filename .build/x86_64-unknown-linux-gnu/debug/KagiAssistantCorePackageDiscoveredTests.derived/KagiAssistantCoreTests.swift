import XCTest
@testable import KagiAssistantCoreTests

fileprivate extension ContentParserTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__ContentParserTests = [
        ("testDetailsWithTrailingColonStrippedFromTitle", testDetailsWithTrailingColonStrippedFromTitle),
        ("testEmptyStringReturnsNoSegments", testEmptyStringReturnsNoSegments),
        ("testLastEventCompletedWhenContentFollows", testLastEventCompletedWhenContentFollows),
        ("testLastEventNotCompletedWhenStreaming", testLastEventNotCompletedWhenStreaming),
        ("testMixedContentAndDetails", testMixedContentAndDetails),
        ("testPlainHTMLReturnsSingleSegment", testPlainHTMLReturnsSingleSegment),
        ("testSegmentIdsAreSequential", testSegmentIdsAreSequential),
        ("testSingleDetailsBlockReturnsEvent", testSingleDetailsBlockReturnsEvent),
        ("testWhitespaceOnlyReturnsNoSegments", testWhitespaceOnlyReturnsNoSegments)
    ]
}

fileprivate extension KagiAPIParsingTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__KagiAPIParsingTests = [
        ("testExtractCitationsEmpty", testExtractCitationsEmpty),
        ("testExtractCitationsNoRefList", testExtractCitationsNoRefList),
        ("testExtractCitationsWithRefs", testExtractCitationsWithRefs),
        ("testParseFromInvalidJSON", testParseFromInvalidJSON),
        ("testParseFromPartialJSON", testParseFromPartialJSON),
        ("testParseFromValidJSON", testParseFromValidJSON),
        ("testParseThreadListEmpty", testParseThreadListEmpty),
        ("testParseThreadListMultipleEntries", testParseThreadListMultipleEntries),
        ("testParseThreadListNoThreads", testParseThreadListNoThreads),
        ("testParseThreadListSingleEntry", testParseThreadListSingleEntry)
    ]
}

fileprivate extension ModelsTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__ModelsTests = [
        ("testChatAttachmentByteCount", testChatAttachmentByteCount),
        ("testChatAttachmentNilData", testChatAttachmentNilData),
        ("testChatMessageDefaultValues", testChatMessageDefaultValues),
        ("testChatMessageEquality", testChatMessageEquality),
        ("testChatThreadDefaults", testChatThreadDefaults),
        ("testChatThreadEquality", testChatThreadEquality)
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __KagiAssistantCoreTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ContentParserTests.__allTests__ContentParserTests),
        testCase(KagiAPIParsingTests.__allTests__KagiAPIParsingTests),
        testCase(ModelsTests.__allTests__ModelsTests)
    ]
}