import XCTest
@testable import CodeIslandCore

final class CodexTranscriptIdentityTests: XCTestCase {
    private func rollout(_ payload: [String: Any]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var data = try JSONSerialization.data(withJSONObject: ["type": "session_meta", "payload": payload])
        data.append(10)
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testDesktopHooksWithoutTerminalAncestryShareDesktopIdentity() throws {
        let url = try rollout(["originator": "Codex Desktop", "source": "vscode", "thread_source": "user"])
        let data = try JSONSerialization.data(withJSONObject: [
            "hook_event_name": "Stop", "session_id": "thread", "_source": "codex", "transcript_path": url.path
        ])
        let event = try XCTUnwrap(HookEvent(from: data))
        XCTAssertEqual(event.sessionId, "codexapp:thread")
        XCTAssertEqual(event.rawJSON["_term_bundle"] as? String, "com.openai.codex")
        XCTAssertFalse(CodexTranscriptIdentity.isGuardian(path: url.path))
    }

    func testGuardianMetadataWithTopLevelParentIsInternal() throws {
        let url = try rollout(["originator": "Codex Desktop", "parent_thread_id": "parent",
            "source": ["subagent": ["other": "guardian"]], "thread_source": "guardian_review"])
        XCTAssertTrue(CodexTranscriptIdentity.isGuardian(path: url.path))
        XCTAssertTrue(CodexTranscriptIdentity.isDesktop(path: url.path))
    }

    func testCLIAndRemoteIdentityRemainUnchanged() throws {
        let cli = try rollout(["originator": "codex_cli_rs", "source": "cli"])
        let desktop = try rollout(["originator": "Codex Desktop"])
        for (path, remote, expected) in [(cli.path, "", "thread"), (desktop.path, "server", "remote:server:thread")] {
            var payload: [String: Any] = ["hook_event_name": "Stop", "session_id": "thread", "_source": "codex", "transcript_path": path]
            if !remote.isEmpty { payload["_remote_host_id"] = remote }
            XCTAssertEqual(HookEvent(from: try JSONSerialization.data(withJSONObject: payload))?.sessionId, expected)
        }
    }
}
