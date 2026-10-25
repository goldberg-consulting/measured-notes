import Foundation
@main struct MarkdownHeadingChecks {
    static func main() {
        for level in 1...6 {
            let result = MarkdownHeadings.heading([String(repeating: "#", count: level) + " Heading **bold**"], at: 0)
            precondition(result?.level == level && result?.text == "Heading **bold**")
        }
        precondition(MarkdownHeadings.heading(["#hashtag"], at: 0) == nil)
        precondition(MarkdownHeadings.heading(["####### Not a heading"], at: 0) == nil)
        precondition(MarkdownHeadings.heading(["## Title ##"], at: 0)?.text == "Title")
        precondition(MarkdownHeadings.heading(["Title", "==="], at: 0)?.level == 1)
        precondition(MarkdownHeadings.heading(["Section", "---"], at: 0)?.level == 2)
        for marker in ["```", "~~~", "````"] {
            let lines = [marker, "# Literal", marker, "## Heading"]
            precondition(MarkdownHeadings.heading(lines, at: 1) == nil)
            precondition(MarkdownHeadings.heading(lines, at: 3)?.level == 2)
        }
        precondition(MarkdownHeadings.heading(["    # Code"], at: 0) == nil)
        print("PASS: six heading levels, inline formatting, closing markers, setext headings, code fences, hashtags")
    }
}
