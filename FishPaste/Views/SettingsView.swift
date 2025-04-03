//
//  SettingsView.swift
//  FishPaste
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import AppKit
import Darwin
import UniformTypeIdentifiers

// 定义设置选项卡
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case shortcuts = "快捷键"
    case rules = "排除规则"
    case sync = "同步"
    case advanced = "高级"
    case about = "关于"
    case experimentLab = "实验室" // 添加新选项
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .shortcuts: return "command"
        case .rules: return "hand.raised"
        case .sync: return "arrow.triangle.2.circlepath.circle"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        case .experimentLab: return "flask.fill"
        }
    }
}

// NSToolbar标识符和项目标识符
extension NSToolbar.Identifier {
    static let settingsToolbar = NSToolbar.Identifier("SettingsToolbar")
}

extension NSToolbarItem.Identifier {
    static let general = NSToolbarItem.Identifier("general")
    static let shortcuts = NSToolbarItem.Identifier("shortcuts")
    static let rules = NSToolbarItem.Identifier("rules")
    static let sync = NSToolbarItem.Identifier("sync")
    static let advanced = NSToolbarItem.Identifier("advanced")
    static let experimentLab = NSToolbarItem.Identifier("experimentLab")
    static let about = NSToolbarItem.Identifier("about")
}

// NSHostingView用于在AppKit中使用SwiftUI视图
class SettingsHostingController: NSHostingController<SettingsContentView?> {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 创建并配置工具栏
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("PreferencesToolbar"))
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifier = nil
        toolbar.showsBaselineSeparator = false
        toolbar.sizeMode = .regular
        
        // 设置工具栏到窗口
        view.window?.toolbar = toolbar
        view.window?.toolbarStyle = .preference
        
        // 设置窗口标题
        view.window?.title = "FishPaste 设置"
        
        // 分配委托
        view.window?.delegate = self
    }
}

// 工具栏委托实现
extension SettingsHostingController: NSToolbarDelegate {
    // 工具栏中允许的项目标识符
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .general,
            .shortcuts,
            .rules,
            .sync,
            .advanced,
            .experimentLab,
            .about
        ]
    }
    
    // 工具栏的默认项目标识符
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .general,
            .shortcuts,
            .rules,
            .sync,
            .advanced,
            .experimentLab,
            .about
        ]
    }
    
    // 根据标识符创建工具栏项目
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        // 根据标识符配置不同的工具栏项目
        switch itemIdentifier {
        case .general:
            configureToolbarItem(toolbarItem, title: "通用", icon: "gear", tag: 0)
        case .shortcuts:
            configureToolbarItem(toolbarItem, title: "快捷键", icon: "command", tag: 1)
        case .rules:
            configureToolbarItem(toolbarItem, title: "排除规则", icon: "hand.raised", tag: 2)
        case .sync:
            configureToolbarItem(toolbarItem, title: "同步", icon: "arrow.triangle.2.circlepath.circle", tag: 3)
        case .advanced:
            configureToolbarItem(toolbarItem, title: "高级", icon: "wrench.and.screwdriver", tag: 4)
        case .experimentLab:
            configureToolbarItem(toolbarItem, title: "实验室", icon: "flask.fill", tag: 5)
        case .about:
            configureToolbarItem(toolbarItem, title: "关于", icon: "info.circle", tag: 6)
        default:
            return nil
        }
        
        return toolbarItem
    }
    
    // 配置工具栏项目的外观和行为
    private func configureToolbarItem(_ toolbarItem: NSToolbarItem, title: String, icon: String, tag: Int) {
        // 创建按钮
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        button.title = ""
        
        // 创建图标
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            button.image = image.withSymbolConfiguration(config)
        }
        
        // 设置按钮样式
        button.bezelStyle = .recessed
        button.imagePosition = .imageOnly
        button.isBordered = true
        button.tag = tag
        
        // 添加按钮点击事件
        button.target = self
        button.action = #selector(toolbarItemClicked(_:))
        
        // 设置工具栏项目属性
        toolbarItem.label = title
        toolbarItem.paletteLabel = title
        toolbarItem.toolTip = title
        toolbarItem.view = button
    }
    
    // 处理工具栏项目点击事件
    @objc private func toolbarItemClicked(_ sender: NSButton) {
        guard let settingsView = self.rootView else { return }
        let selectedTab = SettingsTab.allCases[sender.tag]
        settingsView.selectedTab = selectedTab
    }
}

// 窗口委托实现
extension SettingsHostingController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        // 处理窗口大小调整
        guard let settingsView = self.rootView else { return }
        let newHeight = settingsView.tabSize.height
        if let window = view.window, window.frame.height != newHeight {
            var frame = window.frame
            frame.origin.y += (frame.height - newHeight)
            frame.size.height = newHeight
            window.setFrame(frame, display: true, animate: true)
        }
    }
}

// SwiftUI内容视图
struct SettingsContentView: View {
    @Binding var selectedTab: SettingsTab
    
    let generalTab: AnyView
    let shortcutsTab: AnyView
    let rulesTab: AnyView
    let syncTab: AnyView
    let advancedTab: AnyView
    let aboutTab: AnyView
    let experimentLabTab: AnyView
    
    let tabSize: CGSize
    
    init(selectedTab: Binding<SettingsTab>, 
         generalTab: some View, 
         shortcutsTab: some View, 
         rulesTab: some View, 
         syncTab: some View, 
         advancedTab: some View, 
         aboutTab: some View, 
         experimentLabTab: some View,
         tabSize: CGSize) {
        self._selectedTab = selectedTab
        self.generalTab = AnyView(generalTab)
        self.shortcutsTab = AnyView(shortcutsTab)
        self.rulesTab = AnyView(rulesTab)
        self.syncTab = AnyView(syncTab)
        self.advancedTab = AnyView(advancedTab)
        self.aboutTab = AnyView(aboutTab)
        self.experimentLabTab = AnyView(experimentLabTab)
        self.tabSize = tabSize
    }
    
    var body: some View {
        ZStack {
            // 根据选中的选项卡显示不同的内容
            switch selectedTab {
            case .general:
                generalTab
            case .shortcuts:
                shortcutsTab
            case .rules:
                rulesTab
            case .sync:
                syncTab
            case .advanced:
                advancedTab
            case .about:
                aboutTab
            case .experimentLab:
                experimentLabTab
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// SwiftUI视图包装器
struct SettingsView: View {
    // MARK: - 属性
    @ObservedObject var clipboardManager: ClipboardManager
    
    // 设置状态
    @State private var selectedTab: SettingsTab = .general
    @State private var launchAtStartup = UserDefaults.standard.bool(forKey: "launchAtStartup")
    @State private var enableSounds = UserDefaults.standard.bool(forKey: "enableSoundEffects")
    @State private var showSourceAppIcon = UserDefaults.standard.bool(forKey: "showSourceAppIcon")
    @State private var monitoringInterval = UserDefaults.standard.double(forKey: "monitoringInterval")
    @State private var isCheckingForUpdates = false  // 添加更新检查状态
    @State private var excludedApps: [ExcludedApp] = [] // 添加排除应用列表
    @State private var selectedExcludedAppId: UUID? = nil // 当前选中的排除应用ID
    
    // 其他规则设置
    @State private var ignoreIosData = UserDefaults.standard.bool(forKey: "ignoreIosData")
    @State private var ignorePrivateData = UserDefaults.standard.bool(forKey: "ignorePrivateData")
    @State private var ignoreAutoGeneratedData = UserDefaults.standard.bool(forKey: "ignoreAutoGeneratedData")
    @State private var convertLargeExcelToText = UserDefaults.standard.bool(forKey: "convertLargeExcelToText")
    @State private var ignoreSizeLimit = UserDefaults.standard.string(forKey: "ignoreSizeLimit") ?? "0.0"
    
    // 高级设置
    @State private var useVimKeys = false
    @State private var useQwertyLayout = false
    @State private var showStatusIcon = true
    @State private var statusIconMode = "出现在状态栏图标旁"
    @State private var enableVimNavigation = false
    @State private var removeHistoryDays = 30
    
    // 粘贴设置
    @State private var pasteToActiveApp = true
    @State private var moveToFront = false 
    @State private var pasteFormat = "粘贴为原始文本"
    
    // 历史项目设置
    @State private var deleteAfter = "一个月以后"
    
    // 快捷键录制相关状态
    @State private var recordingAction: String? = nil
    @State private var shortcutValues: [String: String] = [:]
    @State private var eventMonitor: Any? = nil
    @State private var refreshTrigger = UUID() // 添加刷新触发器
    @State private var showingShortcutConflictAlert = false
    @State private var conflictInfo: (shortcut: String, action: String, conflictWith: String)? = nil
    @State private var previousShortcutValue: String? = nil // 保存录制前的快捷键值
    
    // 在SettingsView结构体中添加状态变量，与其他状态变量放在一起
    @State private var useGPUAcceleration = UserDefaults.standard.bool(forKey: "useGPUAcceleration")
    @State private var enableHEXColorRecognition = UserDefaults.standard.bool(forKey: "enableHEXColorRecognition")
    
    let statusIconModes = ["出现在状态栏图标旁", "重置状态"]
    let pasteFormats = ["粘贴为原始文本", "保持格式粘贴", "智能粘贴"]
    let deleteOptions = ["永不", "一周以后", "一个月以后", "三个月以后"]
    
    // 初始化方法，允许指定初始选中的选项卡
    init(clipboardManager: ClipboardManager, initialTab: SettingsTab = .general) {
        self.clipboardManager = clipboardManager
        // 使用_selectedTab以直接设置@State变量
        self._selectedTab = State(initialValue: initialTab)
        
        // 加载保存的快捷键
        loadSavedShortcuts()
        
        // 加载排除应用列表
        loadExcludedApps()
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
                .tag(SettingsTab.general)
                
            shortcutsTab
                .tabItem {
                    Label("快捷键", systemImage: "command")
                }
                .tag(SettingsTab.shortcuts)
                
            rulesTab
                .tabItem {
                    Label("排除规则", systemImage: "hand.raised")
                }
                .tag(SettingsTab.rules)
                
            syncTab
                .tabItem {
                    Label("同步", systemImage: "arrow.triangle.2.circlepath.circle")
                }
                .tag(SettingsTab.sync)
                
            advancedTab
                .tabItem {
                    Label("高级", systemImage: "wrench.and.screwdriver")
                }
                .tag(SettingsTab.advanced)
                
            experimentLabTab
                .tabItem {
                    Label("实验室", systemImage: "flask.fill")
                }
                .tag(SettingsTab.experimentLab)
            
            aboutTab
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 700, height: tabSize.height)
        .onChange(of: selectedTab) { newTab in
            adjustWindowSize()
            
            // 当切换到排除规则标签页时重新加载排除应用列表
            if newTab == .rules {
                print("切换到排除规则标签页，重新加载排除应用列表")
                loadExcludedApps()
            }
        }
        .onAppear {
            adjustWindowSize()
            
            // 如果初始标签页是排除规则，则立即加载排除应用列表
            if selectedTab == .rules {
                print("初始标签页是排除规则，立即加载排除应用列表")
                loadExcludedApps()
            }
        }
        .environmentObject(clipboardManager)
    }
    
    // 根据选项卡获取合适的窗口大小
    internal var tabSize: CGSize {
        switch selectedTab {
        case .general:
            return CGSize(width: 700, height: 220)  // 通用 - 高度从300减小到220
        case .shortcuts:
            return CGSize(width: 700, height: 580)  // 快捷键 - 较高
        case .rules:
            return CGSize(width: 700, height: 450)  // 排除规则 - 中等高度
        case .sync:
            return CGSize(width: 700, height: 280)  // 同步 - 中小高度
        case .advanced:
            return CGSize(width: 700, height: 650)  // 高级 - 最高
        case .about:
            return CGSize(width: 700, height: 360)  // 关于 - 较小高度
        case .experimentLab:
            return CGSize(width: 700, height: 380)  // 实验室 - 中等高度
        }
    }
    
    // 动态调整窗口大小的方法
    private func adjustWindowSize() {
        if let window = NSApplication.shared.windows.first(where: { $0.title.contains("设置") || ($0.contentView?.subviews.first?.subviews.contains(where: { $0.className.contains("TabView") }) ?? false) }) {
            let size = tabSize
            let frame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y + (window.frame.height - size.height), width: size.width, height: size.height)
            window.setFrame(frame, display: true, animate: true)
        }
    }
    
    // 通用设置选项卡
    internal var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                // MARK: - 使用体验
                Text("使用体验")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 1)
                
                // 启动设置
                HStack(spacing: 0) {
                    Text("启动：")
                        .frame(width: 50, alignment: .trailing)
                    
                    Toggle("随系统启动", isOn: $launchAtStartup)
                        .toggleStyle(.checkbox)
                        .onChange(of: launchAtStartup) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "launchAtStartup")
                            clipboardManager.setLaunchAtStartup(newValue)
                        }
                }
                
                // 音效设置
                HStack(spacing: 0) {
                    Text("声音：")
                        .frame(width: 50, alignment: .trailing)
                    
                    Toggle("启用音效", isOn: $enableSounds)
                        .toggleStyle(.checkbox)
                        .onChange(of: enableSounds) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "enableSoundEffects")
                            clipboardManager.setEnableSoundEffects(newValue)
                        }
                }
                
                Divider()
                    .padding(.vertical, 3)
                
                // 支持选项
                HStack {
                    Text("支持：")
                        .frame(width: 50, alignment: .trailing)
                    
                    Button("发送反馈") {
                        sendFeedbackEmail()
                    }
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 15)
                }
                
                // 更新选项
                HStack {
                    Text("更新：")
                        .frame(width: 50, alignment: .trailing)
                    
                    Button(action: {
                        checkForUpdates()
                    }) {
                        if isCheckingForUpdates {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Text("检查更新")
                        }
                    }
                    .controlSize(.regular)
                    .disabled(isCheckingForUpdates)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 15)
                }
                
                // 版本信息
                Text("当前版本: \(getCurrentVersion())")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
                
                Divider()
                    .padding(.vertical, 2)
                
                // 退出选项
                HStack {
                    Text("退出：")
                        .frame(width: 50, alignment: .trailing)
                    
                    Button("退出 FishPaste") {
                        NSApplication.shared.terminate(nil)
                    }
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 15)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .frame(width: 260)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 200)
    }
    
    // 快捷键设置选项卡
    internal var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                Text("快捷键设置")
                    .font(.headline)
                    .padding(.bottom, 10)
                
                Text("为常用操作设置键盘快捷键，以便更高效地使用FishPaste。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            
            // 快捷键列表
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    shortcutRow(label: "激活 FishPaste:", keyText: "⌃⌥⌘F", canEdit: false)
                        .id("激活 FishPaste:\(refreshTrigger)")
                    
                    Divider().padding(.vertical, 8)
                    
                    Group {
                        shortcutRow(label: "重置界面状态:", action: {
                            startRecordingShortcut(for: "重置界面状态:")
                        })
                        .id("重置界面状态:\(refreshTrigger)")
                    
                        shortcutRow(label: "选择上个列表:", action: {
                            startRecordingShortcut(for: "选择上个列表:")
                        })
                        .id("选择上个列表:\(refreshTrigger)")
                    
                        shortcutRow(label: "选择下个列表:", action: {
                            startRecordingShortcut(for: "选择下个列表:")
                        })
                        .id("选择下个列表:\(refreshTrigger)")
                    
                        shortcutRow(label: "快速选择列表", action: {
                            startRecordingShortcut(for: "快速选择列表")
                        })
                        .id("快速选择列表\(refreshTrigger)")
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    Group {
                        shortcutRow(label: "清除剪贴板内容:", action: {
                            startRecordingShortcut(for: "清除剪贴板内容:")
                        })
                        .id("清除剪贴板内容:\(refreshTrigger)")
                    
                        shortcutRow(label: "将最近一个项目以纯文本粘贴:", action: {
                            startRecordingShortcut(for: "将最近一个项目以纯文本粘贴:")
                        })
                        .id("将最近一个项目以纯文本粘贴:\(refreshTrigger)")
                    
                        shortcutRow(label: "清空已保存的项目", action: {
                            startRecordingShortcut(for: "清空已保存的项目")
                        })
                        .id("清空已保存的项目\(refreshTrigger)")
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    // 特殊修饰键设置
                    Group {
                        // 快速粘贴
                        HStack(spacing: 10) {
                            Text("快速粘贴:")
                                .foregroundColor(.primary)
                                .frame(width: 250, alignment: .leading)
                            
                            HStack {
                                Text("按住")
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    startRecordingShortcut(for: "快速粘贴")
                                }) {
                                    if let savedShortcut = shortcutValues["快速粘贴"], !savedShortcut.isEmpty {
                                        Text(savedShortcut)
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .foregroundColor(.primary)
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                            )
                                    } else {
                                        Text("⌘")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .foregroundColor(.primary)
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Text("键")
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 200, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .id("快速粘贴\(refreshTrigger)")
                        
                        // 纯文本模式
                        HStack(spacing: 10) {
                            Text("纯文本模式:")
                                .foregroundColor(.primary)
                                .frame(width: 250, alignment: .leading)
                            
                            HStack {
                                Text("按住")
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    startRecordingShortcut(for: "纯文本模式")
                                }) {
                                    if let savedShortcut = shortcutValues["纯文本模式"], !savedShortcut.isEmpty {
                                        Text(savedShortcut)
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .foregroundColor(.primary)
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                            )
                                    } else {
                                        Text("⌥")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .foregroundColor(.primary)
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Text("键")
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 200, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .id("纯文本模式\(refreshTrigger)")
                    }
                }
                .onAppear {
                    // 加载已保存的快捷键
                    loadSavedShortcuts()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 20)
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $showingShortcutConflictAlert) {
            Alert(
                title: Text("无法使用快捷键"),
                message: Text("\"\(conflictInfo?.shortcut ?? "")\"，因为已用于菜单项\"\(conflictInfo?.conflictWith ?? "")\"。"),
                dismissButton: .default(Text("好"))
            )
        }
    }
    
    // 快捷键行
    @ViewBuilder
    private func shortcutRow(label: String, keyText: String? = nil, isRecording: Bool = false, canEdit: Bool = true, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundColor(.primary)
                .frame(width: 250, alignment: .leading)
            
            if let keyText = keyText {
                // 预设快捷键显示 (但可点击以更改)
                Button {
                    action?()
                } label: {
                    Text(keyText)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .frame(width: 200, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else if canEdit {
                // 可录入的快捷键按钮
                HStack(spacing: 4) {
                    if recordingAction == label {
                        // 录制状态 - 使用原生macOS风格
                        ZStack {
                            Rectangle()
                                .fill(Color(NSColor.controlBackgroundColor))
                                .frame(height: 28)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                            
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                                
                                // 向右箭头
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .padding(.trailing, 8)
                        }
                        .frame(width: 150)
                        
                        // 取消按钮
                        Button(action: {
                            stopRecording()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10, weight: .bold))
                                .padding(4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("取消录制")
                        
                        // 返回按钮 - 只有在有之前的值时才显示
                        if previousShortcutValue != nil {
                            Button(action: {
                                // 恢复之前的值并停止录制
                                if let prevValue = previousShortcutValue,
                                   let action = recordingAction {
                                    shortcutValues[action] = prevValue
                                    UserDefaults.standard.set(prevValue, forKey: "shortcut-\(action)")
                                }
                                stopRecording()
                                refreshTrigger = UUID()
                            }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(4)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("恢复之前的快捷键")
                        }
                    } else if let savedShortcut = shortcutValues[label], !savedShortcut.isEmpty {
                        // 已保存的快捷键显示 - 使用原生macOS风格
                        Button {
                            action?()
                        } label: {
                            // 调试输出
                            let _ = print("显示已保存的快捷键: \(label) -> \(savedShortcut)")
                            
                            // 使用原生macOS风格的按钮
                            HStack {
                                Text(savedShortcut)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // 添加小图标表示已保存
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: 200, alignment: .leading)
                    } else {
                        // 未设置快捷键状态
                        Button {
                            action?()
                        } label: {
                            ZStack {
                                Rectangle()
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .frame(height: 28)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                                
                                HStack {
                                    Text("录制快捷键")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12))
                                    
                                    // 向右箭头
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 200, alignment: .leading)
                    }
                }
                .id("\(label)-\(shortcutValues[label] ?? "none")-\(refreshTrigger)") // 增强ID刷新机制
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(recordingAction == label ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    // 开始录制快捷键
    private func startRecordingShortcut(for action: String) {
        // 如果已经在录制，先停止之前的录制
        if recordingAction != nil {
            stopRecording()
        }
        
        // 保存之前的快捷键值以便返回
        previousShortcutValue = shortcutValues[action]
        
        // 设置当前正在录制的动作
        recordingAction = action
        print("===== 开始录制[\(action)]的快捷键 =====")
        
        // 创建本地事件监听器(只能捕获当前应用的事件，但比全局监听器更可靠)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [self] event in
            // 非常重要：确保只打印keyDown事件的字符，flagsChanged事件没有字符属性
            if event.type == .keyDown {
                print("捕获到本地键盘事件: \(event.type) keyCode: \(event.keyCode) chars: \(event.characters ?? "nil")")
            } else {
                print("捕获到本地键盘事件: \(event.type) keyCode: \(event.keyCode) (修饰键事件)")
            }
            handleKeyEvent(event)
            return event // 返回事件让系统继续处理
        }
    }
    
    // 处理按键事件
    private func handleKeyEvent(_ event: NSEvent) {
        // 确保我们正在录制
        guard let action = recordingAction else { 
            print("没有正在录制的动作，忽略键盘事件")
            return 
        }
        
        // 安全地打印事件信息，避免访问flagsChanged事件的characters属性
        if event.type == .keyDown {
            print("处理键盘事件: 类型=\(event.type), keyCode=\(event.keyCode), 字符=\(event.characters ?? "nil"), modifiers=\(event.modifierFlags.rawValue)")
        } else {
            print("处理键盘事件: 类型=\(event.type), keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")
        }
        
        // 检查是否是"快速粘贴"或"纯文本模式"这两个特殊的修饰键设置
        let isModifierKeyOnly = (action == "快速粘贴" || action == "纯文本模式")
        
        // 处理修饰键事件
        if event.type == .flagsChanged {
            // 更新修饰键状态
            updateModifierKeys(event)
            
            // 如果是单独录制修饰键，直接处理修饰键事件
            if isModifierKeyOnly {
                // 获取修饰键信息
                var shortcutString = ""
                if event.modifierFlags.contains(.command) { shortcutString = "⌘"; print("设置为Command修饰键") }
                else if event.modifierFlags.contains(.option) { shortcutString = "⌥"; print("设置为Option修饰键") }
                else if event.modifierFlags.contains(.control) { shortcutString = "⌃"; print("设置为Control修饰键") }
                else if event.modifierFlags.contains(.shift) { shortcutString = "⇧"; print("设置为Shift修饰键") }
                
                // 只有在有修饰键按下时才保存
                if !shortcutString.isEmpty {
                    print("单独修饰键快捷键: \(shortcutString)")
                    DispatchQueue.main.async { [self] in
                        saveShortcut(shortcutString, for: action)
                        print("UI状态检查 - 当前recordingAction: \(String(describing: recordingAction))")
                        print("UI状态检查 - 保存的快捷键值: \(shortcutValues)")
                        stopRecording()
                    }
                }
            }
            
            return // 仅记录修饰键状态，其他情况不保存
        }
        // 处理普通按键事件
        else if event.type == .keyDown {
            // 获取按键字符
            let character = event.charactersIgnoringModifiers?.uppercased() ?? ""
            
            // 如果按下的是Escape键，取消录制
            if event.keyCode == 53 { // Escape键的keyCode
                print("按下了Escape键，取消录制")
                stopRecording()
                return
            }
            
            // 对于单独修饰键设置，不处理普通按键事件
            if isModifierKeyOnly {
                return
            }
            
            // 将按键转换成容易阅读的形式
            let keyName = getReadableKeyName(for: event.keyCode, character: character)
            print("转换后的按键名称: \(keyName)")
            
            // 添加修饰键前缀
            var shortcutString = ""
            if event.modifierFlags.contains(.command) { shortcutString += "⌘"; print("添加Command修饰键") }
            if event.modifierFlags.contains(.option) { shortcutString += "⌥"; print("添加Option修饰键") }
            if event.modifierFlags.contains(.control) { shortcutString += "⌃"; print("添加Control修饰键") }
            if event.modifierFlags.contains(.shift) { shortcutString += "⇧"; print("添加Shift修饰键") }
            
            // 加上按键名
            shortcutString += keyName
            print("完整快捷键字符串: \(shortcutString)")
            
            // 保存快捷键并停止录制
            if !shortcutString.isEmpty {
                DispatchQueue.main.async { [self] in
                    saveShortcut(shortcutString, for: action)
                    print("UI状态检查 - 当前recordingAction: \(String(describing: recordingAction))")
                    print("UI状态检查 - 保存的快捷键值: \(shortcutValues)")
                    stopRecording()
                }
            } else {
                print("快捷键字符串为空，不保存")
            }
        }
    }
    
    // 更新修饰键状态
    private func updateModifierKeys(_ event: NSEvent) {
        print("修饰键状态更新: \(event.modifierFlags.rawValue)")
        // 这里可以存储当前按下的修饰键状态
    }
    
    // 将keyCode转换为易读的按键名称
    private func getReadableKeyName(for keyCode: UInt16, character: String) -> String {
        // 特殊按键映射
        let specialKeys: [UInt16: String] = [
            123: "←", 124: "→", 125: "↓", 126: "↑", // 箭头键
            36: "↩", 76: "↩", // Return/Enter
            48: "⇥", // Tab
            49: "␣", // Space
            51: "⌫", // Delete (Backspace)
            117: "⌦", // Forward Delete
            115: "⇱", // Home
            119: "⇲", // End
            116: "⇞", // Page Up
            121: "⇟", // Page Down
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        
        // 检查是否是特殊按键
        if let specialKey = specialKeys[keyCode] {
            print("找到特殊按键映射: keyCode \(keyCode) -> \(specialKey)")
            return specialKey
        }
        
        // 字母键的处理
        if !character.isEmpty {
            print("使用字符作为按键名: \(character)")
            return character
        }
        
        // 如果没有字符，使用keyCode
        print("无法识别的按键，使用keyCode: \(keyCode)")
        return "Key\(keyCode)"
    }
    
    // 保存快捷键
    private func saveShortcut(_ shortcut: String, for action: String) {
        // 使用ShortcutManager检查系统快捷键冲突
        if let conflictWith = ShortcutManager.shared.checkForSystemConflicts(shortcut: shortcut) {
            // 显示冲突警告
            conflictInfo = (shortcut, action, conflictWith)
            showingShortcutConflictAlert = true
            return
        }

        // 保存快捷键到状态变量
        print("保存前 shortcutValues: \(shortcutValues)")
        shortcutValues[action] = shortcut
        print("保存后 shortcutValues: \(shortcutValues)")
        
        // 注册快捷键
        ShortcutManager.shared.registerShortcut(for: action, shortcut: shortcut)
        
        // 强制视图更新 - 使用额外的状态变量触发更新
        DispatchQueue.main.async {
            print("成功保存快捷键: \(action) -> \(shortcut)")
            
            // 保存到UserDefaults
            UserDefaults.standard.set(shortcut, forKey: "shortcut-\(action)")
            
            // 强制刷新整个视图
            self.refreshTrigger = UUID()
            print("已触发视图刷新: \(self.refreshTrigger)")
        }
    }
    
    // 停止录制
    private func stopRecording() {
        print("停止录制\(recordingAction != nil ? "[\(recordingAction!)]" : "")的快捷键")
        recordingAction = nil
        
        // 移除事件监听器
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("已移除事件监听器")
        }
    }
    
    // 载入已保存的快捷键
    private func loadSavedShortcuts() {
        print("开始加载已保存的快捷键")
        let shortcuts = [
            "激活 FishPaste:", 
            "重置界面状态:", 
            "选择上个列表:", 
            "选择下个列表:", 
            "快速选择列表",
            "清除剪贴板内容:",
            "将最近一个项目以纯文本粘贴:",
            "清空已保存的项目",
            "快速粘贴",
            "纯文本模式"
        ]
        
        var loadedShortcuts: [String: String] = [:]
        
        // 从UserDefaults加载保存的快捷键
        for shortcut in shortcuts {
            if let value = UserDefaults.standard.string(forKey: "shortcut-\(shortcut)") {
                loadedShortcuts[shortcut] = value
                print("已加载快捷键: \(shortcut) -> \(value)")
                
                // 同时注册到ShortcutManager
                ShortcutManager.shared.registerShortcut(for: shortcut, shortcut: value)
            }
        }
        
        // 更新状态
        DispatchQueue.main.async {
            self.shortcutValues = loadedShortcuts
            print("已更新shortcutValues: \(self.shortcutValues)")
        }
    }
    
    // 加载排除应用列表
    private func loadExcludedApps() {
        print("开始加载排除应用列表...")
        if let data = UserDefaults.standard.data(forKey: "excludedApps") {
            print("找到排除应用数据，大小: \(data.count) 字节")
            do {
                let apps = try JSONDecoder().decode([ExcludedApp].self, from: data)
                DispatchQueue.main.async {
                    self.excludedApps = apps
                    print("成功加载排除应用列表: \(apps.count) 个应用")
                    print("成功更新UI显示排除应用列表")
                    if !apps.isEmpty {
                        print("已加载的应用: \(apps.map { $0.name }.joined(separator: ", "))")
                    }
                }
            } catch {
                print("解码排除应用列表时出错: \(error)")
                print("错误详情: \(error.localizedDescription)")
                // 尝试恢复 - 设置为空列表
                DispatchQueue.main.async {
                    self.excludedApps = []
                }
            }
        } else {
            print("UserDefaults中没有找到排除应用数据，使用空列表")
            DispatchQueue.main.async {
                self.excludedApps = []
            }
        }
    }
    
    // 排除规则选项卡
    internal var rulesTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabView {
                // 根据App选项卡
                VStack(alignment: .leading, spacing: 20) {
                    Text("如果当前App在\"排除列表\"中，则FishPaste会忽略复制操作。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(excludedApps) { app in
                                HStack(spacing: 15) {
                                    if let appIcon = app.icon {
                                        Image(nsImage: appIcon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                    } else {
                                        Image(systemName: "app.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text(app.name)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .contentShape(Rectangle())
                                .background(selectedExcludedAppId == app.id ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    selectedExcludedAppId = app.id
                                }
                            }
                        }
                        .id(UUID()) // 强制在每次渲染时重新创建视图
                    }
                    .frame(maxHeight: .infinity)
                    
                    HStack {
                        Button(action: {
                            selectAndAddApplication()
                        }) {
                            Label("添加应用", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            removeSelectedApplication()
                        }) {
                            Label("移除", systemImage: "minus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedExcludedAppId == nil)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .tabItem {
                    Label("根据App", systemImage: "app.badge")
                }
                .onAppear {
                    // 每次显示此视图时重新加载排除列表
                    loadExcludedApps()
                }
                .id("ExcludedAppsTab-\(excludedApps.count)") // 当应用列表数量变化时重新创建视图
                
                // 其他规则选项卡
                VStack(alignment: .leading, spacing: 20) {
                    Text("设置其他排除规则以自定义FishPaste的复制行为。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // 根据截图添加规则选项
                    VStack(alignment: .leading, spacing: 24) {
                        Toggle("忽略来自 iOS 设备的剪贴板数据", isOn: $ignoreIosData)
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                            .onChange(of: ignoreIosData) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "ignoreIosData")
                                updateClipboardRules()
                            }
                        
                        Toggle("忽略标记为机密的剪贴板数据", isOn: $ignorePrivateData)
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                            .onChange(of: ignorePrivateData) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "ignorePrivateData")
                                updateClipboardRules()
                            }
                        
                        Toggle("忽略标记为自动生成的剪贴板数据", isOn: $ignoreAutoGeneratedData)
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                            .onChange(of: ignoreAutoGeneratedData) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "ignoreAutoGeneratedData")
                                updateClipboardRules()
                            }
                        
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        
                        // Excel文件大小限制
                        Toggle("当 Excel 中的内容超过 100 KB 时，仅存为纯文本", isOn: $convertLargeExcelToText)
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                            .onChange(of: convertLargeExcelToText) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "convertLargeExcelToText")
                                updateClipboardRules()
                            }
                        
                        // 文件大小限制
                        HStack(spacing: 15) {
                            Text("忽略剪贴板数据大于")
                                .padding(.leading, 20)
                            
                            TextField("", text: $ignoreSizeLimit)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: ignoreSizeLimit) { newValue in
                                    // 确保输入是有效的数字
                                    let filtered = newValue.filter { "0123456789.".contains($0) }
                                    if filtered != newValue {
                                        ignoreSizeLimit = filtered
                                    }
                                    UserDefaults.standard.set(ignoreSizeLimit, forKey: "ignoreSizeLimit")
                                    updateClipboardRules()
                                }
                            
                            Text("MB")
                            
                            Spacer()
                        }
                        
                        Text("如果您不想按大小忽略，请设置为零")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
                .tabItem {
                    Label("其他规则", systemImage: "list.bullet")
                }
                .onAppear {
                    // 加载保存的设置
                    ignoreIosData = UserDefaults.standard.bool(forKey: "ignoreIosData")
                    ignorePrivateData = UserDefaults.standard.bool(forKey: "ignorePrivateData")
                    ignoreAutoGeneratedData = UserDefaults.standard.bool(forKey: "ignoreAutoGeneratedData")
                    convertLargeExcelToText = UserDefaults.standard.bool(forKey: "convertLargeExcelToText")
                    ignoreSizeLimit = UserDefaults.standard.string(forKey: "ignoreSizeLimit") ?? "0.0"
                }
            }
            .padding(.vertical, 10)
        }
    }
    
    // 同步选项卡
    internal var syncTab: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.circle")
                    .font(.system(size: 60))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.blue)
                
                Text("iCloud 同步")
                    .font(.title)
                    .fontWeight(.medium)
                
                VStack(spacing: 10) {
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                        .scaleEffect(1.2)
                        .frame(width: 50)
                        .disabled(true)  // 禁用开关
                    
                    Text("开启后自动同步剪贴板历史记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer().frame(height: 10)
                
                Button("立刻同步") {
                    // 显示提示框
                    let alert = NSAlert()
                    alert.messageText = "功能即将推出"
                    alert.informativeText = "由于经费有限，当前版本暂不支持Cloud同步，后续版本即将推出。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "好的")
                    alert.runModal()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(width: 120)
                
                Text("最近同步: 从未同步")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .frame(maxWidth: 300)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 高级设置选项卡
    internal var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Spacer().frame(height: 14)
                
                // 键盘设置
                KeyboardSettingsSection(useVimKeys: $useVimKeys, useQwertyLayout: $useQwertyLayout)
                
                // 菜单栏设置
                MenuBarSettingsSection(showStatusIcon: $showStatusIcon, statusIconMode: $statusIconMode, statusIconModes: statusIconModes)
                
                // 粘贴选项设置
                PasteSettingsSection(pasteToActiveApp: $pasteToActiveApp, moveToFront: $moveToFront, pasteFormat: $pasteFormat, pasteFormats: pasteFormats)
                
                // 历史项目设置
                HistorySettingsSection(deleteAfter: $deleteAfter, deleteOptions: deleteOptions)
                
                Spacer().frame(height: 14)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
    
    // 关于选项卡
    internal var aboutTab: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 25) {
                // 应用图标 - 使用自定义应用Logo
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.18, blue: 0.22))
                        .frame(width: 120, height: 120)
                    
                    // 直接从Asset Catalog加载图标
                    Image("logo-circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                }
                
                // 应用信息
                VStack(spacing: 8) {
                    Text("FishPaste")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("版本 0.1.0")
                        .foregroundColor(.secondary)
                }
                
                // 分隔线
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 1)
                
                // 版权信息
                VStack(spacing: 8) {
                    Text("© 2025 俞云烽")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    Text("保留所有权利")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                // 链接
                HStack(spacing: 20) {
                    Button("隐私政策") {
                        // 打开隐私政策
                        if let url = URL(string: "https://auroral0810.github.io/fishpaste-pages/privacy.html") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    
                    Button("服务条款") {
                        // 打开服务条款
                        if let url = URL(string: "https://auroral0810.github.io/fishpaste-pages/terms.html") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                }
                .padding(.top, 10)
            }
            .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 实验室选项卡
    internal var experimentLabTab: some View {
        VStack(alignment: .center, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("这里是实验性功能，可能不稳定或在未来的版本中更改。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    
                    GroupBox(label: Text("功能预览").font(.headline)) {
                        VStack(alignment: .leading, spacing: 15) {
                            Toggle("自动获取链接的标题", isOn: .constant(false))
                                .toggleStyle(.checkbox)
                            
                            Toggle("启用模糊搜索", isOn: .constant(false))
                                .toggleStyle(.checkbox)
                            
                            Toggle("新的\"置顶窗口功能\"", isOn: .constant(false))
                                .toggleStyle(.checkbox)
                        }
                        .padding()
                    }
                    .padding(.horizontal, 40)
                    
                    GroupBox(label: Text("性能选项").font(.headline)) {
                        VStack(alignment: .leading, spacing: 15) {
                            Toggle("使用GPU加速图像处理", isOn: $useGPUAcceleration)
                                .toggleStyle(.checkbox)
                                .onChange(of: useGPUAcceleration) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "useGPUAcceleration")
                                    applyGPUAccelerationSetting(newValue)
                                }
                            
                            Toggle("HEX颜色识别", isOn: $enableHEXColorRecognition)
                                .toggleStyle(.checkbox)
                                .onChange(of: enableHEXColorRecognition) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "enableHEXColorRecognition")
                                    applyHEXColorRecognitionSetting(newValue)
                                }
                        }
                        .padding()
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 30)
            }
        }
    }
    
    // 发送反馈邮件
    internal func sendFeedbackEmail() {
        // 准备邮件数据
        let recipient = "15968588744@163.com"
        let subject = "FishPaste反馈"
        
        // 收集系统信息
        let appVersion = getCurrentVersion()
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceModel = getMacModel()
        let deviceUUID = "UUID-" + UUID().uuidString
        
        // 邮件正文
        let body = """
        FishPaste (Official): \(appVersion)
        System: \(systemVersion)
        Device: \(deviceModel)
        UUID: \(deviceUUID)
        
        我的反馈：
        
        
        """
        
        // 创建附件内容
        let settingsContent = generateSettingsFileContent()
        
        // 保存临时附件文件
        let tempDir = FileManager.default.temporaryDirectory
        let attachmentFile = tempDir.appendingPathComponent("AppSettings.txt")
        
        do {
            try settingsContent.write(to: attachmentFile, atomically: true, encoding: .utf8)
            
            // 使用系统分享服务直接打开邮件并附加文件
            // 首先创建共享内容
            let sharingService = NSSharingService(named: NSSharingService.Name.composeEmail)
            
            if let sharingService = sharingService {
                // 设置收件人
                sharingService.recipients = [recipient]
                                
                // 准备要分享的内容：正文文本和附件文件
                let sharingItems: [Any] = [
                    subject as NSString,
                    body as NSString,
                    attachmentFile
                ]
                
                // 检查是否可以分享这些内容
                if sharingService.canPerform(withItems: sharingItems) {
                    // 执行分享操作
                    sharingService.perform(withItems: sharingItems)
                } else {
                    print("无法执行邮件分享操作")
                    simpleMailtoLink(recipient: recipient, subject: subject, body: body)
                }
            } else {
                print("无法创建邮件分享服务")
                simpleMailtoLink(recipient: recipient, subject: subject, body: body)
            }
        } catch {
            print("创建附件文件失败: \(error)")
            simpleMailtoLink(recipient: recipient, subject: subject, body: body)
        }
    }
    
    // 简单的mailto链接方法，作为最后的回退方案
    private func simpleMailtoLink(recipient: String, subject: String, body: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURLString = "mailto:\(recipient)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        if let mailtoURL = URL(string: mailtoURLString) {
            NSWorkspace.shared.open(mailtoURL)
        }
    }
    
    // 获取Mac型号
    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    // 生成设置文件内容
    private func generateSettingsFileContent() -> String {
        let defaults = UserDefaults.standard
        
        // 收集所有设置项
        var settings = [String: Any]()
        settings["useDvorakKeyboardLayout"] = defaults.bool(forKey: "useDvorakKeyboardLayout") ? 1 : 0
        settings["quickPaste"] = 1048576
        settings["pasteToActiveApp"] = defaults.bool(forKey: "pasteToActiveApp") ? 1 : 0
        settings["showStatusItem"] = defaults.bool(forKey: "showStatusItem") ? 1 : 0
        settings["navigationByVimKey"] = defaults.bool(forKey: "navigationByVimKey") ? 1 : 0
        settings["removeHistoryItemsAfter"] = defaults.integer(forKey: "removeHistoryItemsAfter")
        settings["floatWindowRect"] = "{{1374, 275}, {360, 825}}"
        settings["monitorPasteboardInterval"] = defaults.double(forKey: "monitoringInterval")
        
        // 添加快捷键设置
        // 注意：实际应用中应该从UserDefaults或其他设置存储中读取这些值
        settings["shortcuts-select-interface"] = """
        ["characters": V, "keyCode": 9, "modifierFlags": 1179648, "charactersIgnoringModifiers": v]
        """
        settings["shortcuts-reset-state"] = """
        ["characters": R, "keyCode": 15, "modifierFlags": 1048576, "charactersIgnoringModifiers": r]
        """
        settings["shortcuts-select-previous-list"] = """
        ["characters": [, "keyCode": 33, "modifierFlags": 1179648, "charactersIgnoringModifiers": {]
        """
        settings["shortcuts-select-next-list"] = """
        ["characters": ], "keyCode": 30, "modifierFlags": 1179648, "charactersIgnoringModifiers": }]
        """
        
        // 转换为文本格式
        var settingsText = ""
        for (key, value) in settings {
            settingsText += "\(key): \(value)\n"
        }
        
        return settingsText
    }
    
    // 获取当前版本
    func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    
    // 检查更新
    private func checkForUpdates() {
        isCheckingForUpdates = true
        
        // 使用UpdateChecker执行更新检查
        UpdateChecker.shared.checkForUpdates { _, _, _, _ in
            // 完成后重置状态
            DispatchQueue.main.async {
                self.isCheckingForUpdates = false
            }
        }
    }
    
    // 添加排除应用的数据模型
    struct ExcludedApp: Identifiable, Codable {
        var id: UUID
        var name: String
        var bundleIdentifier: String
        var path: String
        
        var icon: NSImage? {
            if let appURL = URL(string: path) {
                return NSWorkspace.shared.icon(forFile: appURL.path)
            }
            return nil
        }
        
        enum CodingKeys: String, CodingKey {
            case id, name, bundleIdentifier, path
        }
    }
    
    // 选择并添加应用到排除列表
    private func selectAndAddApplication() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [UTType.application]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.title = "选择要添加到排除列表的应用"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                self.addApplicationToExcludedList(url)
            }
        }
    }
    
    // 添加应用到排除列表
    private func addApplicationToExcludedList(_ url: URL) {
        let bundle = Bundle(url: url)
        
        guard let bundleIdentifier = bundle?.bundleIdentifier else {
            print("无法获取应用的Bundle标识符")
            return
        }
        
        // 检查是否已经在列表中
        if excludedApps.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
            print("应用已在排除列表中: \(url.lastPathComponent)")
            return
        }
        
        let appName = url.deletingPathExtension().lastPathComponent
        
        let excludedApp = ExcludedApp(
            id: UUID(),
            name: appName,
            bundleIdentifier: bundleIdentifier,
            path: url.absoluteString
        )
        
        excludedApps.append(excludedApp)
        saveExcludedApps()
        
        print("已添加应用到排除列表: \(appName) (\(bundleIdentifier))")
    }
    
    // 从排除列表中移除选中的应用
    private func removeSelectedApplication() {
        guard let selectedId = selectedExcludedAppId,
              let index = excludedApps.firstIndex(where: { $0.id == selectedId }) else {
            return
        }
        
        let appName = excludedApps[index].name
        excludedApps.remove(at: index)
        selectedExcludedAppId = nil
        saveExcludedApps()
        
        print("已从排除列表中移除应用: \(appName)")
    }
    
    // 保存排除应用列表
    private func saveExcludedApps() {
        do {
            let data = try JSONEncoder().encode(excludedApps)
            UserDefaults.standard.set(data, forKey: "excludedApps")
            UserDefaults.standard.synchronize() // 确保立即同步数据到磁盘
            print("已保存排除应用列表: \(excludedApps.count) 个应用")
            
            // 通知ClipboardManager重新加载排除列表
            clipboardManager.refreshExcludedApps()
        } catch {
            print("编码排除应用列表时出错: \(error)")
        }
    }
    
    // 在合适的位置添加这个方法，用于通知ClipboardManager规则已更新
    private func updateClipboardRules() {
        // 创建规则配置
        let rules = [
            "ignoreIosData": ignoreIosData,
            "ignorePrivateData": ignorePrivateData,
            "ignoreAutoGeneratedData": ignoreAutoGeneratedData,
            "convertLargeExcelToText": convertLargeExcelToText,
            "ignoreSizeLimit": Double(ignoreSizeLimit) ?? 0.0
        ] as [String : Any]
        
        // 通知ClipboardManager规则已更新
        clipboardManager.updateClipboardRules(rules: rules)
        
        print("已更新剪贴板规则设置")
    }
    
    // 应用GPU加速设置
    private func applyGPUAccelerationSetting(_ enabled: Bool) {
        if enabled {
            print("启用GPU加速图像处理")
            // 在这里实现GPU加速处理的逻辑
            if let processingConfig = clipboardManager.getImageProcessingConfig() {
                var updatedConfig = processingConfig
                updatedConfig.useGPU = true
                clipboardManager.updateImageProcessingConfig(updatedConfig)
            }
        } else {
            print("禁用GPU加速图像处理")
            // 在这里实现禁用GPU加速的逻辑
            if let processingConfig = clipboardManager.getImageProcessingConfig() {
                var updatedConfig = processingConfig
                updatedConfig.useGPU = false
                clipboardManager.updateImageProcessingConfig(updatedConfig)
            }
        }
    }
    
    // 应用HEX颜色识别设置
    private func applyHEXColorRecognitionSetting(_ enabled: Bool) {
        if enabled {
            print("启用HEX颜色识别")
            // 在这里实现颜色识别的逻辑
            clipboardManager.setHEXColorRecognitionEnabled(true)
        } else {
            print("禁用HEX颜色识别")
            // 在这里实现禁用颜色识别的逻辑
            clipboardManager.setHEXColorRecognitionEnabled(false)
        }
    }
}

// 部分标题组件
struct SectionTitle: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
            .padding(.bottom, 4)
    }
}

// 菜单栏设置部分
struct MenuBarSettingsSection: View {
    @Binding var showStatusIcon: Bool
    @Binding var statusIconMode: String
    let statusIconModes: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("菜单栏设置")
                .font(.headline)
                .padding(.horizontal, 60)
            
            Divider()
                .padding(.horizontal, 60)
            
            Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 16) {
                // 菜单栏图标显示
                GridRow {
                    Text("菜单栏:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    Toggle("显示状态图标", isOn: $showStatusIcon)
                        .toggleStyle(.checkbox)
                }
                
                // 快捷键激活设置
                GridRow {
                    Text("快捷键激活时:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    Picker("", selection: $statusIconMode) {
                        ForEach(statusIconModes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    .frame(width: 240)
                }
                
                // 界面显示设置
                GridRow {
                    Text("显示界面时:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: .constant("有新内容时重置状态")) {
                            Text("有新内容时重置状态").tag("有新内容时重置状态")
                        }
                        .frame(width: 240)
                        
                        Text("有新内容时滚动到顶部并退出搜索状态")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.05))
    }
}

// 键盘设置部分
struct KeyboardSettingsSection: View {
    @Binding var useVimKeys: Bool
    @Binding var useQwertyLayout: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("键盘设置")
                .font(.headline)
                .padding(.horizontal, 60)
            
            Divider()
                .padding(.horizontal, 60)
            
            Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 16) {
                // Vim键绑定设置
                GridRow {
                    Text("Vim键绑定:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    Toggle("使用HJKL键在项目与列表间导航", isOn: $useVimKeys)
                        .toggleStyle(.checkbox)
                }
                
                // 键盘布局设置
                GridRow {
                    Text("键盘布局:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    Toggle("使用德沃夏克键盘布局", isOn: $useQwertyLayout)
                        .toggleStyle(.checkbox)
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.05))
    }
}

// 粘贴设置部分
struct PasteSettingsSection: View {
    @Binding var pasteToActiveApp: Bool
    @Binding var moveToFront: Bool
    @Binding var pasteFormat: String
    let pasteFormats: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("粘贴选项")
                .font(.headline)
                .padding(.horizontal, 60)
            
            Divider()
                .padding(.horizontal, 60)
            
            Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 16) {
                // 粘贴到活动App
                GridRow {
                    Text("粘贴选项:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("粘贴至当前激活的App", isOn: $pasteToActiveApp)
                            .toggleStyle(.checkbox)
                        
                        Text("需要辅助功能权限")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading, 20)
                    }
                }
                
                // 粘贴后移至最前
                GridRow {
                    Text("")
                        .gridColumnAlignment(.trailing)
                        .frame(width: 120)
                    
                    Toggle("粘贴后将项目移至最前", isOn: $moveToFront)
                        .toggleStyle(.checkbox)
                }
                
                // 粘贴文本格式
                GridRow {
                    Text("粘贴文本:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $pasteFormat) {
                            ForEach(pasteFormats, id: \.self) { format in
                                Text(format).tag(format)
                            }
                        }
                        .frame(width: 240)
                        
                        Text("按住 ⌥ Option 键以粘贴纯文本")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.05))
    }
}

// 历史记录设置部分
struct HistorySettingsSection: View {
    @Binding var deleteAfter: String
    let deleteOptions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("历史记录")
                .font(.headline)
                .padding(.horizontal, 60)
            
            Divider()
                .padding(.horizontal, 60)
            
            Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 16) {
                // 移除历史项目
                GridRow {
                    Text("移除历史项目:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $deleteAfter) {
                            ForEach(deleteOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .frame(width: 240)
                        
                        Text("添加至普通列表的项目不会被移除")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.05))
    }
}

#Preview {
    SettingsView(clipboardManager: ClipboardManager())
} 

