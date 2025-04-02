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
        // 创建新的剪贴板内容对象
        let content = ClipboardContent(id: UUID())
        var hasContent = false
        
        // 安全地检查文本
        if let text = pasteboard.string(forType: .string) {
            content.text = text
            hasContent = true
        }
        
        // 安全地检查图片，使用PNG格式而非TIFF以提高兼容性
        if let image = NSImage(pasteboard: pasteboard) {
            // 创建深拷贝以避免共享内存和引用问题
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]),
               let newImage = NSImage(data: pngData) {
                content.image = newImage
                hasContent = true
            }
        }
        
        // 安全地检查文件URL
        do {
            // 使用更安全的选项配置
            let options: [NSPasteboard.ReadingOptionKey: Any] = [
                .urlReadingContentsConformToTypes: ["public.item"],
                .urlReadingFileURLsOnly: true
            ]
            
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
                // 创建URL的深拷贝
                let safeURLs = urls.compactMap { URL(string: $0.absoluteString) }
                if !safeURLs.isEmpty {
                    content.fileURLs = safeURLs
                    hasContent = true
                }
            }
        } catch {
            print("读取剪贴板URL时出错: \(error.localizedDescription)")
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
                    // 保存到数据库
                    self.saveToDatabase(content)
                }
            }
        }
    }
    
    // 保存剪贴板内容到数据库
    private func saveToDatabase(_ content: ClipboardContent) {
        guard let modelContext = modelContext else { 
            print("警告: 模型上下文未初始化，数据未保存") 
            return 
        }
        
        // 安全处理图像数据
        var imageData: Data? = nil
        if let image = content.image {
            // 尝试获取更可靠的PNG表示而非TIFF
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                imageData = pngData
            }
        }
        
        // 将ClipboardContent转换为可存储的ClipboardItem
        let clipboardItem = ClipboardItem(
            id: content.id,
            textContent: content.text,
            imageData: imageData,
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
        
        // 安全地复制文本
        if let text = content.text {
            success = pasteboard.setString(text, forType: .string)
            if !success {
                print("警告: 无法复制文本到剪贴板")
            }
        }
        
        // 安全地复制图片
        if let image = content.image {
            do {
                // 使用PNG表示而非直接写入NSImage对象
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    
                    // 创建一个新的NSImage用于写入
                    let safeImage = NSImage(data: pngData)
                    if let safeImage = safeImage {
                        success = pasteboard.writeObjects([safeImage])
                        if !success {
                            print("警告: 无法复制图片到剪贴板")
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
                success = pasteboard.writeObjects(validURLs as [NSURL])
                if !success {
                    print("警告: 无法复制文件URL到剪贴板")
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