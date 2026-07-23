import UIKit

/// 按截图像素尺寸 / 机型推算主屏小组件裁切框（假透明壁纸）
enum WidgetTransparentCrop {
  /// 裁切结果 key → 像素坐标系矩形
  static func cropRects(forPixelSize size: CGSize) -> [String: CGRect] {
    let w = size.width
    let h = size.height
    guard w > 100, h > 100 else { return [:] }

    let key = "\(Int(w.rounded()))x\(Int(h.rounded()))"
    if let known = knownLayouts[key] {
      return known
    }

    // 兼容 @2x/@3x 逻辑尺寸换算后的近似匹配
    for (knownKey, rects) in knownLayouts {
      let parts = knownKey.split(separator: "x")
      guard parts.count == 2,
            let kw = Double(parts[0]),
            let kh = Double(parts[1]) else { continue }
      if abs(kw - w) / w < 0.02, abs(kh - h) / h < 0.02 {
        return scaleRects(rects, from: CGSize(width: kw, height: kh), to: size)
      }
    }

    return proportionalLayout(pixelSize: size)
  }

  /// 常见竖屏主屏截图像素尺寸（含状态栏）
  private static let knownLayouts: [String: [String: CGRect]] = [
    // iPhone 14 / 13 / 12 (1170×2532 @3x)
    "1170x2532": layout(
      w: 1170, h: 2532,
      left: 69, top: 231, small: 465, hGap: 102, vGap: 54
    ),
    // iPhone 14 Pro / 15 Pro (1179×2556)
    "1179x2556": layout(
      w: 1179, h: 2556,
      left: 72, top: 258, small: 474, hGap: 87, vGap: 54
    ),
    // iPhone 14 Plus / 15 Plus / 15 Pro Max 部分 (1290×2796)
    "1290x2796": layout(
      w: 1290, h: 2796,
      left: 75, top: 270, small: 516, hGap: 108, vGap: 60
    ),
    // iPhone 12/13 Pro Max (1284×2778)
    "1284x2778": layout(
      w: 1284, h: 2778,
      left: 75, top: 264, small: 510, hGap: 114, vGap: 60
    ),
    // iPhone 16 Pro (1206×2622)
    "1206x2622": layout(
      w: 1206, h: 2622,
      left: 72, top: 270, small: 486, hGap: 90, vGap: 57
    ),
    // iPhone 16 Pro Max (1320×2868)
    "1320x2868": layout(
      w: 1320, h: 2868,
      left: 78, top: 282, small: 528, hGap: 108, vGap: 63
    ),
    // iPhone 11 / XR (828×1792 @2x)
    "828x1792": layout(
      w: 828, h: 1792,
      left: 48, top: 168, small: 330, hGap: 72, vGap: 42
    ),
    // iPhone X / XS / 11 Pro (1125×2436)
    "1125x2436": layout(
      w: 1125, h: 2436,
      left: 69, top: 231, small: 447, hGap: 93, vGap: 51
    ),
    // iPhone SE 2/3 (750×1334)
    "750x1334": layout(
      w: 750, h: 1334,
      left: 54, top: 90, small: 297, hGap: 48, vGap: 30,
      rows: 2
    ),
    // iPhone 8 Plus (1242×2208)
    "1242x2208": layout(
      w: 1242, h: 2208,
      left: 81, top: 114, small: 486, hGap: 108, vGap: 48,
      rows: 2
    ),
  ]

  private static func layout(
    w: CGFloat,
    h: CGFloat,
    left: CGFloat,
    top: CGFloat,
    small: CGFloat,
    hGap: CGFloat,
    vGap: CGFloat,
    rows: Int = 3
  ) -> [String: CGRect] {
    let right = left + small + hGap
    let row2 = top + small + vGap
    let row3 = row2 + small + vGap
    let mediumW = small * 2 + hGap
    let mediumH = small

    var result: [String: CGRect] = [
      "topLeft": CGRect(x: left, y: top, width: small, height: small),
      "topRight": CGRect(x: right, y: top, width: small, height: small),
      "mediumTop": CGRect(x: left, y: top, width: mediumW, height: mediumH),
    ]

    if rows >= 2 {
      result["midLeft"] = CGRect(x: left, y: row2, width: small, height: small)
      result["midRight"] = CGRect(x: right, y: row2, width: small, height: small)
      result["mediumMiddle"] = CGRect(x: left, y: row2, width: mediumW, height: mediumH)
      result["center"] = result["mediumMiddle"]!
    }

    if rows >= 3 {
      result["bottomLeft"] = CGRect(x: left, y: row3, width: small, height: small)
      result["bottomRight"] = CGRect(x: right, y: row3, width: small, height: small)
      result["mediumBottom"] = CGRect(x: left, y: row3, width: mediumW, height: mediumH)
    } else {
      // 矮屏：第二行当底部
      result["bottomLeft"] = result["midLeft"]
      result["bottomRight"] = result["midRight"]
      result["mediumBottom"] = result["mediumMiddle"]
    }

    _ = (w, h)
    return result.compactMapValues { $0 }
  }

  private static func proportionalLayout(pixelSize: CGSize) -> [String: CGRect] {
    let w = pixelSize.width
    let h = pixelSize.height
    let aspect = h / w
    // 刘海/灵动岛机：顶部留白更大
    let topFrac: CGFloat = aspect > 2.0 ? 0.095 : (aspect > 1.9 ? 0.09 : 0.07)
    let leftFrac: CGFloat = 0.059
    let smallFrac: CGFloat = 0.397
    let hGapFrac: CGFloat = 0.088
    let vGapFrac: CGFloat = aspect > 1.9 ? 0.021 : 0.024
    let rows = aspect < 1.8 ? 2 : 3

    return layout(
      w: w,
      h: h,
      left: w * leftFrac,
      top: h * topFrac,
      small: w * smallFrac,
      hGap: w * hGapFrac,
      vGap: h * vGapFrac,
      rows: rows
    )
  }

  private static func scaleRects(
    _ rects: [String: CGRect],
    from: CGSize,
    to: CGSize
  ) -> [String: CGRect] {
    let sx = to.width / from.width
    let sy = to.height / from.height
    var out: [String: CGRect] = [:]
    for (k, r) in rects {
      out[k] = CGRect(
        x: r.origin.x * sx,
        y: r.origin.y * sy,
        width: r.size.width * sx,
        height: r.size.height * sy
      )
    }
    return out
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
