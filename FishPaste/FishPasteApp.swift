//
//  FishPasteApp.swift
//  FishPaste
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData
import AppKit
import ServiceManagement

@main
struct FishPasteApp: App {
    // 状态管理
    @StateObject private var clipboardManager = ClipboardManager()
    // 设置存储
    @AppStorage("launchAtStartup") private var launchAtStartup = true {
        didSet {
            // 当设置变更时应用启动项设置
            if oldValue != launchAtStartup {
                Self.checkAndApplyStartupSetting(launchAtStartup)
            }
        }
    }
    // 控制主窗口的显示状态
    @State private var showMainWindow = false
    
    // 提供一个静态实例，以便其他视图可以访问
    static var shared: FishPasteApp!
    
    // 全局活动窗口引用数组，防止窗口被释放
    static var activeWindows: [NSWindow] = []
    
    // 状态栏图标动画控制器
    private let statusItemAnimator = StatusItemAnimator.shared
    
    init() {
        FishPasteApp.shared = self
        
        // 设置UserDefaults默认值
        setupDefaultUserDefaults()
        
        // 初始化状态栏动画控制器(这样确保它在应用程序生命周期内存在)
        print("FishPasteApp初始化，设置状态栏动画器")
        _ = statusItemAnimator
        
        // 在初始化完成后异步设置随系统启动
        let launchSetting = launchAtStartup // 复制值到本地变量
        DispatchQueue.main.async {
            print("异步执行启动项设置")
            Self.checkAndApplyStartupSetting(launchSetting) // 使用本地变量
        }
    }
    
    // 设置UserDefaults默认值
    private func setupDefaultUserDefaults() {
        let defaultValues: [String: Any] = [
            "launchAtStartup": true,
            "enableSoundEffects": true,
            "showSourceAppIcon": true,
            "monitoringInterval": 0.1
        ]
        
        UserDefaults.standard.register(defaults: defaultValues)
        print("已设置UserDefaults默认值")
    }
    
    // 检查并应用随系统启动设置
    private static func checkAndApplyStartupSetting(_ enabled: Bool) {
        if enabled {
            DispatchQueue.main.async {
                applyStartupSetting(enabled)
            }
        }
    }
    
    // 应用随系统启动设置
    private static func applyStartupSetting(_ launchAtStartup: Bool) {
        // 获取应用的 Bundle ID
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("无法获取应用 Bundle ID")
            return
        }
        
        if #available(macOS 13.0, *) {
            // 使用 macOS 13 及以上版本的新 API
            do {
                let service = SMAppService.mainApp
                if launchAtStartup && service.status != .enabled {
                    try service.register()
                    print("应用启动时：已设置为随系统启动")
                }
            } catch {
                print("设置随系统启动失败: \(error.localizedDescription)")
            }
        } else {
            // 使用老版本的 API
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, launchAtStartup)
            if success {
                print("应用启动时：已应用随系统启动设置")
            } else {
                print("应用启动时：设置随系统启动失败")
            }
        }
    }
    
    // SwiftData模型容器配置
    var sharedModelContainer: ModelContainer = {
        do {
            // 配置持久化存储选项
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false
            )
            
            // 创建具有错误恢复和迁移选项的ModelContainer
            let container = try ModelContainer(
                for: ClipboardItem.self, ClipboardCategory.self,
                configurations: modelConfiguration
            )
            print("SwiftData模型容器成功初始化")
            return container
        } catch {
            // 如果创建失败，尝试使用内存存储模式作为备用
            print("初始化持久化ModelContainer失败，错误: \(error.localizedDescription)")
            print("尝试使用内存存储作为备用...")
            
            do {
                let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: ClipboardItem.self, ClipboardCategory.self,
                    configurations: fallbackConfiguration
                )
            } catch {
                fatalError("无法创建任何ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        // 状态栏菜单
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(self.clipboardManager)
                .frame(width: 350)
                .modelContainer(sharedModelContainer)
        } label: {
            // 使用自定义状态栏图标
            Group {
                if let customIcon = loadAppropriateStatusBarIcon() {
                    Image(nsImage: customIcon)
                } else {
                    // 备用：如果找不到自定义图标，使用系统图标
                    Image(systemName: "doc.on.clipboard")
                }
            }
        }
        .menuBarExtraStyle(.window) // 使用窗口样式显示菜单
        
        // 主窗口
        WindowGroup {
            MainView()
                .environmentObject(clipboardManager)
                .preferredColorScheme(.dark) // 强制使用深色模式
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar) // 使用无标题栏风格
        .defaultSize(width: 800, height: 600) // 设置默认窗口大小
        .windowResizability(.contentSize) // 允许调整窗口大小
        .defaultPosition(.center) // 默认在屏幕中央显示
        .commands {
            // 添加自定义命令，以便能通过菜单和快捷键显示窗口
            CommandGroup(after: .newItem) {
                Button("打开FishPaste主窗口") {
                    openMainWindow()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            
            // 自定义关于菜单
            CommandGroup(replacing: .appInfo) {
                Button("关于 FishPaste") {
                    openAboutWindow()
                }
            }
        }
    }
    
    // 打开主窗口的方法
    func openMainWindow() {
        // 查找是否有已存在的FishPaste主窗口
        if let existingWindow = NSApplication.shared.windows.first(where: { $0.title.contains("FishPaste") || $0.identifier?.rawValue.contains("MainWindow") == true }) {
            // 如果找到，将其置于最前面
            existingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        
        // 没有找到现有窗口，创建一个新窗口
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "FishPaste 主窗口"
        newWindow.identifier = NSUserInterfaceItemIdentifier("FishPasteMainWindow")
        newWindow.center()
        
        // 创建SwiftUI视图
        let mainView = MainView()
            .environmentObject(clipboardManager)
            .modelContext(sharedModelContainer.mainContext)
        
        // 创建托管视图
        let hostingController = NSHostingController(rootView: mainView)
        newWindow.contentViewController = hostingController
        
        // 显示窗口
        newWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // 将窗口添加到全局活动窗口数组
        FishPasteApp.activeWindows.append(newWindow)
    }
    
    // 提供一个静态方法，供其他视图调用
    static func openMainWindow() {
        shared.openMainWindow()
    }
    
    // 打开关于窗口
    func openAboutWindow() {
        // 检查是否已有关于窗口
        if let existingWindow = NSApplication.shared.windows.first(where: { $0.title.contains("关于 FishPaste") }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建关于窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "关于 FishPaste"
        window.center()
        
        // 创建关于视图
        let aboutView = AboutView()
        
        // 创建托管视图
        let hostingController = NSHostingController(rootView: aboutView)
        window.contentViewController = hostingController
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // 保持窗口引用
        FishPasteApp.activeWindows.append(window)
    }
    
    // 打开设置窗口
    func openSettingsWindow() {
        // 检查是否已有设置窗口
        if let existingWindow = NSApplication.shared.windows.first(where: { $0.title.contains("FishPaste 设置") }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建设置内容视图
        let settingsView = SettingsView(clipboardManager: clipboardManager)
        
        // 创建窗口控制器并显示
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "FishPaste 设置"
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // 保持窗口引用
        FishPasteApp.activeWindows.append(window)
    }
    
    // 根据系统外观加载合适的状态栏图标
    private func loadAppropriateStatusBarIcon() -> NSImage? {
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        // 在深色模式下使用白色图标，否则使用常规图标
        let iconName = isDarkMode ? "statusBarIcon_white" : "statusBarIcon"
        
        // 直接从Asset Catalog加载图标
        if let customIcon = NSImage(named: iconName) {
            // 设置为模板图像，以便根据状态栏颜色自动调整
            customIcon.isTemplate = true
            return customIcon
        }
        
        // 如果找不到图标，使用系统图标作为备用
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "FishPaste")
    }
}
