import SwiftUI
#if os(macOS)
import AppKit
#endif

enum ThemeName: String, CaseIterable, Identifiable {
    case oneDark = "One Dark"
    case dracula = "Dracula"
    case nord = "Nord"
    case monokai = "Monokai"
    case gruvboxDark = "Gruvbox Dark"
    case solarizedDark = "Solarized Dark"
    case materialOcean = "Material Ocean"
    case nightOwl = "Night Owl"
    case tomorrowNight = "Tomorrow Night"
    case cobalt2 = "Cobalt 2"

    // Added: text-focused palettes
    case inkBlack = "Ink Black"
    case solarYellow = "Solar Yellow"
    case emberRed = "Ember Red"
    case forestDarkGreen = "Forest Dark Green"
    case cocoaChocolate = "Cocoa Chocolate"

    var id: String { rawValue }
}

enum SemanticRole: String {
    case primary
    case second
    case warning
    case error
    case notice
    case debug
    case normal
}

struct ThemePalette {
    let colors: [SemanticRole: Color]

    static func palette(for name: ThemeName) -> ThemePalette {
        switch name {
        case .oneDark:
            return ThemePalette(colors: [
                .primary: Color(red: 0.82, green: 0.82, blue: 0.82),
                .second: Color(red: 0.49, green: 0.37, blue: 0.26), // chocolate-like for paths
                .warning: Color(red: 0.90, green: 0.70, blue: 0.30),
                .error: Color(red: 0.85, green: 0.40, blue: 0.45),
                .notice: Color(red: 0.45, green: 0.70, blue: 0.85),
                .debug: Color(red: 0.55, green: 0.55, blue: 0.80),
                .normal: Color(red: 0.75, green: 0.75, blue: 0.75)
            ])
        case .dracula:
            return ThemePalette(colors: [
                .primary: Color(red: 0.90, green: 0.90, blue: 0.90),
                .second: Color(red: 0.48, green: 0.34, blue: 0.22),
                .warning: Color(red: 0.98, green: 0.78, blue: 0.34),
                .error: Color(red: 0.86, green: 0.47, blue: 0.56),
                .notice: Color(red: 0.49, green: 0.77, blue: 0.87),
                .debug: Color(red: 0.60, green: 0.62, blue: 0.85),
                .normal: Color(red: 0.78, green: 0.78, blue: 0.78)
            ])
        case .nord:
            return ThemePalette(colors: [
                .primary: Color(red: 0.88, green: 0.90, blue: 0.93),
                .second: Color(red: 0.45, green: 0.33, blue: 0.22),
                .warning: Color(red: 0.95, green: 0.80, blue: 0.40),
                .error: Color(red: 0.80, green: 0.50, blue: 0.55),
                .notice: Color(red: 0.57, green: 0.81, blue: 0.89),
                .debug: Color(red: 0.60, green: 0.66, blue: 0.84),
                .normal: Color(red: 0.80, green: 0.82, blue: 0.85)
            ])
        case .monokai:
            return ThemePalette(colors: [
                .primary: Color(red: 0.93, green: 0.93, blue: 0.93),
                .second: Color(red: 0.50, green: 0.35, blue: 0.20),
                .warning: Color(red: 0.99, green: 0.82, blue: 0.38),
                .error: Color(red: 0.86, green: 0.45, blue: 0.56),
                .notice: Color(red: 0.59, green: 0.79, blue: 0.88),
                .debug: Color(red: 0.64, green: 0.64, blue: 0.86),
                .normal: Color(red: 0.82, green: 0.82, blue: 0.82)
            ])
        case .gruvboxDark:
            return ThemePalette(colors: [
                .primary: Color(red: 0.93, green: 0.89, blue: 0.85),
                .second: Color(red: 0.53, green: 0.34, blue: 0.17),
                .warning: Color(red: 0.99, green: 0.76, blue: 0.38),
                .error: Color(red: 0.80, green: 0.50, blue: 0.50),
                .notice: Color(red: 0.58, green: 0.74, blue: 0.84),
                .debug: Color(red: 0.70, green: 0.70, blue: 0.85),
                .normal: Color(red: 0.85, green: 0.80, blue: 0.75)
            ])
        case .solarizedDark:
            return ThemePalette(colors: [
                .primary: Color(red: 0.85, green: 0.89, blue: 0.82),
                .second: Color(red: 0.49, green: 0.35, blue: 0.22),
                .warning: Color(red: 0.99, green: 0.75, blue: 0.30),
                .error: Color(red: 0.86, green: 0.50, blue: 0.54),
                .notice: Color(red: 0.51, green: 0.64, blue: 0.74),
                .debug: Color(red: 0.60, green: 0.64, blue: 0.80),
                .normal: Color(red: 0.65, green: 0.70, blue: 0.60)
            ])
        case .materialOcean:
            return ThemePalette(colors: [
                .primary: Color(red: 0.88, green: 0.91, blue: 0.95),
                .second: Color(red: 0.46, green: 0.36, blue: 0.24),
                .warning: Color(red: 0.98, green: 0.79, blue: 0.35),
                .error: Color(red: 0.82, green: 0.47, blue: 0.55),
                .notice: Color(red: 0.52, green: 0.75, blue: 0.88),
                .debug: Color(red: 0.60, green: 0.66, blue: 0.85),
                .normal: Color(red: 0.80, green: 0.84, blue: 0.88)
            ])
        case .nightOwl:
            return ThemePalette(colors: [
                .primary: Color(red: 0.89, green: 0.90, blue: 0.92),
                .second: Color(red: 0.50, green: 0.37, blue: 0.24),
                .warning: Color(red: 0.96, green: 0.78, blue: 0.36),
                .error: Color(red: 0.82, green: 0.46, blue: 0.54),
                .notice: Color(red: 0.48, green: 0.72, blue: 0.85),
                .debug: Color(red: 0.58, green: 0.62, blue: 0.83),
                .normal: Color(red: 0.78, green: 0.80, blue: 0.82)
            ])
        case .tomorrowNight:
            return ThemePalette(colors: [
                .primary: Color(red: 0.95, green: 0.95, blue: 0.95),
                .second: Color(red: 0.48, green: 0.36, blue: 0.24),
                .warning: Color(red: 0.98, green: 0.76, blue: 0.35),
                .error: Color(red: 0.80, green: 0.45, blue: 0.52),
                .notice: Color(red: 0.53, green: 0.77, blue: 0.88),
                .debug: Color(red: 0.64, green: 0.66, blue: 0.86),
                .normal: Color(red: 0.82, green: 0.82, blue: 0.82)
            ])
        case .cobalt2:
            return ThemePalette(colors: [
                .primary: Color(red: 0.92, green: 0.92, blue: 0.92),
                .second: Color(red: 0.47, green: 0.34, blue: 0.22),
                .warning: Color(red: 0.97, green: 0.78, blue: 0.38),
                .error: Color(red: 0.85, green: 0.46, blue: 0.54),
                .notice: Color(red: 0.51, green: 0.74, blue: 0.89),
                .debug: Color(red: 0.62, green: 0.64, blue: 0.86),
                .normal: Color(red: 0.80, green: 0.80, blue: 0.80)
            ])

        // MARK: Added text-focused palettes
        case .inkBlack:
            // 主文字黑色，强调巧克力路径、红黄蓝用于语义
            return ThemePalette(colors: [
                .primary: Color(red: 0.07, green: 0.07, blue: 0.07),   // 近黑
                .second: Color(red: 0.42, green: 0.24, blue: 0.09),    // 巧克力
                .warning: Color(red: 1.00, green: 0.84, blue: 0.30),   // 黄色
                .error: Color(red: 0.90, green: 0.33, blue: 0.31),     // 红色
                .notice: Color(red: 0.40, green: 0.67, blue: 0.84),    // 蓝青
                .debug: Color(red: 0.55, green: 0.55, blue: 0.80),
                .normal: Color(red: 0.55, green: 0.55, blue: 0.55)     // 中灰
            ])
        case .solarYellow:
            // 主文字偏黄，强调红/绿/巧克力对比
            return ThemePalette(colors: [
                .primary: Color(red: 1.00, green: 0.83, blue: 0.29),   // 亮黄
                .second: Color(red: 0.46, green: 0.32, blue: 0.19),    // 巧克力
                .warning: Color(red: 1.00, green: 0.76, blue: 0.26),   // 强黄
                .error: Color(red: 0.92, green: 0.33, blue: 0.31),     // 红
                .notice: Color(red: 0.45, green: 0.70, blue: 0.85),
                .debug: Color(red: 0.60, green: 0.62, blue: 0.85),
                .normal: Color(red: 0.80, green: 0.80, blue: 0.75)
            ])
        case .emberRed:
            // 主文字红色，适合警报流
            return ThemePalette(colors: [
                .primary: Color(red: 0.94, green: 0.33, blue: 0.31),   // 红
                .second: Color(red: 0.50, green: 0.35, blue: 0.20),    // 巧克力
                .warning: Color(red: 0.98, green: 0.78, blue: 0.34),
                .error: Color(red: 0.95, green: 0.35, blue: 0.33),
                .notice: Color(red: 0.52, green: 0.75, blue: 0.88),
                .debug: Color(red: 0.64, green: 0.66, blue: 0.86),
                .normal: Color(red: 0.85, green: 0.80, blue: 0.80)
            ])
        case .forestDarkGreen:
            // 主文字深绿色
            return ThemePalette(colors: [
                .primary: Color(red: 0.18, green: 0.49, blue: 0.20),   // 深绿
                .second: Color(red: 0.45, green: 0.33, blue: 0.22),    // 巧克力偏棕
                .warning: Color(red: 0.99, green: 0.76, blue: 0.38),
                .error: Color(red: 0.86, green: 0.45, blue: 0.52),
                .notice: Color(red: 0.45, green: 0.70, blue: 0.85),
                .debug: Color(red: 0.55, green: 0.60, blue: 0.80),
                .normal: Color(red: 0.78, green: 0.82, blue: 0.78)
            ])
        case .cocoaChocolate:
            // 主文字巧克力色
            return ThemePalette(colors: [
                .primary: Color(red: 0.42, green: 0.24, blue: 0.09),   // 巧克力
                .second: Color(red: 0.50, green: 0.35, blue: 0.20),    // 次级巧克力
                .warning: Color(red: 0.98, green: 0.78, blue: 0.34),
                .error: Color(red: 0.85, green: 0.40, blue: 0.45),
                .notice: Color(red: 0.49, green: 0.77, blue: 0.87),
                .debug: Color(red: 0.62, green: 0.64, blue: 0.86),
                .normal: Color(red: 0.82, green: 0.80, blue: 0.78)
            ])
        }
    }
}

// MARK: - Color Hex Helpers
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var rgba: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgba) else { return nil }
        switch s.count {
        case 8: // RRGGBBAA
            let r = Double((rgba & 0xFF000000) >> 24) / 255.0
            let g = Double((rgba & 0x00FF0000) >> 16) / 255.0
            let b = Double((rgba & 0x0000FF00) >> 8) / 255.0
            let a = Double(rgba & 0x000000FF) / 255.0
            self = Color(red: r, green: g, blue: b).opacity(a)
        case 6: // RRGGBB
            let r = Double((rgba & 0xFF0000) >> 16) / 255.0
            let g = Double((rgba & 0x00FF00) >> 8) / 255.0
            let b = Double(rgba & 0x0000FF) / 255.0
            self = Color(red: r, green: g, blue: b)
        default:
            return nil
        }
    }

    func toHex(alpha: Bool = false) -> String {
        let ui = NSColor(self)
        let rgb = ui.usingColorSpace(.deviceRGB) ?? ui
        let r = Int((rgb.redComponent * 255.0).rounded())
        let g = Int((rgb.greenComponent * 255.0).rounded())
        let b = Int((rgb.blueComponent * 255.0).rounded())
        let a = Int((rgb.alphaComponent * 255.0).rounded())
        if alpha { return String(format: "#%02X%02X%02X%02X", r, g, b, a) }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Contrast helpers
extension NSColor {
    var relativeLuminance: CGFloat {
        let rgb = self.usingColorSpace(.deviceRGB) ?? self
        func channel(_ c: CGFloat) -> CGFloat {
            return (c <= 0.03928) ? (c/12.92) : pow((c+0.055)/1.055, 2.4)
        }
        let r = channel(rgb.redComponent)
        let g = channel(rgb.greenComponent)
        let b = channel(rgb.blueComponent)
        return 0.2126*r + 0.7152*g + 0.0722*b
    }
}

extension Color {
    #if os(macOS)
    func asNSColor() -> NSColor { NSColor(self) }
    #endif
}

func adaptiveOnBackground(foreground: Color, background: Color) -> Color {
    #if os(macOS)
    let fg = foreground.asNSColor()
    let bg = background.asNSColor()
    let l1 = fg.relativeLuminance
    let l2 = bg.relativeLuminance
    let lighter = max(l1, l2) + 0.05
    let darker  = min(l1, l2) + 0.05
    let ratio = lighter / darker
    if ratio >= 4.5 { return foreground }
    // choose black or white based on background luminance
    return (l2 > 0.5) ? Color.black : Color.white
    #else
    return foreground
    #endif
}


