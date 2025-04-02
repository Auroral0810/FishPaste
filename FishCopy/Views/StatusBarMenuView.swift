//
//  StatusBarMenuView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData  // 添加SwiftData导入
import AppKit  // 添加AppKit导入以使用NSWindow
import Foundation

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
    
    // 添加这些状态变量
    @State private var showingNormalListSheet = false
    @State private var showingSmartListSheet = false
    @State private var newListName = ""
    
    // 添加分类管理器窗口状态
    @State private var showingCategoryManager = false
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏 - 固定高度
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
                
                // 设置按钮
                Button(action: {
                    clipboardManager.showSettings()
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
            
            // 标签栏区域 - 使用可滚动布局
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
                        ForEach(categories) { category in
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
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 剪贴板历史列表 - 固定高度，内容可滚动
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
                    // 根据视图模式显示不同的列表样式
                    switch viewMode {
                    case .simpleList:
                        // 简洁列表视图
                        List {
                            ForEach(filteredClipboardItems) { item in
                                ClipboardItemView(item: item)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .clipboardItemContextMenu(item: item)
                                    .onTapGesture {
                                        clipboardManager.copyToClipboard(item)
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        
                    case .richList:
                        // 丰富列表视图 - 显示更多细节
                        List {
                            ForEach(filteredClipboardItems) { item in
                                RichClipboardItemView(item: item)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .clipboardItemContextMenu(item: item)
                                    .onTapGesture {
                                        clipboardManager.copyToClipboard(item)
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        
                    case .gridView:
                        // 网格视图 - 固定2×2布局
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.fixed(130), spacing: 12),
                                    GridItem(.fixed(130), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                ForEach(filteredClipboardItems) { item in
                                    GridClipboardItemView(item: item)
                                        .frame(width: 130, height: 130)
                                        .clipboardItemContextMenu(item: item)
                                        .onTapGesture {
                                            clipboardManager.copyToClipboard(item)
                                        }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .frame(height: contentHeight)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 底部工具栏 - 使用ZStack实现真正的居中
            ZStack {
                // 中心层 - 居中显示项目计数
                Text("\(filteredClipboardItems.count) 个项目")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // 顶层 - 左右两侧的按钮
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
            }
            .frame(height: bottomBarHeight)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
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
        FishCopyApp.activeWindows.append(window)
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
        FishCopyApp.activeWindows.append(window)
    }
    
    // 辅助方法：安全地关闭窗口并从activeWindows中移除
    private func closeWindow(_ window: NSWindow) {
        window.close()
        FishCopyApp.activeWindows.removeAll { $0 === window }
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
        FishCopyApp.activeWindows.append(window)
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
        detachedWindow.title = "FishCopy"
        detachedWindow.identifier = NSUserInterfaceItemIdentifier("DetachedFishCopyWindow")
        
        // 将当前窗口位置作为新窗口的位置
        if let screenFrame = currentWindow.screen?.frame {
            let currentOrigin = currentWindow.frame.origin
            detachedWindow.setFrameOrigin(currentOrigin)
        } else {
            detachedWindow.center()
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
        FishCopyApp.activeWindows.append(detachedWindow)
    }
    
    // 修改过滤逻辑，支持自定义分类
    private var filteredClipboardItems: [ClipboardContent] {
        let items = clipboardManager.searchHistory(query: searchText)
        
        // 根据选择的标签过滤
        return items.filter { item in
            switch selectedTab {
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
                if let category = item.category, category == selectedTab {
                    return true
                }
                return false
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

// 优化的剪贴板项目视图 - 更新右键菜单
struct ClipboardItemView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    
    var body: some View {
        HStack(spacing: 12) {
            // 内容类型图标
            contentTypeIcon
                .frame(width: 24, height: 24)
            
            // 内容预览
            Text(getPreviewText())
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.white)
            
            Spacer()
            
            // 时间戳
            Text(item.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
    
    // 内容类型图标
    private var contentTypeIcon: some View {
        Group {
            if item.image != nil {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
            } else if item.fileURLs != nil && !(item.fileURLs?.isEmpty ?? true) {
                Image(systemName: "folder")
                    .foregroundColor(.orange)
            } else if let text = item.text, text.hasPrefix("http") {
                Image(systemName: "link")
                    .foregroundColor(.purple)
            } else if item.text != nil {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "questionmark.square")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 优化的预览文本方法 - 减少运行时计算
    private func getPreviewText() -> String {
        if let text = item.text {
            return text
        } else if item.image != nil {
            return "图片"
        } else if let urls = item.fileURLs, !urls.isEmpty {
            return urls.first!.lastPathComponent
        } else {
            return "未知内容"
        }
    }
}

// 丰富视图组件
struct RichClipboardItemView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                contentTypeIcon
                    .frame(width: 24, height: 24)
                
                Text(getPreviewText())
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // 添加更多预览内容
            if let text = item.text {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .padding(.leading, 28)
            } else if item.image != nil {
                HStack {
                    Spacer()
                    Image(nsImage: item.image!)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 60)
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
    
    // 这里复用与ClipboardItemView相同的辅助方法
    private var contentTypeIcon: some View {
        Group {
            if item.image != nil {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
            } else if item.fileURLs != nil && !(item.fileURLs?.isEmpty ?? true) {
                Image(systemName: "folder")
                    .foregroundColor(.orange)
            } else if let text = item.text, text.hasPrefix("http") {
                Image(systemName: "link")
                    .foregroundColor(.purple)
            } else if item.text != nil {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "questionmark.square")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func getPreviewText() -> String {
        if let text = item.text {
            return text.prefix(30).replacingOccurrences(of: "\n", with: " ") + (text.count > 30 ? "..." : "")
        } else if item.image != nil {
            return "图片"
        } else if let urls = item.fileURLs, !urls.isEmpty {
            return urls.first!.lastPathComponent
        } else {
            return "未知内容"
        }
    }
}

// 修改网格视图组件 - 修复语法错误
struct GridClipboardItemView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 内容预览区域
            ZStack {
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(width: 130, height: 110)
                    .cornerRadius(6)
                
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 110)
                        .cornerRadius(6)
                        .clipped()
                } else {
                    contentPreview
                        .frame(width: 130, height: 110)
                }
                
                // 类型指示器
                VStack {
                    HStack {
                        Spacer()
                        contentTypeIcon
                            .frame(width: 16, height: 16)
                            .padding(2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(2)
            }
            
            // 时间戳
            Text(item.timestamp, style: .time)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .background(Color(white: 0.15))
        .cornerRadius(8)
        .frame(width: 130, height: 130)
        .contentShape(Rectangle())
    }
    
    // 内容类型图标 - 移出闭包
    var contentTypeIcon: some View {
        Group {
            if item.image != nil {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
            } else if item.fileURLs != nil && !(item.fileURLs?.isEmpty ?? true) {
                Image(systemName: "folder")
                    .foregroundColor(.orange)
            } else if let text = item.text, text.hasPrefix("http") {
                Image(systemName: "link")
                    .foregroundColor(.purple)
            } else if item.text != nil {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "questionmark.square")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 内容预览 - 移出闭包
    var contentPreview: some View {
        Group {
            if let text = item.text {
                VStack(alignment: .leading) {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                .padding(8)
            } else if let urls = item.fileURLs, !urls.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(urls.prefix(2), id: \.self) { url in
                        Text(url.lastPathComponent)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    if urls.count > 2 {
                        Text("还有\(urls.count - 2)个文件...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(8)
            } else {
                Text("未知内容")
                    .foregroundColor(.gray)
            }
        }
    }
}

// 分类管理器视图

// 自定义按钮样式 - 提供点击反馈效果
struct EffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

