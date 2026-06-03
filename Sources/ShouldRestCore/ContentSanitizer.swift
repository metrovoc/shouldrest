import Foundation

public enum ContentSanitizer {
    public static func sanitizeRichText(_ input: String) -> String {
        var output = input
        output = removeTagAndBody("script", from: output)
        output = removeTagAndBody("style", from: output)
        output = removeStandaloneTag("img", from: output)
        output = removeDangerousAttributes(from: output)
        output = removeDangerousURLSchemes(from: output)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeTagAndBody(_ tag: String, from input: String) -> String {
        let pattern = #"<\#(tag)\b[^>]*>[\s\S]*?</\#(tag)>"#
        return input.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func removeStandaloneTag(_ tag: String, from input: String) -> String {
        let pattern = #"<\#(tag)\b[^>]*>"#
        return input.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func removeDangerousAttributes(from input: String) -> String {
        input.replacingOccurrences(
            of: #"\s+on[a-zA-Z]+\s*=\s*(".*?"|'.*?'|[^\s>]+)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func removeDangerousURLSchemes(from input: String) -> String {
        input.replacingOccurrences(
            of: #"\s+(href|src)\s*=\s*("|')?\s*(javascript|data|file):[^"'\s>]*("|')?"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }
}
