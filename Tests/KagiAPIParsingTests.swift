import XCTest
@testable import KagiAssistantCore

final class KagiAPIParsingTests: XCTestCase {

    // MARK: - KagiHTMLParser.parseThreadList

    func testParseThreadListEmpty() {
        let entries = KagiHTMLParser.parseThreadList(html: "")
        XCTAssertTrue(entries.isEmpty)
    }

    func testParseThreadListNoThreads() {
        let html = "<html><body><p>No threads here</p></body></html>"
        let entries = KagiHTMLParser.parseThreadList(html: html)
        XCTAssertTrue(entries.isEmpty)
    }

    func testParseThreadListSingleEntry() {
        let html = """
        <div class="thread" data-code="abc123" data-x="y">
            <div class="title">My Thread Title</div>
            <div class="excerpt">Some excerpt text</div>
        </div>
        """
        let entries = KagiHTMLParser.parseThreadList(html: html)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, "abc123")
        XCTAssertEqual(entries[0].title, "My Thread Title")
        XCTAssertEqual(entries[0].excerpt, "Some excerpt text")
    }

    func testParseThreadListMultipleEntries() {
        let html = """
        <div class="thread" data-code="t1" data-x="y">
            <div class="title">Thread 1</div>
            <div class="excerpt">Excerpt 1</div>
        </div>
        <div class="thread" data-code="t2" data-x="y">
            <div class="title">Thread 2</div>
            <div class="excerpt">Excerpt 2</div>
        </div>
        """
        let entries = KagiHTMLParser.parseThreadList(html: html)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].id, "t1")
        XCTAssertEqual(entries[1].id, "t2")
    }

    // MARK: - KagiMessageDTO.extractCitations

    func testExtractCitationsEmpty() {
        let dto = KagiMessageDTO(id: nil, prompt: nil, reply: nil, documents: nil,
                                  branch_list: nil, references_html: nil, md: nil,
                                  metadata: nil, state: nil)
        let citations = dto.extractCitations()
        XCTAssertTrue(citations.isEmpty)
    }

    func testExtractCitationsNoRefList() {
        let dto = KagiMessageDTO(id: nil, prompt: nil, reply: nil, documents: nil,
                                  branch_list: nil, references_html: "<p>No refs</p>",
                                  md: nil, metadata: nil, state: nil)
        let citations = dto.extractCitations()
        XCTAssertTrue(citations.isEmpty)
    }

    func testExtractCitationsWithRefs() {
        let html = """
        <ol data-ref-list>
            <li><a href="https://example.com">Example Site</a></li>
            <li><a href="https://test.org/page?q=1&amp;r=2">Test &amp; Page</a></li>
        </ol>
        """
        let dto = KagiMessageDTO(id: nil, prompt: nil, reply: nil, documents: nil,
                                  branch_list: nil, references_html: html,
                                  md: nil, metadata: nil, state: nil)
        let citations = dto.extractCitations()
        XCTAssertEqual(citations.count, 2)
        XCTAssertEqual(citations[0].url, "https://example.com")
        XCTAssertEqual(citations[0].title, "Example Site")
        XCTAssertEqual(citations[1].url, "https://test.org/page?q=1&r=2")
        XCTAssertEqual(citations[1].title, "Test & Page")
    }

    // MARK: - KagiThreadListWrapper.parse

    func testParseFromValidJSON() {
        let json = #"{"html":"<div>threads</div>","has_more":true,"count":5}"#
        let wrapper = KagiThreadListWrapper.parse(from: json)
        XCTAssertNotNil(wrapper)
        XCTAssertEqual(wrapper?.html, "<div>threads</div>")
        XCTAssertEqual(wrapper?.has_more, true)
        XCTAssertEqual(wrapper?.count, 5)
    }

    func testParseFromInvalidJSON() {
        let wrapper = KagiThreadListWrapper.parse(from: "not json")
        XCTAssertNil(wrapper)
    }

    func testParseFromPartialJSON() {
        let json = #"{"html":"<p>partial</p>"}"#
        let wrapper = KagiThreadListWrapper.parse(from: json)
        XCTAssertNotNil(wrapper)
        XCTAssertEqual(wrapper?.html, "<p>partial</p>")
        XCTAssertNil(wrapper?.has_more)
        XCTAssertNil(wrapper?.count)
    }
}
