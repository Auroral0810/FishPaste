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
    
    // 最后处理的内容ID
    private var lastProcessedContentID: UUID?
    
    // 最大历史记录大小
    private let maxHistorySize: Int = 1000
    
    init() {
        // 从UserDefaults加载保存的监控间隔设置
        if let savedInterval = UserDefaults.standard.object(forKey: "monitoringInterval") as? Double {
            self.monitoringInterval = savedInterval
            print("从UserDefaults加载监控间隔设置: \(savedInterval)秒")
        }
        
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
        if isInternalCopyOperation || (lastInternalCopyTime != nil && Date().timeIntervalSince(lastInternalCopyTime!) < 1.0) {
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
            
            // 确保内部复制标志已重置
            isInternalCopyOperation = false
            
            // 更新上次处理时间和changeCount
            lastProcessTime = currentTime
            lastChangeCount = changeCount
            
            // 处理剪贴板内容
            processClipboardContent()
        }
    }
    
    // 处理剪贴板内容
    private func processClipboardContent() {
        // 如果最近执行了内部复制操作，跳过处理以避免重复
        if isInternalCopyOperation {
            let now = Date()
            if let lastTime = lastInternalCopyTime, now.timeIntervalSince(lastTime) < 1.0 {
                print("检测到内部复制操作，跳过处理")
                return
            }
            
            // 重置内部复制标志
            isInternalCopyOperation = false
        }
        
        // 强制重置内部复制标志，防止卡在复制状态
        if let lastTime = lastInternalCopyTime, Date().timeIntervalSince(lastTime) > 5.0 {
            print("内部复制标志超时，强制重置")
            isInternalCopyOperation = false
        }
        
        let pasteboard = NSPasteboard.general
        let newChangeCount = pasteboard.changeCount
        
        // 如果变化计数没有改变，说明内容没有变化
        if newChangeCount == lastChangeCount {
            return
        }
        
        // 更新变化计数
        lastChangeCount = newChangeCount
        
        // 创建新的剪贴板内容对象
        let content = ClipboardContent()
        
        // 处理多种类型的内容
        var hasContent = false
        
        // 尝试读取剪贴板中的所有项目
        var containsImage = false
        var containsText = false
        var containsFileURL = false
        
        // 首先检查是否有多个项目
        let items = pasteboard.pasteboardItems
        if let items = items, !items.isEmpty {
            print("剪贴板包含 \(items.count) 个项目")
            
            // 处理每个项目
            var allImages: [NSImage] = []
            var allTexts: [String] = []
            var allFileURLs: [URL] = []
            
            for (index, item) in items.enumerated() {
                print("处理剪贴板项目 #\(index + 1)，包含类型: \(item.types)")
                
                // 处理文本
                if item.types.contains(.string) {
                    if let string = item.string(forType: .string), !string.isEmpty {
                        // 检查是否是已经识别过的文本（避免重复计数）
                        if !allTexts.contains(string) {
                            allTexts.append(string)
                            containsText = true
                            print("项目 #\(index + 1) 包含文本: \(string.prefix(min(20, string.count)))...")
                        }
                    }
                }
                
                // 处理图片（TIFF或PNG格式）
                let imageTypeIdentifiers: [NSPasteboard.PasteboardType] = [.tiff, .png]
                var foundImage = false
                
                for imageType in imageTypeIdentifiers {
                    if item.types.contains(imageType), !foundImage {
                        if let imageData = item.data(forType: imageType),
                           let image = NSImage(data: imageData) {
                            // 检查是否和已经识别的图片重复
                            if !isDuplicateImage(image, in: allImages) {
                                allImages.append(image)
                                containsImage = true
                                foundImage = true
                                print("项目 #\(index + 1) 包含图片，大小: \(image.size.width)x\(image.size.height)")
                            }
                        }
                    }
                }
                
                // 处理自定义图片类型
                for type in item.types {
                    if type.rawValue.hasPrefix("com.fishcopy.image."), !foundImage {
                        if let imageData = item.data(forType: type),
                           let image = NSImage(data: imageData) {
                            // 检查是否和已经识别的图片重复
                            if !isDuplicateImage(image, in: allImages) {
                                allImages.append(image)
                                containsImage = true
                                foundImage = true
                                print("项目 #\(index + 1) 包含自定义图片类型: \(type.rawValue)")
                            }
                        }
                    }
                }
                
                // 处理PDF格式数据
                if item.types.contains(.pdf) && !foundImage {
                    if let pdfData = item.data(forType: .pdf),
                       let pdfImage = createImageFromPDF(pdfData) {
                        allImages.append(pdfImage)
                        containsImage = true
                        foundImage = true
                        print("项目 #\(index + 1) 包含PDF数据，转换为图片")
                    }
                }
                
                // 处理RTF格式数据，提取纯文本
                if item.types.contains(.rtf) && !containsText {
                    if let rtfData = item.data(forType: .rtf),
                       let rtfString = createStringFromRTF(rtfData),
                       !rtfString.isEmpty,
                       !allTexts.contains(rtfString) {
                        allTexts.append(rtfString)
                        containsText = true
                        print("项目 #\(index + 1) 包含RTF数据，提取纯文本")
                    }
                }
                
                // 处理文件URL
                if item.types.contains(.fileURL) {
                    if let urlString = item.string(forType: .fileURL),
                       let url = URL(string: urlString),
                       url.isFileURL {
                        allFileURLs.append(url)
                        containsFileURL = true
                        print("项目 #\(index + 1) 包含文件URL: \(url.path)")
                    }
                }
            }
            
            // 设置收集到的所有内容
            if !allTexts.isEmpty {
                content.text = allTexts.joined(separator: "\n")
                hasContent = true
                print("收集到 \(allTexts.count) 个文本")
            }
            
            if !allImages.isEmpty {
                if allImages.count == 1 {
                    content.image = allImages[0]
                } else {
                    content.images = allImages
                }
                hasContent = true
                print("收集到 \(allImages.count) 张图片")
            }
            
            if !allFileURLs.isEmpty {
                content.fileURLs = allFileURLs
                hasContent = true
                print("收集到 \(allFileURLs.count) 个文件URL")
            }
        } else {
            // 单项处理（兼容性模式）
            print("使用兼容性模式处理单项内容")
            
            // 首先尝试获取文件URL
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !fileURLs.isEmpty {
                print("读取到 \(fileURLs.count) 个文件URL")
                
                content.fileURLs = fileURLs
                hasContent = true
                containsFileURL = true
            }
            
            // 然后尝试获取图片
            if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage], !images.isEmpty {
                print("读取到 \(images.count) 张图片")
                
                if images.count == 1 {
                    content.image = images[0]
                } else {
                    content.images = images
                }
                hasContent = true
                containsImage = true
            }
            
            // 最后尝试获取文本
            if let text = pasteboard.string(forType: .string), !text.isEmpty {
                print("读取到文本内容")
                
                content.text = text
                hasContent = true
                containsText = true
            }
            
            // 尝试读取PDF数据
            if let pdfData = pasteboard.data(forType: .pdf),
               let pdfImage = createImageFromPDF(pdfData) {
                if content.image == nil {
                    content.image = pdfImage
                } else if content.images == nil {
                    content.images = [pdfImage]
                } else {
                    content.images?.append(pdfImage)
                }
                hasContent = true
                containsImage = true
                print("读取到PDF数据并转换为图片")
            }
            
            // 尝试读取RTF数据
            if let rtfData = pasteboard.data(forType: .rtf),
               let rtfString = createStringFromRTF(rtfData),
               !rtfString.isEmpty {
                if content.text == nil {
                    content.text = rtfString
                } else {
                    content.text = content.text! + "\n" + rtfString
                }
                hasContent = true
                containsText = true
                print("读取到RTF数据并提取文本")
            }
        }
        
        // 为内容分配唯一标识符和时间戳
        content.id = UUID()
        content.timestamp = Date()
        
        // 添加内容到历史记录（如果有内容且不是重复的）
        if hasContent && !isContentDuplicate(content) {
            print("添加新剪贴板内容到历史记录")
            
            // 设置内容类别
            determineContentCategory(for: content)
            
            // 添加到剪贴板历史的前面
            clipboardHistory.insert(content, at: 0)
            
            // 将新内容保存到数据库
            saveContentToDatabase(content)
            
            // 限制历史记录大小
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
            
            // 播放新项目添加音效（除非是手动复制的，那会有单独的音效）
            if !isInternalCopyOperation {
                playClipboardChangedSound()
            }
            
            // 更新最后处理的内容ID
            lastProcessedContentID = content.id
        } else if hasContent {
            print("未添加内容到历史记录: 检测到重复内容")
        } else {
            print("未添加内容到历史记录: 未检测到有效内容")
        }
        
        // 如果检测到新内容，发送通知以便UI刷新
        if hasContent {
            NotificationCenter.default.post(
                name: Notification.Name("ClipboardContentChanged"),
                object: nil
            )
        }
    }
    
    // 辅助方法：从PDF数据创建图像
    private func createImageFromPDF(_ pdfData: Data) -> NSImage? {
        guard let dataProvider = CGDataProvider(data: pdfData as CFData),
              let pdfDocument = CGPDFDocument(dataProvider) else {
            return nil
        }
        
        guard let page = pdfDocument.page(at: 1) else {
            return nil
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = NSImage(size: pageRect.size)
        
        renderer.lockFocus()
        let context = NSGraphicsContext.current?.cgContext
        
        // 白底黑字
        context?.setFillColor(CGColor.white)
        context?.fill(pageRect)
        
        // 翻转坐标系以正确绘制PDF
        context?.translateBy(x: 0, y: pageRect.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        // 渲染PDF页面
        context?.drawPDFPage(page)
        renderer.unlockFocus()
        
        return renderer
    }
    
    // 辅助方法：从RTF数据创建字符串
    private func createStringFromRTF(_ rtfData: Data) -> String? {
        guard let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) else {
            return nil
        }
        return attributedString.string
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
    
    // 检查两个图片是否重复
    private func isDuplicateImage(_ image1: NSImage, _ image2: NSImage) -> Bool {
        // 简单的尺寸比较
        if abs(image1.size.width - image2.size.width) > 1 || abs(image1.size.height - image2.size.height) > 1 {
            return false
        }
        
        // 将两个图片转换为相同格式的数据进行比较
        guard let tiffData1 = image1.tiffRepresentation,
              let bitmap1 = NSBitmapImageRep(data: tiffData1),
              let pngData1 = bitmap1.representation(using: .png, properties: [:]),
              let tiffData2 = image2.tiffRepresentation,
              let bitmap2 = NSBitmapImageRep(data: tiffData2),
              let pngData2 = bitmap2.representation(using: .png, properties: [:]) else {
            return false
        }
        
        // 数据长度相差太大时，认为不是同一图片
        if abs(pngData1.count - pngData2.count) > pngData1.count / 10 {
            return false
        }
        
        // 进行完整的数据比较
        return pngData1 == pngData2
    }
    
    // 检查图片是否与数组中的任何图片重复
    private func isDuplicateImage(_ image: NSImage, in images: [NSImage]) -> Bool {
        for existingImage in images {
            if isDuplicateImage(image, existingImage) {
                return true
            }
        }
        return false
    }
    
    // 检查两个剪贴板内容对象是否有相同的图片
    private func hasSameImage(_ content1: ClipboardContent, _ content2: ClipboardContent) -> Bool {
        // 如果两者都有单张图片
        if let image1 = content1.image, let image2 = content2.image {
            return isDuplicateImage(image1, image2)
        }
        
        // 如果一个有单张图片，一个有多张图片
        if let image1 = content1.image, let images2 = content2.images, !images2.isEmpty {
            // 检查单张图片是否与多张图片中的任何一张匹配
            return isDuplicateImage(image1, in: images2)
        }
        
        if let images1 = content1.images, !images1.isEmpty, let image2 = content2.image {
            // 检查单张图片是否与多张图片中的任何一张匹配
            return isDuplicateImage(image2, in: images1)
        }
        
        // 如果两者都有多张图片
        if let images1 = content1.images, let images2 = content2.images,
           !images1.isEmpty, !images2.isEmpty {
            // 如果图片数量相同且不多，比较每一张图片
            if images1.count == images2.count && images1.count <= 5 {
                // 对于少量图片，比较每一张
                var matchCount = 0
                for i in 0..<images1.count {
                    if isDuplicateImage(images1[i], images2[i]) {
                        matchCount += 1
                    }
                }
                // 如果所有图片都匹配，认为是相同的内容
                return matchCount == images1.count
            } else {
                // 对于大量图片，只比较第一张和数量
                return images1.count == images2.count && isDuplicateImage(images1[0], images2[0])
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
            print("警告: 无法保存到数据库，模型上下文未初始化")
            return
        }
        
        // 从图片创建Data
        var imageData: Data? = nil
        if let image = content.image, let tiffData = image.tiffRepresentation {
            imageData = tiffData
        }
        
        // 从多张图片创建Data数组
        var imagesData: [Data]? = nil
        if let images = content.images, !images.isEmpty {
            imagesData = images.compactMap { image in
                image.tiffRepresentation
            }
        }
        
        // 检查数据库中是否已存在此ID的项目
        do {
            // 先获取实际的UUID值
            let contentID = content.id
            
            let predicate = #Predicate<ClipboardItem> { item in
                item.id == contentID
            }
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
            
            if let existingItem = try modelContext.fetch(descriptor).first {
                // 如果已存在，则更新而不是插入
                existingItem.textContent = content.text
                existingItem.imageData = imageData
                existingItem.imagesData = imagesData
                existingItem.fileURLStrings = content.fileURLs?.map { $0.absoluteString }
                existingItem.timestamp = content.timestamp
                existingItem.category = content.category
                existingItem.isPinned = content.isPinned
                existingItem.title = content.title  // 更新标题字段
                
                try modelContext.save()
                print("更新现有剪贴板项到数据库: ID=\(content.id), 标题=\(content.title ?? "无"), 钉选=\(content.isPinned)")
                return
            }
        } catch {
            print("检查项目是否存在时出错: \(error.localizedDescription)")
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
            isPinned: content.isPinned,
            title: content.title  // 保存标题字段
        )
        
        // 保存到数据库
        modelContext.insert(clipboardItem)
        
        // 尝试立即保存更改
        do {
            try modelContext.save()
            print("成功保存剪贴板项到数据库: ID=\(content.id), 标题=\(content.title ?? "无"), 钉选=\(content.isPinned)")
        } catch {
            print("保存到数据库时出错: \(error.localizedDescription)")
        }
    }
    
    // 保存内容到数据库的包装方法
    private func saveContentToDatabase(_ content: ClipboardContent) {
        saveToDatabase(content)
    }
    
    // 从剪贴板历史中复制项目到当前剪贴板
    func copyToClipboard(_ content: ClipboardContent) {
        // 标记为内部复制操作，避免重复播放音效
        isInternalCopyOperation = true
        lastInternalCopyTime = Date()
        
        let pasteboard = NSPasteboard.general
        // 记录当前剪贴板状态
        let oldChangeCount = pasteboard.changeCount
        
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
        
        // 播放手动复制音效
        playManualCopySound()
        
        // 检查剪贴板是否真的变化了
        let newChangeCount = pasteboard.changeCount
        if newChangeCount != oldChangeCount {
            print("剪贴板变化计数: \(oldChangeCount) -> \(newChangeCount), 确保记录新内容")
            
            // 手动处理当前剪贴板内容
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                
                // 重置内部复制标志
                self.isInternalCopyOperation = false
                
                // 强制处理当前剪贴板内容
                self.lastChangeCount = newChangeCount - 1 // 确保被识别为变化
                self.processClipboardContent()
            }
        } else {
            // 如果剪贴板没有变化，延迟重置内部复制标志
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isInternalCopyOperation = false
            }
        }
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
        // 标记为内部复制操作，避免重复播放音效
        isInternalCopyOperation = true
        lastInternalCopyTime = Date()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // 收集所有内容
        var allTexts: [String] = []
        var allImages: [NSImage] = []
        var allFileURLs: [URL] = []
        
        // 从所有项目中收集内容
        for item in items {
            // 收集文本
            if let text = item.text, !text.isEmpty {
                allTexts.append(text)
            }
            
            // 收集单图像
            if let image = item.image {
                allImages.append(image)
            }
            
            // 收集多图像
            if let images = item.images, !images.isEmpty {
                allImages.append(contentsOf: images)
            }
            
            // 收集文件URL
            if let fileURLs = item.fileURLs, !fileURLs.isEmpty {
                allFileURLs.append(contentsOf: fileURLs)
            }
        }
        
        // 创建安全图片拷贝
        let safeImages = allImages.compactMap { image -> NSImage? in
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]),
               let safeImage = NSImage(data: pngData) {
                return safeImage
            }
            return nil
        }
        
        // 过滤有效的URL
        let validURLs = allFileURLs.filter { url in url.isFileURL && FileManager.default.fileExists(atPath: url.path) }
        
        // 合并文本内容
        let combinedText = allTexts.joined(separator: "\n")
        
        print("准备写入剪贴板: \(allTexts.count)个文本, \(safeImages.count)个图片, \(validURLs.count)个文件URL")
        
        // 创建写入对象数组
        var writeObjects: [NSPasteboardWriting] = []
        
        // 如果有文本，添加到写入对象
        if !combinedText.isEmpty {
            writeObjects.append(combinedText as NSString)
        }
        
        // 如果有图片，添加到写入对象
        writeObjects.append(contentsOf: safeImages)
        
        // 如果有URL，添加到写入对象
        if !validURLs.isEmpty {
            writeObjects.append(contentsOf: validURLs as [NSURL])
        }
        
        // 一次性写入所有对象
        var writeSuccess = false
        if !writeObjects.isEmpty {
            writeSuccess = pasteboard.writeObjects(writeObjects)
            print("一次性写入对象\(writeSuccess ? "成功" : "失败")")
        }
        
        // 如果一次性写入失败，尝试使用NSPasteboardItem方式
        if !writeSuccess && (!combinedText.isEmpty || !safeImages.isEmpty) {
            print("尝试使用NSPasteboardItem方式")
            
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            
            // 添加文本
            if !combinedText.isEmpty {
                item.setString(combinedText, forType: .string)
            }
            
            // 添加图片
            if !safeImages.isEmpty, let firstImage = safeImages.first,
               let tiffData = firstImage.tiffRepresentation {
                item.setData(tiffData, forType: .tiff)
                
                // 为多张图片添加自定义类型
                if safeImages.count > 1 {
                    for (index, image) in safeImages.enumerated().dropFirst() {
                        if let tiffData = image.tiffRepresentation {
                            let customType = NSPasteboard.PasteboardType("com.fishcopy.image.\(index)")
                            item.setData(tiffData, forType: customType)
                        }
                    }
                }
            }
            
            writeSuccess = pasteboard.writeObjects([item])
            print("NSPasteboardItem方式写入\(writeSuccess ? "成功" : "失败")")
        }
        
        // 如果前两种方法都失败，尝试分别写入
        if !writeSuccess {
            print("尝试分别写入")
            
            pasteboard.clearContents()
            
            // 先写入文本
            if !combinedText.isEmpty {
                let textSuccess = pasteboard.setString(combinedText, forType: .string)
                print("写入文本\(textSuccess ? "成功" : "失败")")
                writeSuccess = textSuccess
            }
            
            // 再添加所有图片（不清空剪贴板）
            if !safeImages.isEmpty {
                let imageData = NSMutableData()
                var lastSuccess = false
                
                for image in safeImages {
                    if let representation = image.tiffRepresentation {
                        let success = pasteboard.setData(representation, forType: .tiff)
                        lastSuccess = success || lastSuccess
                    }
                }
                
                if !lastSuccess {
                    // 如果逐个添加失败，尝试一次性添加所有
                    let imagesSuccess = pasteboard.writeObjects(safeImages)
                    print("写入\(safeImages.count)张图片\(imagesSuccess ? "成功" : "失败")")
                    writeSuccess = writeSuccess || imagesSuccess
                } else {
                    print("逐个写入图片成功")
                    writeSuccess = true
                }
            }
            
            // 最后添加文件URL（如果前面都失败）
            if !writeSuccess && !validURLs.isEmpty {
                let urlSuccess = pasteboard.writeObjects(validURLs as [NSURL])
                print("写入\(validURLs.count)个文件URL\(urlSuccess ? "成功" : "失败")")
                writeSuccess = urlSuccess
            }
        }
        
        // 最后的备份方法：如果还是失败，创建RTF格式组合文本和图片
        if !writeSuccess && !combinedText.isEmpty && !safeImages.isEmpty {
            print("尝试使用RTF格式组合文本和图片")
            
            pasteboard.clearContents()
            
            // 创建富文本
            let attributedString = NSMutableAttributedString(string: combinedText)
            
            // 为富文本添加图片附件
            for (index, image) in safeImages.enumerated() {
                let attachment = NSTextAttachment()
                attachment.image = image
                let attachmentString = NSAttributedString(attachment: attachment)
                
                // 在文本末尾添加换行符和图片
                attributedString.append(NSAttributedString(string: "\n"))
                attributedString.append(attachmentString)
            }
            
            // 获取RTF数据
            if let rtfData = attributedString.rtf(from: NSRange(location: 0, length: attributedString.length)) {
                let rtfSuccess = pasteboard.setData(rtfData, forType: .rtf)
                print("写入RTF数据\(rtfSuccess ? "成功" : "失败")")
                writeSuccess = rtfSuccess
            }
        }
        
        // 触发状态栏图标旋转动画
        NotificationCenter.default.post(
            name: Notification.Name("ClipboardContentChanged"),
            object: nil
        )
        
        // 播放手动复制音效
        playManualCopySound()
        
        // 延迟重置内部复制标志，避免过早检测到变化
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isInternalCopyOperation = false
        }
        
        // 输出总结信息
        print("已复制内容: \(allTexts.count)个文本, \(safeImages.count)个图片, \(validURLs.count)个文件URL")
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
        
        // 收集所有图片
        var allImages: [NSImage] = []
        
        // 同时处理单图像和多图像集合
        for item in items {
            if let image = item.image {
                allImages.append(image)
            }
            if let images = item.images, !images.isEmpty {
                allImages.append(contentsOf: images)
            }
        }
        
        // 处理图片 - 尝试注册所有图片
        if !allImages.isEmpty {
            // 创建图片的安全拷贝
            let safeImages = allImages.compactMap { image -> NSImage? in
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]),
                   let safeImage = NSImage(data: pngData) {
                    return safeImage
                }
                return nil
            }
            
            // 注册所有图片
            if !safeImages.isEmpty {
                // 注册第一张图片作为主要图片内容
                provider.registerObject(safeImages[0], visibility: .all)
                
                // 为拖拽操作注册所有图片
                if safeImages.count > 1 {
                    // 以写入对象方式注册所有图片
                    if let writableArray = NSArray(array: safeImages) as? NSItemProviderWriting {
                        provider.registerObject(writableArray, visibility: .all)
                    } else {
                        // 如果无法转换，逐个注册
                        for (index, image) in safeImages.enumerated() {
                            provider.registerObject(image, visibility: .all)
                        }
                    }
                    
                    // 注册图片数据表示
                    provider.registerDataRepresentation(forTypeIdentifier: kUTTypeImage as String,
                                                    visibility: .all) { completion in
                        // 创建一个TIFF图像集合
                        var imageReps: [NSBitmapImageRep] = []
                        for image in safeImages {
                            if let tiffData = image.tiffRepresentation,
                               let rep = NSBitmapImageRep(data: tiffData) {
                                imageReps.append(rep)
                            }
                        }
                        
                        if !imageReps.isEmpty {
                            // 尝试创建多页TIFF
                            if let multiImageData = NSBitmapImageRep.representationOfImageReps(in: imageReps, using: .tiff, properties: [:]) {
                                completion(multiImageData, nil)
                                return nil
                            }
                        }
                        
                        // 如果多页TIFF失败，返回第一张图片的数据
                        if let firstImage = safeImages.first,
                           let tiffData = firstImage.tiffRepresentation {
                            completion(tiffData, nil)
                        } else {
                            completion(nil, NSError(domain: "FishCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建图片数据"]))
                        }
                        return nil
                    }
                } else if let firstImage = safeImages.first, let tiffData = firstImage.tiffRepresentation {
                    // 单个图片的情况
                    provider.registerDataRepresentation(forTypeIdentifier: kUTTypeTIFF as String,
                                                    visibility: .all) { completion in
                        completion(tiffData, nil)
                        return nil
                    }
                }
            }
        }
        
        // 处理文件 - 查找所有选中项目中的文件
        let allFileURLs = items.compactMap { $0.fileURLs }.flatMap { $0 }
        if !allFileURLs.isEmpty {
            // 过滤出有效的URL
            let validURLs = allFileURLs.filter { FileManager.default.fileExists(atPath: $0.path) }
            
            if !validURLs.isEmpty {
                // 创建URL数组并注册
                if let fileURLArray = NSArray(array: validURLs) as? NSItemProviderWriting {
                    provider.registerObject(fileURLArray, visibility: .all)
                } else {
                    // 如果无法转换，逐个注册
                    for url in validURLs {
                        provider.registerObject(url as NSURL as NSItemProviderWriting, visibility: .all)
                    }
                }
                
                // 注册每个文件的内容表示
                for url in validURLs {
                    // 注册文件内容表示
                    provider.registerFileRepresentation(forTypeIdentifier: kUTTypeFileURL as String,
                                                    fileOptions: [],
                                                    visibility: .all) { completion in
                        completion(url, true, nil)
                        return nil
                    }
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
                // 从图片创建Data
                var imageData: Data? = nil
                if let image = content.image, let tiffData = image.tiffRepresentation {
                    imageData = tiffData
                }
                
                // 从多图片创建Data数组
                var imagesData: [Data]? = nil
                if let images = content.images, !images.isEmpty {
                    imagesData = images.compactMap { image in
                        image.tiffRepresentation
                    }
                }
                
                // 更新现有项目的属性
                existingItem.textContent = content.text
                existingItem.imageData = imageData
                existingItem.imagesData = imagesData
                existingItem.fileURLStrings = content.fileURLs?.map { $0.absoluteString }
                existingItem.isPinned = content.isPinned
                existingItem.category = content.category
                existingItem.timestamp = content.timestamp
                existingItem.title = content.title  // 更新标题字段
                
                // 保存更改
                try modelContext.save()
                print("成功更新数据库中的剪贴板项目: ID=\(content.id), 标题=\(content.title ?? "无"), 钉选=\(content.isPinned)")
            } else {
                print("错误: 在数据库中找不到ID为 \(content.id) 的项目")
                
                // 如果找不到，作为备选方案创建新记录
                saveToDatabase(content)
            }
        } catch {
            print("更新数据库中的剪贴板项目时出错: \(error.localizedDescription)")
        }
    }
    
    // 更新剪贴板文本内容
    func updateTextContent(for itemID: UUID, newText: String, newTitle: String? = nil) {
        // 查找项目
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 更新文本内容
            clipboardHistory[index].text = newText
            
            // 如果提供了标题，则更新标题
            if let title = newTitle {
                clipboardHistory[index].title = title
            }
            
            // 更新时间戳
            clipboardHistory[index].timestamp = Date()
            
            // 更新数据库
            updateItemInDatabase(clipboardHistory[index])
            
            print("已更新剪贴板项目（ID: \(itemID)）的文本内容")
        }
    }
    
    // 更新剪贴板图片内容
    func updateImageContent(for itemID: UUID, newImage: NSImage, newTitle: String? = nil) {
        // 查找项目
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 更新图片内容
            clipboardHistory[index].image = newImage
            
            // 如果是多图片，则替换为单图片
            if clipboardHistory[index].images != nil {
                clipboardHistory[index].images = [newImage]
            }
            
            // 如果提供了标题，则更新标题
            if let title = newTitle {
                clipboardHistory[index].title = title
            }
            
            // 更新时间戳
            clipboardHistory[index].timestamp = Date()
            
            // 更新数据库
            updateItemInDatabase(clipboardHistory[index])
            
            print("已更新剪贴板项目（ID: \(itemID)）的图片内容")
        }
    }
    
    // 更新多张图片内容
    func updateMultipleImages(for itemID: UUID, newImages: [NSImage], newTitle: String? = nil) {
        // 查找项目
        if let index = clipboardHistory.firstIndex(where: { $0.id == itemID }) {
            // 更新图片内容
            clipboardHistory[index].images = newImages
            
            // 更新第一张作为主图片
            if let firstImage = newImages.first {
                clipboardHistory[index].image = firstImage
            }
            
            // 如果提供了标题，则更新标题
            if let title = newTitle {
                clipboardHistory[index].title = title
            }
            
            // 更新时间戳
            clipboardHistory[index].timestamp = Date()
            
            // 更新数据库
            updateItemInDatabase(clipboardHistory[index])
            
            print("已更新剪贴板项目（ID: \(itemID)）的多张图片内容")
        }
    }
    
    // 更新剪贴板项目的标题
    func updateTitle(for id: UUID, newTitle: String) {
        print("已更新剪贴板项目（ID: \(id)）的标题为：\(newTitle)")
        
        // 尝试在历史记录中找到相应的项目
        if let index = clipboardHistory.firstIndex(where: { $0.id == id }) {
            clipboardHistory[index].title = newTitle
            
            // 如果项目存在于数据库中，也更新数据库
            if let modelContext = modelContext {
                do {
                    let descriptor = FetchDescriptor<ClipboardItem>(
                        predicate: #Predicate<ClipboardItem> { item in
                            item.id == id
                        }
                    )
                    
                    if let existingItem = try modelContext.fetch(descriptor).first {
                        existingItem.title = newTitle
                        try modelContext.save()
                        print("成功更新数据库中的剪贴板项目: ID=\(id), 标题=\(newTitle), 钉选=\(existingItem.isPinned)")
                    }
                } catch {
                    print("更新数据库中的标题时出错: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 根据ID获取剪贴板项目的标题
    func getItemTitle(for id: UUID) -> String? {
        // 在历史记录中查找项目
        if let item = clipboardHistory.first(where: { $0.id == id }) {
            return item.title
        }
        
        // 如果在内存中找不到，尝试从数据库中查找
        if let modelContext = modelContext {
            do {
                let descriptor = FetchDescriptor<ClipboardItem>(
                    predicate: #Predicate<ClipboardItem> { item in
                        item.id == id
                    }
                )
                
                if let existingItem = try modelContext.fetch(descriptor).first {
                    return existingItem.title
                }
            } catch {
                print("从数据库获取标题时出错: \(error.localizedDescription)")
            }
        }
        
        return nil
    }
    
    // 在clipboardHistory插入内容前和内部复制时检查是否重复
    private func isContentDuplicate(_ newContent: ClipboardContent) -> Bool {
        // 检查最近处理的内容(限制检查范围，提高性能)
        let recentItems = clipboardHistory.prefix(20)
        
        for existingContent in recentItems {
            // 如果ID相同，认为是同一个内容
            if newContent.id == existingContent.id {
                return true
            }
            
            // 对于文本内容进行比较
            if let newText = newContent.text, let existingText = existingContent.text {
                // 完全相同的文本认为是重复的
                if newText == existingText {
                    print("检测到重复文本")
                    return true
                }
                
                // 对于非常短的文本(如URL)，需要更严格的比较
                if newText.count < 100 && existingText.count < 100 {
                    // 移除空白字符后再比较
                    let trimmedNew = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedExisting = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedNew == trimmedExisting {
                        print("检测到修剪后重复的短文本")
                        return true
                    }
                }
            }
            
            // 比较图片内容而非引用
            if (newContent.image != nil && existingContent.image != nil) ||
               (newContent.images != nil && existingContent.images != nil) {
                if hasSameImage(newContent, existingContent) {
                    print("检测到重复图片")
                    return true
                }
            }
            
            // 比较文件URL
            if let newURLs = newContent.fileURLs, let existingURLs = existingContent.fileURLs,
               !newURLs.isEmpty, !existingURLs.isEmpty {
                // 将URL转换为字符串集合进行比较
                let newURLSet = Set(newURLs.map { $0.absoluteString })
                let existingURLSet = Set(existingURLs.map { $0.absoluteString })
                if newURLSet == existingURLSet {
                    print("检测到重复文件URL")
                    return true
                }
            }
        }
        
        return false
    }
    
    // 为内容确定适当的分类
    private func determineContentCategory(for content: ClipboardContent) {
        // 根据内容类型设置默认分类
        if content.image != nil || (content.images != nil && !content.images!.isEmpty) {
            content.category = "图像"
        } else if let text = content.text {
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                content.category = "链接"
            } else {
                content.category = "文本"
            }
        } else if content.fileURLs != nil && !content.fileURLs!.isEmpty {
            content.category = "文件"
        }
    }
    
    // 从数据库删除指定ID的项目
    private func deleteItemFromDatabase(with id: UUID) {
        guard let modelContext = modelContext else {
            print("警告: 无法从数据库删除项目，模型上下文未初始化")
            return
        }
        
        do {
            // 创建查询
            let predicate = #Predicate<ClipboardItem> { item in
                item.id == id
            }
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
            
            // 查找项目
            if let item = try modelContext.fetch(descriptor).first {
                // 删除项目
                modelContext.delete(item)
                try modelContext.save()
                print("成功从数据库中删除ID为\(id)的项目")
            } else {
                print("在数据库中找不到ID为\(id)的项目")
            }
        } catch {
            print("从数据库删除项目时出错: \(error.localizedDescription)")
        }
    }
} 
