//
//  SettingsView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import AppKit

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
        view.window?.title = "FishCopy 设置"
        
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
    var clipboardManager: ClipboardManager
    @State internal var selectedTab: SettingsTab = .general
    
    // 通用设置
    @AppStorage("launchAtStartup") private var launchAtStartup = true
    @AppStorage("enableSounds") private var enableSounds = true
    
    // 高级设置
    @State private var useVimKeys = false
    @State private var useQwertyLayout = false
    @State private var showStatusIcon = true
    @State private var statusIconMode = "出现在状态栏图标旁"
    
    // 粘贴设置
    @State private var pasteToActiveApp = true
    @State private var moveToFront = false 
    @State private var pasteFormat = "粘贴为原始文本"
    
    // 历史项目设置
    @State private var deleteAfter = "一个月以后"
    
    let statusIconModes = ["出现在状态栏图标旁", "重置状态"]
    let pasteFormats = ["粘贴为原始文本", "保持格式粘贴", "智能粘贴"]
    let deleteOptions = ["永不", "一周以后", "一个月以后", "三个月以后"]
    
    // 初始化方法，允许指定初始选中的选项卡
    init(clipboardManager: ClipboardManager, initialTab: SettingsTab = .general) {
        self.clipboardManager = clipboardManager
        // 使用_selectedTab以直接设置@State变量
        self._selectedTab = State(initialValue: initialTab)
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
        .onChange(of: selectedTab) { _ in
            adjustWindowSize()
        }
        .onAppear {
            adjustWindowSize()
        }
        .environmentObject(clipboardManager)
    }
    
    // 根据选项卡获取合适的窗口大小
    internal var tabSize: CGSize {
        switch selectedTab {
        case .general:
            return CGSize(width: 700, height: 300)  // 通用 - 较小
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
        VStack(alignment: .leading, spacing: 0) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 20) {
                // 启动设置
                GridRow {
                    Text("启动:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                    
                    Toggle("随系统启动", isOn: $launchAtStartup)
                        .toggleStyle(.checkbox)
                }
                
                // 声音设置
                GridRow {
                    Text("声音:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                    
                    Toggle("启用音效", isOn: $enableSounds)
                        .toggleStyle(.checkbox)
                }
                
                // 支持选项
                GridRow {
                    Text("支持:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                    
                    Button("发送反馈") {
                        if let url = URL(string: "mailto:feedback@example.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                }
                
                // 更新选项
                GridRow {
                    Text("更新:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Button("检查更新") {
                            // 检查更新的操作
                        }
                        .buttonStyle(.link)
                        
                        Text("当前版本: 0.1.0")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // 退出选项
                GridRow {
                    Text("退出:")
                        .gridColumnAlignment(.trailing)
                        .foregroundColor(.secondary)
                    
                    Button("退出 FishCopy") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(30)
        }
    }
    
    // 快捷键设置选项卡
    internal var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("定制快捷键以使用更加快速的方式操作 FishCopy。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .padding(.bottom, 15)
                    
                    Grid(alignment: .leading, horizontalSpacing: 25, verticalSpacing: 18) {
                        // 标题行
                        GridRow {
                            Text("操作")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 200)
                                .gridColumnAlignment(.trailing)
                            
                            Text("快捷键")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        // 分隔
                        GridRow {
                            Divider()
                                .gridCellColumns(2)
                        }
                        
                        // 预设快捷键部分
                        GridRow {
                            Text("激活 FishCopy:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                                .frame(width: 200)
                            
                            HStack {
                                keyBadge(text: "⌘⌥V")
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        GridRow {
                            Text("重置界面状态:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                keyBadge(text: "⌘R")
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        GridRow {
                            Text("选择上个列表:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                keyBadge(text: "⌘⌃[")
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        GridRow {
                            Text("选择下个列表:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                keyBadge(text: "⌘⌃]")
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        // 分隔
                        GridRow {
                            Color.clear
                                .frame(height: 8)
                            
                            Color.clear
                        }
                        
                        // 可自定义的快捷键部分
                        GridRow {
                            Text("快速选择列表:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("录制快捷键") {
                                    // 录制快捷键的操作
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        GridRow {
                            Text("清除剪贴板内容:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("录制快捷键") {
                                    // 录制快捷键的操作
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        GridRow {
                            Text("清空已保存的项目:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("录制快捷键") {
                                    // 录制快捷键的操作
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        GridRow {
                            Text("将最近一个项目以纯文本粘贴:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("录制快捷键") {
                                    // 录制快捷键的操作
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Spacer()
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        // 分隔
                        GridRow {
                            Divider()
                                .gridCellColumns(2)
                                .padding(.vertical, 8)
                        }
                        
                        // 修饰键设置
                        GridRow {
                            Text("快速粘贴:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Text("按住")
                                modifierKeyBadge(text: "⌘")
                                Text("键")
                                
                                Spacer().frame(width: 10)
                                
                                Picker("", selection: .constant("Command")) {
                                    Text("Command").tag("Command")
                                    Text("Option").tag("Option")
                                    Text("Control").tag("Control")
                                }
                                .frame(width: 100)
                            }
                        }
                        
                        GridRow {
                            Text("纯文本模式:")
                                .gridColumnAlignment(.trailing)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Text("按住")
                                modifierKeyBadge(text: "⌥")
                                Text("键")
                                
                                Spacer().frame(width: 10)
                                
                                Picker("", selection: .constant("Option")) {
                                    Text("Command").tag("Command")
                                    Text("Option").tag("Option")
                                    Text("Control").tag("Control")
                                }
                                .frame(width: 100)
                            }
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // 自定义快捷键显示样式
    @ViewBuilder
    func keyBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
    
    // 修饰键样式
    @ViewBuilder
    func modifierKeyBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    // 排除规则选项卡
    internal var rulesTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabView {
                // 根据App选项卡
                VStack(alignment: .leading, spacing: 20) {
                    Text("如果当前App在\"排除列表\"中，则FishCopy会忽略复制操作。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(["Passwords", "1Password"], id: \.self) { app in
                                HStack(spacing: 15) {
                                    Image(systemName: app == "Passwords" ? "key.fill" : "lock.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(.blue)
                                    
                                    Text(app)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .contentShape(Rectangle())
                                .background(Color.gray.opacity(0.1).cornerRadius(8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    HStack {
                        Button(action: {
                            // 添加应用
                        }) {
                            Label("添加应用", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            // 移除应用
                        }) {
                            Label("移除", systemImage: "minus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .tabItem {
                    Label("根据App", systemImage: "app.badge")
                }
                
                // 其他规则选项卡
                VStack(alignment: .leading, spacing: 20) {
                    Text("设置其他排除规则以自定义FishCopy的复制行为。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // 根据截图添加规则选项
                    VStack(alignment: .leading, spacing: 24) {
                        Toggle("忽略来自 iOS 设备的剪贴板数据", isOn: .constant(true))
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                        
                        Toggle("忽略标记为机密的剪贴板数据", isOn: .constant(true))
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                        
                        Toggle("忽略标记为自动生成的剪贴板数据", isOn: .constant(true))
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        
                        // Excel文件大小限制
                        Toggle("当 Excel 中的内容超过 100 KB 时，仅存为纯文本", isOn: .constant(true))
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 20)
                        
                        // 文件大小限制
                        HStack(spacing: 15) {
                            Text("忽略剪贴板数据大于")
                                .padding(.leading, 20)
                            
                            TextField("", text: .constant("0.0"))
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
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
                    
                    Text("开启后自动同步剪贴板历史记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer().frame(height: 10)
                
                Button("立刻同步") {
                    // 同步操作
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(true)
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
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Spacer().frame(height: 14)
                    
                    // 键盘设置
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
                    
                    // 菜单栏设置
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
                    
                    // 粘贴选项设置
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
                    
                    // 历史项目设置
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
                    
                    Spacer().frame(height: 14)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    // 关于选项卡
    internal var aboutTab: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 25) {
                // 应用图标
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "doc.on.clipboard")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                }
                
                // 应用信息
                VStack(spacing: 8) {
                    Text("FishCopy")
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
                    }
                    .buttonStyle(.link)
                    
                    Button("服务条款") {
                        // 打开服务条款
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
                            Toggle("启用AI智能分类", isOn: .constant(false))
                                .toggleStyle(.checkbox)
                            
                            Toggle("启用模糊搜索", isOn: .constant(false))
                                .toggleStyle(.checkbox)
                            
                            Toggle("允许自定义主题", isOn: .constant(false))
                                .toggleStyle(.checkbox)
                        }
                        .padding()
                    }
                    .padding(.horizontal, 40)
                    
                    GroupBox(label: Text("性能选项").font(.headline)) {
                        VStack(alignment: .leading, spacing: 15) {
                            Toggle("使用GPU加速图像处理", isOn: .constant(false))
                                .toggleStyle(.checkbox)
                            
                            Toggle("后台保持活动状态", isOn: .constant(false))
                                .toggleStyle(.checkbox)
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
}

#Preview {
    SettingsView(clipboardManager: ClipboardManager())
} 
