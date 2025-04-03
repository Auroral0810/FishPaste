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
    // 音效设置
    @AppStorage("enableSoundEffects") var enableSoundEffects: Bool = true
    // 排除的应用列表
    private var excludedAppBundleIds: [String] = []
    
    // 音效对象
    private var clipboardChangedSound: NSSound?
    private var manualCopySound: NSSound?
    
    // 标记是否为内部复制操作，避免重复播放音效
    private var isInternalCopyOperation = false
    // 内部复制操作的时间戳，用于避免冲突
    private var lastInternalCopyTime: Date?
    
    // SwiftData模型上下文
    private var modelContext: ModelContext?
    
    // 定时器用于定期检查剪贴板
    private var timer: Timer?
    // 当前剪贴板数据的校验和，用于检测变化
    private var lastChangeCount: Int = 0
    
    // 上次处理剪贴板的时间
    private var lastProcessTime: Date = Date()
    
    // 上次处理的内容ID
    private var lastProcessedContentID: UUID?
    
    // 最大历史记录大小
    private let maxHistorySize: Int = 500
    
    init() {
        // 从UserDefaults加载保存的监控间隔设置
        if let savedInterval = UserDefaults.standard.object(forKey: "monitoringInterval") as? Double {
            self.monitoringInterval = savedInterval
            print("从UserDefaults加载监控间隔设置: \(savedInterval)秒")
        }
        
        // 加载排除应用列表
        loadExcludedApps()
        
        // 加载音效
        loadSoundEffects()
        
        // 启动剪贴板监控
        startMonitoring()
        
        // 加载测试数据（当真实数据库连接后可以移除）
        loadDemoData()
    }
    
    // 加载音效文件
    private func loadSoundEffects() {
        // 使用系统内置超短音效 - "Morse"作为剪贴板变化的提示音
        clipboardChangedSound = NSSound(named: "Morse")
        clipboardChangedSound?.volume = 0.3 // 降低音量以免干扰
        
        // 使用系统内置超短音效 - "Ping"作为手动复制的提示音
        manualCopySound = NSSound(named: "Ping") 
        manualCopySound?.volume = 0.4
        
        print("音效加载完成: 使用超短系统音效")
    }
    
    // 播放剪贴板变化音效
    private func playClipboardChangedSound() {
        // 如果这是一个内部复制操作或者在内部复制后的短时间内，不播放自动检测音效
        if isInternalCopyOperation || Date().timeIntervalSince(lastInternalCopyTime ?? Date()) < 1.0 {
            print("检测到内部复制操作，跳过自动检测音效")
            return
        }
        
        guard enableSoundEffects, let sound = clipboardChangedSound else { return }
        sound.stop() // 确保停止之前的播放
        sound.play()
    }
    
    // 播放手动复制音效
    private func playManualCopySound() {
        guard enableSoundEffects, let sound = manualCopySound else { return }
        sound.stop() // 确保停止之前的播放
        sound.play()
    }
    
    // 设置音效开关
    func setEnableSoundEffects(_ enable: Bool) {
        enableSoundEffects = enable
        UserDefaults.standard.set(enable, forKey: "enableSoundEffects")
        print("音效设置已更改: \(enable ? "启用" : "禁用")")
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
                    print("加载项目: id=\(content.id), text=\(content.text ?? "无文本"), isPinned=\(content.isPinned)")
                }
                
                // 添加日志以检查钉选项目
                let pinnedItems = clipboardHistory.filter { $0.isPinned }
                print("加载了 \(pinnedItems.count) 个钉选项目")
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
        // 检查是否已经有设置窗口存在
        for window in NSApplication.shared.windows {
            if window.title == "FishCopy 设置" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        
        // 创建并显示设置窗口
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.center()
        settingsWindow.title = "FishCopy 设置"
        
        // 刷新排除应用列表
        loadExcludedApps()
        
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
        
        // 剪贴板变化时处理
        if changeCount != lastChangeCount {
            // 检查当前应用是否在排除列表中
            if isCurrentAppExcluded() {
                print("当前应用在排除列表中，忽略此次剪贴板变化")
                lastChangeCount = changeCount // 更新计数器，避免重复处理
                return
            }
            
            // 检查时间间隔
            let elapsedTime = currentTime.timeIntervalSince(lastProcessTime)
            
            // 如果时间间隔不足，跳过此次处理
            if elapsedTime < monitoringInterval {
                print("监测到变化但间隔小于\(monitoringInterval)秒 (实际\(elapsedTime)秒)，忽略此次变化")
                // 仅更新changeCount，等待下次检查
                lastChangeCount = changeCount
                return
            }
            
            // 更新处理时间和计数器
            lastProcessTime = currentTime
            lastChangeCount = changeCount
            print("检测到剪贴板变化，尝试处理内容")
            
            // 如果有内部复制操作标记且超过5秒，强制重置
            if isInternalCopyOperation && (lastInternalCopyTime == nil || currentTime.timeIntervalSince(lastInternalCopyTime!) > 5.0) {
                print("内部复制标记超时，强制重置")
                isInternalCopyOperation = false
            }
            
            // 处理剪贴板内容
            processClipboardContent()
        }
    }
    
    // 确定内容类别
    private func determineContentCategory(for content: ClipboardContent) {
        // 根据内容特征设置类别
        if content.image != nil || (content.images != nil && !content.images!.isEmpty) {
            content.category = "image"
        } else if let text = content.text {
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                content.category = "url"
            } else if text.contains("\n") || text.count > 100 {
                content.category = "text"
            } else {
                content.category = "snippet"
            }
        } else if content.fileURLs != nil && !content.fileURLs!.isEmpty {
            content.category = "file"
        } else {
            content.category = "other"
        }
    }
    
    // 保存内容到数据库
    private func saveContentToDatabase(_ content: ClipboardContent) {
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
        }
        
        // 提取应用信息
        let sourceBundleID = content.sourceApp?.bundleIdentifier
        let sourceAppName = content.sourceApp?.name
        
        // 创建数据库项目
        let item = ClipboardItem(
            id: content.id,
            textContent: content.text,
            imageData: imageData,
            imagesData: imagesData,
            fileURLStrings: content.fileURLs?.map { $0.absoluteString },
            category: content.category,
            timestamp: content.timestamp,
            isPinned: content.isPinned,
            title: content.title,
            sourceAppBundleID: sourceBundleID,
            sourceAppName: sourceAppName
        )
        
        // 将项目添加到持久存储
        modelContext.insert(item)
        
        // 尝试保存更改
        do {
            try modelContext.save()
            print("成功保存新项目到数据库: id=\(content.id)")
        } catch {
            print("保存到数据库时出错: \(error.localizedDescription)")
        }
    }
    
    // 从数据库中删除项目
    private func deleteItemFromDatabase(with id: UUID) {
        guard let modelContext = modelContext else {
            print("警告: 无法删除项目，模型上下文未初始化")
            return
        }
        
        do {
            // 创建查询来找到相应的数据库记录
            let predicate = #Predicate<ClipboardItem> { item in
                item.id == id
            }
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
            
            // 尝试查找并删除项目
            if let itemToDelete = try modelContext.fetch(descriptor).first {
                modelContext.delete(itemToDelete)
                try modelContext.save()
                print("成功从数据库中删除ID为 \(id) 的项目")
            } else {
                print("警告: 在数据库中找不到ID为 \(id) 的项目")
            }
        } catch {
            print("从数据库删除项目时出错: \(error.localizedDescription)")
        }
    }
    
    // 处理剪贴板内容
    private func processClipboardContent() {
        // 重要：提前打印内部复制状态，方便调试
        print("处理剪贴板内容: 内部复制状态=\(isInternalCopyOperation)")
        
        // 如果是内部复制操作且时间在1秒内，跳过
        if isInternalCopyOperation {
            let now = Date()
            if let lastTime = lastInternalCopyTime, now.timeIntervalSince(lastTime) < 1.0 {
                print("跳过内部复制操作处理")
                return
            }
            
            // 超过1秒，重置标记
            isInternalCopyOperation = false
            print("重置内部复制标记")
        }
        
        let pasteboard = NSPasteboard.general
        
        // 获取当前活跃的应用信息
        let sourceAppInfo = getCurrentApplicationInfo()
        let sourceBundleID = sourceAppInfo.bundleIdentifier
        let sourceAppName = sourceAppInfo.name
        print("检测到内容来源应用: \(sourceAppName ?? "未知"), ID: \(sourceBundleID ?? "未知")")
        
        // === 获取文件URL ===
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !fileURLs.isEmpty {
            // 检查是否有多个不同类型的文件
            if fileURLs.count > 1 {
                // 按文件类型分组
                let filesByExtension = Dictionary(grouping: fileURLs) { url -> String in
                    return url.pathExtension.lowercased()
                }
                
                // 如果有多种不同类型的文件，为每种类型创建单独的条目
                if filesByExtension.count > 1 {
                    print("检测到\(filesByExtension.count)种不同类型的文件，创建多个条目")
                    
                    // 为每种文件类型创建单独的剪贴板条目
                    for (fileExtension, urls) in filesByExtension {
                        let content = ClipboardContent()
                        content.id = UUID()
                        content.timestamp = Date()
                        content.fileURLs = urls
                        content.sourceApp = (sourceBundleID, sourceAppName, getAppIcon(for: sourceBundleID))
                        
                        // 设置类别
                        determineContentCategory(for: content)
                        
                        // 添加到历史记录前面
                        clipboardHistory.insert(content, at: 0)
                        
                        // 保存到数据库
                        saveContentToDatabase(content)
                        
                        print("为\(fileExtension)类型创建了独立条目，包含\(urls.count)个文件")
                    }
                    
                    // 限制历史记录大小
                    limitHistorySize()
                    
                    // 播放音效
                    if !isInternalCopyOperation {
                        playClipboardChangedSound()
                    }
                    
                    // 发送通知以刷新UI
                    NotificationCenter.default.post(
                        name: Notification.Name("ClipboardContentChanged"),
                        object: nil
                    )
                    
                    return // 处理完多个文件后直接返回
                }
            }
        }
        
        // 创建剪贴板内容对象（用于单一内容类型的情况）
        let content = ClipboardContent()
        content.id = UUID()  // 生成唯一ID
        content.timestamp = Date() // 设置当前时间
        content.sourceApp = (sourceBundleID, sourceAppName, getAppIcon(for: sourceBundleID))
        
        // 标志是否找到内容
        var hasContent = false
        
        // === 获取剪贴板文本 ===
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            content.text = text
            hasContent = true
            print("从剪贴板读取文本: \(text.prefix(min(20, text.count)))...")
        }
        
        // === 获取剪贴板图片 ===
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage], !images.isEmpty {
            if images.count == 1 {
                content.image = images[0]
            } else {
                content.images = images
            }
            hasContent = true
            print("从剪贴板读取\(images.count)张图片")
        }
        
        // === 获取文件URL（单一类型或单个文件的情况）===
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !fileURLs.isEmpty {
            content.fileURLs = fileURLs
            hasContent = true
            print("从剪贴板读取\(fileURLs.count)个文件URL")
        }
        
        // 如果找到内容，添加到历史记录
        if hasContent {
            // 检查是否已经存在相同内容（只检查最近10条记录提高性能）
            let isDuplicate = clipboardHistory.prefix(10).contains { existingContent in
                // 1. 检查ID
                if existingContent.id == content.id {
                    return true
                }
                
                // 2. 检查文本
                if let newText = content.text, let existingText = existingContent.text, newText == existingText {
                    print("检测到重复文本，跳过添加")
                    return true
                }
                
                // 3. 简单检查图片 - 只比较第一张图片尺寸
                if let newImage = content.image, let existingImage = existingContent.image,
                   abs(newImage.size.width - existingImage.size.width) < 1 &&
                   abs(newImage.size.height - existingImage.size.height) < 1 {
                    print("检测到可能重复图片，跳过添加")
                    return true
                }
                
                return false
            }
            
            if !isDuplicate {
                print("添加新内容到历史记录")
                
                // 设置类别
                determineContentCategory(for: content)
                
                // 添加到历史记录前面
                clipboardHistory.insert(content, at: 0)
                
                // 保存到数据库
                saveContentToDatabase(content)
                
                // 限制历史记录大小
                limitHistorySize()
                
                // 播放音效
                if !isInternalCopyOperation {
                    playClipboardChangedSound()
                }
                
                // 更新最后处理的内容ID
                lastProcessedContentID = content.id
                
                // 发送通知以刷新UI
                NotificationCenter.default.post(
                    name: Notification.Name("ClipboardContentChanged"),
                    object: nil
                )
            } else {
                print("跳过添加重复内容")
            }
        } else {
            print("未发现可添加内容")
        }
    }
    
    // 限制历史记录大小的辅助方法
    private func limitHistorySize() {
        if clipboardHistory.count > maxHistorySize {
            // 移除非钉选的最旧项目
            let nonPinnedItems = clipboardHistory.filter { !$0.isPinned }
            if let oldestNonPinned = nonPinnedItems.last {
                if let index = clipboardHistory.firstIndex(where: { $0.id == oldestNonPinned.id }) {
                    // 从内存中移除
                    let removedItem = clipboardHistory.remove(at: index)
                    
                    // 从数据库中删除
                    deleteItemFromDatabase(with: removedItem.id)
                }
            }
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
    
    // 复制多个项目到剪贴板
    func copyMultipleToClipboard(_ items: [ClipboardContent]) {
        // 设置内部复制标志，避免自我检测
        isInternalCopyOperation = true
        lastInternalCopyTime = Date()
        
        // 收集所有文本、图片和文件URL
        var allTexts: [String] = []
        var allImages: [NSImage] = []
        var allFileURLs: [URL] = []
        
        for item in items {
            if let text = item.text, !text.isEmpty {
                // 确保没有重复的文本
                if !allTexts.contains(text) {
                    allTexts.append(text)
                }
            }
            
            if let image = item.image {
                // 创建图像的安全副本
                if let safeImage = createSafeImage(from: image) {
                    allImages.append(safeImage)
                }
            }
            
            if let images = item.images, !images.isEmpty {
                for img in images {
                    if let safeImage = createSafeImage(from: img) {
                        allImages.append(safeImage)
                    }
                }
            }
            
            if let fileURLs = item.fileURLs, !fileURLs.isEmpty {
                // 过滤有效的文件URL
                let validURLs = fileURLs.filter { url in
                    let path = url.path
                    return FileManager.default.fileExists(atPath: path)
                }
                allFileURLs.append(contentsOf: validURLs)
            }
        }
        
        // 准备保存结果
        let combinedItem = ClipboardContent(id: UUID())
        var success = false
        
        // 方法1: 尝试一次性写入所有对象
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // 如果只有文本，优先使用纯文本格式
        if !allTexts.isEmpty && allImages.isEmpty && allFileURLs.isEmpty {
            let combinedText = allTexts.joined(separator: "\n\n----------\n\n")
            pasteboard.setString(combinedText, forType: .string)
            combinedItem.text = combinedText
            success = true
            print("方法1: 成功写入\(allTexts.count)个文本到剪贴板")
        }
        // 如果只有图片，优先使用图片格式
        else if allTexts.isEmpty && !allImages.isEmpty && allFileURLs.isEmpty {
            let result = pasteboard.writeObjects(allImages as [NSPasteboardWriting])
            if result {
                // 为单张图片使用image属性，为多张图片使用images属性
                if allImages.count == 1 {
                    combinedItem.image = allImages[0]
                } else {
                    combinedItem.images = allImages
                }
                success = true
                print("方法1: 成功写入\(allImages.count)张图片到剪贴板")
            }
        }
        // 如果只有文件URL，优先使用URL格式
        else if allTexts.isEmpty && allImages.isEmpty && !allFileURLs.isEmpty {
            let result = pasteboard.writeObjects(allFileURLs as [NSPasteboardWriting])
            if result {
                combinedItem.fileURLs = allFileURLs
                success = true
                print("方法1: 成功写入\(allFileURLs.count)个文件URL到剪贴板")
            }
        }
        // 处理混合内容类型
        else {
            var objectsToWrite: [NSPasteboardWriting] = []
            
            // 如果有文本，创建属性字符串
            if !allTexts.isEmpty {
                let combinedText = allTexts.joined(separator: "\n\n----------\n\n")
                objectsToWrite.append(combinedText as NSString)
                combinedItem.text = combinedText
            }
            
            // 添加所有图片
            objectsToWrite.append(contentsOf: allImages as [NSPasteboardWriting])
            
            // 添加所有文件URL
            objectsToWrite.append(contentsOf: allFileURLs as [NSPasteboardWriting])
            
            // 尝试写入所有对象
            let result = pasteboard.writeObjects(objectsToWrite)
            if result {
                // 根据内容类型设置组合项目的属性
                if !allImages.isEmpty {
                    if allImages.count == 1 {
                        combinedItem.image = allImages[0]
                    } else {
                        combinedItem.images = allImages
                    }
                }
                
                if !allFileURLs.isEmpty {
                    combinedItem.fileURLs = allFileURLs
                }
                
                success = true
                print("方法1: 成功写入混合内容到剪贴板")
            }
        }
        
        // 如果成功，添加到历史记录
        if success {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.clipboardHistory.insert(combinedItem, at: 0)
                
                // 保存到数据库
                if self.modelContext != nil {
                    self.saveContentToDatabase(combinedItem)
                }
                
                // 播放手动复制的音效
                self.playManualCopySound()
                
                // 发送通知以刷新UI
                NotificationCenter.default.post(
                    name: Notification.Name("ClipboardContentChanged"),
                    object: nil
                )
            }
        } else {
            print("所有写入方法都失败")
        }
    }
    
    // 从剪贴板历史中复制项目到当前剪贴板
    func copyToClipboard(_ content: ClipboardContent) {
        // 设置内部复制标志
        isInternalCopyOperation = true
        lastInternalCopyTime = Date()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var writeSuccess = false
        
        // 尝试各种写入方法，确保内容成功复制到剪贴板
        
        // 1. 尝试文本写入
        if let text = content.text {
            if pasteboard.setString(text, forType: .string) {
                print("成功写入文本到剪贴板")
                writeSuccess = true
            }
        }
        
        // 2. 尝试图片写入
        if let image = content.image {
            // 如果文本复制成功，添加图片而不清除
            if writeSuccess {
                // 添加图片到已有内容
                if pasteboard.writeObjects([image]) {
                    print("成功添加图片到剪贴板（附加到文本）")
                    writeSuccess = true
                }
            } else {
                // 如果还没有成功写入，先清除内容再写入图片
                pasteboard.clearContents()
                if pasteboard.writeObjects([image]) {
                    print("成功写入图片到剪贴板")
                    writeSuccess = true
                }
            }
        }
        
        // 3. 尝试多图片写入
        if let images = content.images, !images.isEmpty {
            // 如果之前的写入已成功，添加图片而不清除
            if writeSuccess {
                for image in images {
                    if pasteboard.writeObjects([image]) {
                        print("成功添加多个图片到剪贴板")
                    }
                }
            } else {
                // 如果还没有成功写入，先清除内容再写入图片
                pasteboard.clearContents()
                if pasteboard.writeObjects(images as [NSPasteboardWriting]) {
                    print("成功写入多个图片到剪贴板")
                    writeSuccess = true
                }
            }
        }
        
        // 4. 尝试文件URL写入
        if let fileURLs = content.fileURLs, !fileURLs.isEmpty {
            // 如果之前的写入已成功，添加URL而不清除
            if writeSuccess {
                if pasteboard.writeObjects(fileURLs as [NSPasteboardWriting]) {
                    print("成功添加文件URL到剪贴板")
                }
            } else {
                // 如果还没有成功写入，先清除内容再写入URL
                pasteboard.clearContents()
                if pasteboard.writeObjects(fileURLs as [NSPasteboardWriting]) {
                    print("成功写入文件URL到剪贴板")
                    writeSuccess = true
                }
            }
        }
        
        // 播放手动复制音效
        playManualCopySound()
        
        // 更新最后处理的时间戳，避免立即重新处理
        lastProcessTime = Date()
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
    
    // 创建单个项目的NSItemProvider
    func createItemProvider(from item: ClipboardContent) -> NSItemProvider {
        let provider = NSItemProvider()
        
        // 处理文本内容 - 增强文本兼容性
        if let text = item.text {
            // 以标准字符串类型注册
            provider.registerObject(text as NSString as NSItemProviderWriting, visibility: .all)
            
            // 注册为明确的文本类型 - 增加多种UTType支持
            ["public.text", "public.plain-text", kUTTypePlainText as String].forEach { typeID in
                provider.registerDataRepresentation(forTypeIdentifier: typeID,
                                                  visibility: .all) { completion in
                    completion(text.data(using: .utf8), nil)
                    return nil
                }
            }
        }
        
        // 处理图片内容
        if let image = item.image, let tiffData = image.tiffRepresentation {
            // 直接注册NSImage对象
            provider.registerObject(image, visibility: .all)
            
            // 同时注册为二进制数据
            provider.registerDataRepresentation(forTypeIdentifier: kUTTypeTIFF as String,
                                              visibility: .all) { completion in
                completion(tiffData, nil)
                return nil
            }
        }
        
        // 处理文件内容 - 直接拖放文件而不是路径
        if let urls = item.fileURLs, !urls.isEmpty {
            // 注册每个单独的URL
            for url in urls {
                if FileManager.default.fileExists(atPath: url.path) {
                    // 对于每个存在的文件，尝试直接注册URL
                    provider.registerObject(url as NSURL as NSItemProviderWriting, visibility: .all)
                    
                    // 或者创建基于URL内容的provider
                    let contentProvider = NSItemProvider(contentsOf: url)
                    if let contentProvider = contentProvider {
                        return contentProvider
                    }
                }
            }
        }
        
        return provider
    }
    
    // 创建多个项目的NSItemProvider
    func createMultiItemsProvider(from items: [ClipboardContent]) -> NSItemProvider {
        let provider = NSItemProvider()
        
        // 收集所有文本内容 - 改进文本拖拽
        let texts = items.compactMap { $0.text }.joined(separator: "\n")
        if !texts.isEmpty {
            // 以标准字符串类型注册
            provider.registerObject(texts as NSString as NSItemProviderWriting, visibility: .all)
            
            // 注册为明确的文本类型 - 增加多种UTType支持
            ["public.text", "public.plain-text", kUTTypePlainText as String].forEach { typeID in
                provider.registerDataRepresentation(forTypeIdentifier: typeID,
                                                  visibility: .all) { completion in
                    completion(texts.data(using: .utf8), nil)
                    return nil
                }
            }
        }
        
        // 处理图片 - 只使用第一张图片
        if let firstImage = items.compactMap({ $0.image }).first {
            // 直接注册NSImage对象
            provider.registerObject(firstImage, visibility: .all)
            
            // 同时注册为二进制数据
            if let tiffData = firstImage.tiffRepresentation {
                provider.registerDataRepresentation(forTypeIdentifier: kUTTypeTIFF as String,
                                                  visibility: .all) { completion in
                    completion(tiffData, nil)
                    return nil
                }
            }
        }
        
        // 处理文件 - 查找所有选中项目中的文件
        let allFileURLs = items.compactMap { $0.fileURLs }.flatMap { $0 }
        if !allFileURLs.isEmpty {
            // 逐个注册有效的URL
            for url in allFileURLs {
                if FileManager.default.fileExists(atPath: url.path) {
                    provider.registerObject(url as NSURL as NSItemProviderWriting, visibility: .all)
                }
            }
            
            // 单个文件处理 - 使用专用Provider
            if let firstURL = allFileURLs.first,
               FileManager.default.fileExists(atPath: firstURL.path) {
                // 创建基于URL内容的provider
                let contentProvider = NSItemProvider(contentsOf: firstURL)
                if let contentProvider = contentProvider {
                    return contentProvider
                }
            }
        }
        
        return provider
    }
    
    // 切换项目的钉选状态并保存到数据库
    func togglePinStatus(for itemID: UUID) {
        // 查找项目并更新状态
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 切换钉选状态
            clipboardHistory[index].isPinned.toggle()
            let newPinStatus = clipboardHistory[index].isPinned
            
            print("切换项目 \(itemID) 的钉选状态为: \(newPinStatus ? "钉选" : "取消钉选")")
            
            // 更新数据库中的记录
            updateItemInDatabase(clipboardHistory[index])
        }
    }
    
    // 设置项目的钉选状态并保存到数据库
    func setPinStatus(for itemID: UUID, isPinned: Bool) {
        // 查找项目并更新状态
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 设置钉选状态
            clipboardHistory[index].isPinned = isPinned
            
            print("设置项目 \(itemID) 的钉选状态为: \(isPinned ? "钉选" : "取消钉选")")
            
            // 更新数据库中的记录
            updateItemInDatabase(clipboardHistory[index])
        }
    }
    
    // 更新数据库中的剪贴板项目
    private func updateItemInDatabase(_ content: ClipboardContent) {
        guard let modelContext = modelContext else {
            print("警告: 无法更新数据库，模型上下文未初始化")
            return
        }
        
        do {
            // 创建查询来找到相应的数据库记录 - 使用正确的UUID比较
            let contentID = content.id // 获取实际的UUID值
            let predicate = #Predicate<ClipboardItem> { item in
                item.id == contentID
            }
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
            
            // 查找数据库中的项目
            if let existingItem = try modelContext.fetch(descriptor).first {
                // 更新现有项目的属性
                existingItem.isPinned = content.isPinned
                existingItem.category = content.category
                
                // 如果有其他属性更改，也可以在这里更新
                existingItem.timestamp = content.timestamp
                
                // 保存更改
                try modelContext.save()
                print("成功更新数据库中的剪贴板项目: ID=\(content.id), 钉选=\(content.isPinned)")
            } else {
                print("错误: 在数据库中找不到ID为 \(content.id) 的项目")
                
                // 如果找不到，作为备选方案创建新记录
                saveToDatabase(content)
            }
        } catch {
            print("更新数据库中的剪贴板项目时出错: \(error.localizedDescription)")
        }
    }
    
    // 保存数据库更改
    private func saveToDatabase(_ content: ClipboardContent) {
        // 调用新的saveContentToDatabase函数
        saveContentToDatabase(content)
    }
    
    // 更新剪贴板项目的标题
    func updateTitle(for itemID: UUID, newTitle: String) {
        // 查找项目并更新标题
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 设置新标题
            clipboardHistory[index].title = newTitle
            
            print("更新项目 \(itemID) 的标题为: \(newTitle)")
            
            // 更新数据库中的记录
            updateTitleInDatabase(itemID, newTitle: newTitle)
        }
    }
    
    // 更新剪贴板项目的文本内容
    func updateTextContent(for itemID: UUID, newText: String, newTitle: String?) {
        // 查找项目并更新内容
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 设置新内容
            clipboardHistory[index].text = newText
            
            // 如果有标题也一并更新
            if let title = newTitle {
                clipboardHistory[index].title = title
            }
            
            print("更新项目 \(itemID) 的文本内容")
            
            // 更新数据库中的记录
            updateContentInDatabase(clipboardHistory[index])
            
            // 发送通知以刷新UI
            NotificationCenter.default.post(
                name: Notification.Name("ClipboardContentChanged"),
                object: nil
            )
        }
    }
    
    // 更新剪贴板项目的图片内容
    func updateImageContent(for itemID: UUID, newImage: NSImage, newTitle: String?) {
        // 查找项目并更新内容
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 设置新图片
            clipboardHistory[index].image = newImage
            clipboardHistory[index].images = nil  // 清除多图片集合
            
            // 如果有标题也一并更新
            if let title = newTitle {
                clipboardHistory[index].title = title
            }
            
            print("更新项目 \(itemID) 的图片内容")
            
            // 更新数据库中的记录
            updateContentInDatabase(clipboardHistory[index])
            
            // 发送通知以刷新UI
            NotificationCenter.default.post(
                name: Notification.Name("ClipboardContentChanged"),
                object: nil
            )
        }
    }
    
    // 在数据库中更新项目标题
    private func updateTitleInDatabase(_ itemID: UUID, newTitle: String) {
        guard let modelContext = modelContext else {
            print("警告: 无法更新数据库，模型上下文未初始化")
            return
        }
        
        do {
            // 创建查询来找到相应的数据库记录
            let predicate = #Predicate<ClipboardItem> { item in
                item.id == itemID
            }
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
            
            // 查找数据库中的项目
            if let existingItem = try modelContext.fetch(descriptor).first {
                // 更新标题
                existingItem.title = newTitle
                
                // 保存更改
                try modelContext.save()
                print("成功更新数据库中的项目标题: ID=\(itemID), 新标题=\(newTitle)")
            } else {
                print("错误: 在数据库中找不到ID为 \(itemID) 的项目")
            }
        } catch {
            print("更新数据库中的项目标题时出错: \(error.localizedDescription)")
        }
    }
    
    // 在数据库中更新项目内容
    private func updateContentInDatabase(_ content: ClipboardContent) {
        guard let modelContext = modelContext else {
            print("警告: 无法更新数据库，模型上下文未初始化")
            return
        }
        
        do {
            // 创建查询来找到相应的数据库记录
            let contentID = content.id
            let predicate = #Predicate<ClipboardItem> { item in
                item.id == contentID
            }
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
            
            // 查找数据库中的项目
            if let existingItem = try modelContext.fetch(descriptor).first {
                // 更新文本内容
                existingItem.textContent = content.text
                
                // 更新标题
                existingItem.title = content.title
                
                // 更新时间戳
                existingItem.timestamp = content.timestamp
                
                // 更新图片数据
                if let image = content.image {
                    // 处理单图片
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        existingItem.imageData = pngData
                    }
                    
                    // 清除多图片数据
                    existingItem.imagesData = nil
                } else if let images = content.images, !images.isEmpty {
                    // 处理多图片
                    var imagesData: [Data] = []
                    for img in images {
                        if let tiffData = img.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmap.representation(using: .png, properties: [:]) {
                            imagesData.append(pngData)
                        }
                    }
                    
                    existingItem.imagesData = imagesData.isEmpty ? nil : imagesData
                    existingItem.imageData = nil
                }
                
                // 保存更改
                try modelContext.save()
                print("成功更新数据库中的项目内容: ID=\(content.id)")
            } else {
                print("错误: 在数据库中找不到ID为 \(content.id) 的项目")
                
                // 如果找不到，作为备选方案创建新记录
                saveContentToDatabase(content)
            }
        } catch {
            print("更新数据库中的项目内容时出错: \(error.localizedDescription)")
        }
    }
    
    // 获取剪贴板项目的标题
    func getItemTitle(for itemID: UUID) -> String? {
        // 查找项目并返回其标题
        if let item = clipboardHistory.first(where: { $0.id == itemID }) {
            return item.title
        }
        
        return nil
    }
    
    // 获取当前活跃应用的信息
    private func getCurrentApplicationInfo() -> (bundleIdentifier: String?, name: String?) {
        // 获取当前活跃的应用
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            return (activeApp.bundleIdentifier, activeApp.localizedName)
        }
        
        // 如果无法获取活跃应用，使用默认值（当前应用）
        return (Bundle.main.bundleIdentifier, "FishCopy")
    }
    
    // 获取应用图标
    private func getAppIcon(for bundleIdentifier: String?) -> NSImage? {
        guard let bundleID = bundleIdentifier else { return nil }
        
        // 尝试获取应用图标
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return icon
        }
        
        return nil
    }
    
    // 加载排除应用列表
    private func loadExcludedApps() {
        print("ClipboardManager - 开始加载排除应用列表...")
        if let data = UserDefaults.standard.data(forKey: "excludedApps") {
            print("ClipboardManager - 找到排除应用数据，大小: \(data.count) 字节")
            do {
                // 使用相同的ExcludedApp结构进行解码
                let excludedApps = try JSONDecoder().decode([ExcludedApp].self, from: data)
                self.excludedAppBundleIds = excludedApps.map { $0.bundleIdentifier }
                print("ClipboardManager - 成功加载 \(excludedAppBundleIds.count) 个排除应用的Bundle ID")
                if !excludedAppBundleIds.isEmpty {
                    print("ClipboardManager - 排除的应用Bundle ID: \(excludedAppBundleIds.joined(separator: ", "))")
                }
            } catch {
                print("ClipboardManager - 解码排除应用列表时出错: \(error)")
                print("ClipboardManager - 错误详情: \(error.localizedDescription)")
                // 出错时设置为空列表
                self.excludedAppBundleIds = []
            }
        } else {
            print("ClipboardManager - UserDefaults中没有找到排除应用数据，使用空列表")
            self.excludedAppBundleIds = []
        }
    }
    
    // 定义与SettingsView中相同的ExcludedApp结构
    struct ExcludedApp: Codable {
        var id: UUID
        var name: String
        var bundleIdentifier: String
        var path: String
    }
    
    // 检查当前应用是否在排除列表中
    private func isCurrentAppExcluded() -> Bool {
        // 获取当前活动应用的Bundle ID
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            let bundleId = currentApp.bundleIdentifier ?? ""
            
            // 检查是否在排除列表中
            if excludedAppBundleIds.contains(bundleId) {
                print("当前应用 '\(currentApp.localizedName ?? "未知")' (\(bundleId)) 在排除列表中")
                return true
            }
        }
        return false
    }
    
    // 当设置更新时重新加载排除应用列表
    func refreshExcludedApps() {
        let previousCount = excludedAppBundleIds.count
        loadExcludedApps()
        let newCount = excludedAppBundleIds.count
        print("排除应用列表已更新: \(previousCount) -> \(newCount) 个应用")
        if !excludedAppBundleIds.isEmpty {
            print("排除的应用bundleID列表: \(excludedAppBundleIds)")
        }
    }
} 