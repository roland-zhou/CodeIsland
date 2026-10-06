import Foundation

/// Provenance supplied by Codex itself, independent of the hook's terminal ancestry.
public enum CodexTranscriptIdentity {
    public static func metadata(path: String?) -> [String: Any]? {
        guard let path, let file = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? file.close() }
        guard let bytes = try? file.read(upToCount: 1_048_576),
              let newline = bytes.firstIndex(of: 10),
              let row = try? JSONSerialization.jsonObject(with: bytes.prefix(upTo: newline)) as? [String: Any],
              row["type"] as? String == "session_meta" else { return nil }
        return row["payload"] as? [String: Any]
    }

    public static func isDesktop(path: String?) -> Bool {
        guard let meta = metadata(path: path) else { return false }
        let origin = (meta["originator"] as? String)?.lowercased() ?? ""
        let source = (meta["source"] as? String)?.lowercased() ?? ""
        return origin.contains("desktop") || source == "vscode" || source == "appserver"
    }

    public static func isGuardian(path: String?) -> Bool {
        guard let meta = metadata(path: path) else { return false }
        if meta["thread_source"] as? String == "guardian_review" { return true }
        let source = meta["source"] as? [String: Any]
        let child = source?["subagent"] as? [String: Any]
        return child?["other"] as? String == "guardian"
    }
}
