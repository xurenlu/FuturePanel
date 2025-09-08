import SwiftUI

struct Highlighter {
    static func highlight(text: String, keyword: String) -> Text {
        guard !keyword.isEmpty, let range = text.range(of: keyword, options: .caseInsensitive) else {
            return Text(text)
        }
        let before = String(text[..<range.lowerBound])
        let match = String(text[range])
        let after = String(text[range.upperBound...])
        return Text(before) + Text(match).bold().underline() + Text(after)
    }
}


