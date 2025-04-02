//
//  ClipboardManager.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import Combine
import SwiftData
import AppKit
import UniformTypeIdentifiers  // 添加 UTType 支持

// 剪贴板管理器：负责监控系统剪贴板变化和管理历史记录
class ClipboardManager: ObservableObject {
    // 发布最新的剪贴板内容
    @Published var currentClipboardContent: ClipboardContent?
    // 剪贴板历史记录
    @Published var clipboardHistory: [ClipboardContent] = []
    // 选择的项目
    @Published var selectedItems: Set<UUID> = []
    // 监控状态
    @Published var isMonitoring: Bool = true
    // 监控间隔（秒）
    @AppStorage("monitoringInterval") var monitoringInterval: Double = 0.5
    
    // SwiftData模型上下文
    private var modelContext: ModelContext?
    
    // 定时器用于定期检查剪贴板
    private var timer: Timer?
    // 当前剪贴板数据的校验和，用于检测变化
    private var lastChangeCount: Int = 0
    
    init() {
        // 启动剪贴板监控
        startMonitoring()
        
        // 加载测试数据（当真实数据库连接后可以移除）
        loadDemoData()
    }
    
    // 设置模型上下文
    func setModelContext(_ context: ModelContext) {
        print("设置ModelContext: \(context)")
        self.modelContext = context
        
        // 等待主线程队列执行完毕后再加载数据，确保UI初始化完成
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 在设置上下文后尝试加载保存的数据
            self.loadSavedClipboardItems()
        }
    }
    
    // 从数据库加载保存的剪贴板项目
    private func loadSavedClipboardItems() {
        guard let modelContext = modelContext else {
            print("警告: 无法加载保存的剪贴板项目，模型上下文未初始化")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<ClipboardItem>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let savedItems = try modelContext.fetch(descriptor)
            
            if !savedItems.isEmpty {
                print("从数据库加载了 \(savedItems.count) 个剪贴板项目")
                
                // 清除演示数据并加载实际保存的数据
                clipboardHistory.removeAll()
                
                // 将保存的项目转换为ClipboardContent对象并添加到历史记录
                for item in savedItems {
                    let content = item.toClipboardContent()
                    clipboardHistory.append(content)
                }
            } else {
                print("数据库中没有保存的剪贴板项目")
            }
        } catch {
            print("加载保存的剪贴板项目时出错: \(error.localizedDescription)")
        }
    }
    
    // 临时加载一些演示数据
    private func loadDemoData() {
        let now = Date()
        clipboardHistory.append(ClipboardContent(id: UUID(), text: "* 支持无限历史记录\n* 提供智能分类功能...", timestamp: now.addingTimeInterval(-60)))
        clipboardHistory.append(ClipboardContent(id: UUID(), text: "剪切板和复制的历史记录保持。因为我发现macos无法像windows一样打开历史剪切板", timestamp: now.addingTimeInterval(-120)))
        clipboardHistory.append(ClipboardContent(id: UUID(), text: "ardItem.self, // 使用新的剪贴板项目模型", timestamp: now.addingTimeInterval(-180)))
        clipboardHistory.append(ClipboardContent(id: UUID(), text: "https://github.com/example/clipboard-history", timestamp: now.addingTimeInterval(-240)))
    }
    
    // 开始监控剪贴板变化
    func startMonitoring() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        
        isMonitoring = true
        
        // 设置定时检查
        timer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    // 停止监控剪贴板
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }
    
    // 设置监控间隔
    func setMonitoringInterval(_ interval: Double) {
        monitoringInterval = interval
        if isMonitoring {
            startMonitoring() // 重启定时器以应用新间隔
        }
    }
    
    // 打开设置
    func showSettings() {
        // 创建并显示设置窗口
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.center()
        settingsWindow.title = "FishCopy 设置"
        
        // 创建设置视图
        let settingsView = SettingsView(clipboardManager: self)
        
        // 设置窗口内容
        let hostingView = NSHostingView(rootView: settingsView)
        settingsWindow.contentView = hostingView
        
        // 显示窗口
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用以防止过早释放
        FishCopyApp.activeWindows.append(settingsWindow)
    }
    
    // 检查剪贴板是否有新内容
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        
        // 只有当剪贴板变化时才处理
        if changeCount != lastChangeCount {
            lastChangeCount = changeCount
            processClipboardContent(pasteboard)
        }
    }
    
    // 处理剪贴板内容
    private func processClipboardContent(_ pasteboard: NSPasteboard) {
        print("开始处理剪贴板内容")
        
        // 检查模型上下文是否初始化
        if modelContext == nil {
            print("警告: 模型上下文未初始化，尝试延迟处理")
            // 延迟100ms后重试，希望此时上下文已初始化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.processClipboardContent(pasteboard)
            }
            return
        }
        
        // 创建新的剪贴板内容对象
        let content = ClipboardContent(id: UUID())
        var hasContent = false
        
        // 安全地检查文本
        if let text = pasteboard.string(forType: .string) {
            content.text = text
            hasContent = true
            print("已获取文本内容")
        }
        
        // 处理剪贴板中的图片和文件 - 完全重新实现
        var multipleImages: [NSImage] = []
        var multipleFiles: [(URL, NSImage?)] = [] // 文件URL和对应的预览图（如果有）
        let pasteboardTypes = pasteboard.types ?? []
        
        print("剪贴板包含以下类型: \(pasteboardTypes)")
        
        // 读取文件URL - 处理文件拖拽和复制的情况
        do {
            let options: [NSPasteboard.ReadingOptionKey: Any] = [
                .urlReadingContentsConformToTypes: ["public.item"],
                .urlReadingFileURLsOnly: true
            ]
            
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
                // 创建URL的深拷贝并处理每个文件
                for url in urls {
                    if let safeURL = URL(string: url.absoluteString), safeURL.isFileURL {
                        let isImage = isImageFile(safeURL.path)
                        
                        // 获取文件预览图和类型描述
                        let preview = getFileIconOrPreview(for: safeURL)
                        let fileTypeDesc = getFileTypeDescription(for: safeURL)
                        let fileName = safeURL.lastPathComponent
                        
                        multipleFiles.append((safeURL, preview))
                        print("添加文件: \(fileName) 到文件列表，类型: \(fileTypeDesc)")
                    }
                }
                
                // 如果有多个文件，分别存储每个文件
                if multipleFiles.count > 1 {
                    print("检测到\(multipleFiles.count)个文件，将分别保存")
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // 触发一次状态栏图标旋转动画
                        print("检测到新复制内容，发送剪贴板变化通知")
                        NotificationCenter.default.post(
                            name: Notification.Name("ClipboardContentChanged"),
                            object: nil
                        )
                        
                        // 为每个文件创建单独的剪贴板内容
                        for (index, (fileURL, preview)) in multipleFiles.enumerated() {
                            let fileName = fileURL.lastPathComponent
                            let fileTypeDesc = getFileTypeDescription(for: fileURL)
                            
                            // 组合文本：文件名 + 类型描述
                            let displayText = fileName
                            
                            let fileContent = ClipboardContent(
                                id: UUID(),
                                text: displayText,  // 使用文件名作为文本内容
                                image: preview,     // 使用文件预览或图标
                                fileURLs: [fileURL],
                                timestamp: Date().addingTimeInterval(Double(-index) * 0.1) // 稍微错开时间戳
                            )
                            
                            // 添加到历史记录
                            if !self.clipboardHistory.contains(where: { $0.isEqual(to: fileContent) }) {
                                self.clipboardHistory.insert(fileContent, at: 0)
                                print("保存文件 '\(fileName)' 为单独剪贴板项")
                                
                                // 保存到数据库
                                if self.modelContext != nil {
                                    self.saveToDatabase(fileContent)
                                } else {
                                    print("错误: 无法保存到数据库，模型上下文为nil")
                                }
                            }
                        }
                        
                        // 更新当前剪贴板内容为第一个文件
                        if let (firstURL, firstPreview) = multipleFiles.first {
                            self.currentClipboardContent = ClipboardContent(
                                id: UUID(),
                                text: firstURL.lastPathComponent,
                                image: firstPreview,
                                fileURLs: [firstURL]
                            )
                        }
                    }
                    
                    return
                } else if multipleFiles.count == 1 {
                    // 单个文件，常规处理
                    let (fileURL, preview) = multipleFiles[0]
                    content.text = fileURL.lastPathComponent  // 使用文件名作为文本
                    content.image = preview // 设置文件预览
                    content.fileURLs = [fileURL]
                    hasContent = true
                    print("保存单个文件: \(fileURL.lastPathComponent)")
                    
                    // 如果是图片文件，不需要继续处理图片内容
                    if isImageFile(fileURL.path) {
                        multipleImages = [] // 清空图片数组，避免重复处理
                    }
                }
            }
        } catch {
            print("读取剪贴板URL时出错: \(error.localizedDescription)")
        }

        // 如果没有检测到文件，继续处理可能的图片内容
        if multipleFiles.isEmpty {
            // 方法1: 尝试使用readObjects获取所有图片
            if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !images.isEmpty {
                print("方法1: 通过readObjects获取到\(images.count)张图片")
                for (index, image) in images.enumerated() {
                    if let safeImage = createSafeImage(from: image) {
                        multipleImages.append(safeImage)
                        print("方法1: 添加第\(index + 1)张图片")
                    }
                }
            }
            
            // 方法2: 遍历所有pasteboard项目
            if multipleImages.isEmpty, let items = pasteboard.pasteboardItems, !items.isEmpty {
                print("方法2: 发现\(items.count)个剪贴板项目")
                for (index, item) in items.enumerated() {
                    let itemTypes = item.types
                    print("方法2: 第\(index + 1)个剪贴板项目包含类型: \(itemTypes)")
                    
                    // 尝试所有可能的图片类型
                    let imageTypes: [NSPasteboard.PasteboardType] = [
                        .tiff, .png, 
                        NSPasteboard.PasteboardType("public.jpeg"),
                        NSPasteboard.PasteboardType("com.adobe.pdf"), 
                        NSPasteboard.PasteboardType("public.image"),
                        NSPasteboard.PasteboardType("com.apple.pict")
                    ]
                    
                    for type in imageTypes {
                        if itemTypes.contains(type), let imgData = item.data(forType: type) {
                            print("方法2: 从第\(index + 1)个项目获取到\(type)类型数据")
                            if let image = NSImage(data: imgData), let safeImage = createSafeImage(from: image) {
                                if !isDuplicateImage(safeImage, in: multipleImages) {
                                    multipleImages.append(safeImage)
                                    print("方法2: 添加来自第\(index + 1)个项目的\(type)类型图片")
                                }
                            }
                        }
                    }
                }
            }
            
            // 方法3: 最后尝试通过通用方法获取图片
            if multipleImages.isEmpty {
                print("方法3: 尝试通过通用方法获取图片")
                if let image = NSImage(pasteboard: pasteboard), let safeImage = createSafeImage(from: image) {
                    multipleImages.append(safeImage)
                    print("方法3: 获取到一张图片")
                }
            }
            
            // 处理检测到的图片
            if !multipleImages.isEmpty {
                // 如果有多张图片，将它们作为单独的剪贴板内容保存
                if multipleImages.count > 1 {
                    print("检测到\(multipleImages.count)张图片，将分别保存")
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // 触发一次状态栏图标旋转动画
                        print("检测到新复制内容，发送剪贴板变化通知")
                        NotificationCenter.default.post(
                            name: Notification.Name("ClipboardContentChanged"),
                            object: nil
                        )
                        
                        // 为每张图片创建单独的剪贴板内容
                        for (index, img) in multipleImages.enumerated() {
                            // 创建图片名称
                            let imageName = "图片_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: ":", with: "-"))_\(index+1)"
                            
                            let singleImageContent = ClipboardContent(
                                id: UUID(),
                                text: imageName, // 使用图片名称
                                image: img,
                                timestamp: Date().addingTimeInterval(Double(-index) * 0.1) // 稍微错开时间戳
                            )
                            
                            // 添加到历史记录
                            if !self.clipboardHistory.contains(where: { $0.isEqual(to: singleImageContent) }) {
                                self.clipboardHistory.insert(singleImageContent, at: 0)
                                print("保存第\(index + 1)张图片为单独剪贴板项: \(imageName)")
                                
                                // 保存到数据库
                                if self.modelContext != nil {
                                    self.saveToDatabase(singleImageContent)
                                } else {
                                    print("错误: 无法保存到数据库，模型上下文为nil")
                                }
                            }
                        }
                        
                        // 更新当前剪贴板内容为第一张图片
                        let imageName = "图片_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: ":", with: "-"))_1"
                        self.currentClipboardContent = ClipboardContent(
                            id: UUID(),
                            text: imageName,
                            image: multipleImages.first
                        )
                    }
                    
                    // 直接返回，后续处理已完成
                    return
                } else {
                    // 单张图片正常处理
                    let imageName = "图片_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: ":", with: "-"))"
                    content.text = imageName // 使用图片名称
                    content.image = multipleImages[0]
                    hasContent = true
                    print("最终: 保存一张图片到内容中: \(imageName)")
                }
            }
        }
        
        // 如果有内容，则更新当前剪贴板内容并添加到历史记录
        if hasContent {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 触发状态栏图标旋转动画
                print("检测到新复制内容，发送剪贴板变化通知")
                NotificationCenter.default.post(
                    name: Notification.Name("ClipboardContentChanged"),
                    object: nil
                )
                
                self.currentClipboardContent = content
                // 避免重复添加相同内容
                if !self.clipboardHistory.contains(where: { $0.isEqual(to: content) }) {
                    self.clipboardHistory.insert(content, at: 0)
                    print("将新内容添加到历史记录，当前历史记录数量: \(self.clipboardHistory.count)")
                    // 保存到数据库
                    if self.modelContext != nil {
                        self.saveToDatabase(content)
                    } else {
                        print("错误: 无法保存到数据库，模型上下文为nil")
                    }
                } else {
                    print("内容已存在于历史记录中，不添加")
                }
            }
        } else {
            print("剪贴板中没有检测到有效内容")
        }
    }
    
    // 辅助方法: 创建安全图像拷贝
    private func createSafeImage(from image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return NSImage(data: pngData)
    }
    
    // 辅助方法: 检查图像是否重复
    private func isDuplicateImage(_ newImage: NSImage, in existingImages: [NSImage]) -> Bool {
        guard let newTiff = newImage.tiffRepresentation else {
            return false
        }
        
        for existingImage in existingImages {
            if let existingTiff = existingImage.tiffRepresentation,
               newTiff == existingTiff {
                return true
            }
        }
        return false
    }
    
    // 辅助方法: 检查文件是否是图片
    private func isImageFile(_ path: String) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic"]
        let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        return imageExtensions.contains(pathExtension)
    }
    
    // 辅助方法: 检查路径是否是目录
    private func isDirectory(at path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
    
    // 辅助方法: 获取文件图标或预览
    private func getFileIconOrPreview(for url: URL) -> NSImage {
        let fileExtension = url.pathExtension.lowercased()
        let path = url.path
        
        // 检查是否是图片文件
        if isImageFile(path) {
            // 对于图片文件，尝试读取内容作为预览
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        
        // 如果是文件夹，使用文件夹图标
        if isDirectory(at: path) {
            return NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
        }
        
        // 为常见文件类型明确指定图标
        switch fileExtension {
        case "pdf":
            return NSWorkspace.shared.icon(forFileType: "com.adobe.pdf")
        case "doc", "docx":
            return NSWorkspace.shared.icon(forFileType: "com.microsoft.word.doc")
        case "xls", "xlsx":
            return NSWorkspace.shared.icon(forFileType: "com.microsoft.excel.xls")
        case "ppt", "pptx":
            return NSWorkspace.shared.icon(forFileType: "com.microsoft.powerpoint.ppt")
        case "txt":
            return NSWorkspace.shared.icon(forFileType: "public.plain-text")
        case "zip", "rar", "7z", "tar", "gz":
            return NSWorkspace.shared.icon(forFileType: "public.archive")
        default:
            // 使用文件本身的图标
            let icon = NSWorkspace.shared.icon(forFile: path)
            // 设置一个合适的大小
            icon.size = NSSize(width: 64, height: 64)
            return icon
        }
    }
    
    // 辅助方法: 获取文件类型描述
    private func getFileTypeDescription(for url: URL) -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        // 文件类型和描述的映射
        let fileTypeMap: [String: String] = [
            // 文档类型
            "pdf": "PDF 文档",
            "doc": "Word 文档",
            "docx": "Word 文档",
            "xls": "Excel 表格",
            "xlsx": "Excel 表格",
            "ppt": "PowerPoint 演示文稿",
            "pptx": "PowerPoint 演示文稿",
            "txt": "文本文件",
            "rtf": "富文本文件",
            "md": "Markdown 文件",
            
            // 图片类型
            "jpg": "JPEG 图片",
            "jpeg": "JPEG 图片",
            "png": "PNG 图片",
            "gif": "GIF 图片",
            "bmp": "BMP 图片",
            "tiff": "TIFF 图片",
            "webp": "WebP 图片",
            "heic": "HEIC 图片",
            
            // 压缩文件
            "zip": "ZIP 压缩文件",
            "rar": "RAR 压缩文件",
            "7z": "7z 压缩文件",
            "tar": "TAR 归档文件",
            "gz": "GZ 压缩文件",
            
            // 代码和开发文件
            "swift": "Swift 源文件",
            "java": "Java 源文件",
            "py": "Python 源文件",
            "js": "JavaScript 源文件",
            "html": "HTML 文件",
            "css": "CSS 样式表",
            "json": "JSON 数据文件",
            "xml": "XML 数据文件",
            
            // 多媒体文件
            "mp3": "MP3 音频文件",
            "mp4": "MP4 视频文件",
            "mov": "QuickTime 视频",
            "avi": "AVI 视频文件",
            "wav": "WAV 音频文件",
            
            // 其他常见类型
            "app": "应用程序",
            "dmg": "磁盘映像文件",
            "iso": "ISO 镜像文件"
        ]
        
        // 返回匹配的文件类型描述，或使用默认格式
        if let typeDescription = fileTypeMap[fileExtension] {
            return typeDescription
        } else if fileExtension.isEmpty {
            // 没有扩展名的文件
            return "无扩展名文件"
        } else {
            // 未知扩展名，以大写形式显示
            return "\(fileExtension.uppercased()) 文件"
        }
    }
    
    // 保存剪贴板内容到数据库
    private func saveToDatabase(_ content: ClipboardContent) {
        guard let modelContext = modelContext else { 
            print("警告: 模型上下文未初始化，数据未保存") 
            return 
        }
        
        // 安全处理单个图像数据
        var imageData: Data? = nil
        if let image = content.image {
            // 尝试获取更可靠的PNG表示而非TIFF
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                imageData = pngData
            }
        }
        
        // 处理多个图像数据
        var imagesData: [Data]? = nil
        if let images = content.images, !images.isEmpty {
            imagesData = []
            for img in images {
                if let tiffData = img.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    imagesData?.append(pngData)
                }
            }
            if imagesData!.isEmpty {
                imagesData = nil
            }
        }
        
        // 将ClipboardContent转换为可存储的ClipboardItem
        let clipboardItem = ClipboardItem(
            id: content.id,
            textContent: content.text,
            imageData: imageData,
            imagesData: imagesData,
            fileURLStrings: content.fileURLs?.map { $0.absoluteString },
            category: content.category,
            timestamp: content.timestamp,
            isPinned: content.isPinned
        )
        
        // 保存到数据库
        modelContext.insert(clipboardItem)
        
        // 尝试立即保存更改
        do {
            try modelContext.save()
            print("成功保存剪贴板项到数据库")
        } catch {
            print("错误: 保存数据时出错: \(error.localizedDescription)")
        }
    }
    
    // 从剪贴板历史中复制项目到当前剪贴板
    func copyToClipboard(_ content: ClipboardContent) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var success = false
        
        // 优先复制多图片（如果存在）
        if let images = content.images, !images.isEmpty {
            do {
                // 将所有图片转换为安全的NSImage对象
                var safeImages: [NSImage] = []
                
                for image in images {
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]),
                       let safeImage = NSImage(data: pngData) {
                        safeImages.append(safeImage)
                    }
                }
                
                if !safeImages.isEmpty {
                    print("正在复制\(safeImages.count)张图片到剪贴板")
                    success = pasteboard.writeObjects(safeImages)
                    if !success {
                        print("警告: 无法复制多张图片到剪贴板")
                    } else {
                        print("成功复制多张图片到剪贴板")
                        
                        // 触发状态栏图标旋转动画
                        NotificationCenter.default.post(
                            name: Notification.Name("ClipboardContentChanged"),
                            object: nil
                        )
                        
                        return // 成功复制多张图片后直接返回
                    }
                }
            } catch {
                print("复制多张图片到剪贴板时出错: \(error.localizedDescription)")
            }
        }
        
        // 安全地复制文本
        if let text = content.text {
            success = pasteboard.setString(text, forType: .string)
            if !success {
                print("警告: 无法复制文本到剪贴板")
            } else {
                print("成功复制文本到剪贴板")
            }
        }
        
        // 安全地复制单张图片
        if let image = content.image {
            do {
                // 使用PNG表示而非直接写入NSImage对象
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    
                    // 创建一个新的NSImage用于写入
                    let safeImage = NSImage(data: pngData)
                    if let safeImage = safeImage {
                        print("正在复制单张图片到剪贴板")
                        success = pasteboard.writeObjects([safeImage])
                        if !success {
                            print("警告: 无法复制图片到剪贴板")
                        } else {
                            print("成功复制单张图片到剪贴板")
                        }
                    }
                }
            } catch {
                print("复制图片到剪贴板时出错: \(error.localizedDescription)")
            }
        }
        
        // 安全地复制文件URL
        if let urls = content.fileURLs, !urls.isEmpty {
            // 确保URLs是有效的
            let validURLs = urls.filter { url in url.isFileURL && FileManager.default.fileExists(atPath: url.path) }
            
            if !validURLs.isEmpty {
                print("正在复制\(validURLs.count)个文件URL到剪贴板")
                success = pasteboard.writeObjects(validURLs as [NSURL])
                if !success {
                    print("警告: 无法复制文件URL到剪贴板")
                } else {
                    print("成功复制文件URL到剪贴板")
                }
            }
        }
        
        // 触发状态栏图标旋转动画
        print("手动复制内容，发送剪贴板变化通知")
        NotificationCenter.default.post(
            name: Notification.Name("ClipboardContentChanged"),
            object: nil
        )
    }
    
    // 清除所有历史记录
    func clearHistory() {
        clipboardHistory.removeAll()
        
        // 从数据库中清除所有项目
        guard let modelContext = modelContext else {
            print("警告: 无法清除数据库，模型上下文未初始化")
            return
        }
        
        do {
            // 获取所有剪贴板项目
            let descriptor = FetchDescriptor<ClipboardItem>()
            let allItems = try modelContext.fetch(descriptor)
            
            // 删除所有项目
            for item in allItems {
                modelContext.delete(item)
            }
            
            // 保存更改
            try modelContext.save()
            print("成功从数据库中清除了所有历史记录")
        } catch {
            print("清除数据库时出错: \(error.localizedDescription)")
        }
    }
    
    // 根据ID删除特定项目
    func deleteItems(withIDs ids: Set<UUID>) {
        clipboardHistory.removeAll(where: { ids.contains($0.id) })
        selectedItems.removeAll()
        
        // 从数据库中删除
        guard let modelContext = modelContext else {
            print("警告: 无法从数据库删除项目，模型上下文未初始化")
            return
        }
        
        do {
            // 对每个ID执行删除操作
            for id in ids {
                // 创建查询
                let predicate = #Predicate<ClipboardItem> { item in
                    item.id == id
                }
                let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
                
                // 查找项目
                if let item = try modelContext.fetch(descriptor).first {
                    // 删除项目
                    modelContext.delete(item)
                }
            }
            
            // 保存更改
            try modelContext.save()
            print("成功从数据库中删除了\(ids.count)个项目")
        } catch {
            print("从数据库删除项目时出错: \(error.localizedDescription)")
        }
    }
    
    // 根据关键词搜索历史记录
    func searchHistory(query: String) -> [ClipboardContent] {
        if query.isEmpty {
            return clipboardHistory
        }
        
        return clipboardHistory.filter { content in
            if let text = content.text, text.localizedCaseInsensitiveContains(query) {
                return true
            }
            if let urls = content.fileURLs {
                return urls.contains(where: { $0.lastPathComponent.localizedCaseInsensitiveContains(query) })
            }
            return false
        }
    }
    
    // 切换监控状态
    @objc func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    // 更新监控间隔
    @objc func updateInterval(_ sender: NSMenuItem) {
        if let interval = sender.representedObject as? Double {
            setMonitoringInterval(interval)
        }
    }
    
    // 切换启动状态
    @objc func toggleStartupLaunch() {
        let launchAtStartup = !UserDefaults.standard.bool(forKey: "launchAtStartup")
        UserDefaults.standard.set(launchAtStartup, forKey: "launchAtStartup")
        // 实际应用中，这里还应该设置启动项
    }
} 