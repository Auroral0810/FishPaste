//
//  ClipboardContent.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData

// 表示剪贴板中的内容
class ClipboardContent: Identifiable {
    var id: UUID
    var text: String?
    var image: NSImage?
    var fileURLs: [URL]?
    var timestamp: Date
    var category: String?
    var isPinned: Bool
    
    init(id: UUID = UUID(), text: String? = nil, image: NSImage? = nil, fileURLs: [URL]? = nil, 
         category: String? = nil, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.image = image
        self.fileURLs = fileURLs
        self.timestamp = timestamp
        self.category = category
        self.isPinned = isPinned
    }
    
    // 检查两个剪贴板内容是否相同
    func isEqual(to other: ClipboardContent) -> Bool {
        if let text = text, let otherText = other.text, text == otherText {
            return true
        }
        
        // 对于图片的比较
        if let image = image, let otherImage = other.image {
            // 这里应该添加更复杂的图片比较逻辑
            return true
        }
        
        // 对于文件URL的比较
        if let urls = fileURLs, let otherURLs = other.fileURLs {
            // 检查URL集合是否相同
            let urlSet = Set(urls.map { $0.absoluteString })
            let otherURLSet = Set(otherURLs.map { $0.absoluteString })
            return urlSet == otherURLSet
        }
        
        return false
    }
}

// SwiftData模型用于持久化
@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var textContent: String?
    var imageData: Data?
    // 将fileURLStrings改为计算属性
    var fileURLStrings: [String]? {
        get {
            if let urlsString = fileURLsString, !urlsString.isEmpty {
                return urlsString.components(separatedBy: "|||")
            }
            return nil
        }
        set {
            if let newValue = newValue, !newValue.isEmpty {
                self.fileURLsString = newValue.joined(separator: "|||")
            } else {
                self.fileURLsString = nil
            }
        }
    }
    // 用于存储URL的替代字段，将多个URL合并为单个字符串，用分隔符分隔
    var fileURLsString: String?
    var timestamp: Date
    var category: String?
    var isPinned: Bool
    
    init(id: UUID = UUID(), textContent: String? = nil, imageData: Data? = nil, 
         fileURLStrings: [String]? = nil, category: String? = nil, timestamp: Date = Date(), 
         isPinned: Bool = false) {
        self.id = id
        self.textContent = textContent
        self.imageData = imageData
        self.timestamp = timestamp
        self.category = category
        self.isPinned = isPinned
        
        // 安全地设置fileURLsString，避免空数组造成问题
        if let urls = fileURLStrings, !urls.isEmpty {
            self.fileURLsString = urls.joined(separator: "|||")
        } else {
            self.fileURLsString = nil
        }
    }
    
    // 将模型转换为通用剪贴板内容对象 - 添加此方法以便于应用中使用
    func toClipboardContent() -> ClipboardContent {
        // 从Data创建图像
        var image: NSImage? = nil
        if let imgData = imageData {
            image = NSImage(data: imgData)
        }
        
        // 从字符串数组创建URL数组
        var urls: [URL]? = nil
        if let urlStrings = fileURLStrings {
            urls = urlStrings.compactMap { URL(string: $0) }
        }
        
        return ClipboardContent(
            id: id,
            text: textContent,
            image: image,
            fileURLs: urls,
            category: category,
            timestamp: timestamp,
            isPinned: isPinned
        )
    }
}

// 分类模型
@Model
final class ClipboardCategory {
    @Attribute(.unique) var name: String
    var color: String // 存储颜色的十六进制值
    var items: [ClipboardItem]?
    
    init(name: String, color: String = "#0096FF") {
        self.name = name
        self.color = color
        self.items = []
    }
} 