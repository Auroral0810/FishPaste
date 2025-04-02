//
//  ClipboardManager.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import Combine
import SwiftData

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
    
    // 定时器用于定期检查剪贴板
    private var timer: Timer?
    // 当前剪贴板数据的校验和，用于检测变化
    private var lastChangeCount: Int = 0
    
    init() {
        // 启动剪贴板监控
        startMonitoring()
        
        // 加载测试数据
        loadDemoData()
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
        // 在实际应用中，这里会显示设置窗口
        // 暂时用一个菜单替代
        let menu = NSMenu(title: "设置")
        
        let monitorToggleItem = NSMenuItem(title: isMonitoring ? "停止监控剪贴板" : "开始监控剪贴板", 
                                  action: #selector(NSApp.sendAction(_:to:from:)), 
                                  keyEquivalent: "")
        monitorToggleItem.target = self
        monitorToggleItem.action = #selector(toggleMonitoring)
        menu.addItem(monitorToggleItem)
        
        let intervalSubmenu = NSMenu()
        for interval in [0.5, 1.0, 2.0, 5.0] {
            let item = NSMenuItem(title: "\(interval)秒", 
                                  action: #selector(NSApp.sendAction(_:to:from:)), 
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.action = #selector(updateInterval(_:))
            if abs(interval - monitoringInterval) < 0.1 {
                item.state = .on
            }
            intervalSubmenu.addItem(item)
        }
        
        let intervalItem = NSMenuItem(title: "剪贴板监视间隔", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalSubmenu
        menu.addItem(intervalItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let startupItem = NSMenuItem(title: "随系统启动", 
                                    action: #selector(NSApp.sendAction(_:to:from:)), 
                                    keyEquivalent: "")
        startupItem.target = self
        startupItem.action = #selector(toggleStartupLaunch)
        // 在实际应用中，这里应该检查是否已经设置为自启动
        menu.addItem(startupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "关于", 
                                  action: #selector(NSApp.sendAction(_:to:from:)), 
                                  keyEquivalent: "")
        menu.addItem(aboutItem)
        
        let feedbackItem = NSMenuItem(title: "发送反馈", 
                                     action: #selector(NSApp.sendAction(_:to:from:)), 
                                     keyEquivalent: "")
        menu.addItem(feedbackItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", 
                                 action: #selector(NSApplication.terminate(_:)), 
                                 keyEquivalent: "q")
        menu.addItem(quitItem)
        
        // 显示菜单
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
    
    @objc private func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    @objc private func updateInterval(_ sender: NSMenuItem) {
        if let interval = sender.representedObject as? Double {
            setMonitoringInterval(interval)
        }
    }
    
    @objc private func toggleStartupLaunch() {
        // 实现设置/取消自启动的逻辑
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
        
        // 检查文本
        if let text = pasteboard.string(forType: .string) {
            content.text = text
            hasContent = true
        }
        
        // 检查图片
        if let image = NSImage(pasteboard: pasteboard) {
            content.image = image
            hasContent = true
        }
        
        // 检查文件URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            content.fileURLs = urls
            hasContent = true
        }
        
        // 如果有内容，则更新当前剪贴板内容并添加到历史记录
        if hasContent {
            DispatchQueue.main.async {
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
        // 数据库保存逻辑（稍后实现）
    }
    
    // 从剪贴板历史中复制项目到当前剪贴板
    func copyToClipboard(_ content: ClipboardContent) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // 复制文本
        if let text = content.text {
            pasteboard.setString(text, forType: .string)
        }
        
        // 复制图片
        if let image = content.image {
            pasteboard.writeObjects([image])
        }
        
        // 复制文件URL
        if let urls = content.fileURLs, !urls.isEmpty {
            pasteboard.writeObjects(urls as [NSURL])
        }
    }
    
    // 清除所有历史记录
    func clearHistory() {
        clipboardHistory.removeAll()
        // 清除数据库（稍后实现）
    }
    
    // 根据ID删除特定项目
    func deleteItems(withIDs ids: Set<UUID>) {
        clipboardHistory.removeAll(where: { ids.contains($0.id) })
        selectedItems.removeAll()
        // 从数据库删除（稍后实现）
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
} 