import XCTest
@testable import KagiAssistantCore

final class ModelsTests: XCTestCase {

    // MARK: - ChatAttachment

    func testChatAttachmentByteCount() {
        let data = Data([0x01, 0x02, 0x03])
        let attachment = ChatAttachment(name: "test.txt", mimeType: "text/plain", data: data, thumbnailData: nil, thumbnailMimeType: nil)
        XCTAssertEqual(attachment.byteCount, 3)
    }

    func testChatAttachmentNilData() {
        let attachment = ChatAttachment(name: "test.txt", mimeType: "text/plain", data: nil, thumbnailData: nil, thumbnailMimeType: nil)
        XCTAssertNil(attachment.byteCount)
    }

    // MARK: - ChatMessage

    func testChatMessageEquality() {
        let msg = ChatMessage(role: .user, content: "Hello")
        // Same instance → equal
        XCTAssertEqual(msg, msg)

        // Different instances with different UUIDs → not equal
        let msg2 = ChatMessage(role: .user, content: "Hello")
        XCTAssertNotEqual(msg, msg2, "Different ids should not be equal")
    }

    func testChatMessageDefaultValues() {
        let msg = ChatMessage(role: .assistant, content: "Hi")
        XCTAssertNil(msg.kagiMessageId)
        XCTAssertTrue(msg.attachments.isEmpty)
        XCTAssertFalse(msg.isStreaming)
    }

    // MARK: - ChatThread

    func testChatThreadEquality() {
        let thread = ChatThread(name: "Test")
        XCTAssertEqual(thread, thread)

        let thread2 = ChatThread(name: "Test")
        XCTAssertNotEqual(thread, thread2, "Different ids should not be equal")
    }

    func testChatThreadDefaults() {
        let thread = ChatThread(name: "New Thread")
        XCTAssertNil(thread.kagiThreadId)
        XCTAssertNil(thread.branchId)
        XCTAssertTrue(thread.messages.isEmpty)
    }
}
