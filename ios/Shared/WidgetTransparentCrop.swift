import UIKit

/// 按当前 iPhone 主屏分辨率裁切假透明壁纸。
/// 优先使用本机像素表；未知机型则按点距布局换算。
enum WidgetTransparentCrop {
  static func makeCrops(from image: UIImage) -> [String: UIImage] {
    guard let screenImage = normalizeToPortraitScreen(image),
          let cg = screenImage.cgImage else { return [:] }
    let pixelSize = CGSize(width: cg.width, height: cg.height)
    let rects = cropRects(forPixelSize: pixelSize)
    var result: [String: UIImage] = [:]
    for (key, rect) in rects {
      if let cropped = crop(screenImage, toPixelRect: rect) {
        result[key] = cropped
      }
    }
    return result
  }

  /// 与本机竖屏 native 分辨率对齐：已是截图则直接用，否则 aspect-fill
  static func normalizeToPortraitScreen(_ image: UIImage) -> UIImage? {
    let oriented = image.fixedOrientation()
    guard let cg = oriented.cgImage else { return nil }
    let iw = CGFloat(cg.width)
    let ih = CGFloat(cg.height)
    let screen = UIScreen.main.nativeBounds
    let tw = min(screen.width, screen.height)
    let th = max(screen.width, screen.height)

    // 竖屏截图/壁纸已与本机像素一致
    if abs(iw - tw) <= 2, abs(ih - th) <= 2 {
      return oriented
    }
    // 横图尺寸对调时仍按竖屏目标铺满
    return aspectFill(oriented, to: CGSize(width: tw, height: th))
  }

  static func aspectFill(_ image: UIImage, to target: CGSize) -> UIImage? {
    guard target.width > 10, target.height > 10 else { return nil }
    let srcSize = CGSize(
      width: image.cgImage.map { CGFloat($0.width) } ?? image.size.width,
      height: image.cgImage.map { CGFloat($0.height) } ?? image.size.height
    )
    guard srcSize.width > 1, srcSize.height > 1 else { return nil }
    let scale = max(target.width / srcSize.width, target.height / srcSize.height)
    let drawSize = CGSize(width: srcSize.width * scale, height: srcSize.height * scale)
    let origin = CGPoint(
      x: (target.width - drawSize.width) / 2,
      y: (target.height - drawSize.height) / 2
    )
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: target, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: origin, size: drawSize))
    }
  }

  static func cropRects(forPixelSize size: CGSize) -> [String: CGRect] {
    let w = Int(size.width.rounded())
    let h = Int(size.height.rounded())
    if let table = pixelTable(width: w, height: h) {
      return table
    }
    return pointDerivedRects(pixelWidth: size.width, pixelHeight: size.height)
  }

  /// 常见机型像素表（小号 / 中号 / 边距）。来源：主屏空桌面实测 + Scriptable 社区表
  private static func pixelTable(width w: Int, height h: Int) -> [String: CGRect]? {
    // 右列与中号宽度由屏幕宽度和左边距统一推导，避免同一机型的裁切坐标互相矛盾。
    typealias L = (left: CGFloat, top: CGFloat, small: CGFloat, vGap: CGFloat, rows: Int)
    let layouts: [String: L] = [
      // SE / mini 类
      "750x1334": (54, 110, 296, 46, 2),
      "1080x2340": (54, 198, 474, 60, 3),
      "1125x2436": (54, 201, 465, 60, 3),
      // X / 11 Pro / 12 mini 等
      "1170x2532": (66, 213, 474, 66, 3), // 12/13
      "1179x2556": (72, 231, 474, 66, 3), // 14 Pro
      "1284x2778": (84, 258, 516, 72, 3), // 12/13 Pro Max
      "1290x2796": (84, 270, 510, 72, 3), // 14/15 Plus
      "1320x2868": (87, 270, 510, 72, 3), // 16 Plus
      "1206x2622": (75, 246, 486, 66, 3), // 16 Pro
      "1290x2868": (87, 270, 510, 72, 3),
      "1374x2982": (93, 285, 528, 75, 3), // 16 Pro Max 近似
    ]
    let key = "\(w)x\(h)"
    guard let L = layouts[key] else { return nil }
    return buildRects(
      screenWidth: CGFloat(w), left: L.left, top: L.top,
      small: L.small, vGap: L.vGap, rows: L.rows
    )
  }

  private static func pointDerivedRects(pixelWidth w: CGFloat, pixelHeight h: CGFloat) -> [String: CGRect] {
    let bounds = UIScreen.main.bounds
    let pointW = min(bounds.width, bounds.height)
    let pointH = max(bounds.width, bounds.height)
    let sx = w / pointW
    let sy = h / pointH

    let smallPt = smallWidgetSide(screenWidth: pointW)
    let leftPt = horizontalMargin(screenWidth: pointW, smallSide: smallPt)
    let topPt = topMargin(screenHeight: pointH)
    let vGapPt = verticalGap(screenHeight: pointH)
    let rows = pointH < 700 ? 2 : 3

    return buildRects(
      screenWidth: w,
      left: leftPt * sx,
      top: topPt * sy,
      small: smallPt * sx,
      vGap: vGapPt * sy,
      rows: rows
    )
  }

  private static func buildRects(
    screenWidth: CGFloat,
    left: CGFloat,
    top: CGFloat,
    small: CGFloat,
    vGap: CGFloat,
    rows: Int
  ) -> [String: CGRect] {
    let right = screenWidth - left - small
    let mediumWidth = screenWidth - left * 2
    let row2 = top + small + vGap
    let row3 = row2 + small + vGap
    var result: [String: CGRect] = [
      "topLeft": CGRect(x: left, y: top, width: small, height: small),
      "topRight": CGRect(x: right, y: top, width: small, height: small),
      "mediumTop": CGRect(x: left, y: top, width: mediumWidth, height: small),
    ]
    if rows >= 2 {
      result["midLeft"] = CGRect(x: left, y: row2, width: small, height: small)
      result["midRight"] = CGRect(x: right, y: row2, width: small, height: small)
      result["mediumMiddle"] = CGRect(x: left, y: row2, width: mediumWidth, height: small)
    }
    if rows >= 3 {
      result["bottomLeft"] = CGRect(x: left, y: row3, width: small, height: small)
      result["bottomRight"] = CGRect(x: right, y: row3, width: small, height: small)
      result["mediumBottom"] = CGRect(x: left, y: row3, width: mediumWidth, height: small)
    } else if let midL = result["midLeft"], let midR = result["midRight"] {
      result["bottomLeft"] = midL
      result["bottomRight"] = midR
      result["mediumBottom"] = result["mediumMiddle"]
    }
    return result
  }

  private static func smallWidgetSide(screenWidth sw: CGFloat) -> CGFloat {
    if sw >= 428 { return 170 }
    if sw >= 390 { return 158 }
    if sw >= 375 { return 155 }
    return 148
  }

  private static func horizontalMargin(screenWidth sw: CGFloat, smallSide: CGFloat) -> CGFloat {
    let idealGap: CGFloat = sw >= 390 ? 22 : 20
    let remaining = sw - smallSide * 2 - idealGap
    return max(remaining / 2, 14)
  }

  private static func topMargin(screenHeight sh: CGFloat) -> CGFloat {
    if sh >= 900 { return 90 }
    if sh >= 850 { return 82 }
    if sh >= 800 { return 77 }
    if sh >= 700 { return 62 }
    return 50
  }

  private static func verticalGap(screenHeight sh: CGFloat) -> CGFloat {
    if sh >= 850 { return 22 }
    if sh >= 700 { return 20 }
    return 16
  }

  static func crop(_ image: UIImage, toPixelRect rect: CGRect) -> UIImage? {
    guard let cg = image.cgImage else { return nil }
    let pixelRect = CGRect(
      x: rect.origin.x.rounded(.down),
      y: rect.origin.y.rounded(.down),
      width: rect.size.width.rounded(.down),
      height: rect.size.height.rounded(.down)
    )
    let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
    let clipped = pixelRect.intersection(bounds)
    guard clipped.width > 2, clipped.height > 2,
          let cut = cg.cropping(to: clipped) else { return nil }
    return UIImage(cgImage: cut, scale: 1, orientation: .up)
  }
}

private extension UIImage {
  func fixedOrientation() -> UIImage {
    if imageOrientation == .up { return self }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
