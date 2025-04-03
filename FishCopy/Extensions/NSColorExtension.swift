import AppKit

// NSColor扩展，用于HEX颜色支持
extension NSColor {
    
    // 从HEX字符串创建颜色
    convenience init?(hexString: String) {
        // 移除可能的前缀和空格
        var hexSanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        // 验证HEX字符串长度
        guard hexSanitized.count == 3 || hexSanitized.count == 6 || hexSanitized.count == 8 else {
            return nil
        }
        
        // 将3位HEX转换为6位HEX
        if hexSanitized.count == 3 {
            let r = String(hexSanitized[hexSanitized.startIndex])
            let g = String(hexSanitized[hexSanitized.index(hexSanitized.startIndex, offsetBy: 1)])
            let b = String(hexSanitized[hexSanitized.index(hexSanitized.startIndex, offsetBy: 2)])
            hexSanitized = r + r + g + g + b + b
        }
        
        // 创建扫描器
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        
        var red, green, blue, alpha: CGFloat
        
        if hexSanitized.count == 8 {
            // 8位HEX包含透明度
            red = CGFloat((rgbValue & 0xFF00_0000) >> 24) / 255.0
            green = CGFloat((rgbValue & 0x00FF_0000) >> 16) / 255.0
            blue = CGFloat((rgbValue & 0x0000_FF00) >> 8) / 255.0
            alpha = CGFloat(rgbValue & 0x0000_00FF) / 255.0
        } else {
            // 6位HEX不包含透明度
            red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgbValue & 0x0000FF) / 255.0
            alpha = 1.0
        }
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // 将颜色转换为HEX字符串
    func toHexString(includeAlpha: Bool = true) -> String {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return "#000000"
        }
        
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        let alpha = Int(round(rgbColor.alphaComponent * 255))
        
        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        } else {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
    }
} 