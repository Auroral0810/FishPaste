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
import ServiceManagement  // 添加 ServiceManagement 框架支持

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
    
    // 上次处理剪贴板的时间
    private var lastProcessTime: Date = Date()
    
    init() {
        // 从UserDefaults加载保存的监控间隔设置
        if let savedInterval = UserDefaults.standard.object(forKey: "monitoringInterval") as? Double {
            self.monitoringInterval = savedInterval
            print("从UserDefaults加载监控间隔设置: \(savedInterval)秒")
        }
        
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
        print("更新监控间隔: \(monitoringInterval) -> \(interval)秒")
        monitoringInterval = interval
        
        // 重置上次处理时间，使间隔更改立即生效
        lastProcessTime = Date().addingTimeInterval(-interval)
        
        if isMonitoring {
            startMonitoring() // 重启定时器以应用新间隔
        }
        
        // 保存设置到UserDefaults
        UserDefaults.standard.set(interval, forKey: "monitoringInterval")
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
        let currentTime = Date()
        
        // 只有当剪贴板变化时才处理
        if changeCount != lastChangeCount {
            // 检查距离上次处理的时间间隔是否超过设定的监控间隔
            let elapsedTime = currentTime.timeIntervalSince(lastProcessTime)
            
            // 如果间隔不足，则不处理此次变化
            if elapsedTime < monitoringInterval {
                print("监测到变化但间隔小于\(monitoringInterval)秒 (实际\(elapsedTime)秒)，忽略此次变化")
                // 仅更新changeCount，但不处理内容
                lastChangeCount = changeCount
                return
            }
            
            // 更新上次处理时间和changeCount
            lastProcessTime = currentTime
            lastChangeCount = changeCount
            
            // 处理剪贴板内容
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
        
        // 处理剪贴板中的图片和文件 - 重新实现
        let pasteboardTypes = pasteboard.types ?? []
        print("剪贴板包含以下类型: \(pasteboardTypes)")
        
        // 首先检查是否有文件URL
        var multipleFiles: [URL] = []
        
        do {
            let options: [NSPasteboard.ReadingOptionKey: Any] = [
                .urlReadingContentsConformToTypes: ["public.item"],
                .urlReadingFileURLsOnly: true
            ]
            
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
                for url in urls {
                    if let safeURL = URL(string: url.absoluteString), safeURL.isFileURL {
                        if FileManager.default.fileExists(atPath: safeURL.path) {
                            multipleFiles.append(safeURL)
                            print("添加文件URL: \(safeURL.lastPathComponent)")
                        }
                    }
                }
            }
        } catch {
            print("读取剪贴板URL时出错: \(error.localizedDescription)")
        }
        
        // 如果有文件，处理文件
        if !multipleFiles.isEmpty {
            // 检测到多个文件
            if multipleFiles.count > 1 {
                print("检测到\(multipleFiles.count)个文件，将分别保存")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 触发状态栏图标旋转动画
                    NotificationCenter.default.post(
                        name: Notification.Name("ClipboardContentChanged"),
                        object: nil
                    )
                    
                    // 为每个文件创建单独的剪贴板内容
                    for (index, fileURL) in multipleFiles.enumerated() {
                        let fileName = fileURL.lastPathComponent
                        
                        // 使用专用方法获取文件图标
                        let fileIcon = self.getFileIconOrPreview(for: fileURL)
                        
                        // 创建剪贴板内容
                        let fileContent = ClipboardContent(
                            id: UUID(),
                            text: fileName,
                            image: fileIcon,
                            fileURLs: [fileURL],
                            timestamp: Date().addingTimeInterval(Double(-index) * 0.1)
                        )
                        
                        // 添加到历史记录
                        if !self.clipboardHistory.contains(where: { $0.isEqual(to: fileContent) }) {
                            self.clipboardHistory.insert(fileContent, at: 0)
                            print("保存文件 '\(fileName)' 为单独剪贴板项，图标类型: \(fileIcon.size)")
                            
                            // 保存到数据库
                            if self.modelContext != nil {
                                self.saveToDatabase(fileContent)
                            } else {
                                print("错误: 无法保存到数据库，模型上下文为nil")
                            }
                        }
                    }
                    
                    // 更新当前剪贴板内容为第一个文件
                    if let firstURL = multipleFiles.first {
                        self.currentClipboardContent = ClipboardContent(
                            id: UUID(),
                            text: firstURL.lastPathComponent,
                            image: self.getFileIconOrPreview(for: firstURL),
                            fileURLs: [firstURL]
                        )
                    }
                }
                
                return // 已处理完成，直接返回
            } else if multipleFiles.count == 1 {
                // 单个文件处理
                let fileURL = multipleFiles[0]
                content.text = fileURL.lastPathComponent
                content.fileURLs = [fileURL]
                content.image = getFileIconOrPreview(for: fileURL)
                hasContent = true
                print("保存单个文件: \(fileURL.lastPathComponent)，使用适当的文件图标")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 触发图标旋转动画
                    NotificationCenter.default.post(
                        name: Notification.Name("ClipboardContentChanged"),
                        object: nil
                    )
                    
                    self.currentClipboardContent = content
                    
                    // 避免重复添加相同内容
                    if !self.clipboardHistory.contains(where: { $0.isEqual(to: content) }) {
                        self.clipboardHistory.insert(content, at: 0)
                        
                        // 保存到数据库
                        if self.modelContext != nil {
                            self.saveToDatabase(content)
                        }
                    }
                }
                
                return // 已处理完成，直接返回
            }
        }
        
        // 如果没有文件，检查是否有图片
        var multipleImages: [NSImage] = []
        
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
        
        // 方法2: 仅在方法1未找到图片时，遍历所有pasteboard项目
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
                    NSPasteboard.PasteboardType("public.image")
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
        
        // 处理检测到的图片
        if !multipleImages.isEmpty {
            // 如果有多张图片，将它们作为单独的剪贴板内容保存
            if multipleImages.count > 1 {
                print("检测到\(multipleImages.count)张图片，将分别保存")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 触发状态栏图标旋转动画
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
                            text: imageName,
                            image: img,
                            timestamp: Date().addingTimeInterval(Double(-index) * 0.1)
                        )
                        
                        // 添加到历史记录
                        if !self.clipboardHistory.contains(where: { $0.isEqual(to: singleImageContent) }) {
                            self.clipboardHistory.insert(singleImageContent, at: 0)
                            
                            // 保存到数据库
                            if self.modelContext != nil {
                                self.saveToDatabase(singleImageContent)
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
                
                return
            } else {
                // 单张图片处理
                let imageName = "图片_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: ":", with: "-"))"
                content.text = imageName
                content.image = multipleImages[0]
                hasContent = true
                print("最终: 保存一张图片到内容中: \(imageName)")
            }
        }
        
        // 如果有内容，则更新当前剪贴板内容并添加到历史记录
        if hasContent {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 触发状态栏图标旋转动画
                NotificationCenter.default.post(
                    name: Notification.Name("ClipboardContentChanged"),
                    object: nil
                )
                
                self.currentClipboardContent = content
                
                // 避免重复添加相同内容
                if !self.clipboardHistory.contains(where: { $0.isEqual(to: content) }) {
                    self.clipboardHistory.insert(content, at: 0)
                    
                    // 保存到数据库
                    if self.modelContext != nil {
                        self.saveToDatabase(content)
                    }
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
        let path = url.path
        
        // 检查是否是目录
        if isDirectory(at: path) {
            let folderIcon = NSWorkspace.shared.icon(forFile: path)
            folderIcon.size = NSSize(width: 64, height: 64)
            return folderIcon
        }
        
        // 始终返回文件关联的应用程序图标 - 不再返回图片内容
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        
        return icon
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
        
        // 设置或移除登录项
        setLaunchAtStartup(launchAtStartup)
    }
    
    // 设置随系统启动
    func setLaunchAtStartup(_ enable: Bool) {
        // 获取应用的 Bundle ID
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("无法获取应用 Bundle ID")
            notifyUser(title: "设置失败", message: "无法获取应用标识符")
            return
        }
        
        if #available(macOS 13.0, *) {
            // 使用 macOS 13 及以上版本的新 API
            Task {
                do {
                    let service = SMAppService.mainApp
                    
                    // 获取当前状态
                    let currentStatus = service.status
                    print("当前登录项状态: \(currentStatus)")
                    
                    if enable {
                        // 注册为登录项
                        if currentStatus != .enabled {
                            try service.register()
                            print("已成功将应用设置为随系统启动")
                            notifyUser(title: "设置成功", message: "已将应用设置为随系统启动")
                        } else {
                            print("应用已设置为随系统启动")
                        }
                    } else {
                        // 取消注册为登录项
                        if currentStatus == .enabled {
                            try service.unregister()
                            print("已成功取消应用随系统启动设置")
                            notifyUser(title: "设置已关闭", message: "已取消应用随系统启动设置")
                        } else {
                            print("应用未设置为随系统启动")
                        }
                    }
                } catch {
                    print("设置登录项失败: \(error.localizedDescription)")
                    notifyUser(title: "设置失败", message: "无法\(enable ? "启用" : "禁用")随系统启动功能: \(error.localizedDescription)")
                }
            }
        } else {
            // 使用老版本的 API（已废弃但向后兼容）
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, enable)
            if success {
                print(enable ? "已成功将应用设置为随系统启动" : "已成功取消应用随系统启动设置")
                notifyUser(title: enable ? "设置成功" : "设置已关闭", 
                           message: enable ? "已将应用设置为随系统启动" : "已取消应用随系统启动设置")
            } else {
                print("设置登录项失败")
                notifyUser(title: "设置失败", message: "无法\(enable ? "启用" : "禁用")随系统启动功能")
            }
        }
    }
    
    // 显示用户通知
    private func notifyUser(title: String, message: String) {
        DispatchQueue.main.async {
            let center = NSUserNotificationCenter.default
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName
            center.deliver(notification)
        }
    }
    
    // 复制多个项目到剪贴板
    func copyMultipleToClipboard(_ items: [ClipboardContent]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var success = false
        
        // 收集所有文本内容
        let texts = items.compactMap { $0.text }.joined(separator: "\n")
        if !texts.isEmpty {
            success = pasteboard.setString(texts, forType: .string)
            print("已复制\(items.count)个文本到剪贴板")
        }
        
        // 收集所有图片
        let images = items.compactMap { $0.image }
        if !images.isEmpty {
            // 创建安全拷贝
            let safeImages = images.compactMap { image -> NSImage? in
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]),
                   let safeImage = NSImage(data: pngData) {
                    return safeImage
                }
                return nil
            }
            
            if !safeImages.isEmpty {
                success = pasteboard.writeObjects(safeImages)
                print("已复制\(safeImages.count)个图片到剪贴板")
            }
        }
        
        // 收集所有文件URL
        let allURLs = items.compactMap { $0.fileURLs }.flatMap { $0 }
        let validURLs = allURLs.filter { url in url.isFileURL && FileManager.default.fileExists(atPath: url.path) }
        
        if !validURLs.isEmpty {
            success = pasteboard.writeObjects(validURLs as [NSURL])
            print("已复制\(validURLs.count)个文件到剪贴板")
        }
        
        // 触发状态栏图标旋转动画
        NotificationCenter.default.post(
            name: Notification.Name("ClipboardContentChanged"),
            object: nil
        )
    }
    
    // 创建单个项目的NSItemProvider - 从StatusBarMenuView移动到ClipboardManager
    func createItemProvider(from item: ClipboardContent) -> NSItemProvider {
        let provider = NSItemProvider()
        
        // 处理文本内容
        if let text = item.text {
            provider.registerDataRepresentation(forTypeIdentifier: kUTTypePlainText as String, 
                                              visibility: .all) { completion in
                completion(text.data(using: .utf8), nil)
                return nil
            }
        }
        
        // 处理图片内容
        if let image = item.image, let tiffData = image.tiffRepresentation {
            provider.registerDataRepresentation(forTypeIdentifier: kUTTypeTIFF as String,
                                              visibility: .all) { completion in
                completion(tiffData, nil)
                return nil
            }
        }
        
        // 处理文件内容 - 直接拖放文件而不是路径
        if let urls = item.fileURLs, !urls.isEmpty {
            // 遍历所有文件URL并添加它们
            for url in urls {
                if FileManager.default.fileExists(atPath: url.path) {
                    // 对于每个存在的文件，创建一个内容类型的provider
                    let contentProvider = NSItemProvider(contentsOf: url)
                    
                    // 如果创建成功，就使用这个provider代替原来的
                    if let contentProvider = contentProvider {
                        return contentProvider
                    }
                }
            }
        }
        
        return provider
    }
    
    // 创建多个项目的NSItemProvider - 从StatusBarMenuView移动到ClipboardManager
    func createMultiItemsProvider(from items: [ClipboardContent]) -> NSItemProvider {
        let provider = NSItemProvider()
        
        // 收集所有文本内容
        let texts = items.compactMap { $0.text }.joined(separator: "\n")
        if !texts.isEmpty {
            provider.registerDataRepresentation(forTypeIdentifier: kUTTypePlainText as String,
                                              visibility: .all) { completion in
                completion(texts.data(using: .utf8), nil)
                return nil
            }
        }
        
        // 处理图片 - 只使用第一张图片
        if let firstImage = items.compactMap({ $0.image }).first,
           let tiffData = firstImage.tiffRepresentation {
            provider.registerDataRepresentation(forTypeIdentifier: kUTTypeTIFF as String,
                                              visibility: .all) { completion in
                completion(tiffData, nil)
                return nil
            }
        }
        
        // 处理文件 - 查找所有选中项目中的文件
        let allFileURLs = items.compactMap { $0.fileURLs }.flatMap { $0 }
        if let firstURL = allFileURLs.first,
           FileManager.default.fileExists(atPath: firstURL.path) {
            // 创建基于URL内容的provider
            let contentProvider = NSItemProvider(contentsOf: firstURL)
            if let contentProvider = contentProvider {
                return contentProvider
            }
        }
        
        return provider
    }
} 