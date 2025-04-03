import Foundation
import SwiftUI
import AppKit

// 确保创建富文本色彩时可以访问NSColor扩展

// 富文本颜色测试类
// 提供一些测试方法来检验富文本颜色提取功能
class RichTextTests {
    
    static let shared = RichTextTests()
    
    // 创建一个带有不同颜色的富文本
    func createColoredAttributedString() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // 添加蓝色文本
        let blueText = NSAttributedString(
            string: "这是蓝色文本 ",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.blue,
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14)
            ]
        )
        attributedString.append(blueText)
        
        // 添加红色文本
        let redText = NSAttributedString(
            string: "这是红色文本 ",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.red,
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14)
            ]
        )
        attributedString.append(redText)
        
        // 添加绿色文本
        let greenText = NSAttributedString(
            string: "这是绿色文本 ",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.green,
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14)
            ]
        )
        attributedString.append(greenText)
        
        // 添加橙色文本
        let orangeText = NSAttributedString(
            string: "这是橙色文本",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.orange,
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14)
            ]
        )
        attributedString.append(orangeText)
        
        return attributedString
    }
    
    // 创建模拟的富文本代码（模拟Xcode语法高亮）
    func createCodeSampleAttributedString() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // 添加关键字 (紫色)
        let keywordText = NSAttributedString(
            string: "func ",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor(red: 0.6, green: 0.0, blue: 0.6, alpha: 1.0),
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(keywordText)
        
        // 添加方法名 (黑色)
        let methodText = NSAttributedString(
            string: "extractColors",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.black,
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(methodText)
        
        // 添加括号和参数 (黑色)
        let paramsText = NSAttributedString(
            string: "() -> ",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.black,
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(paramsText)
        
        // 添加返回类型 (蓝色)
        let returnTypeText = NSAttributedString(
            string: "[NSColor]",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.blue,
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(returnTypeText)
        
        // 添加函数体开始 (黑色)
        let openBraceText = NSAttributedString(
            string: " {\n    ",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.black,
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(openBraceText)
        
        // 添加注释 (绿色)
        let commentText = NSAttributedString(
            string: "// 提取颜色\n    ",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.green,
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(commentText)
        
        // 添加字符串 (红色)
        let stringText = NSAttributedString(
            string: "let colorValue = \"#FF5500\"",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.red,
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(stringText)
        
        // 添加函数体结束 (黑色)
        let closeBraceText = NSAttributedString(
            string: "\n}",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.black,
                NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )
        attributedString.append(closeBraceText)
        
        return attributedString
    }
    
    // 测试提取富文本颜色函数
    func testExtractColorsFromAttributedString() {
        let attrString = createColoredAttributedString()
        
        // 提取所有颜色和对应的样本文本
        var results: [(NSColor, String)] = []
        let entireRange = NSRange(location: 0, length: attrString.length)
        
        attrString.enumerateAttributes(in: entireRange, options: []) { (attrs, range, _) in
            if let color = attrs[NSAttributedString.Key.foregroundColor] as? NSColor {
                let sampleText = (attrString.string as NSString).substring(with: range)
                results.append((color, sampleText))
            }
        }
        
        // 打印结果
        print("发现 \(results.count) 种颜色:")
        for (index, result) in results.enumerated() {
            let (color, sample) = result
            let hexColor = color.toHexString(includeAlpha: false)
            print("颜色 \(index+1): \(hexColor) - 样本: \"\(sample)\"")
        }
    }
    
    // 测试将富文本插入到剪贴板并通过ClipboardManager提取颜色
    func testClipboardRichTextExtraction() {
        // 创建富文本
        let attrString = createCodeSampleAttributedString()
        
        // 将富文本放入剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([attrString])
        
        print("已将富文本代码示例复制到剪贴板")
        print("请在应用中测试颜色提取功能")
    }
}
