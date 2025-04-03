//
//  StatusBarMenuView.swift
//  FishPaste
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData  // 添加SwiftData导入
import AppKit  // 添加AppKit导入以使用NSWindow
import Foundation
import UniformTypeIdentifiers  // 添加UniformTypeIdentifiers导入
import CoreServices  // 添加CoreServices导入以使用kUTType常量

// 视图模式枚举 - 加入到结构体外部，便于复用
enum ViewMode: String, CaseIterable {
    case simpleList = "简洁列表"
    case richList = "丰富列表"
    case gridView = "网格视图"
    
    var iconName: String {
        switch self {
        case .simpleList: return "list.bullet"
        case .richList: return "list.dash"
        case .gridView: return "square.grid.2x2"
        }
    }
}

struct StatusBarMenuView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.modelContext) private var modelContext  // 添加modelContext
    @Query(sort: \ClipboardCategory.sortOrder) var categories: [ClipboardCategory]  // 明确按sortOrder排序
    @State private var searchText = ""
    @State private var selectedTab = "全部" // 默认选中"全部"标签
    
    // 添加多选相关状态变量
    @State private var isMultiSelectMode = false
    @State private var selectedItems = Set<UUID>()
    
    // 添加这些状态变量
    @State private var showingNormalListSheet = false
    @State private var showingSmartListSheet = false
    @State private var newListName = ""
    
    // 添加分类管理器窗口状态
    @State private var showingCategoryManager = false
    
    // 添加搜索显示状态变量
    @State private var isSearching: Bool = true
    
    // 固定高度常量
    private let searchBarHeight: CGFloat = 44
    private let tabBarHeight: CGFloat = 36  // 减小了标签栏高度
    private let bottomBarHeight: CGFloat = 44
    private let contentHeight: CGFloat = 320
    
    // 添加视图模式状态
    @State private var viewMode: ViewMode = .simpleList
    @State private var showingViewModeMenu = false
    
    // 状态变量，用于存储通知观察者
    @State private var categoryChangeObserver: NSObjectProtocol?
    
    // 添加置顶窗口状态变量
    @State private var isWindowAlwaysOnTop = false
    
    // 修改RichClipboardItemView结构体中的hexColors变量类型
    @State private var hexColors: [(String, NSColor, String, String)]? = nil  // (标题, 颜色, 样本文本, 来源)
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            topToolbar
            
            // 标签栏区域
            categoryTabBar
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 剪贴板历史列表
            clipboardContentView
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 底部操作区域
            bottomActionBar
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12)) // 深色背景
        .onAppear {
            // 将modelContext传递给clipboardManager
            clipboardManager.setModelContext(modelContext)
            
            // 订阅分类变更通知
            categoryChangeObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("CategoryOrderChanged"),
                object: nil,
                queue: .main
            ) { _ in
                self.refreshCategories()
            }
        }
        .onDisappear {
            // 移除通知订阅
            if let observer = categoryChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    // MARK: - 子视图组件
    
    // 顶部工具栏
    private var topToolbar: some View {
        HStack {
            // 多窗口切换按钮
            Button(action: {
                // 将状态栏窗口转换为独立窗口
                detachWindowFromStatusBar()
            }) {
                Image(systemName: "square.on.square")
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(6)
            }
            .buttonStyle(EffectButtonStyle())
            .frame(width: 28, height: 28)
            .help("在独立窗口中打开") // 添加悬停提示
            
            // 搜索栏
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("输入开始搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // 多选模式切换按钮
            Button(action: {
                toggleMultiSelectMode()
            }) {
                Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(isMultiSelectMode ? .blue : .white)
            }
            .buttonStyle(EffectButtonStyle())
            .frame(width: 28, height: 28)
            .help(isMultiSelectMode ? "退出多选模式" : "进入多选模式")
            
            // 批量复制按钮（仅在多选模式且有选中项时显示）
            if isMultiSelectMode && !selectedItems.isEmpty {
                // 使用本地变量存储选中数量
                let selectedCount = selectedItems.count
                Button(action: {
                    copySelectedItems()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("\(selectedCount)")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(EffectButtonStyle())
                .frame(width: 46, height: 28)
                // 使用本地变量构建提示文本
                .help("复制选中的\(selectedCount)项")
            }
            
            // 隐藏/显示搜索按钮
            Button(action: {
                withAnimation {
                    isSearching.toggle()
                }
            }) {
                Image(systemName: isSearching ? "eye.slash" : "magnifyingglass")
                    .foregroundColor(.white)
            }
            .buttonStyle(EffectButtonStyle())
            .frame(width: 28, height: 28)
            .help(isSearching ? "隐藏搜索" : "显示搜索") // 添加悬停提示
            
            // 置顶按钮
            Button(action: {
                toggleWindowAlwaysOnTop()
            }) {
                Image(systemName: isWindowAlwaysOnTop ? "pin.circle.fill" : "pin.circle")
                    .foregroundColor(isWindowAlwaysOnTop ? .yellow : .white)
            }
            .buttonStyle(EffectButtonStyle())
            .frame(width: 28, height: 28)
            .help("保持窗口在最前端") // 添加悬停提示
            
            // 设置按钮
            Button(action: {
                showSettingsMenu()
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(height: searchBarHeight)
    }
    
    // 分类标签栏
    private var categoryTabBar: some View {
        HStack(spacing: 0) {
            // 标签按钮区域 - 使用ScrollView替代固定HStack
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {  // 减小间距
                    // 全部按钮
                    TabButtonFixed(title: "全部", isSelected: selectedTab == "全部") {
                        selectedTab = "全部"
                    }
                    
                    // 钉选按钮 - 修复为可点击的按钮并与其他标签保持一致
                    Button(action: {
                        selectedTab = "钉选"
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                            Text("钉选")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(selectedTab == "钉选" ? .white : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedTab == "钉选" ? Color.blue : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    
                    // 其他标签按钮
                    TabButtonFixed(title: "今天", isSelected: selectedTab == "今天") {
                        selectedTab = "今天"
                    }
                    
                    TabButtonFixed(title: "文本", isSelected: selectedTab == "文本") {
                        selectedTab = "文本"
                    }
                    
                    TabButtonFixed(title: "图像", isSelected: selectedTab == "图像") {
                        selectedTab = "图像"
                    }
                    
                    TabButtonFixed(title: "链接", isSelected: selectedTab == "链接") {
                        selectedTab = "链接"
                    }
                    
                    // 显示用户创建的分类
                    // 将categories转换为数组，避免在循环中直接使用SwiftData查询结果
                    let categoryArray = Array(categories)
                    ForEach(0..<categoryArray.count, id: \.self) { index in
                        let category = categoryArray[index]
                        TabButtonFixed(title: category.name, isSelected: selectedTab == category.name) {
                            selectedTab = category.name
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
            
            // 删除按钮
            Button(action: {
                openCategoryManagerWindow()
            }) {
                Image(systemName: "minus")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .frame(width: 26, height: 26)
                    .padding(.horizontal, 2)
            }
            .buttonStyle(.borderless)
            
            // 添加按钮，放在最右边
            Menu {
                Button(action: {
                    openNormalListWindow()  // 使用新方法
                }) {
                    Text("创建普通列表")
                }
                
                Button(action: {
                    openSmartListWindow()  // 使用新方法
                }) {
                    Text("创建智能列表")
                }
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .frame(width: 26, height: 26)
                    .padding(.horizontal, 2)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .frame(height: tabBarHeight)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }
    
    // 剪贴板内容视图
    private var clipboardContentView: some View {
        ZStack {
            // 背景颜色，确保空白区域也是深色
            Color(red: 0.1, green: 0.1, blue: 0.12)
                .frame(height: contentHeight)
            
            if filteredClipboardItems.isEmpty {
                // 无内容状态
                VStack(spacing: 15) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("暂无剪贴板历史")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 根据视图模式选择适当的视图组件
                contentViewForCurrentMode
            }
        }
        .frame(height: contentHeight)
    }
    
    // 根据当前视图模式选择内容视图
    @ViewBuilder
    private var contentViewForCurrentMode: some View {
        switch viewMode {
        case .simpleList:
            simpleListView
        case .richList:
            richListView
        case .gridView:
            gridView
        }
    }
    
    // 简单列表视图
    private var simpleListView: some View {
        List {
            ForEach(filteredClipboardItems) { item in
                SimpleClipboardItemRow(item: item, 
                                      isSelected: selectedItems.contains(item.id),
                                      isMultiSelectMode: isMultiSelectMode,
                                      selectedItems: selectedItems,
                                      filteredItems: filteredClipboardItems,
                                      onToggleSelection: toggleItemSelection,
                                      onCopyItem: clipboardManager.copyToClipboard)
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
    }
    
    // 丰富列表视图
    private var richListView: some View {
        List {
            ForEach(filteredClipboardItems) { item in
                RichClipboardItemRow(item: item, 
                                    isSelected: selectedItems.contains(item.id),
                                    isMultiSelectMode: isMultiSelectMode,
                                    selectedItems: selectedItems,
                                    filteredItems: filteredClipboardItems,
                                    onToggleSelection: toggleItemSelection,
                                    onCopyItem: clipboardManager.copyToClipboard)
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
    }
    
    // 网格视图
    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.fixed(130), spacing: 12),
                    GridItem(.fixed(130), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(filteredClipboardItems) { item in
                    GridClipboardItemRow(item: item, 
                                        isSelected: selectedItems.contains(item.id),
                                        isMultiSelectMode: isMultiSelectMode,
                                        selectedItems: selectedItems,
                                        filteredItems: filteredClipboardItems,
                                        onToggleSelection: toggleItemSelection,
                                        onCopyItem: clipboardManager.copyToClipboard)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    // 底部操作栏
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            // 项目计数和视图切换
            HStack {
                // 左侧视图切换按钮
                Button(action: {
                    showingViewModeMenu = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundColor(.white)
                        
                        Text(viewMode.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingViewModeMenu, arrowEdge: .bottom) {
                    viewModePopover
                }
                
                Spacer()
                
                // 项目计数
                Text("\(filteredClipboardItems.count) 个项目")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                // 清除历史按钮
                Button(action: {
                    clipboardManager.clearHistory()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        }
    }
    
    // 视图模式选择弹出窗口
    private var viewModePopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    viewMode = mode
                    showingViewModeMenu = false
                }) {
                    HStack {
                        Image(systemName: mode.iconName)
                        Text(mode.rawValue)
                    }
                    .foregroundColor(.white)
                    .frame(minWidth: 120, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(viewMode == mode ? Color.blue.opacity(0.5) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(8)
        .padding(4)
    }
    
    // 设置通知监听
    private func setupCategoryChangeNotification() {
        categoryChangeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("CategoryOrderChanged"),
            object: nil,
            queue: .main
        ) { _ in
            self.refreshCategories()
        }
    }
    
    // 移除通知监听
    private func removeCategoryChangeNotification() {
        if let observer = categoryChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            categoryChangeObserver = nil
        }
    }
    
    // 添加刷新分类方法
    private func refreshCategories() {
        // 通过重载Query模拟器强制UI刷新
        print("分类顺序已更新，强制刷新UI")
        
        // 一个技巧：创建一个零延迟的异步调度，强制SwiftUI重新评估@Query的结果
        DispatchQueue.main.async {
            // 这个空块会让SwiftUI在下一个渲染周期重新评估视图
            // 包括刷新@Query的结果并重新排序标签
        }
        
        // 为确保视图再次接收到新顺序，我们可以尝试重新设置modelContext
        // 这会触发@Query重新连接到数据库
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.clipboardManager.setModelContext(self.modelContext)
        }
    }
    
    // 替换原有的sheet方法，使用NSWindow替代
    private func openNormalListWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "创建普通列表"
        
        // 添加窗口关闭回调，在关闭时从activeWindows中移除
        window.isReleasedWhenClosed = false
        
        // 点击保存时的逻辑
        let contentView = CreateListView(
            title: "请输入新列表的名字",
            listName: $newListName,
            onSave: {
                // 安全检查
                if self.newListName.isEmpty {
                    self.closeWindow(window)
                    return
                }
                
                // 创建一个全新的分类对象
                let newCategory = ClipboardCategory(name: self.newListName)
                
                // 使用异常处理安全地插入到数据库
                do {
                    // 插入到数据库
                    self.modelContext.insert(newCategory)
                    
                    // 立即尝试保存上下文变更
                    try self.modelContext.save()
                    
                    // 切换到新创建的分类
                    self.selectedTab = self.newListName
                    
                    print("成功创建新分类: \(self.newListName)")
                } catch {
                    print("创建分类时出错: \(error.localizedDescription)")
                }
                
                // 重置输入并关闭窗口
                self.newListName = ""
                self.closeWindow(window)
            }
        )
        .environment(\.colorScheme, .dark)
        
        // 保留对rootView的引用，防止内存回收
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用以防止过早释放
        FishPasteApp.activeWindows.append(window)
    }
    
    // 添加智能列表窗口方法
    private func openSmartListWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "创建智能列表"
        
        // 添加窗口关闭回调，在关闭时从activeWindows中移除
        window.isReleasedWhenClosed = false
        
        // 点击保存时的逻辑
        let contentView = CreateSmartListView(
            listName: $newListName,
            onSave: {
                // 安全检查
                if self.newListName.isEmpty {
                    self.closeWindow(window)
                    return
                }
                
                // 创建一个全新的分类对象
                let newCategory = ClipboardCategory(name: self.newListName)
                
                // 使用异常处理安全地插入到数据库
                do {
                    // 插入到数据库
                    self.modelContext.insert(newCategory)
                    
                    // 立即尝试保存上下文变更
                    try self.modelContext.save()
                    
                    // 切换到新创建的分类
                    self.selectedTab = self.newListName
                    
                    print("成功创建新智能分类: \(self.newListName)")
                } catch {
                    print("创建智能分类时出错: \(error.localizedDescription)")
                }
                
                // 重置输入并关闭窗口
                self.newListName = ""
                self.closeWindow(window)
            }
        )
        .environment(\.colorScheme, .dark)
        
        // 保留对rootView的引用，防止内存回收
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用以防止过早释放
        FishPasteApp.activeWindows.append(window)
    }
    
    // 辅助方法：安全地关闭窗口并从activeWindows中移除
    private func closeWindow(_ window: NSWindow) {
        window.close()
        FishPasteApp.activeWindows.removeAll { $0 === window }
    }
    
    // 打开分类管理器窗口
    private func openCategoryManagerWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "管理分类"
        window.isReleasedWhenClosed = false
        
        // 使用独立文件中定义的CategoryManagerView
        let contentView = CategoryManagerView(modelContext: modelContext)
            .modelContext(modelContext) // 将modelContext注入到环境中
        
        // 保留对rootView的引用，防止内存回收
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用以防止过早释放
        FishPasteApp.activeWindows.append(window)
    }
    
    // 判断当前选中的标签是否可以删除
    private var canDeleteSelectedTab: Bool {
        // 系统默认标签不能删除（全部、钉选、今天、文本、图像、链接）
        let defaultTabs = ["全部", "钉选", "今天", "文本", "图像", "链接"]
        return !defaultTabs.contains(selectedTab)
    }
    
    // 将状态栏窗口转换为独立窗口
    private func detachWindowFromStatusBar() {
        // 获取当前窗口
        guard let currentWindow = NSApp.keyWindow else {
            print("无法获取当前窗口")
            return
        }
        
        // 存储当前窗口的内容和大小
        let contentSize = currentWindow.contentView?.frame.size ?? NSSize(width: 350, height: 450)
        
        // 创建新窗口
        let detachedWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口标题和标识符
        detachedWindow.title = "FishPaste"
        detachedWindow.identifier = NSUserInterfaceItemIdentifier("DetachedFishPasteWindow")
        
        // 将当前窗口位置作为新窗口的位置
        if let screenFrame = currentWindow.screen?.frame {
            let currentOrigin = currentWindow.frame.origin
            detachedWindow.setFrameOrigin(currentOrigin)
        } else {
            detachedWindow.center()
        }
        
        // 保持置顶状态（如果已启用）
        if isWindowAlwaysOnTop {
            detachedWindow.level = .floating
        }
        
        // 创建相同的内容视图
        let contentView = StatusBarMenuView()
            .environmentObject(clipboardManager)
            .frame(minWidth: 350, minHeight: 400)
            .modelContext(modelContext)
        
        // 设置窗口内容
        let hostingView = NSHostingView(rootView: contentView)
        detachedWindow.contentView = hostingView
        
        // 设置窗口最小大小
        detachedWindow.minSize = NSSize(width: 350, height: 400)
        
        // 显示窗口
        detachedWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 关闭当前的状态栏窗口
        currentWindow.close()
        
        // 保存对窗口的引用，防止被释放
        FishPasteApp.activeWindows.append(detachedWindow)
    }
    
    // 修改过滤逻辑，支持自定义分类
    private var filteredClipboardItems: [ClipboardContent] {
        let items = clipboardManager.searchHistory(query: searchText)
        return filterItemsByCategory(items, category: selectedTab)
    }
    
    // 根据分类过滤项目
    private func filterItemsByCategory(_ items: [ClipboardContent], category: String) -> [ClipboardContent] {
        return items.filter { item in
            switch category {
            case "钉选":
                return item.isPinned
            case "今天":
                let calendar = Calendar.current
                return calendar.isDateInToday(item.timestamp)
            case "文本":
                return item.text != nil && item.image == nil && (item.fileURLs?.isEmpty ?? true)
            case "图像":
                return item.image != nil
            case "链接":
                if let text = item.text, text.hasPrefix("http") {
                    return true
                }
                return false
            case "全部":
                return true
            default:
                // 对于自定义分类，根据分类名称过滤
                if let itemCategory = item.category, itemCategory == category {
                    return true
                }
                return false
            }
        }
    }
    
    // 切换窗口置顶状态
    private func toggleWindowAlwaysOnTop() {
        isWindowAlwaysOnTop.toggle()
        
        guard let window = NSApp.keyWindow else { return }
        
        if isWindowAlwaysOnTop {
            // 设置窗口级别为浮动级别（总在最前）
            window.level = .floating
        } else {
            // 恢复正常级别
            window.level = .normal
        }
    }
    
    // 打开设置窗口并指定选中的选项卡
    private func openSettingsWindow(selectedTab: SettingsTab = .general) {
        // 创建并显示设置窗口
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.center()
        settingsWindow.title = "FishPaste 设置"
        
        // 创建设置视图，并指定默认选中的选项卡
        let settingsView = SettingsView(clipboardManager: clipboardManager, initialTab: selectedTab)
        
        // 设置窗口内容
        let hostingView = NSHostingView(rootView: settingsView)
        settingsWindow.contentView = hostingView
        
        // 显示窗口
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用以防止过早释放
        FishPasteApp.activeWindows.append(settingsWindow)
    }
    
    // 显示设置菜单
    private func showSettingsMenu() {
        // 创建菜单
        let menu = NSMenu(title: "设置")
        
        // 添加"激活许可证"选项
        let activateLicenseItem = NSMenuItem(title: "激活许可证", action: nil, keyEquivalent: "")
        activateLicenseItem.target = self as AnyObject
        activateLicenseItem.setAction {
            self.showLicenseActivationDialog()
        }
        menu.addItem(activateLicenseItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 添加"停止监控剪贴板"选项
        let monitorToggleItem = NSMenuItem(
            title: clipboardManager.isMonitoring ? "停止监控剪贴板" : "开始监控剪贴板",
            action: #selector(NSApp.sendAction(_:to:from:)),
            keyEquivalent: ""
        )
        monitorToggleItem.target = clipboardManager
        monitorToggleItem.action = #selector(ClipboardManager.toggleMonitoring)
        menu.addItem(monitorToggleItem)
        
        // 添加强制iOS内容检测选项
        let iosDetectionItem = NSMenuItem(title: "强制iOS内容检测模式", action: nil, keyEquivalent: "")
        iosDetectionItem.target = clipboardManager
        iosDetectionItem.setAction {
            self.clipboardManager.detectIOSDeviceClipboard()
        }
        menu.addItem(iosDetectionItem)
        
        // 添加剪贴板监视间隔子菜单
        let intervalSubmenu = NSMenu()
        for interval in [0.1, 0.5, 1.0, 2.0, 5.0] {
            let item = NSMenuItem(
                title: "\(interval)秒",
                action: #selector(NSApp.sendAction(_:to:from:)),
                keyEquivalent: ""
            )
            item.target = clipboardManager
            item.representedObject = interval
            item.action = #selector(ClipboardManager.updateInterval(_:))
            
            // 检查当前的监控间隔，设置勾选状态
            if abs(interval - clipboardManager.monitoringInterval) < 0.01 {
                item.state = .on
            }
            
            intervalSubmenu.addItem(item)
        }
        
        let intervalItem = NSMenuItem(title: "剪贴板监控间隔", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalSubmenu
        menu.addItem(intervalItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 添加"数据库视图"选项
        let databaseViewItem = NSMenuItem(title: "数据库视图", action: nil, keyEquivalent: "")
        databaseViewItem.target = self as AnyObject
        databaseViewItem.setAction {
            self.openDatabaseViewerWindow()
        }
        menu.addItem(databaseViewItem)
        
        // 添加"设置..."选项
        let settingsItem = NSMenuItem(title: "设置...", action: nil, keyEquivalent: "")
        settingsItem.target = self as AnyObject
        // 使用closure代替@objc方法
        settingsItem.setAction {
            self.openSettingsWindow(selectedTab: .general)
        }
        menu.addItem(settingsItem)
        
        // 添加"随系统启动"选项，带复选标记
        let startupItem = NSMenuItem(
            title: "随系统启动",
            action: #selector(NSApp.sendAction(_:to:from:)),
            keyEquivalent: ""
        )
        startupItem.target = clipboardManager
        startupItem.action = #selector(ClipboardManager.toggleStartupLaunch)
        // 获取当前启动状态并设置选中状态
        if UserDefaults.standard.bool(forKey: "launchAtStartup") {
            startupItem.state = .on
        }
        menu.addItem(startupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 添加"关于"选项
        let aboutItem = NSMenuItem(title: "关于", action: nil, keyEquivalent: "")
        aboutItem.target = self as AnyObject
        // 使用closure代替@objc方法
        aboutItem.setAction {
            self.openSettingsWindow(selectedTab: .about)
        }
        menu.addItem(aboutItem)
        
        // 添加"发送反馈"选项
        let feedbackItem = NSMenuItem(title: "发送反馈", action: nil, keyEquivalent: "")
        feedbackItem.target = self as AnyObject
        feedbackItem.setAction {
            self.sendFeedback()
        }
        menu.addItem(feedbackItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 添加"退出"选项
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        // 获取当前事件并显示菜单
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
    
    // 显示许可证激活弹窗
    private func showLicenseActivationDialog() {
        let alert = NSAlert()
        alert.messageText = "关于FishPaste"
        
        // 作者信息和支持方式
        let informativeText = """
        本项目开源，无需许可证

        作者信息:
        邮箱：15968588744@163.com
        开源地址：https://github.com/Auroral0810/FishPaste
        QQ：1957689514
        个人博客：https://fishblog.yyf040810.cn

        如果您觉得FishPaste对您有所帮助，欢迎请作者喝杯奶茶支持一下~
        您的支持是我持续开发和维护的动力！
        """
        
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        
        // 创建支付二维码视图
        let qrCodeView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 150))
        
        // 使用相对路径加载图片
        let bundle = Bundle.main
        if let alipayImage = NSImage(named: "alipay") {
            // 如果成功从Assets加载
            let alipayImageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 140, height: 140))
            alipayImageView.image = alipayImage
            alipayImageView.imageScaling = .scaleProportionallyUpOrDown
            
            let alipayLabel = NSTextField(labelWithString: "支付宝")
            alipayLabel.frame = NSRect(x: 40, y: 140, width: 60, height: 20)
            alipayLabel.alignment = .center
            alipayLabel.isBordered = false
            alipayLabel.isEditable = false
            alipayLabel.backgroundColor = .clear
            
            qrCodeView.addSubview(alipayImageView)
            qrCodeView.addSubview(alipayLabel)
            
            print("成功加载支付宝图片")
        } else {
            // 创建一个简单的文本标签
            let alipayLabel = NSTextField(labelWithString: "支付宝二维码")
            alipayLabel.frame = NSRect(x: 0, y: 40, width: 140, height: 40)
            alipayLabel.alignment = .center
            alipayLabel.isBordered = false
            alipayLabel.isEditable = false
            alipayLabel.backgroundColor = .clear
            alipayLabel.textColor = NSColor.white
            
            qrCodeView.addSubview(alipayLabel)
            print("无法加载支付宝图片，使用文本替代")
        }
        
        // 添加微信二维码
        if let wechatImage = NSImage(named: "wechat") {
            // 如果成功从Assets加载
            let wechatImageView = NSImageView(frame: NSRect(x: 160, y: 0, width: 140, height: 140))
            wechatImageView.image = wechatImage
            wechatImageView.imageScaling = .scaleProportionallyUpOrDown
            
            let wechatLabel = NSTextField(labelWithString: "微信")
            wechatLabel.frame = NSRect(x: 200, y: 140, width: 60, height: 20)
            wechatLabel.alignment = .center
            wechatLabel.isBordered = false
            wechatLabel.isEditable = false
            wechatLabel.backgroundColor = .clear
            
            qrCodeView.addSubview(wechatImageView)
            qrCodeView.addSubview(wechatLabel)
            
            print("成功加载微信图片")
        } else {
            // 创建一个简单的文本标签
            let wechatLabel = NSTextField(labelWithString: "微信二维码")
            wechatLabel.frame = NSRect(x: 160, y: 40, width: 140, height: 40)
            wechatLabel.alignment = .center
            wechatLabel.isBordered = false
            wechatLabel.isEditable = false
            wechatLabel.backgroundColor = .clear
            wechatLabel.textColor = NSColor.white
            
            qrCodeView.addSubview(wechatLabel)
            print("无法加载微信图片，使用文本替代")
        }
        
        alert.accessoryView = qrCodeView
        
        // 添加按钮
        alert.addButton(withTitle: "了解")
        alert.addButton(withTitle: "访问开源仓库")
        alert.addButton(withTitle: "访问博客")
        
        // 显示对话框并处理点击结果
        let response = alert.runModal()
        
        // 根据点击的按钮执行不同的操作
        switch response {
        case .alertSecondButtonReturn: // 第二个按钮
            if let url = URL(string: "https://github.com/Auroral0810/FishPaste") {
                NSWorkspace.shared.open(url)
            }
        case .alertThirdButtonReturn: // 第三个按钮
            if let url = URL(string: "https://fishblog.yyf040810.cn") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
    
    // 发送反馈
    func sendFeedback() {
        // 创建一个临时的设置视图实例
        let settingsView = SettingsView(clipboardManager: clipboardManager)
        
        // 使用方法
        settingsView.sendFeedbackEmail()
    }
    
    // 打开数据库视图窗口
    private func openDatabaseViewerWindow() {
        // 创建并显示数据库视图窗口
        let dbViewerWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        dbViewerWindow.center()
        dbViewerWindow.title = "数据库视图"
        
        // 创建数据库视图并确保传递正确的modelContext
        let dbViewerView = DatabaseViewerView(modelContext: modelContext)
            .environment(\.modelContext, modelContext) // 确保通过环境也提供modelContext
        
        // 设置窗口内容
        let hostingView = NSHostingView(rootView: dbViewerView)
        dbViewerWindow.contentView = hostingView
        
        // 显示窗口
        dbViewerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用以防止过早释放
        FishPasteApp.activeWindows.append(dbViewerWindow)
    }
    
    // 切换多选模式
    private func toggleMultiSelectMode() {
        withAnimation {
            isMultiSelectMode.toggle()
            if !isMultiSelectMode {
                // 退出多选模式时清空选择
                selectedItems.removeAll()
            }
        }
    }
    
    // 切换项目选择状态
    private func toggleItemSelection(_ item: ClipboardContent) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    // 复制选中的多个项目
    private func copySelectedItems() {
        let itemsToCopy = filteredClipboardItems.filter { selectedItems.contains($0.id) }
        if !itemsToCopy.isEmpty {
            clipboardManager.copyMultipleToClipboard(itemsToCopy)
            
            // 显示成功提示
            let notification = NSUserNotification()
            notification.title = "已复制"
            notification.informativeText = "已复制\(itemsToCopy.count)个项目到剪贴板"
            NSUserNotificationCenter.default.deliver(notification)
            
            // 如果配置为复制后退出多选模式
            //toggleMultiSelectMode()
        }
    }
    
    // MARK: - 行项目组件
    
    // 简单样式的行项目
    private struct SimpleClipboardItemRow: View {
        let item: ClipboardContent
        let isSelected: Bool
        let isMultiSelectMode: Bool
        let selectedItems: Set<UUID>
        let filteredItems: [ClipboardContent]
        let onToggleSelection: (ClipboardContent) -> Void
        let onCopyItem: (ClipboardContent) -> Void
        
        @EnvironmentObject var clipboardManager: ClipboardManager
        
        var body: some View {
            ClipboardItemView(item: item, isSelected: isSelected)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .clipboardItemContextMenu(item: item)
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .modifiers(.command)
                        .onEnded { _ in
                            onToggleSelection(item)
                        }
                )
                .onTapGesture {
                    if isMultiSelectMode {
                        onToggleSelection(item)
                    } else {
                        onCopyItem(item)
                    }
                }
                .onDrag {
                    createDragItemProvider(for: item)
                }
        }
        
        // 创建拖拽内容提供程序
        private func createDragItemProvider(for item: ClipboardContent) -> NSItemProvider {
            if isMultiSelectMode && selectedItems.contains(item.id) {
                // 处理多选拖拽
                let selectedContentItems = selectedItems.compactMap { id -> ClipboardContent? in
                    return filteredItems.first { $0.id == id }
                }
                return clipboardManager.createMultiItemsProvider(from: selectedContentItems)
            } else {
                // 处理单项拖拽
                return clipboardManager.createItemProvider(from: item)
            }
        }
    }
    
    // 丰富样式的行项目
    private struct RichClipboardItemRow: View {
        let item: ClipboardContent
        let isSelected: Bool
        let isMultiSelectMode: Bool
        let selectedItems: Set<UUID>
        let filteredItems: [ClipboardContent]
        let onToggleSelection: (ClipboardContent) -> Void
        let onCopyItem: (ClipboardContent) -> Void
        
        @EnvironmentObject var clipboardManager: ClipboardManager
        
        var body: some View {
            RichClipboardItemView(item: item, isSelected: isSelected)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .clipboardItemContextMenu(item: item)
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .modifiers(.command)
                        .onEnded { _ in
                            onToggleSelection(item)
                        }
                )
                .onTapGesture {
                    if isMultiSelectMode {
                        onToggleSelection(item)
                    } else {
                        onCopyItem(item)
                    }
                }
                .onDrag {
                    createDragItemProvider(for: item)
                }
        }
        
        // 创建拖拽内容提供程序
        private func createDragItemProvider(for item: ClipboardContent) -> NSItemProvider {
            if isMultiSelectMode && selectedItems.contains(item.id) {
                // 处理多选拖拽
                let selectedContentItems = selectedItems.compactMap { id -> ClipboardContent? in
                    return filteredItems.first { $0.id == id }
                }
                return clipboardManager.createMultiItemsProvider(from: selectedContentItems)
            } else {
                // 处理单项拖拽
                return clipboardManager.createItemProvider(from: item)
            }
        }
    }
    
    // 网格样式的行项目
    private struct GridClipboardItemRow: View {
        let item: ClipboardContent
        let isSelected: Bool
        let isMultiSelectMode: Bool
        let selectedItems: Set<UUID>
        let filteredItems: [ClipboardContent]
        let onToggleSelection: (ClipboardContent) -> Void
        let onCopyItem: (ClipboardContent) -> Void
        
        @EnvironmentObject var clipboardManager: ClipboardManager
        
        var body: some View {
            GridClipboardItemView(item: item, isSelected: isSelected)
                .frame(width: 130, height: 130)
                .clipboardItemContextMenu(item: item)
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .modifiers(.command)
                        .onEnded { _ in
                            onToggleSelection(item)
                        }
                )
                .onTapGesture {
                    if isMultiSelectMode {
                        onToggleSelection(item)
                    } else {
                        onCopyItem(item)
                    }
                }
                .onDrag {
                    createDragItemProvider(for: item)
                }
        }
        
        // 创建拖拽内容提供程序
        private func createDragItemProvider(for item: ClipboardContent) -> NSItemProvider {
            if isMultiSelectMode && selectedItems.contains(item.id) {
                // 处理多选拖拽
                let selectedContentItems = selectedItems.compactMap { id -> ClipboardContent? in
                    return filteredItems.first { $0.id == id }
                }
                return clipboardManager.createMultiItemsProvider(from: selectedContentItems)
            } else {
                // 处理单项拖拽
                return clipboardManager.createItemProvider(from: item)
            }
        }
    }
}

// 固定大小的标签按钮 - 更轻量和紧凑
struct TabButtonFixed: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    // 计算处理后的标题，限制长度
    private var displayTitle: String {
        if title.count > 8 {
            return String(title.prefix(5)) + "..."
        }
        return title
    }
    
    var body: some View {
        Button(action: action) {
            Text(displayTitle)
                .font(.system(size: 12)) // 更小的字体
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 8) // 减小水平内边距
                .padding(.vertical, 4) // 减小垂直内边距
                .background(isSelected ? Color.blue : Color.clear)
                .cornerRadius(4) // 较小的圆角
        }
        .buttonStyle(.plain)
    }
}

// 修改ClipboardItemView以支持选中状态
struct ClipboardItemView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    let isSelected: Bool
    @State private var localTitle: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            // 如果有标题，显示标题
            if let title = localTitle ?? item.title, !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#49b1f5"))
                        .lineLimit(1)
                        .padding(.leading, 30)
                    Spacer()
                }
                .padding(.bottom, 2)
            }
            
            HStack(spacing: 12) {
                // 选中状态指示器（多选模式下显示）
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                } else {
                    // 内容类型图标
                    contentTypeIcon
                        .frame(width: 24, height: 24)
                }
                
                // 内容预览
                Text(getPreviewText())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 钉选指示器
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                        .padding(.trailing, 4)
                }
                
                // 显示图片数量指示器
                if item.imageCount > 1 {
                    Text("\(item.imageCount)张图片")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                // 时间戳
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onAppear {
            // 初始化本地标题
            localTitle = item.title
            
            // 监听通知
            setupNotificationObservers()
        }
        .onDisappear {
            // 移除通知监听
            removeNotificationObservers()
        }
    }
    
    // 设置通知监听
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ClipboardItemUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            // 检查更新的是否是当前项目
            if let userInfo = notification.userInfo,
               let updatedID = userInfo["itemID"] as? UUID,
               updatedID == item.id {
                // 强制刷新本地标题
                self.localTitle = self.clipboardManager.getItemTitle(for: item.id)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshClipboardView"),
            object: nil,
            queue: .main
        ) { _ in
            // 强制刷新本地标题
            self.localTitle = self.clipboardManager.getItemTitle(for: item.id)
        }
    }
    
    // 移除通知监听
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ClipboardItemUpdated"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("RefreshClipboardView"),
            object: nil
        )
    }
    
    // 内容类型图标
    private var contentTypeIcon: some View {
        Group {
            if let fileURLs = item.fileURLs, !fileURLs.isEmpty {
                // 对于文件，直接使用文件的应用程序图标
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else {
                    // 如果没有预加载的图标，使用通用文件夹图标
                    Image(systemName: "folder")
                        .foregroundColor(.orange)
                }
            } else if item.displayImage != nil {
                // 图片类型
                Image(systemName: item.imageCount > 1 ? "photo.on.rectangle" : "photo")
                    .foregroundColor(.blue)
            } else if let text = item.text, text.hasPrefix("http") {
                // 链接类型
                Image(systemName: "link")
                    .foregroundColor(.purple)
            } else if item.text != nil {
                // 文本类型
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
            } else {
                // 未知类型
                Image(systemName: "questionmark.square")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 优化的预览文本方法 - 减少运行时计算
    private func getPreviewText() -> String {
        if let text = item.text {
            return text
        } else if item.imageCount > 1 {
            return "\(item.imageCount)张图片"
        } else if item.displayImage != nil {
            return "图片"
        } else if let urls = item.fileURLs, !urls.isEmpty, let firstUrl = urls.first {
            return firstUrl.lastPathComponent
        } else {
            return "未知内容"
        }
    }
}

// 丰富版本的剪贴板内容视图
struct RichClipboardItemView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    let isSelected: Bool
    @State private var localTitle: String? = nil
    @State private var hexColors: [(String, NSColor, String, String)]? = nil  // (标题, 颜色, 样本文本, 来源)
    @State private var isColorInfoExpanded: Bool = false  // 是否展开颜色详情
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 顶部信息行
            HStack {
                // 选中状态指示器或内容类型图标
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                } else {
                    contentTypeIcon
                        .frame(width: 24, height: 24)
                }
                
                // 如果有标题则显示标题，否则显示内容预览
                if let title = localTitle ?? item.title, !title.isEmpty {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#49b1f5"))
                } else {
                    Text(getPreviewText())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // 钉选指示器
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                        .padding(.trailing, 4)
                }
                
                // 显示图片数量指示器
                if let images = item.images, images.count > 1 {
                    Text("\(images.count)张")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(3)
                }
                
                // 如果有颜色数据，显示展开/折叠按钮
                if let colors = hexColors, !colors.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isColorInfoExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isColorInfoExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 第二行：内容预览
            if !hasTitle() {
                Text(getPreviewText())
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .padding(.leading, 24)
            }
            
            // 如果检测到了HEX颜色，显示颜色预览
            if let colors = hexColors, !colors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    // 颜色预览标题
                    HStack {
                        Text("颜色")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(colors.count)种")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(3)
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 24)
                    
                    // 颜色预览区域
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(0..<colors.count, id: \.self) { index in
                                let (title, color, sample, source) = colors[index]
                                VStack(spacing: 2) {
                                    // 颜色预览方块
                                    Rectangle()
                                        .fill(Color(nsColor: color))
                                        .frame(width: 28, height: 28)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                                        .contextMenu {
                                            Button("复制颜色代码") {
                                                copyColorToClipboard(title)
                                            }
                                            
                                            if !sample.isEmpty {
                                                Button("复制样本文本") {
                                                    copyColorToClipboard(sample)
                                                }
                                            }
                                            
                                            Button("查看颜色详情") {
                                                showColorDetails(color)
                                            }
                                        }
                                    
                                    // 颜色代码
                                    Text(title)
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                    
                                    // 如果有样本文本且展开状态，显示样本
                                    if isColorInfoExpanded && !sample.isEmpty {
                                        Text(sample)
                                            .font(.system(size: 8))
                                            .lineLimit(1)
                                            .foregroundColor(Color(nsColor: color))
                                    }
                                }
                            }
                        }
                        .padding(.leading, 24)
                        .padding(.top, 2)
                    }
                    .frame(height: getColorPreviewHeight())
                    
                    // 如果展开状态，显示更多颜色信息
                    if isColorInfoExpanded {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(0..<min(colors.count, 3), id: \.self) { index in
                                let (title, color, sample, source) = colors[index]
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(nsColor: color))
                                        .frame(width: 12, height: 12)
                                    
                                    Text(title)
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    
                                    if !sample.isEmpty {
                                        Text(sample.prefix(15))
                                            .font(.system(size: 10))
                                            .lineLimit(1)
                                            .foregroundColor(Color(nsColor: color))
                                    }
                                }
                            }
                        }
                        .padding(.leading, 24)
                    }
                }
            }
            
            // 第三行：时间与来源
            HStack {
                // 时间信息
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if let appName = item.sourceApp?.name {
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    // 来源应用名称
                    Text(appName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.leading, 24)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onAppear {
            // 初始化本地标题
            localTitle = item.title
            
            // 提取HEX颜色信息
            extractHexColors()
            
            // 监听通知
            setupNotificationObservers()
        }
        .onDisappear {
            // 移除通知监听
            removeNotificationObservers()
        }
    }
    
    // 获取颜色预览区域高度
    private func getColorPreviewHeight() -> CGFloat {
        let baseHeight: CGFloat = 40  // 基础高度
        
        // 如果展开并且有样本文本，增加高度
        if isColorInfoExpanded, let colors = hexColors, colors.contains(where: { !$0.2.isEmpty }) {
            return baseHeight + 16
        }
        
        return baseHeight
    }
    
    // 复制颜色代码到剪贴板
    private func copyColorToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    // 显示颜色详情
    private func showColorDetails(_ color: NSColor) {
        let colorHex = color.toHexString(includeAlpha: false)
        
        let r = Int(round(color.redComponent * 255))
        let g = Int(round(color.greenComponent * 255))
        let b = Int(round(color.blueComponent * 255))
        
        let infoString = """
        颜色: \(colorHex)
        RGB: \(r), \(g), \(b)
        HSB: \(Int(round(color.hueComponent * 360)))°, \(Int(round(color.saturationComponent * 100)))%, \(Int(round(color.brightnessComponent * 100)))%
        """
        
        let alert = NSAlert()
        alert.messageText = "颜色详情"
        alert.informativeText = infoString
        alert.addButton(withTitle: "复制")
        alert.addButton(withTitle: "关闭")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            copyColorToClipboard(infoString)
        }
    }
    
    // 提取HEX颜色信息
    private func extractHexColors() {
        if let hexColorData = item.metadata["hexColors"] as? [String: [String: Any]] {
            var colors: [(String, NSColor, String, String)] = [] // (标题, 颜色, 样本, 来源)
            
            // 按索引顺序遍历元数据中的颜色信息
            let sortedKeys = hexColorData.keys.sorted { Int($0) ?? 0 < Int($1) ?? 0 }
            
            for key in sortedKeys {
                if let colorInfo = hexColorData[key] {
                    let source = colorInfo["source"] as? String ?? "unknown"
                    
                    if let red = colorInfo["red"] as? CGFloat,
                       let green = colorInfo["green"] as? CGFloat,
                       let blue = colorInfo["blue"] as? CGFloat,
                       let alpha = colorInfo["alpha"] as? CGFloat {
                        
                        let color = NSColor(red: red, green: green, blue: blue, alpha: alpha)
                        
                        // 确定标题和样本
                        let title: String
                        let sample: String
                        
                        if source == "hexCode", let code = colorInfo["code"] as? String {
                            title = code
                            sample = ""
                        } else if source == "richText" {
                            // 为富文本颜色生成HEX代码
                            title = color.toHexString(includeAlpha: false) ?? "#000000"
                            sample = colorInfo["sample"] as? String ?? ""
                        } else {
                            title = color.toHexString(includeAlpha: false) ?? "#000000"
                            sample = ""
                        }
                        
                        colors.append((title, color, sample, source))
                    }
                }
            }
            
            if !colors.isEmpty {
                self.hexColors = colors
            }
        }
    }
    
    // 设置通知监听
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ClipboardItemUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            // 检查更新的是否是当前项目
            if let userInfo = notification.userInfo,
               let updatedID = userInfo["itemID"] as? UUID,
               updatedID == item.id {
                // 强制刷新本地标题
                self.localTitle = self.clipboardManager.getItemTitle(for: item.id)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshClipboardView"),
            object: nil,
            queue: .main
        ) { _ in
            // 强制刷新本地标题
            self.localTitle = self.clipboardManager.getItemTitle(for: item.id)
        }
    }
    
    // 移除通知监听
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ClipboardItemUpdated"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("RefreshClipboardView"),
            object: nil
        )
    }
    
    // 内容类型图标
    private var contentTypeIcon: some View {
        Group {
            if let fileURLs = item.fileURLs, !fileURLs.isEmpty {
                // 对于文件，直接使用文件的应用程序图标
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else {
                    // 如果没有预加载的图标，使用通用文件夹图标
                    Image(systemName: "folder")
                        .foregroundColor(.orange)
                }
            } else if item.displayImage != nil {
                // 图片类型
                Image(systemName: item.imageCount > 1 ? "photo.on.rectangle" : "photo")
                    .foregroundColor(.blue)
            } else if let text = item.text, text.hasPrefix("http") {
                // 链接类型
                Image(systemName: "link")
                    .foregroundColor(.purple)
            } else if item.text != nil {
                // 文本类型
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
            } else {
                // 未知类型
                Image(systemName: "questionmark.square")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 预览文本
    private func getPreviewText() -> String {
        if let text = item.text {
            return text.prefix(30).replacingOccurrences(of: "\n", with: " ") + (text.count > 30 ? "..." : "")
        } else if item.imageCount > 1 {
            return "\(item.imageCount)张图片"
        } else if item.displayImage != nil {
            return "图片"
        } else if let urls = item.fileURLs, !urls.isEmpty, let firstUrl = urls.first {
            return firstUrl.lastPathComponent
        } else {
            return "未知内容"
        }
    }
    
    // 检查是否有标题
    private func hasTitle() -> Bool {
        return item.title != nil && !item.title!.isEmpty
    }
}

// 自定义按钮样式 - 提供点击反馈效果
struct EffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// NSMenuItem扩展，支持使用闭包作为action
extension NSMenuItem {
    private static var actionClosures = [NSMenuItem: () -> Void]()
    
    // 设置闭包作为action
    func setAction(_ closure: @escaping () -> Void) {
        // 保存闭包
        NSMenuItem.actionClosures[self] = closure
        
        // 设置target和action
        self.target = self
        self.action = #selector(NSMenuItem.executeActionClosure(_:))
    }
    
    // 执行保存的闭包
    @objc private func executeActionClosure(_ sender: NSMenuItem) {
        if let closure = NSMenuItem.actionClosures[self] {
            closure()
        }
    }
}

// 网格样式的剪贴板项目视图
struct GridClipboardItemView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    let isSelected: Bool
    @State private var localTitle: String? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            // 顶部指示器区域
            HStack {
                // 选中状态指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                }
                
                Spacer()
                
                // 钉选指示器
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                }
            }
            .frame(height: 16)
            .padding(.horizontal, 8)
            
            // 内容预览区域
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                
                // 内容预览
                Group {
                    if let image = item.displayImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                    } else if let text = item.text {
                        if text.hasPrefix("http") {
                            // 链接预览
                            VStack {
                                Image(systemName: "link")
                                    .font(.system(size: 24))
                                    .foregroundColor(.purple)
                                
                                Text(text)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(8)
                        } else {
                            // 文本预览
                            Text(text)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .lineLimit(6)
                                .padding(6)
                        }
                    } else if let urls = item.fileURLs, !urls.isEmpty {
                        // 文件预览
                        VStack {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                            
                            Text(urls.first?.lastPathComponent ?? "")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(8)
                    } else {
                        // 未知内容
                        Image(systemName: "questionmark.square")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 80)
            
            // 底部信息区域
            VStack(alignment: .leading, spacing: 2) {
                // 标题或内容类型
                if let title = localTitle ?? item.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#49b1f5"))
                        .lineLimit(1)
                } else {
                    Text(getContentTypeText())
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // 时间戳
                Text(item.timestamp, style: .time)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
        .padding(4)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .onAppear {
            // 初始化本地标题
            localTitle = item.title
            
            // 监听通知
            setupNotificationObservers()
        }
        .onDisappear {
            // 移除通知监听
            removeNotificationObservers()
        }
    }
    
    // 获取内容类型文本
    private func getContentTypeText() -> String {
        if item.displayImage != nil {
            return item.imageCount > 1 ? "\(item.imageCount)张图片" : "图片"
        } else if let text = item.text {
            if text.hasPrefix("http") {
                return "链接"
            } else {
                return "文本"
            }
        } else if let urls = item.fileURLs, !urls.isEmpty {
            return urls.count > 1 ? "\(urls.count)个文件" : "文件"
        } else {
            return "未知类型"
        }
    }
    
    // 设置通知监听
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ClipboardItemUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            // 检查更新的是否是当前项目
            if let userInfo = notification.userInfo,
               let updatedID = userInfo["itemID"] as? UUID,
               updatedID == item.id {
                // 强制刷新本地标题
                self.localTitle = self.clipboardManager.getItemTitle(for: item.id)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshClipboardView"),
            object: nil,
            queue: .main
        ) { _ in
            // 强制刷新本地标题
            self.localTitle = self.clipboardManager.getItemTitle(for: item.id)
        }
    }
    
    // 移除通知监听
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ClipboardItemUpdated"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("RefreshClipboardView"),
            object: nil
        )
    }
}

