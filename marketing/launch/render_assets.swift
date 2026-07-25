import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetDirectory = root.appendingPathComponent("marketing/launch/assets", isDirectory: true)
let keyboardURL = assetDirectory.appendingPathComponent("keyboard-enter-source.png")
let iconURL = root.appendingPathComponent("UniEnter/Assets.xcassets/AppIcon.appiconset/icon_1024.png")
let imeURL = root.appendingPathComponent("site/public/assets/feature-ime.png")

let ink = NSColor(calibratedRed: 55 / 255, green: 53 / 255, blue: 47 / 255, alpha: 1)
let muted = NSColor(calibratedRed: 115 / 255, green: 114 / 255, blue: 110 / 255, alpha: 1)
let paper = NSColor(calibratedRed: 247 / 255, green: 247 / 255, blue: 245 / 255, alpha: 1)
let line = NSColor(calibratedRed: 230 / 255, green: 230 / 255, blue: 228 / 255, alpha: 1)
let newlineGreen = NSColor(calibratedRed: 15 / 255, green: 123 / 255, blue: 108 / 255, alpha: 1)
let sendBlue = NSColor(calibratedRed: 35 / 255, green: 131 / 255, blue: 226 / 255, alpha: 1)

struct Canvas {
    let width: CGFloat
    let height: CGFloat
    let bitmap: NSBitmapImageRep
    let context: NSGraphicsContext

    init(width: Int, height: Int) {
        self.width = CGFloat(width)
        self.height = CGFloat(height)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Could not create bitmap canvas")
        }
        bitmap.size = NSSize(width: width, height: height)
        self.bitmap = bitmap
        self.context = context
    }

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: x, y: self.height - y - height, width: width, height: height)
    }

    func save(_ filename: String) {
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode \(filename)")
        }
        let destination = assetDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: destination)
            print("Rendered \(destination.path)")
        } catch {
            fatalError("Could not write \(destination.path): \(error)")
        }
    }
}

func withCanvas(width: Int, height: Int, draw: (Canvas) -> Void) -> Canvas {
    let canvas = Canvas(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = canvas.context
    canvas.context.imageInterpolation = .high
    draw(canvas)
    canvas.context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return canvas
}

func fill(_ color: NSColor, in rect: NSRect) {
    color.setFill()
    rect.fill()
}

func roundedFill(_ color: NSColor, in rect: NSRect, radius: CGFloat) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func roundedStroke(_ color: NSColor, in rect: NSRect, radius: CGFloat, width: CGFloat = 2) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

func hexColor(_ hex: String) -> NSColor {
    var value: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&value)
    return NSColor(
        calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
}

func drawImage(
    _ image: NSImage,
    aspectFill rect: NSRect,
    radius: CGFloat = 0,
    horizontalAlignment: CGFloat = 0.5
) {
    let sourceSize = image.size
    let scale = max(rect.width / sourceSize.width, rect.height / sourceSize.height)
    let destinationSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let destination = NSRect(
        x: rect.minX - (destinationSize.width - rect.width) * horizontalAlignment,
        y: rect.midY - destinationSize.height / 2,
        width: destinationSize.width,
        height: destinationSize.height
    )

    NSGraphicsContext.saveGraphicsState()
    if radius > 0 {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    } else {
        NSBezierPath(rect: rect).addClip()
    }
    image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func paragraph(alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineSpacing = lineSpacing
    style.lineBreakMode = .byWordWrapping
    return style
}

func drawText(
    _ text: String,
    in rect: NSRect,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = ink,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 0
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment: alignment, lineSpacing: lineSpacing),
    ]
    NSAttributedString(string: text, attributes: attributes).draw(in: rect)
}

func drawCenteredText(
    _ text: String,
    in rect: NSRect,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = ink
) {
    let style = paragraph(alignment: .center)
    let attributed = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ])
    let textSize = attributed.size()
    let destination = NSRect(
        x: rect.minX,
        y: rect.midY - textSize.height / 2,
        width: rect.width,
        height: textSize.height + 4
    )
    attributed.draw(in: destination)
}

func drawPill(_ text: String, in rect: NSRect, fillColor: NSColor = NSColor.white.withAlphaComponent(0.82), textColor: NSColor = muted) {
    roundedFill(fillColor, in: rect, radius: rect.height / 2)
    drawCenteredText(text, in: rect, size: 20, weight: .medium, color: textColor)
}

func drawKey(_ label: String, in rect: NSRect, width: CGFloat? = nil) {
    let keyRect = width.map { NSRect(x: rect.midX - $0 / 2, y: rect.minY, width: $0, height: rect.height) } ?? rect
    roundedFill(NSColor.black.withAlphaComponent(0.10), in: keyRect.offsetBy(dx: 0, dy: -8), radius: 18)
    roundedFill(NSColor(calibratedWhite: 0.99, alpha: 1), in: keyRect, radius: 18)
    roundedStroke(NSColor(calibratedWhite: 0.82, alpha: 1), in: keyRect, radius: 18, width: 2)
    drawCenteredText(label, in: keyRect, size: label == "⌘" ? 40 : 32, weight: .semibold)
}

func drawBrand(icon: NSImage, canvas: Canvas, x: CGFloat, y: CGFloat, iconSize: CGFloat, dark: Bool = false) {
    let iconRect = canvas.rect(x, y, iconSize, iconSize)
    icon.draw(in: iconRect)
    drawText(
        "UniEnter",
        in: canvas.rect(x + iconSize + 18, y + 7, 280, iconSize - 10),
        size: iconSize * 0.42,
        weight: .bold,
        color: dark ? .white : ink
    )
}

guard let keyboard = NSImage(contentsOf: keyboardURL),
      let icon = NSImage(contentsOf: iconURL),
      let ime = NSImage(contentsOf: imeURL) else {
    fatalError("Required source image is missing")
}

// 1. Main launch image: a three-panel composition modeled on the reference post.
let main = withCanvas(width: 1600, height: 900) { c in
    fill(NSColor(calibratedWhite: 0.93, alpha: 1), in: c.rect(0, 0, 1600, 900))

    let left = c.rect(24, 24, 930, 852)
    roundedFill(NSColor.white, in: left, radius: 32)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: left, radius: 32, width: 2)

    drawPill("macOS用メニューバーアプリ", in: c.rect(72, 68, 300, 46), fillColor: paper)
    drawText(
        "どのアプリでも、\n改行と送信を統一。",
        in: c.rect(70, 148, 810, 176),
        size: 62,
        weight: .bold,
        lineSpacing: 6
    )
    drawText(
        "Enterはいつでも改行、送信は⌘Enter。",
        in: c.rect(74, 352, 760, 48),
        size: 27,
        weight: .semibold,
        color: ink
    )
    drawBrand(icon: icon, canvas: c, x: 72, y: 414, iconSize: 58)

    let keyboardPhoto = c.rect(48, 500, 882, 348)
    drawImage(keyboard, aspectFill: keyboardPhoto, radius: 24, horizontalAlignment: 1)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: keyboardPhoto, radius: 24, width: 2)

    let topRight = c.rect(978, 24, 598, 414)
    roundedFill(NSColor.white, in: topRight, radius: 32)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: topRight, radius: 32, width: 2)
    drawText("操作は、これだけ。", in: c.rect(1024, 64, 510, 54), size: 37, weight: .bold)

    drawKey("Enter", in: c.rect(1028, 154, 172, 78))
    drawCenteredText("→", in: c.rect(1216, 154, 62, 78), size: 34, color: muted)
    drawText("改行", in: c.rect(1290, 164, 180, 65), size: 43, weight: .bold, color: newlineGreen)

    drawKey("⌘", in: c.rect(1028, 280, 84, 78))
    drawCenteredText("+", in: c.rect(1120, 280, 42, 78), size: 30, color: muted)
    drawKey("Enter", in: c.rect(1168, 280, 172, 78))
    drawCenteredText("→", in: c.rect(1352, 280, 55, 78), size: 34, color: muted)
    drawText("送信", in: c.rect(1412, 290, 130, 65), size: 43, weight: .bold, color: sendBlue)

    // 対応アプリ: LP(brands.tsx)と同じ表現。simple-icons収録分は公式ロゴ、
    // 未収録(Slack/Teams/ChatGPT)はブランドカラーの頭文字タイル。
    let bottomRight = c.rect(978, 462, 598, 414)
    roundedFill(NSColor.white, in: bottomRight, radius: 32)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: bottomRight, radius: 32, width: 2)
    drawText("対応アプリ", in: c.rect(1024, 498, 220, 50), size: 34, weight: .bold)
    drawText(
        "アプリでも、ブラウザでも。",
        in: c.rect(1230, 514, 306, 30),
        size: 19,
        weight: .medium,
        color: muted,
        alignment: .right
    )

    // Slack/Teams/ChatGPT(OpenAI)は現行simple-iconsから削除済みのため、
    // 削除前の simple-icons v8.15.0 のパスデータをラスタライズして使用(商標は各社に帰属)。
    let tiles: [(name: String, hex: String, icon: String?, initial: String?)] = [
        ("Slack", "4A154B", "slack", nil),
        ("Teams", "6264A7", "teams", nil),
        ("LINE", "00C300", "line", nil),
        ("ChatGPT", "10A37F", "chatgpt", nil),
        ("Discord", "5865F2", "discord", nil),
        ("Claude", "D97757", "claude", nil),
        ("Gemini", "8E75B2", "gemini", nil),
        ("X(DM)", "000000", "x", nil),
    ]
    let gridLeft: CGFloat = 1016
    let colWidth: CGFloat = 522.0 / 4.0
    for (index, tile) in tiles.enumerated() {
        let col = CGFloat(index % 4)
        let row = CGFloat(index / 4)
        let centerX = gridLeft + colWidth * col + colWidth / 2
        let tileTop: CGFloat = 576 + row * 132
        let tileRect = c.rect(centerX - 31, tileTop, 62, 62)
        roundedFill(hexColor(tile.hex), in: tileRect, radius: 16)
        if let iconName = tile.icon {
            // PNGはsimple-iconsのパスをブラウザCanvasでラスタライズしたもの(288px・白)。
            // CoreSVG(NSImageのSVG読み込み)はsimple-iconsのパスを正しく描画できないことがある。
            let iconURL = assetDirectory.appendingPathComponent("icons/\(iconName).png")
            if let iconImage = NSImage(contentsOf: iconURL) {
                let iconRect = c.rect(centerX - 18, tileTop + 13, 36, 36)
                iconImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
            }
        } else if let initial = tile.initial {
            drawCenteredText(initial, in: tileRect, size: 30, weight: .bold, color: .white)
        }
        drawText(
            tile.name,
            in: c.rect(centerX - colWidth / 2, tileTop + 70, colWidth, 26),
            size: 16,
            weight: .medium,
            color: ink,
            alignment: .center
        )
    }

    drawText(
        "ほか、Messenger・InstagramのDMにも対応",
        in: c.rect(1016, 826, 522, 28),
        size: 17,
        weight: .medium,
        color: muted,
        alignment: .center
    )
}
main.save("x-launch-main-1600x900.png")

// 2. Standalone explanation image for a reply or quote-post.
let how = withCanvas(width: 1600, height: 900) { c in
    fill(paper, in: c.rect(0, 0, 1600, 900))
    drawBrand(icon: icon, canvas: c, x: 72, y: 56, iconSize: 58)
    drawPill("macOS用メニューバーアプリ", in: c.rect(1116, 62, 402, 48), fillColor: NSColor.white, textColor: muted)

    drawText(
        "どのアプリでも、\n改行と送信を統一。",
        in: c.rect(120, 180, 1360, 190),
        size: 68,
        weight: .bold,
        alignment: .center,
        lineSpacing: 5
    )

    let first = c.rect(120, 442, 640, 224)
    roundedFill(.white, in: first, radius: 28)
    roundedStroke(line, in: first, radius: 28)
    drawKey("Enter", in: c.rect(180, 512, 218, 88))
    drawCenteredText("→", in: c.rect(428, 512, 80, 88), size: 42, color: muted)
    drawText("改行", in: c.rect(526, 520, 190, 70), size: 54, weight: .bold, color: newlineGreen)

    let second = c.rect(840, 442, 640, 224)
    roundedFill(.white, in: second, radius: 28)
    roundedStroke(line, in: second, radius: 28)
    drawKey("⌘", in: c.rect(890, 512, 94, 88))
    drawCenteredText("+", in: c.rect(994, 512, 52, 88), size: 38, color: muted)
    drawKey("Enter", in: c.rect(1056, 512, 204, 88))
    drawCenteredText("→", in: c.rect(1272, 512, 68, 88), size: 42, color: muted)
    drawText("送信", in: c.rect(1350, 520, 120, 70), size: 54, weight: .bold, color: sendBlue)

    drawText(
        "Slack・Teams・Discord・LINE・ChatGPT・Claude・Gemini・X / InstagramのDM",
        in: c.rect(110, 732, 1380, 42),
        size: 25,
        weight: .medium,
        color: ink,
        alignment: .center
    )
    drawText(
        "アプリでも、Safari / Chrome / Edge / Arcのブラウザでも。",
        in: c.rect(140, 792, 1320, 36),
        size: 22,
        color: muted,
        alignment: .center
    )
}
how.save("x-launch-how-1600x900.png")

// 3. Safety message image focused on Japanese IME behavior and privacy.
let safety = withCanvas(width: 1600, height: 900) { c in
    fill(paper, in: c.rect(0, 0, 1600, 900))
    let photo = c.rect(24, 24, 708, 852)
    drawImage(ime, aspectFill: photo, radius: 32)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: photo, radius: 32)

    drawBrand(icon: icon, canvas: c, x: 792, y: 68, iconSize: 56)
    drawText(
        "日本語入力に、\nとことん安全。",
        in: c.rect(792, 182, 720, 180),
        size: 66,
        weight: .bold,
        lineSpacing: 4
    )
    drawText(
        "変換確定のEnterは、書き換えません。",
        in: c.rect(796, 390, 710, 48),
        size: 29,
        weight: .semibold,
        color: newlineGreen
    )

    let items = [
        "変換中のEnterは、そのまま確定",
        "判定に迷ったら「何もしない」",
        "入力内容を読まない・外部送信なし",
    ]
    for (index, item) in items.enumerated() {
        let y = CGFloat(500 + index * 94)
        roundedFill(index == 2 ? sendBlue : newlineGreen, in: c.rect(798, y + 4, 42, 42), radius: 21)
        drawCenteredText("✓", in: c.rect(798, y + 3, 42, 42), size: 23, weight: .bold, color: .white)
        drawText(item, in: c.rect(864, y, 640, 54), size: 29, weight: .medium)
    }

    drawText(
        "必要な権限はアクセシビリティのみ",
        in: c.rect(798, 804, 680, 36),
        size: 21,
        color: muted
    )
}
safety.save("x-launch-safety-1600x900.png")

// 4. Square variant for mobile-heavy timelines and other social networks.
let square = withCanvas(width: 1200, height: 1200) { c in
    fill(paper, in: c.rect(0, 0, 1200, 1200))
    let plate = c.rect(28, 28, 1144, 566)
    roundedFill(NSColor.white, in: plate, radius: 38)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: plate, radius: 38, width: 2)
    drawBrand(icon: icon, canvas: c, x: 126, y: 122, iconSize: 66)
    drawText(
        "どのアプリでも、\n改行と送信を統一。",
        in: c.rect(122, 250, 820, 210),
        size: 66,
        weight: .bold,
        lineSpacing: 10
    )
    drawText(
        "Enterはいつでも改行、送信は⌘Enter。",
        in: c.rect(126, 508, 780, 50),
        size: 28,
        weight: .semibold,
        color: muted
    )

    let photo = c.rect(28, 628, 1144, 544)
    drawImage(keyboard, aspectFill: photo, radius: 38, horizontalAlignment: 1)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: photo, radius: 38, width: 2)
}
square.save("x-launch-square-1200x1200.png")

// 5. Link-card candidate. Kept outside site/public so it can be reviewed before wiring.
let og = withCanvas(width: 1200, height: 630) { c in
    fill(.white, in: c.rect(0, 0, 1200, 630))
    let photoPanel = c.rect(704, 30, 466, 570)
    roundedFill(paper, in: photoPanel, radius: 30)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: photoPanel, radius: 30, width: 2)
    let right = c.rect(728, 158, 418, 236)
    drawImage(keyboard, aspectFill: right, radius: 22, horizontalAlignment: 1)
    roundedStroke(NSColor.black.withAlphaComponent(0.08), in: right, radius: 22, width: 2)
    drawText(
        "Enter → 改行",
        in: c.rect(736, 440, 400, 38),
        size: 24,
        weight: .bold,
        color: newlineGreen,
        alignment: .center
    )
    drawText(
        "⌘Enter → 送信",
        in: c.rect(736, 492, 400, 38),
        size: 24,
        weight: .bold,
        color: sendBlue,
        alignment: .center
    )

    drawBrand(icon: icon, canvas: c, x: 68, y: 58, iconSize: 60)
    drawText(
        "どのアプリでも、\n改行と送信を統一。",
        in: c.rect(66, 196, 690, 152),
        size: 56,
        weight: .bold,
        lineSpacing: 6
    )
    drawText(
        "Enterはいつでも改行、送信は⌘Enter。",
        in: c.rect(70, 400, 650, 45),
        size: 27,
        weight: .medium,
        color: muted
    )
    drawPill("macOS 13以降・14日間無料", in: c.rect(66, 506, 372, 50), fillColor: paper, textColor: ink)
}
og.save("og-link-card-1200x630.png")
