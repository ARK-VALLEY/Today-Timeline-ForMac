import AppKit

// 用法: icongen <输出路径> <cream|dark>
// 生成 1024x1024 应用图标：
//   cream —— Claude Code 风格：奶油底色 + 墨色时间轴 + 陶土橙「当前」圆点
//   dark  —— macOS 风格：深空黑渐变 + 白色时间轴 + 橙色「当前」圆点
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let variant = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "cream"
let S: CGFloat = 1024

// 调色板
let creamBG = CGColor(red: 0.941, green: 0.933, blue: 0.902, alpha: 1)      // #F0EEE6
let ink = CGColor(red: 0.122, green: 0.118, blue: 0.114, alpha: 1)          // #1F1E1D
let terracotta = CGColor(red: 0.851, green: 0.467, blue: 0.341, alpha: 1)   // #D97757
let darkTop = CGColor(red: 0.184, green: 0.184, blue: 0.192, alpha: 1)      // #2F2F31
let darkBottom = CGColor(red: 0.113, green: 0.113, blue: 0.121, alpha: 1)   // #1D1D1F
let white = CGColor(gray: 1, alpha: 1)
let orange = CGColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1)         // #FF9F0A

let isCream = variant == "cream"
let lineColor = isCream ? ink : white
let pastColor = isCream ? ink : white
let accent = isCream ? terracotta : orange

let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// 背景：满幅填充（macOS 会自动裁出圆角方形）
if isCream {
    ctx.setFillColor(creamBG)
    ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
} else {
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [darkTop, darkBottom] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: S),
                           end: CGPoint(x: 0, y: 0),
                           options: [])
}

// 竖线时间轴
ctx.setStrokeColor(lineColor)
ctx.setLineWidth(38)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 512, y: 296))
ctx.addLine(to: CGPoint(x: 512, y: 728))
ctx.strokePath()

// 圆点辅助函数
func dot(y: CGFloat, d: CGFloat, alpha: CGFloat, filled: Bool, color: CGColor, stroke: CGFloat = 16) {
    let rect = CGRect(x: 512 - d / 2, y: y - d / 2, width: d, height: d)
    if filled {
        ctx.setFillColor(color.copy(alpha: alpha) ?? color)
        ctx.fillEllipse(in: rect)
    } else {
        ctx.setStrokeColor(color.copy(alpha: alpha) ?? color)
        ctx.setLineWidth(stroke)
        ctx.strokeEllipse(in: rect)
    }
}

// 已结束日程（渐深）
dot(y: 368, d: 58, alpha: isCream ? 0.20 : 0.24, filled: true, color: pastColor)
dot(y: 472, d: 58, alpha: isCream ? 0.48 : 0.52, filled: true, color: pastColor)

// 当前时刻：光环 + 实心圆点
dot(y: 592, d: 204, alpha: isCream ? 0.32 : 0.38, filled: false, color: accent, stroke: 18)
dot(y: 592, d: 128, alpha: 1, filled: true, color: accent)

// 未来日程（空心）
dot(y: 700, d: 58, alpha: isCream ? 0.42 : 0.48, filled: false, color: pastColor, stroke: 15)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("encode failed")
}
try! png.write(to: URL(fileURLWithPath: out))
print("icon written: \(out) (\(variant))")
