import Foundation
import SwiftUI
import AppKit

// 确保创建富文本色彩时可以访问NSColor扩展

class TestingHelper {
    static let shared = TestingHelper()
    
    // 将富文本复制到剪贴板
    func copyRichTextToClipboard() {
        // 1. 创建富文本
        let richText = createRichTextSample()
        
        // 2. 复制到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([richText])
        
        print("富文本已复制到剪贴板")
    }
    
    // 创建富文本样例
    private func createRichTextSample() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // Swift关键字 (紫色)
        attributedString.append(NSAttributedString(
            string: "func ",
            attributes: [
                .foregroundColor: NSColor(red: 0.6, green: 0.0, blue: 0.6, alpha: 1.0),
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 函数名 (黑色)
        attributedString.append(NSAttributedString(
            string: "processColors",
            attributes: [
                .foregroundColor: NSColor.black,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 括号和参数 (黑色)
        attributedString.append(NSAttributedString(
            string: "() -> ",
            attributes: [
                .foregroundColor: NSColor.black,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 返回类型 (蓝色)
        attributedString.append(NSAttributedString(
            string: "[Color]",
            attributes: [
                .foregroundColor: NSColor.blue,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 括号 (黑色)
        attributedString.append(NSAttributedString(
            string: " {\n    ",
            attributes: [
                .foregroundColor: NSColor.black,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 注释 (绿色)
        attributedString.append(NSAttributedString(
            string: "// 提取所有颜色\n    ",
            attributes: [
                .foregroundColor: NSColor.green,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 变量关键字 (紫色)
        attributedString.append(NSAttributedString(
            string: "let ",
            attributes: [
                .foregroundColor: NSColor(red: 0.6, green: 0.0, blue: 0.6, alpha: 1.0),
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 变量名 (黑色)
        attributedString.append(NSAttributedString(
            string: "colors ",
            attributes: [
                .foregroundColor: NSColor.black,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 赋值符号 (黑色)
        attributedString.append(NSAttributedString(
            string: "= ",
            attributes: [
                .foregroundColor: NSColor.black,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 字符串 (红色)
        attributedString.append(NSAttributedString(
            string: "\"#FF5500 #00AAFF\"",
            attributes: [
                .foregroundColor: NSColor.red,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 结束 (黑色)
        attributedString.append(NSAttributedString(
            string: "\n}",
            attributes: [
                .foregroundColor: NSColor.black,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        return attributedString
    }
    
    // 分析剪贴板中的富文本
    func analyzeClipboardRichText() {
        let pasteboard = NSPasteboard.general
        
        if let rtfData = pasteboard.data(forType: .rtf) ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.rtf")) {
            do {
                let attributedString = try NSAttributedString(data: rtfData,
                                                           options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                           documentAttributes: nil)
                
                print("富文本分析:")
                print("总长度: \(attributedString.length)个字符")
                
                // 收集所有不同颜色
                var colors: [NSColor] = []
                var colorTexts: [NSColor: String] = [:]
                
                attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, _ in
                    if let color = attributes[.foregroundColor] as? NSColor {
                        // 转换为标准RGB色彩空间
                        let rgbColor = color.usingColorSpace(.sRGB) ?? color
                        
                        // 忽略黑色和白色
                        if (rgbColor.redComponent < 0.1 && rgbColor.greenComponent < 0.1 && rgbColor.blueComponent < 0.1) ||
                           (rgbColor.redComponent > 0.9 && rgbColor.greenComponent > 0.9 && rgbColor.blueComponent > 0.9) {
                            return
                        }
                        
                        // 检查是否已有此颜色
                        if !colors.contains(where: { existingColor in
                            abs(existingColor.redComponent - rgbColor.redComponent) < 0.05 &&
                            abs(existingColor.greenComponent - rgbColor.greenComponent) < 0.05 &&
                            abs(existingColor.blueComponent - rgbColor.blueComponent) < 0.05
                        }) {
                            colors.append(rgbColor)
                            let text = (attributedString.string as NSString).substring(with: range)
                            colorTexts[rgbColor] = text
                        }
                    }
                }
                
                print("发现\(colors.count)种不同颜色:")
                for (index, color) in colors.enumerated() {
                    let hexColor = color.toHexString(includeAlpha: false)
                    let sample = colorTexts[color] ?? ""
                    print("\(index+1). 颜色: \(hexColor), 样本: \"\(sample)\"")
                    print("RGB值: R:\(Int(color.redComponent*255)), G:\(Int(color.greenComponent*255)), B:\(Int(color.blueComponent*255))")
                }
                
            } catch {
                print("解析富文本失败: \(error)")
            }
        } else {
            print("剪贴板中没有找到富文本数据")
        }
    }
} 