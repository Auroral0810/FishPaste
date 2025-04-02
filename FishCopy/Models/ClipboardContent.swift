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
    var image: NSImage?  // 保留单图片支持，用于向后兼容
    var images: [NSImage]?  // 新增：支持多张图片
    var fileURLs: [URL]?
    var timestamp: Date
    var category: String?
    var isPinned: Bool
    var title: String?  // 新增：内容标题
    
    init(id: UUID = UUID(), text: String? = nil, image: NSImage? = nil, images: [NSImage]? = nil, fileURLs: [URL]? = nil, 
         category: String? = nil, timestamp: Date = Date(), isPinned: Bool = false, title: String? = nil) {
        self.id = id
        self.text = text
        self.image = image
        self.images = images
        self.fileURLs = fileURLs
        self.timestamp = timestamp
        self.category = category
        self.isPinned = isPinned
        self.title = title
    }
    
    // 检查两个剪贴板内容是否相同
    func isEqual(to other: ClipboardContent) -> Bool {
        // 首先检查IDs - 如果ID相同，它们肯定是同一个内容
        if self.id == other.id {
            return true
        }
        
        // 对于文本内容的比较
        if let text = text, let otherText = other.text {
            return text == otherText
        }
        
        // 对于图片的比较，不能直接比较引用，应检查图片的实际内容
        // 注意：图片比较可能会很耗费资源
        
        // 对于文件URL的比较
        if let urls = fileURLs, let otherURLs = other.fileURLs {
            // 检查URL集合是否相同
            let urlSet = Set(urls.map { $0.absoluteString })
            let otherURLSet = Set(otherURLs.map { $0.absoluteString })
            return urlSet == otherURLSet
        }
        
        // 如果它们都没有内容，则认为是相同的
        if text == nil && other.text == nil && 
           image == nil && other.image == nil && 
           (images == nil || images?.isEmpty == true) &&
           (other.images == nil || other.images?.isEmpty == true) &&
           (fileURLs == nil || fileURLs?.isEmpty == true) && 
           (other.fileURLs == nil || other.fileURLs?.isEmpty == true) {
            return true
        }
        
        return false
    }
    
    // 获取显示用的主图片
    var displayImage: NSImage? {
        if let img = image {
            return img
        } else if let imgs = images, !imgs.isEmpty {
            return imgs.first
        }
        return nil
    }
    
    // 获取图片数量
    var imageCount: Int {
        if image != nil {
            return 1
        } else if let imgs = images {
            return imgs.count
        }
        return 0
    }
}

// SwiftData模型用于持久化
@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var textContent: String?
    var imageData: Data?  // 保留单图片支持
    var imagesData: [Data]?  // 新增：支持多张图片数据
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
    var title: String?  // 新增：内容标题
    
    init(id: UUID = UUID(), textContent: String? = nil, imageData: Data? = nil, 
         imagesData: [Data]? = nil, fileURLStrings: [String]? = nil, 
         category: String? = nil, timestamp: Date = Date(), 
         isPinned: Bool = false, title: String? = nil) {
        self.id = id
        self.textContent = textContent
        self.imageData = imageData
        self.imagesData = imagesData
        self.timestamp = timestamp
        self.category = category
        self.isPinned = isPinned
        self.title = title
        
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
        
        // 从Data数组创建图像数组
        var images: [NSImage]? = nil
        if let imgsData = imagesData, !imgsData.isEmpty {
            images = imgsData.compactMap { NSImage(data: $0) }
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
            images: images,
            fileURLs: urls,
            category: category,
            timestamp: timestamp,
            isPinned: isPinned,
            title: title
        )
    }
}

// 分类模型
@Model
final class ClipboardCategory {
    @Attribute(.unique) var name: String
    var color: String // 存储颜色的十六进制值
    var items: [ClipboardItem]?
    var sortOrder: Int // 添加排序字段
    
    init(name: String, color: String = "#0096FF", sortOrder: Int = 0) {
        self.name = name
        self.color = color
        self.items = []
        self.sortOrder = sortOrder
    }
} 