import UIKit

/// Renders soft, painterly placeholder "photographs" for the sample life. They are deliberately
/// abstract — gradients, horizons, light — so they read as memories rather than stock photos.
enum SampleScene: String, CaseIterable {
    case downsMorning, downsEvening, downsRain
    case harbourDusk, harbourEvening, harbourGold
    case trainWindow
    case kitchenTable, kitchenMorning
    case coastBright, seaMorning, coastRocks
    case gardenSummer

    var isPortrait: Bool {
        switch self {
        case .trainWindow, .kitchenMorning, .coastRocks: return true
        default: return false
        }
    }
}

enum SampleImageRenderer {
    static func render(_ scene: SampleScene) -> UIImage {
        let size = scene.isPortrait ? CGSize(width: 900, height: 1200) : CGSize(width: 1200, height: 900)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            draw(scene, in: rect, cg: cg)
            grain(in: rect, cg: cg, seed: Int(truncatingIfNeeded: StableHash.fnv1a(scene.rawValue) % 1_000_000))
        }
    }

    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1).cgColor
    }

    private static func gradient(_ colors: [CGColor], in rect: CGRect, cg: CGContext, vertical: Bool = true) {
        let space = CGColorSpaceCreateDeviceRGB()
        let locations = (0..<colors.count).map { CGFloat($0) / CGFloat(max(1, colors.count - 1)) }
        guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations) else { return }
        cg.saveGState()
        cg.clip(to: rect)
        let start = vertical ? CGPoint(x: rect.midX, y: rect.minY) : CGPoint(x: rect.minX, y: rect.midY)
        let end = vertical ? CGPoint(x: rect.midX, y: rect.maxY) : CGPoint(x: rect.maxX, y: rect.midY)
        cg.drawLinearGradient(gradient, start: start, end: end, options: [])
        cg.restoreGState()
    }

    private static func glow(at center: CGPoint, radius: CGFloat, color: UIColor, cg: CGContext) {
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
        cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    private static func hills(in rect: CGRect, baseline: CGFloat, amplitude: CGFloat, color: CGColor, cg: CGContext, phase: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = 40
        for i in 0...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let t = CGFloat(i) / CGFloat(steps)
            let y = baseline + sin(t * 3.1 + phase) * amplitude + sin(t * 7.3 + phase * 2) * amplitude * 0.3
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        cg.setFillColor(color)
        cg.addPath(path)
        cg.fillPath()
    }

    private static func reflections(in rect: CGRect, from y: CGFloat, color: UIColor, cg: CGContext, seed: Int) {
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: seed))
        for _ in 0..<70 {
            let x = CGFloat.random(in: rect.minX...rect.maxX, using: &generator)
            let w = CGFloat.random(in: 20...110, using: &generator)
            let yy = CGFloat.random(in: y...(rect.maxY), using: &generator)
            let alpha = CGFloat.random(in: 0.05...0.22, using: &generator)
            cg.setFillColor(color.withAlphaComponent(alpha).cgColor)
            cg.fill(CGRect(x: x, y: yy, width: w, height: 3))
        }
    }

    private static func boats(in rect: CGRect, at y: CGFloat, color: CGColor, cg: CGContext, seed: Int) {
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: seed) &+ 11)
        cg.setFillColor(color)
        for _ in 0..<5 {
            let x = CGFloat.random(in: rect.minX + 60...rect.maxX - 120, using: &generator)
            let w = CGFloat.random(in: 50...90, using: &generator)
            cg.fill(CGRect(x: x, y: y - 10, width: w, height: 12))
            cg.fill(CGRect(x: x + w * 0.45, y: y - 60, width: 3, height: 52))
        }
    }

    private static func grain(in rect: CGRect, cg: CGContext, seed: Int) {
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: seed) &+ 99)
        for _ in 0..<6000 {
            let x = CGFloat.random(in: rect.minX...rect.maxX, using: &generator)
            let y = CGFloat.random(in: rect.minY...rect.maxY, using: &generator)
            let dark = Bool.random(using: &generator)
            cg.setFillColor((dark ? UIColor.black : UIColor.white).withAlphaComponent(0.035).cgColor)
            cg.fill(CGRect(x: x, y: y, width: 2.5, height: 2.5))
        }
        // Soft vignette
        let space = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: space, colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.16).cgColor] as CFArray, locations: [0.6, 1]) {
            cg.drawRadialGradient(gradient, startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: max(rect.width, rect.height) * 0.75, options: [])
        }
    }

    private static func draw(_ scene: SampleScene, in rect: CGRect, cg: CGContext) {
        let w = rect.width, h = rect.height
        switch scene {
        case .downsMorning:
            gradient([color(214, 222, 228), color(236, 232, 220), color(201, 206, 186)], in: rect, cg: cg)
            glow(at: CGPoint(x: w * 0.7, y: h * 0.28), radius: w * 0.5, color: UIColor(white: 1, alpha: 0.55), cg: cg)
            hills(in: rect, baseline: h * 0.62, amplitude: 28, color: color(166, 176, 150), cg: cg, phase: 0.4)
            hills(in: rect, baseline: h * 0.72, amplitude: 22, color: color(132, 146, 118), cg: cg, phase: 2.1)
            gradient([UIColor(white: 1, alpha: 0.0).cgColor, UIColor(white: 1, alpha: 0.35).cgColor], in: CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45), cg: cg)
        case .downsEvening:
            gradient([color(92, 88, 128), color(196, 140, 120), color(236, 196, 150)], in: rect, cg: cg)
            glow(at: CGPoint(x: w * 0.3, y: h * 0.58), radius: w * 0.35, color: UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 0.7), cg: cg)
            hills(in: rect, baseline: h * 0.66, amplitude: 30, color: color(78, 72, 76), cg: cg, phase: 1.0)
            hills(in: rect, baseline: h * 0.78, amplitude: 18, color: color(52, 48, 54), cg: cg, phase: 3.2)
        case .downsRain:
            gradient([color(120, 126, 134), color(160, 164, 166), color(140, 148, 140)], in: rect, cg: cg)
            hills(in: rect, baseline: h * 0.64, amplitude: 26, color: color(104, 116, 100), cg: cg, phase: 0.9)
            hills(in: rect, baseline: h * 0.76, amplitude: 20, color: color(82, 92, 80), cg: cg, phase: 2.6)
            var generator = SeededGenerator(seed: 5)
            cg.setStrokeColor(UIColor(white: 1, alpha: 0.12).cgColor)
            cg.setLineWidth(1.5)
            for _ in 0..<160 {
                let x = CGFloat.random(in: 0...w, using: &generator)
                let y = CGFloat.random(in: 0...h, using: &generator)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x - 14, y: y + 44))
            }
            cg.strokePath()
        case .harbourDusk:
            gradient([color(70, 72, 110), color(190, 120, 110), color(240, 180, 130)], in: CGRect(x: 0, y: 0, width: w, height: h * 0.55), cg: cg)
            gradient([color(74, 70, 92), color(38, 36, 54)], in: CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45), cg: cg)
            glow(at: CGPoint(x: w * 0.62, y: h * 0.5), radius: w * 0.3, color: UIColor(red: 1, green: 0.78, blue: 0.55, alpha: 0.6), cg: cg)
            cg.setFillColor(color(44, 42, 60))
            cg.fill(CGRect(x: 0, y: h * 0.47, width: w, height: h * 0.08))
            boats(in: rect, at: h * 0.56, color: color(28, 26, 40), cg: cg, seed: 3)
            reflections(in: rect, from: h * 0.58, color: UIColor(red: 1, green: 0.8, blue: 0.6, alpha: 1), cg: cg, seed: 3)
        case .harbourEvening:
            gradient([color(150, 170, 200), color(230, 210, 190), color(240, 200, 160)], in: CGRect(x: 0, y: 0, width: w, height: h * 0.56), cg: cg)
            gradient([color(90, 110, 130), color(50, 62, 80)], in: CGRect(x: 0, y: h * 0.56, width: w, height: h * 0.44), cg: cg)
            glow(at: CGPoint(x: w * 0.25, y: h * 0.42), radius: w * 0.28, color: UIColor(white: 1, alpha: 0.5), cg: cg)
            cg.setFillColor(color(66, 72, 86))
            cg.fill(CGRect(x: 0, y: h * 0.50, width: w, height: h * 0.06))
            boats(in: rect, at: h * 0.57, color: color(40, 44, 56), cg: cg, seed: 7)
            reflections(in: rect, from: h * 0.6, color: UIColor(white: 1, alpha: 1), cg: cg, seed: 7)
        case .harbourGold:
            gradient([color(240, 190, 120), color(250, 220, 160), color(230, 170, 110)], in: CGRect(x: 0, y: 0, width: w, height: h * 0.55), cg: cg)
            gradient([color(190, 130, 80), color(80, 60, 50)], in: CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45), cg: cg)
            glow(at: CGPoint(x: w * 0.5, y: h * 0.52), radius: w * 0.4, color: UIColor(red: 1, green: 0.93, blue: 0.7, alpha: 0.9), cg: cg)
            cg.setFillColor(color(110, 80, 60))
            cg.fill(CGRect(x: 0, y: h * 0.49, width: w, height: h * 0.06))
            boats(in: rect, at: h * 0.56, color: color(60, 42, 36), cg: cg, seed: 9)
            reflections(in: rect, from: h * 0.58, color: UIColor(red: 1, green: 0.9, blue: 0.6, alpha: 1), cg: cg, seed: 9)
        case .trainWindow:
            gradient([color(150, 158, 166), color(176, 182, 184), color(120, 132, 120)], in: rect, cg: cg)
            hills(in: rect, baseline: h * 0.6, amplitude: 24, color: color(98, 112, 96), cg: cg, phase: 0.2)
            hills(in: rect, baseline: h * 0.7, amplitude: 18, color: color(70, 84, 72), cg: cg, phase: 1.7)
            cg.setFillColor(color(30, 30, 34))
            cg.fill(CGRect(x: 0, y: 0, width: w * 0.08, height: h))
            cg.fill(CGRect(x: w * 0.92, y: 0, width: w * 0.08, height: h))
            var generator = SeededGenerator(seed: 21)
            for _ in 0..<180 {
                let x = CGFloat.random(in: 0...w, using: &generator)
                let y = CGFloat.random(in: 0...h, using: &generator)
                let r = CGFloat.random(in: 2...6, using: &generator)
                cg.setFillColor(UIColor(white: 1, alpha: 0.28).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r * 1.6))
            }
        case .kitchenTable:
            gradient([color(232, 220, 200), color(214, 196, 170)], in: rect, cg: cg)
            glow(at: CGPoint(x: w * 0.78, y: h * 0.2), radius: w * 0.5, color: UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 0.8), cg: cg)
            cg.setFillColor(color(150, 112, 80))
            cg.fill(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42))
            gradient([UIColor(white: 0, alpha: 0.0).cgColor, UIColor(white: 0, alpha: 0.2).cgColor], in: CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42), cg: cg)
            cg.setFillColor(color(196, 140, 86))
            cg.fillEllipse(in: CGRect(x: w * 0.3, y: h * 0.5, width: w * 0.4, height: h * 0.22))
            cg.setFillColor(color(226, 180, 120))
            cg.fillEllipse(in: CGRect(x: w * 0.34, y: h * 0.5, width: w * 0.32, height: h * 0.16))
            cg.setFillColor(color(240, 234, 222))
            cg.fillEllipse(in: CGRect(x: w * 0.08, y: h * 0.62, width: w * 0.16, height: h * 0.09))
        case .kitchenMorning:
            gradient([color(246, 240, 226), color(230, 214, 190)], in: rect, cg: cg)
            glow(at: CGPoint(x: w * 0.5, y: h * 0.18), radius: w * 0.7, color: UIColor(white: 1, alpha: 0.9), cg: cg)
            cg.setFillColor(UIColor(white: 1, alpha: 0.5).cgColor)
            cg.fill(CGRect(x: w * 0.2, y: h * 0.06, width: w * 0.6, height: h * 0.42))
            cg.setFillColor(color(170, 130, 96))
            cg.fill(CGRect(x: 0, y: h * 0.66, width: w, height: h * 0.34))
            cg.setFillColor(color(120, 140, 110))
            cg.fillEllipse(in: CGRect(x: w * 0.6, y: h * 0.46, width: w * 0.3, height: h * 0.18))
            cg.setFillColor(color(222, 200, 170))
            cg.fill(CGRect(x: w * 0.68, y: h * 0.58, width: w * 0.14, height: h * 0.1))
        case .coastBright:
            gradient([color(130, 180, 220), color(190, 220, 240)], in: CGRect(x: 0, y: 0, width: w, height: h * 0.5), cg: cg)
            gradient([color(40, 150, 170), color(90, 190, 190), color(190, 220, 200)], in: CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.3), cg: cg)
            gradient([color(236, 222, 190), color(222, 204, 170)], in: CGRect(x: 0, y: h * 0.8, width: w, height: h * 0.2), cg: cg)
            glow(at: CGPoint(x: w * 0.8, y: h * 0.15), radius: w * 0.4, color: UIColor(white: 1, alpha: 0.7), cg: cg)
            reflections(in: CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.3), from: h * 0.55, color: .white, cg: cg, seed: 13)
        case .seaMorning:
            gradient([color(200, 206, 214), color(226, 222, 214)], in: CGRect(x: 0, y: 0, width: w, height: h * 0.52), cg: cg)
            gradient([color(130, 160, 170), color(170, 190, 190)], in: CGRect(x: 0, y: h * 0.52, width: w, height: h * 0.48), cg: cg)
            glow(at: CGPoint(x: w * 0.5, y: h * 0.5), radius: w * 0.45, color: UIColor(red: 1, green: 0.9, blue: 0.75, alpha: 0.55), cg: cg)
            reflections(in: rect, from: h * 0.55, color: .white, cg: cg, seed: 17)
        case .coastRocks:
            gradient([color(120, 170, 210), color(190, 215, 230)], in: CGRect(x: 0, y: 0, width: w, height: h * 0.45), cg: cg)
            gradient([color(50, 140, 160), color(120, 190, 190)], in: CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.3), cg: cg)
            hills(in: rect, baseline: h * 0.78, amplitude: 36, color: color(96, 88, 84), cg: cg, phase: 0.6)
            hills(in: rect, baseline: h * 0.86, amplitude: 24, color: color(66, 60, 58), cg: cg, phase: 2.9)
            reflections(in: CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.3), from: h * 0.5, color: .white, cg: cg, seed: 19)
        case .gardenSummer:
            gradient([color(196, 214, 230), color(226, 230, 214)], in: CGRect(x: 0, y: 0, width: w, height: h * 0.4), cg: cg)
            gradient([color(110, 150, 90), color(80, 120, 70)], in: CGRect(x: 0, y: h * 0.4, width: w, height: h * 0.6), cg: cg)
            glow(at: CGPoint(x: w * 0.2, y: h * 0.2), radius: w * 0.5, color: UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 0.7), cg: cg)
            var generator = SeededGenerator(seed: 23)
            for _ in 0..<60 {
                let x = CGFloat.random(in: 0...w, using: &generator)
                let y = CGFloat.random(in: h * 0.45...h, using: &generator)
                let r = CGFloat.random(in: 10...28, using: &generator)
                let pink = CGFloat.random(in: 0.6...1.0, using: &generator)
                cg.setFillColor(UIColor(red: 0.9, green: 0.45 * pink, blue: 0.5 * pink, alpha: 0.85).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }
}
