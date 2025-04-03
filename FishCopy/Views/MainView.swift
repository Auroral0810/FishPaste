//
//  MainView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedTab = "全部"
    @State private var viewMode: ViewMode = .list
    
    // 添加分类查询
    @Query(sort: \ClipboardCategory.sortOrder) var categories: [ClipboardCategory]
    
    // 视图模式枚举
    enum ViewMode {
        case simpleList  // 简洁列表
        case list        // 丰富列表
        case grid        // 网格视图
    }
    
    // 标签选项
    let tabs = ["全部", "今天", "文本", "图像", "链接"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack(spacing: 15) {
                // 切换视图按钮
                Menu {
                    Button(action: { viewMode = .simpleList }) {
                        Label("简洁列表", systemImage: "list.bullet")
                    }
                    Button(action: { viewMode = .list }) {
                        Label("丰富列表", systemImage: "list.bullet.below.rectangle")
                    }
                    Button(action: { viewMode = .grid }) {
                        Label("网格视图", systemImage: "square.grid.2x2")
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.white)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("输入开始搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(6)
                .background(Color(NSColor.textBackgroundColor).opacity(0.1))
                .cornerRadius(8)
                
                // 设置按钮
                Button(action: {
                    // 打开设置
                    clipboardManager.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // 标签栏
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        Text(tab)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 6)
                            .foregroundColor(selectedTab == tab ? .white : .gray)
                            .background(
                                selectedTab == tab ? 
                                Color.blue : Color.clear
                            )
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                // 显示自定义分类
                ForEach(categories) { category in
                    Button(action: {
                        selectedTab = category.name
                    }) {
                        Text(category.name)
                            .lineLimit(1)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 6)
                            .foregroundColor(selectedTab == category.name ? .white : .gray)
                            .background(
                                selectedTab == category.name ? 
                                Color.blue : Color.clear
                            )
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    // 添加新的自定义标签或分类
                    openCategoryManagerWindow()
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 内容区域
            if filteredClipboardItems.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    // 使用自定义应用图标
                    if let imagePath = Bundle.main.path(forResource: "appLogo_256x256", ofType: "png"),
                       let appIcon = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .opacity(0.6)
                    } else {
                        // 备用：使用系统图标
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                    
                    Text("没有匹配的剪贴板历史")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredClipboardItems) { item in
                            MainClipboardItemRow(clipboardManager: _clipboardManager, item: item, viewMode: viewMode)
                                .contextMenu {
                                    Button(action: {
                                        clipboardManager.copyToClipboard(item)
                                    }) {
                                        Label("复制", systemImage: "doc.on.doc")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        // 添加到"钉选"
                                    }) {
                                        Label("钉选", systemImage: "pin")
                                    }
                                    
                                    Menu("添加到分类") {
                                        ForEach(["工作", "个人", "代码"], id: \.self) { category in
                                            Button(category) {
                                                // 添加到特定分类
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        clipboardManager.deleteItems(withIDs: [item.id])
                                    }) {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            
            // 底部状态栏
            HStack {
                Text("\(clipboardManager.clipboardHistory.count) 个项目")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hue: 0.0, saturation: 0.0, brightness: 0.10))
        }
        .background(Color(hue: 0.0, saturation: 0.0, brightness: 0.12)) // 深色背景
        .onAppear {
            // 设置窗口标题和标识符
            if let window = NSApplication.shared.keyWindow {
                window.title = "FishCopy 主窗口"
                window.identifier = NSUserInterfaceItemIdentifier("FishCopyMainWindow")
                
                // 设置适当的最小尺寸以避免界面被压缩
                window.minSize = NSSize(width: 600, height: 400)
            }
            
            // 初始化剪贴板管理器的ModelContext
            clipboardManager.setModelContext(modelContext)
            print("MainView出现，设置ModelContext: \(modelContext)")
        }
    }
    
    // 根据当前筛选条件获取内容
    private var filteredClipboardItems: [ClipboardContent] {
        let items = clipboardManager.searchHistory(query: searchText)
        
        // 根据选择的标签过滤
        return items.filter { item in
            switch selectedTab {
            case "今天":
                let calendar = Calendar.current
                return calendar.isDateInToday(item.timestamp)
            case "文本":
                return item.text != nil
            case "图像":
                return item.image != nil
            case "链接":
                if let text = item.text, text.hasPrefix("http") {
                    return true
                }
                return false
            default: // "全部"或自定义分类
                if selectedTab == "全部" {
                    return true
                } else {
                    // 对于自定义分类，根据分类名称过滤
                    if let category = item.category, category == selectedTab {
                        return true
                    }
                    return false
                }
            }
        }
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
        window.isReleasedWhenClosed = true
        
        // 使用独立文件中定义的CategoryManagerView
        let contentView = CategoryManagerView(modelContext: modelContext)
            .modelContext(modelContext) // 将modelContext注入到环境中
        
        // 保留对rootView的引用，防止内存回收
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// 主界面剪贴板项目行视图
struct MainClipboardItemRow: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    let viewMode: MainView.ViewMode
    
    var body: some View {
        Group {
            switch viewMode {
            case .simpleList:
                simpleListRow
            case .list:
                richListRow
            case .grid:
                gridItem
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(hue: 0.0, saturation: 0.0, brightness: 0.15))
        .onHover { hover in
            // 鼠标悬停效果
        }
        .contentShape(Rectangle())
        .onTapGesture {
            clipboardManager.copyToClipboard(item)
        }
    }
    
    // 简洁列表样式
    private var simpleListRow: some View {
        HStack(spacing: 12) {
            contentTypeIcon
                .frame(width: 24, height: 24)
            
            contentPreview
                .lineLimit(1)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(item.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // 丰富列表样式
    private var richListRow: some View {
        HStack(spacing: 12) {
            contentTypeIcon
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                contentPreview
                    .lineLimit(3)
                    .foregroundColor(.white)
                
                Text(item.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 操作按钮
            Button(action: {
                // 复制到剪贴板
                clipboardManager.copyToClipboard(item)
            }) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    // 网格样式
    private var gridItem: some View {
        VStack(alignment: .leading, spacing: 8) {
            contentPreviewFull
                .frame(maxWidth: .infinity, maxHeight: 120)
                .background(Color(hue: 0.0, saturation: 0.0, brightness: 0.18))
                .cornerRadius(6)
            
            HStack {
                contentTypeIcon
                    .frame(width: 16, height: 16)
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
        }
        .frame(width: 160)
    }
    
    // 内容类型图标
    private var contentTypeIcon: some View {
        Group {
            // 优先使用来源应用图标（如果有）
            if let sourceAppIcon = item.sourceApp?.icon, isShowSourceAppIcon() {
                Image(nsImage: sourceAppIcon)
                    .resizable()
                    .scaledToFit()
            }
            // 否则使用默认的基于内容类型的图标
            else if item.image != nil {
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
    
    // 根据设置决定是否显示来源应用图标
    private func isShowSourceAppIcon() -> Bool {
        // 从UserDefaults中获取设置
        return UserDefaults.standard.bool(forKey: "showSourceAppIcon")
    }
    
    // 内容预览（简单版）
    private var contentPreview: some View {
        Group {
            if let text = item.text {
                Text(text)
            } else if item.image != nil {
                Text("图片")
            } else if let urls = item.fileURLs, !urls.isEmpty {
                Text(urls.first!.lastPathComponent)
            } else {
                Text("未知内容")
            }
        }
    }
    
    // 内容预览（完整版）
    private var contentPreviewFull: some View {
        Group {
            if let text = item.text {
                VStack {
                    Text(text)
                        .lineLimit(6)
                        .foregroundColor(.white)
                }
                .padding(8)
            } else if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let urls = item.fileURLs, !urls.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(urls.prefix(3), id: \.self) { url in
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .foregroundColor(.white)
                    }
                    
                    if urls.count > 3 {
                        Text("还有\(urls.count - 3)个文件...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(8)
            } else {
                Text("未知内容")
                    .foregroundColor(.gray)
                    .padding(8)
            }
        }
    }
}

// 分类行视图
struct CategoryRow: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue) // 实际应用中从数据获取颜色
                .frame(width: 12, height: 12)
            
            Text(name)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

// 剪贴板详细行视图
struct ClipboardItemDetailRow: View {
    let item: ClipboardContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头部信息：类型图标和时间戳
            HStack {
                contentTypeIcon
                
                Spacer()
                
                Text(item.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 内容预览
            contentPreview
            
            // 如果有分类，显示分类标签
            if let category = item.category {
                HStack {
                    Circle()
                        .fill(Color.blue) // 实际应用中从数据获取颜色
                        .frame(width: 8, height: 8)
                    
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
    }
    
    // 根据内容类型显示不同图标
    private var contentTypeIcon: some View {
        Group {
            if item.image != nil {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
            } else if item.fileURLs != nil && !(item.fileURLs?.isEmpty ?? true) {
                Image(systemName: "folder")
                    .foregroundColor(.orange)
            } else if item.text != nil {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "questionmark.square")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 内容预览
    private var contentPreview: some View {
        Group {
            if let text = item.text {
                Text(text)
                    .lineLimit(3)
            } else if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 100)
            } else if let urls = item.fileURLs, !urls.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(urls.prefix(3), id: \.self) { url in
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                    }
                    
                    if urls.count > 3 {
                        Text("还有\(urls.count - 3)个文件...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("未知内容")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// 颜色工具扩展
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }
} 
