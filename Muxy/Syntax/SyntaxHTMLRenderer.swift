import AppKit
import Foundation

enum SyntaxHTMLRenderer {
    static func render(source: String, grammar: SyntaxGrammar) -> String {
        let tokenizer = SyntaxTokenizer(grammar: grammar)
        let lines = splitLines(source)
        var state: LineEndState = .normal
        var output = ""
        output.reserveCapacity(source.count * 2)

        for (index, line) in lines.enumerated() {
            let result = tokenizer.tokenize(line: line, startState: state)
            state = result.endState
            output.append(renderLine(line: line, tokens: result.tokens))
            if index < lines.count - 1 {
                output.append("\n")
            }
        }
        return output
    }

    static func cssClass(for scope: SyntaxScope) -> String {
        switch scope {
        case .keyword: "muxy-tok-keyword"
        case .storage: "muxy-tok-storage"
        case .type: "muxy-tok-type"
        case .builtin: "muxy-tok-builtin"
        case .constant: "muxy-tok-constant"
        case .string: "muxy-tok-string"
        case .stringEscape: "muxy-tok-string-escape"
        case .number: "muxy-tok-number"
        case .comment: "muxy-tok-comment"
        case .docComment: "muxy-tok-doc-comment"
        case .function: "muxy-tok-function"
        case .variable: "muxy-tok-variable"
        case .attribute: "muxy-tok-attribute"
        case .preprocessor: "muxy-tok-preprocessor"
        case .op: "muxy-tok-op"
        case .punctuation: "muxy-tok-punctuation"
        case .tag: "muxy-tok-tag"
        case .attributeName: "muxy-tok-attribute-name"
        case .attributeValue: "muxy-tok-attribute-value"
        case .regex: "muxy-tok-regex"
        case .heading: "muxy-tok-heading"
        case .link: "muxy-tok-link"
        case .emphasis: "muxy-tok-emphasis"
        }
    }

    @MainActor
    static func cssStylesheet() -> String {
        let allScopes: [SyntaxScope] = [
            .keyword, .storage, .type, .builtin, .constant, .string, .stringEscape,
            .number, .comment, .docComment, .function, .variable, .attribute,
            .preprocessor, .op, .punctuation, .tag, .attributeName, .attributeValue,
            .regex, .heading, .link, .emphasis,
        ]
        var css = ""
        for scope in allScopes {
            let hex = colorHex(SyntaxTheme.color(for: scope))
            css += ".\(cssClass(for: scope)) { color: #\(hex); }\n"
        }
        return css
    }

    private static func renderLine(line: String, tokens: [TokenSpan]) -> String {
        let ns = line as NSString
        let length = ns.length
        if length == 0 {
            return ""
        }
        var output = ""
        output.reserveCapacity(line.count + tokens.count * 24)
        var cursor = 0
        for token in tokens {
            let tokenStart = max(0, token.location)
            let tokenEnd = min(length, tokenStart + token.length)
            if tokenStart > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: tokenStart - cursor))
                output.append(escape(plain))
            }
            if tokenEnd > tokenStart {
                let chunk = ns.substring(with: NSRange(location: tokenStart, length: tokenEnd - tokenStart))
                output.append("<span class=\"\(cssClass(for: token.scope))\">")
                output.append(escape(chunk))
                output.append("</span>")
            }
            cursor = tokenEnd
        }
        if cursor < length {
            let trailing = ns.substring(with: NSRange(location: cursor, length: length - cursor))
            output.append(escape(trailing))
        }
        return output
    }

    private static func splitLines(_ source: String) -> [String] {
        var normalized = source
        if normalized.contains("\r\n") {
            normalized = normalized.replacingOccurrences(of: "\r\n", with: "\n")
        }
        if normalized.contains("\r") {
            normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        }
        return normalized.components(separatedBy: "\n")
    }

    static func escape(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "&": result.append("&amp;")
            case "<": result.append("&lt;")
            case ">": result.append("&gt;")
            case "\"": result.append("&quot;")
            case "'": result.append("&#39;")
            default: result.append(character)
            }
        }
        return result
    }

    private static func colorHex(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(max(0, min(1, rgb.redComponent)) * 255))
        let g = Int(round(max(0, min(1, rgb.greenComponent)) * 255))
        let b = Int(round(max(0, min(1, rgb.blueComponent)) * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
