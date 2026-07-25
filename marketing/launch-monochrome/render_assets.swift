import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("marketing/launch-monochrome/assets", isDirectory: true)
let textureURL = assets.appendingPathComponent("paper-background-grayscale.png")

let black = NSColor(calibratedWhite: 0.06, alpha: 1)
let charcoal = NSColor(calibratedWhite: 0.17, alpha: 1)
let gray = NSColor(calibratedWhite: 0.46, alpha: 1)
let midGray = NSColor(calibratedWhite: 0.72, alpha: 1)
let line = NSColor(calibratedWhite: 0.88, alpha: 1)
let paper = NSColor(calibratedWhite: 0.965, alpha: 1)
let white = NSColor.white

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
        let destination = assets.appendingPathComponent(filename)
        try! data.write(to: destination)
        print("Rendered \(destination.path)")
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

func drawImage(_ image: NSImage, aspectFill rect: NSRect, radius: CGFloat = 0) {
    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
    let destinationSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let destination = NSRect(
        x: rect.midX - destinationSize.width / 2,
        y: rect.midY - destinationSize.height / 2,
        width: destinationSize.width,
        height: destinationSize.height
    )
    NSGraphicsContext.saveGraphicsState()
    let clip = radius > 0 ? NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius) : NSBezierPath(rect: rect)
    clip.addClip()
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
    color: NSColor = black,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 0
) {
    NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment: alignment, lineSpacing: lineSpacing),
    ]).draw(in: rect)
}

func drawCenteredText(
    _ text: String,
    in rect: NSRect,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = black
) {
    let value = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment: .center),
    ])
    let measured = value.size()
    value.draw(in: NSRect(x: rect.minX, y: rect.midY - measured.height / 2, width: rect.width, height: measured.height + 5))
}

func drawWordmark(canvas: Canvas, x: CGFloat, y: CGFloat, dark: Bool = false, size: CGFloat = 30) {
    let color = dark ? white : black
    drawText("↵", in: canvas.rect(x, y - 5, size * 1.35, size * 1.4), size: size * 1.18, weight: .bold, color: color)
    drawText("UniEnter", in: canvas.rect(x + size * 1.38, y, 260, size * 1.4), size: size, weight: .bold, color: color)
}

func drawPill(_ text: String, canvas: Canvas, x: CGFloat, y: CGFloat, width: CGFloat, dark: Bool = false) {
    let rect = canvas.rect(x, y, width, 48)
    roundedFill(dark ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor(calibratedWhite: 0.92, alpha: 1), in: rect, radius: 24)
    drawCenteredText(text, in: rect, size: 19, weight: .medium, color: dark ? midGray : gray)
}

func drawChatCard(canvas: Canvas, x: CGFloat, label: String, person: String) {
    let card = canvas.rect(x, 272, 420, 438)
    roundedFill(white, in: card, radius: 28)
    roundedStroke(line, in: card, radius: 28, width: 2)

    drawText(label, in: canvas.rect(x + 30, 300, 330, 40), size: 24, weight: .bold)
    fill(line, in: canvas.rect(x + 30, 350, 360, 2))

    roundedFill(NSColor(calibratedWhite: 0.88, alpha: 1), in: canvas.rect(x + 30, 388, 44, 44), radius: 22)
    drawText(person, in: canvas.rect(x + 92, 392, 260, 32), size: 18, weight: .semibold)
    roundedFill(NSColor(calibratedWhite: 0.93, alpha: 1), in: canvas.rect(x + 92, 438, 258, 18), radius: 9)
    roundedFill(NSColor(calibratedWhite: 0.93, alpha: 1), in: canvas.rect(x + 92, 470, 190, 18), radius: 9)

    let input = canvas.rect(x + 28, 554, 364, 104)
    roundedFill(paper, in: input, radius: 18)
    roundedStroke(line, in: input, radius: 18, width: 2)
    drawText("今日の件ですが、\n資料を添付しました。", in: canvas.rect(x + 50, 574, 320, 66), size: 17, color: charcoal, lineSpacing: 4)

    drawText("Enter = 改行", in: canvas.rect(x + 30, 674, 360, 28), size: 17, weight: .semibold, color: gray, alignment: .center)
}

guard let texture = NSImage(contentsOf: textureURL) else {
    fatalError("Missing monochrome paper background")
}

// Main X launch image — type-led, no keyboard/keycap metaphor.
let main = withCanvas(width: 1600, height: 900) { c in
    drawImage(texture, aspectFill: c.rect(0, 0, 1600, 900))
    fill(white.withAlphaComponent(0.88), in: c.rect(0, 0, 1600, 900))

    drawWordmark(canvas: c, x: 76, y: 54, size: 29)
    drawPill("macOS用メニューバーアプリ", canvas: c, x: 1130, y: 52, width: 390)

    drawText(
        "どのアプリでも、\n改行と送信を統一。",
        in: c.rect(74, 164, 1010, 230),
        size: 78,
        weight: .bold,
        lineSpacing: 8
    )
    drawText(
        "Enterはいつでも改行、送信は⌘Enter。",
        in: c.rect(80, 430, 860, 44),
        size: 29,
        weight: .medium,
        color: gray
    )
    drawCenteredText("↵", in: c.rect(1110, 128, 360, 350), size: 270, weight: .bold, color: black)

    let band = c.rect(64, 548, 1472, 296)
    roundedFill(black, in: band, radius: 32)
    drawText("操作は、これだけ。", in: c.rect(112, 584, 500, 38), size: 25, weight: .semibold, color: midGray)
    fill(NSColor(calibratedWhite: 0.24, alpha: 1), in: c.rect(112, 636, 1376, 2))

    drawText("ENTER", in: c.rect(118, 674, 200, 34), size: 22, weight: .bold, color: midGray)
    drawText("↵  改行", in: c.rect(118, 712, 560, 68), size: 56, weight: .bold, color: white)

    fill(NSColor(calibratedWhite: 0.28, alpha: 1), in: c.rect(792, 674, 2, 108))

    drawText("⌘  ENTER", in: c.rect(858, 674, 300, 34), size: 22, weight: .bold, color: midGray)
    drawText("送信", in: c.rect(858, 712, 400, 68), size: 56, weight: .bold, color: white)
    drawText("→", in: c.rect(1248, 714, 120, 68), size: 50, weight: .regular, color: midGray)

    drawText(
        "Slack・Teams・Discord・LINE・ChatGPT・Claude など / アプリでも、ブラウザでも。",
        in: c.rect(112, 800, 1370, 30),
        size: 18,
        weight: .medium,
        color: midGray,
        alignment: .center
    )
}
main.save("x-launch-main-1600x900.png")

// Companion image — the same rule across several chat contexts.
let appsImage = withCanvas(width: 1600, height: 900) { c in
    fill(paper, in: c.rect(0, 0, 1600, 900))
    drawWordmark(canvas: c, x: 72, y: 54, size: 29)
    drawText("アプリでも、ブラウザでも。", in: c.rect(74, 142, 1100, 80), size: 58, weight: .bold)
    drawText("対象のアプリやタブが前面のときだけ働きます。", in: c.rect(78, 226, 1000, 38), size: 24, color: gray)

    drawChatCard(canvas: c, x: 74, label: "Slack", person: "田中")
    drawChatCard(canvas: c, x: 590, label: "ChatGPT", person: "ChatGPT")
    drawChatCard(canvas: c, x: 1106, label: "Claude", person: "Claude")

    roundedFill(black, in: c.rect(74, 752, 1452, 92), radius: 24)
    drawText(
        "Enterはいつでも改行   /   送信は⌘Enter",
        in: c.rect(110, 778, 1380, 42),
        size: 27,
        weight: .bold,
        color: white,
        alignment: .center
    )
}
appsImage.save("x-launch-apps-1600x900.png")

// Safety image — Japanese IME behavior and privacy, fully monochrome.
let safety = withCanvas(width: 1600, height: 900) { c in
    fill(paper, in: c.rect(0, 0, 1600, 900))

    let left = c.rect(32, 32, 560, 836)
    roundedFill(black, in: left, radius: 36)
    drawWordmark(canvas: c, x: 78, y: 72, dark: true, size: 27)
    drawCenteredText("あ", in: c.rect(92, 202, 440, 320), size: 250, weight: .bold, color: white)
    drawCenteredText("↵", in: c.rect(104, 548, 416, 190), size: 150, weight: .bold, color: NSColor(calibratedWhite: 0.42, alpha: 1))
    drawText("変換確定のEnterは、そのまま。", in: c.rect(72, 778, 480, 42), size: 22, weight: .semibold, color: midGray, alignment: .center)

    drawText("日本語入力に、\nとことん安全。", in: c.rect(680, 104, 820, 176), size: 68, weight: .bold, lineSpacing: 6)
    drawText("変換中のEnterは、書き換えません。", in: c.rect(686, 324, 790, 42), size: 27, weight: .semibold, color: gray)

    let items = [
        "変換中のEnterは、そのまま確定",
        "判定に迷ったら「何もしない」",
        "入力内容を読まない・外部送信なし",
    ]
    for (index, item) in items.enumerated() {
        let y = CGFloat(438 + index * 112)
        roundedFill(black, in: c.rect(686, y, 46, 46), radius: 23)
        drawCenteredText("✓", in: c.rect(686, y, 46, 46), size: 23, weight: .bold, color: white)
        drawText(item, in: c.rect(762, y - 1, 700, 52), size: 29, weight: .medium)
    }

    fill(line, in: c.rect(686, 778, 780, 2))
    drawText("必要な権限はアクセシビリティのみ", in: c.rect(686, 804, 780, 34), size: 20, color: gray)
}
safety.save("x-launch-safety-1600x900.png")

// Square version for mobile timelines.
let square = withCanvas(width: 1200, height: 1200) { c in
    drawImage(texture, aspectFill: c.rect(0, 0, 1200, 1200))
    fill(white.withAlphaComponent(0.91), in: c.rect(0, 0, 1200, 1200))
    drawWordmark(canvas: c, x: 72, y: 66, size: 30)
    drawPill("macOS 13以降・14日間無料", canvas: c, x: 724, y: 60, width: 404)

    drawCenteredText("↵", in: c.rect(720, 164, 390, 340), size: 260, weight: .bold, color: black)
    drawText("どのアプリでも、\n改行と送信を統一。", in: c.rect(72, 210, 700, 220), size: 66, weight: .bold, lineSpacing: 8)
    drawText("Enterはいつでも改行、送信は⌘Enter。", in: c.rect(78, 468, 760, 44), size: 27, weight: .medium, color: gray)

    let band = c.rect(52, 660, 1096, 452)
    roundedFill(black, in: band, radius: 34)
    drawText("ENTER", in: c.rect(104, 718, 240, 32), size: 22, weight: .bold, color: midGray)
    drawText("↵  改行", in: c.rect(104, 762, 800, 70), size: 58, weight: .bold, color: white)
    fill(NSColor(calibratedWhite: 0.26, alpha: 1), in: c.rect(104, 858, 992, 2))
    drawText("⌘  ENTER", in: c.rect(104, 902, 300, 32), size: 22, weight: .bold, color: midGray)
    drawText("送信", in: c.rect(104, 946, 650, 70), size: 58, weight: .bold, color: white)
    drawText("Slack・Teams・ChatGPT・Claude など", in: c.rect(104, 1058, 992, 30), size: 19, color: midGray, alignment: .center)
}
square.save("x-launch-square-1200x1200.png")

// Link-card candidate.
let og = withCanvas(width: 1200, height: 630) { c in
    fill(white, in: c.rect(0, 0, 1200, 630))
    drawWordmark(canvas: c, x: 58, y: 48, size: 26)
    drawText("どのアプリでも、\n改行と送信を統一。", in: c.rect(56, 174, 670, 160), size: 54, weight: .bold, lineSpacing: 5)
    drawText("Enterはいつでも改行、送信は⌘Enter。", in: c.rect(60, 392, 640, 40), size: 24, weight: .medium, color: gray)
    drawPill("macOS 13以降・14日間無料", canvas: c, x: 56, y: 506, width: 372)

    let right = c.rect(770, 0, 430, 630)
    fill(black, in: right)
    drawCenteredText("↵", in: c.rect(792, 82, 386, 330), size: 270, weight: .bold, color: white)
    drawText("ENTER = 改行", in: c.rect(800, 444, 370, 38), size: 24, weight: .bold, color: white, alignment: .center)
    drawText("⌘ENTER = 送信", in: c.rect(800, 500, 370, 38), size: 24, weight: .bold, color: midGray, alignment: .center)
}
og.save("og-link-card-1200x630.png")
