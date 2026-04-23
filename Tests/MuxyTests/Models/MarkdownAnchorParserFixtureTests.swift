import Foundation
import Testing

@testable import Muxy

@Suite("MarkdownAnchorParser Fixtures")
struct MarkdownAnchorParserFixtureTests {
    @Test("fixtures exist")
    func fixturesExist() throws {
        let fixtureURLs = try MarkdownAnchorFixtureSupport.fixtureMarkdownFiles()
        #expect(fixtureURLs.count >= 10)
    }

    @Test("parses fixtures with monotonic, non-overlapping anchors")
    func parsesFixtures() throws {
        let fixtureURLs = try MarkdownAnchorFixtureSupport.fixtureMarkdownFiles()

        for fixtureURL in fixtureURLs {
            let markdown = try String(contentsOf: fixtureURL, encoding: .utf8)
            let anchors = MarkdownAnchorParser.parseAnchors(in: markdown)
            let lineCount = markdown.split(separator: "\n", omittingEmptySubsequences: false).count

            #expect(!anchors.isEmpty)

            for (i, anchor) in anchors.enumerated() {
                #expect(anchor.startLine >= 1)
                #expect(anchor.endLine >= anchor.startLine)
                #expect(anchor.endLine <= max(1, lineCount))
                #expect(anchor.id == "anchor-\(i + 1)-\(anchor.startLine)-\(anchor.endLine)")

                if i > 0 {
                    let prev = anchors[i - 1]
                    #expect(anchor.startLine > prev.startLine)
                    #expect(anchor.startLine > prev.endLine)
                }
            }
        }
    }

    @Test("fixtures cover major anchor kinds")
    func fixtureKindCoverage() throws {
        let fixtureURLs = try MarkdownAnchorFixtureSupport.fixtureMarkdownFiles()

        var kinds: Set<MarkdownSyncAnchorKind> = []
        for fixtureURL in fixtureURLs {
            let markdown = try String(contentsOf: fixtureURL, encoding: .utf8)
            kinds.formUnion(MarkdownAnchorParser.parseAnchors(in: markdown).map(\.kind))
        }

        #expect(kinds.contains(.heading))
        #expect(kinds.contains(.paragraph))
        #expect(kinds.contains(.list))
        #expect(kinds.contains(.fencedCode))
        #expect(kinds.contains(.mermaid))
        #expect(kinds.contains(.table))
        #expect(kinds.contains(.image))
        #expect(kinds.contains(.blockquote))
        #expect(kinds.contains(.thematicBreak))
        #expect(kinds.contains(.htmlBlock))
    }
}

enum MarkdownAnchorFixtureSupport {
    static func fixtureMarkdownFiles() throws -> [URL] {
        let root = try repoRootURL()
        let fixtureDir = root.appendingPathComponent("docs/fixtures/markdown-anchor-sync", isDirectory: true)

        let contents = try FileManager.default.contentsOfDirectory(at: fixtureDir, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension.lowercased() == "md" }
            .filter { $0.lastPathComponent.range(of: "^[0-9]{2}-.*\\.md$", options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func repoRootURL() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        for _ in 0 ..< 10 {
            let packagePath = candidate.appendingPathComponent("Package.swift").path
            if FileManager.default.fileExists(atPath: packagePath) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        throw FixtureError.repoRootNotFound
    }

    enum FixtureError: Error {
        case repoRootNotFound
    }
}
