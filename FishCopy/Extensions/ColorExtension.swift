import SwiftUI

// Color扩展
extension Color {
    // 从NSColor创建Color
    init(nsColor: NSColor) {
        let ciColor = CIColor(color: nsColor)!
        self.init(
            .sRGB,
            red: Double(ciColor.red),
            green: Double(ciColor.green),
            blue: Double(ciColor.blue),
            opacity: Double(ciColor.alpha)
        )
    }
} 