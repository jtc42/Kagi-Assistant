import XCTest
@testable import KagiAssistantCore

final class ContentParserTests: XCTestCase {

    // MARK: - Empty / whitespace input

    func testEmptyStringReturnsNoSegments() {
        let segments = ContentParser.parseContent("", isStreaming: false)
        XCTAssertTrue(segments.isEmpty)
    }

    func testWhitespaceOnlyReturnsNoSegments() {
        let segments = ContentParser.parseContent("   \n  ", isStreaming: false)
        XCTAssertTrue(segments.isEmpty)
    }

    // MARK: - Plain HTML (no <details>)

    func testPlainHTMLReturnsSingleSegment() {
        let html = "<p>Hello, world!</p>"
        let segments = ContentParser.parseContent(html, isStreaming: false)
        XCTAssertEqual(segments.count, 1)
        if case .htmlContent(_, let content) = segments[0] {
            XCTAssertEqual(content, html)
        } else {
            XCTFail("Expected .htmlContent segment")
        }
    }

    // MARK: - Details blocks (events)

    func testSingleDetailsBlockReturnsEvent() {
        let html = "<details><summary>Searching</summary>Some results</details>"
        let segments = ContentParser.parseContent(html, isStreaming: false)
        XCTAssertEqual(segments.count, 1)
        if case .event(_, let title, let content, let isCompleted) = segments[0] {
            XCTAssertEqual(title, "Searching")
            XCTAssertEqual(content, "Some results")
            XCTAssertTrue(isCompleted)
        } else {
            XCTFail("Expected .event segment")
        }
    }

    func testDetailsWithTrailingColonStrippedFromTitle() {
        let html = "<details><summary>Reading from:</summary>content</details>"
        let segments = ContentParser.parseContent(html, isStreaming: false)
        if case .event(_, let title, _, _) = segments[0] {
            XCTAssertEqual(title, "Reading")
        } else {
            XCTFail("Expected .event segment")
        }
    }

    func testMixedContentAndDetails() {
        let html = "<p>Before</p><details><summary>Event</summary>data</details><p>After</p>"
        let segments = ContentParser.parseContent(html, isStreaming: false)
        XCTAssertEqual(segments.count, 3)
        if case .htmlContent(_, let content) = segments[0] {
            XCTAssertTrue(content.contains("Before"))
        } else {
            XCTFail("Expected .htmlContent for first segment")
        }
        if case .event(_, let title, _, _) = segments[1] {
            XCTAssertEqual(title, "Event")
        } else {
            XCTFail("Expected .event for second segment")
        }
        if case .htmlContent(_, let content) = segments[2] {
            XCTAssertTrue(content.contains("After"))
        } else {
            XCTFail("Expected .htmlContent for third segment")
        }
    }

    // MARK: - Streaming state

    func testLastEventNotCompletedWhenStreaming() {
        let html = "<details><summary>Working</summary>partial</details>"
        let segments = ContentParser.parseContent(html, isStreaming: true)
        XCTAssertEqual(segments.count, 1)
        if case .event(_, _, _, let isCompleted) = segments[0] {
            XCTAssertFalse(isCompleted, "Last event should not be completed during streaming")
        } else {
            XCTFail("Expected .event segment")
        }
    }

    func testLastEventCompletedWhenContentFollows() {
        let html = "<details><summary>Done</summary>result</details><p>Next</p>"
        let segments = ContentParser.parseContent(html, isStreaming: true)
        // The event is followed by content, so it should be completed
        if case .event(_, _, _, let isCompleted) = segments[0] {
            XCTAssertTrue(isCompleted, "Event followed by content should be completed even when streaming")
        }
    }

    // MARK: - Segment IDs

    func testSegmentIdsAreSequential() {
        let html = "<p>A</p><details><summary>B</summary>C</details><p>D</p>"
        let segments = ContentParser.parseContent(html, isStreaming: false)
        for (i, segment) in segments.enumerated() {
            XCTAssertEqual(segment.id, i)
        }
    }
}
