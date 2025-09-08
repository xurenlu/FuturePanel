import Foundation

struct TemplateEngine {
    static func render(template: String, jsonString: String, metaTimeString: String, id: String) -> String {
        // Very small subset to support constants and simple ${.field} extraction
        var output = template

        // constants
        // New canonical name $DTIME, keep $DATE_TIME for backward compatibility
        output = output.replacingOccurrences(of: "$DTIME", with: metaTimeString)
        output = output.replacingOccurrences(of: "$DATE_TIME", with: metaTimeString)
        // derive $DATE and $TIME from metaTimeString (format yyyy-MM-dd HH:mm:ss)
        var datePart = metaTimeString
        var timePart = metaTimeString
        let comps = metaTimeString.split(separator: " ")
        if comps.count >= 2 {
            datePart = String(comps[0])
            timePart = String(comps[1])
        }
        output = output.replacingOccurrences(of: "$DATE", with: datePart)
        output = output.replacingOccurrences(of: "$TIME", with: timePart)
        // Replace LAST6 first to avoid "$UUID" pre-replacement breaking tokens
        let last6 = String(id.suffix(6))
        output = output.replacingOccurrences(of: "$LAST6", with: last6)
        output = output.replacingOccurrences(of: "$UUID_LAST6", with: last6)
        output = output.replacingOccurrences(of: "$UUID", with: id)

        // naive ${.field} extraction (top-level only)
        if let data = jsonString.data(using: .utf8),
           let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let regex = try! NSRegularExpression(pattern: #"\$\{\.(.*?)\}"#, options: [])
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: output.utf16.count))
            var rendered = output
            for m in matches.reversed() {
                if m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: output) {
                    let keyPath = String(output[r])
                    let val = (obj as NSDictionary).value(forKeyPath: keyPath)
                    let repRange = Range(m.range(at: 0), in: output)!
                    rendered.replaceSubrange(repRange, with: stringOf(val))
                }
            }
            output = rendered
        }
        // evaluate simple functions (max/default) before stripping style wrappers
        output = evaluateFunctions(output)
        // strip style wrappers like primary(x) / second(x) → just keep x (rendering颜色交给UI)
        output = stripStyleFunctions(output)
        return output
    }

    struct StyledSegment {
        let roleName: String? // e.g., "primary", "second", "warning"... nil for default
        let text: String
    }

    static func renderSegments(template: String, jsonString: String, metaTimeString: String, id: String) -> [StyledSegment] {
        // Apply the same replacements/functions as render(), but do NOT strip styles.
        var output = template
        output = output.replacingOccurrences(of: "$DTIME", with: metaTimeString)
        output = output.replacingOccurrences(of: "$DATE_TIME", with: metaTimeString)
        var datePart = metaTimeString
        var timePart = metaTimeString
        let comps = metaTimeString.split(separator: " ")
        if comps.count >= 2 {
            datePart = String(comps[0])
            timePart = String(comps[1])
        }
        output = output.replacingOccurrences(of: "$DATE", with: datePart)
        output = output.replacingOccurrences(of: "$TIME", with: timePart)
        let last6 = String(id.suffix(6))
        output = output.replacingOccurrences(of: "$LAST6", with: last6)
        output = output.replacingOccurrences(of: "$UUID_LAST6", with: last6)
        output = output.replacingOccurrences(of: "$UUID", with: id)

        if let data = jsonString.data(using: .utf8),
           let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let regex = try! NSRegularExpression(pattern: #"\$\{\.(.*?)\}"#, options: [])
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: output.utf16.count))
            var rendered = output
            for m in matches.reversed() {
                if m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: output) {
                    let keyPath = String(output[r])
                    let val = (obj as NSDictionary).value(forKeyPath: keyPath)
                    let repRange = Range(m.range(at: 0), in: output)!
                    rendered.replaceSubrange(repRange, with: stringOf(val))
                }
            }
            output = rendered
        }
        output = evaluateFunctions(output)
        return parseStyledSegments(output)
            .map { seg in
                let unq = stripOuterQuotesIfPresent(seg.text)
                return StyledSegment(roleName: seg.roleName, text: unq)
            }
    }

    private struct _Seg { let roleName: String?; let text: String }
    private static func parseStyledSegments(_ s: String) -> [_Seg] {
        var segments: [_Seg] = []
        var buffer = ""
        var i = s.startIndex
        func isIdentChar(_ c: Character) -> Bool { c.isLetter }
        func flush() { if !buffer.isEmpty { segments.append(_Seg(roleName: nil, text: buffer)); buffer.removeAll() } }
        while i < s.endIndex {
            let c = s[i]
            if isIdentChar(c) {
                // read identifier
                var j = i
                while j < s.endIndex, isIdentChar(s[j]) { j = s.index(after: j) }
                let name = String(s[i..<j])
                if j < s.endIndex, s[j] == "(" {
                    // find matching ) with depth
                    var k = s.index(after: j)
                    var depth = 1
                    var inQuotes = false
                    while k < s.endIndex {
                        let ch = s[k]
                        if ch == "\"" { inQuotes.toggle() }
                        if !inQuotes {
                            if ch == "(" { depth += 1 }
                            else if ch == ")" { depth -= 1; if depth == 0 { break } }
                        }
                        k = s.index(after: k)
                    }
                    if depth == 0 {
                        let innerStart = s.index(after: j)
                        let inner = String(s[innerStart..<k])
                        // recursively parse inner
                        flush()
                        let innerSegs = parseStyledSegments(inner)
                        if innerSegs.isEmpty {
                            segments.append(_Seg(roleName: name, text: ""))
                        } else {
                            for seg in innerSegs {
                                // inherit style if inner has none
                                let rn = seg.roleName ?? name
                                segments.append(_Seg(roleName: rn, text: seg.text))
                            }
                        }
                        i = s.index(after: k)
                        continue
                    }
                }
                // not a function call; treat as plain text
                buffer.append(c)
                i = s.index(after: i)
            } else {
                buffer.append(c)
                i = s.index(after: i)
            }
        }
        flush()
        return segments
    }

    private static func stringOf(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        if let b = value as? Bool { return b ? "true" : "false" }
        if value == nil { return "" }
        if let d = try? JSONSerialization.data(withJSONObject: value!, options: []) {
            return String(data: d, encoding: .utf8) ?? ""
        }
        return String(describing: value!)
    }

    private static func stripStyleFunctions(_ text: String) -> String {
        // Replace occurrences like primary(x) or error(max(...)) with the inner text, shallowly.
        let funcs = ["primary", "second", "warning", "warn", "error", "notice", "success", "debug", "normal", "gray"]
        var out = text
        for f in funcs {
            let pattern = "\\b" + f + "\\(([^()]*)\\)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                var changed = true
                while changed {
                    let range = NSRange(location: 0, length: out.utf16.count)
                    let matches = regex.matches(in: out, range: range)
                    if matches.isEmpty { changed = false; break }
                    var newOut = out
                    for m in matches.reversed() {
                        if m.numberOfRanges >= 2, let inner = Range(m.range(at: 1), in: out), let full = Range(m.range(at: 0), in: out) {
                            let innerText = String(out[inner])
                            let unquoted = stripOuterQuotesIfPresent(innerText)
                            newOut.replaceSubrange(full, with: unquoted)
                        }
                    }
                    out = newOut
                }
            }
        }
        return out
    }

    private static func evaluateFunctions(_ text: String) -> String {
        var out = text
        var changed = true
        while changed {
            changed = false
            // max(str, len, extra?)
            if let res = evalMax(in: out) { out = res; changed = true }
            // default(x, "fallback")
            if let res = evalDefault(in: out) { out = res; changed = true }
        }
        return out
    }

    private static func evalMax(in input: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"max\((.*?),\s*(\d+)(?:\s*,\s*"(.*?)")?\)"#, options: []) else { return nil }
        let range = NSRange(location: 0, length: input.utf16.count)
        guard let m = regex.firstMatch(in: input, range: range) else { return nil }
        func r(_ i: Int) -> Range<String.Index>? { Range(m.range(at: i), in: input) }
        let strArg = r(1).map { String(input[$0]) } ?? ""
        let lenArg = r(2).flatMap { Int(String(input[$0])) } ?? 0
        let extra = r(3).map { String(input[$0]) } ?? ".."
        let result = applyMax(to: strArg, length: lenArg, extra: extra)
        var out = input
        if let full = Range(m.range(at: 0), in: input) { out.replaceSubrange(full, with: result) }
        return out
    }

    private static func applyMax(to s: String, length: Int, extra: String) -> String {
        if s.count <= length { return s }
        if length <= extra.count { return String(s.prefix(max(0, length))) }
        return String(s.prefix(length - extra.count)) + extra
    }

    private static func evalDefault(in input: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"default\((.*?),\s*"(.*?)"\)"#, options: []) else { return nil }
        let range = NSRange(location: 0, length: input.utf16.count)
        guard let m = regex.firstMatch(in: input, range: range) else { return nil }
        func r(_ i: Int) -> Range<String.Index>? { Range(m.range(at: i), in: input) }
        let x = r(1).map { String(input[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
        let fallback = r(2).map { String(input[$0]) } ?? ""
        let val = x.isEmpty ? fallback : x
        var out = input
        if let full = Range(m.range(at: 0), in: input) { out.replaceSubrange(full, with: val) }
        return out
    }
}

private func stripOuterQuotesIfPresent(_ s: String) -> String {
    if s.count >= 2, s.first == "\"", s.last == "\"" {
        return String(s.dropFirst().dropLast())
    }
    return s
}


