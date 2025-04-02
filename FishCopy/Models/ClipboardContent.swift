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
    var fileURLStrings: [String]?
    var timestamp: Date
    var category: String?
    var isPinned: Bool
    
    init(id: UUID = UUID(), textContent: String? = nil, imageData: Data? = nil, 
         fileURLStrings: [String]? = nil, category: String? = nil, timestamp: Date = Date(), 
         isPinned: Bool = false) {
        self.id = id
        self.textContent = textContent
        self.imageData = imageData
        self.fileURLStrings = fileURLStrings
        self.timestamp = timestamp
        self.category = category
        self.isPinned = isPinned
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