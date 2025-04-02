//
//  StatusBarMenuView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI

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
    @State private var searchText = ""
    @State private var selectedTab = "全部" // 默认选中"全部"标签
    
    // 添加这些状态变量
    @State private var showingNormalListSheet = false
    @State private var showingSmartListSheet = false
    @State private var newListName = ""
    
    // 固定高度常量
    private let searchBarHeight: CGFloat = 44
    private let tabBarHeight: CGFloat = 36  // 减小了标签栏高度
    private let bottomBarHeight: CGFloat = 44
    private let contentHeight: CGFloat = 320
    
    // 添加视图模式状态
    @State private var viewMode: ViewMode = .simpleList
    @State private var showingViewModeMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏 - 固定高度
            HStack {
                // 多窗口切换按钮
                Button(action: {
                    // 多窗口功能逻辑
                }) {
                    Image(systemName: "square.on.square")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                
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
            
            // 标签栏区域 - 使用全宽HStack确保布局
            HStack(spacing: 0) {
                // 标签按钮区域 - 使用HStack而不是ScrollView
                HStack(spacing: 2) {  // 减小间距
                    // 全部按钮
                    TabButtonFixed(title: "全部", isSelected: selectedTab == "全部") {
                        selectedTab = "全部"
                    }
                    
                    // 钉选按钮 - 修复为可点击的按钮
                    Button(action: {
                        selectedTab = "钉选"
                    }) {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
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
                }
                
                Spacer(minLength: 0)
                
                // 添加按钮，放在最右边
                Menu {
                    Button(action: {
                        showingNormalListSheet = true
                    }) {
                        Text("创建普通列表")
                    }
                    
                    Button(action: {
                        showingSmartListSheet = true
                    }) {
                        Text("创建智能列表")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 5)
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
                                    .onTapGesture {
                                        clipboardManager.copyToClipboard(item)
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        
                    case .gridView:
                        // 网格视图
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                                ForEach(filteredClipboardItems) { item in
                                    GridClipboardItemView(item: item)
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
            
            // 底部工具栏 - 更新为新设计
            HStack {
                // 视图模式切换按钮
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
            .padding(.vertical, 8)
            .frame(height: bottomBarHeight)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12)) // 保持与整体颜色一致
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12)) // 深色背景
        .sheet(isPresented: $showingNormalListSheet) {
            CreateListView(title: "创建普通列表", listName: $newListName, onSave: {
                // 保存普通列表的逻辑
                print("创建普通列表: \(newListName)")
                showingNormalListSheet = false
            })
        }
        .sheet(isPresented: $showingSmartListSheet) {
            CreateSmartListView(listName: $newListName, onSave: {
                // 保存智能列表的逻辑
                print("创建智能列表: \(newListName)")
                showingSmartListSheet = false
            })
        }
    }
    
    // 根据选择的标签和搜索文本过滤剪贴板项目
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
            default: // "全部"
                return true
            }
        }
    }
}

// 固定大小的标签按钮 - 更轻量和紧凑
struct TabButtonFixed: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13)) // 更小的字体
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 10) // 减小水平内边距
                .padding(.vertical, 5) // 减小垂直内边距
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
        .contextMenu {
            // 粘贴至FishCopy选项
            Button(action: {
                // 粘贴到应用程序中的操作
            }) {
                Label("粘贴至'FishCopy'", systemImage: "arrow.right.doc.on.clipboard")
            }
            
            // 粘贴为子菜单 - 增加选项
            Menu {
                Button("文本", action: {})
                Button("富文本", action: {})
                Button("HTML", action: {})
                Divider()
                Button("无格式文本", action: {}) // 新增选项
                Button("带源代码格式", action: {}) // 新增选项
            } label: {
                Label("粘贴为", systemImage: "doc.on.clipboard")
            }
            
            // 复制选项
            Button(action: {
                clipboardManager.copyToClipboard(item)
            }) {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            // 复制为子菜单
            Menu {
                Button("文本", action: {})
                Button("富文本", action: {})
                Button("HTML", action: {})
            } label: {
                Label("复制为", systemImage: "doc.on.doc.fill")
            }
            
            Divider()
            
            // 图片相关选项 - 仅当内容是图片时显示
            if item.image != nil {
                Button(action: {
                    // 编辑图片逻辑
                }) {
                    Label("编辑图片", systemImage: "pencil")
                }
                
                Button(action: {
                    // 保存图片逻辑
                }) {
                    Label("保存图片", systemImage: "square.and.arrow.down")
                }
                
                Button(action: {
                    // 添加标题逻辑
                }) {
                    Label("添加标题", systemImage: "text.badge.plus")
                }
                
                Divider()
            }
            // 文本相关选项 - 仅当内容是文本时显示
            else if item.text != nil {
                Button(action: {
                    // 编辑文本逻辑
                }) {
                    Label("编辑文本", systemImage: "pencil")
                }
                
                Button(action: {
                    // 编辑标题逻辑
                }) {
                    Label("编辑标题", systemImage: "text.badge.star")
                }
                
                Divider()
            }
            
            // 添加到列表子菜单 - 更新选项包含钉选和分类
            Menu {
                Button(action: {
                    // 添加到钉选逻辑
                    var updatedItem = item
                    updatedItem.isPinned = true
                    // 更新项目
                }) {
                    Label("钉选", systemImage: "pin.fill")
                }
                
                Divider()
                
                Button(action: {
                    // 创建新列表逻辑
                }) {
                    Label("创建新列表", systemImage: "folder.badge.plus")
                }
                
                Divider()
                
                // 预设分类
                Button("工作", action: {})
                Button("个人", action: {})
                Button("代码", action: {})
                
                // 这里可以添加用户自定义的分类
            } label: {
                Label("添加到列表", systemImage: "list.bullet")
            }
            
            Divider()
            
            // 删除选项
            Button(action: {
                clipboardManager.deleteItems(withIDs: [item.id])
            }) {
                Label("删除", systemImage: "trash")
            }
            
            Divider()
            
            // 预览选项
            Button(action: {
                // 预览逻辑
            }) {
                Label("预览", systemImage: "eye")
            }
            
            // 分享子菜单
            Menu {
                Button("AirDrop", action: {})
                Button("信息", action: {})
                Button("邮件", action: {})
                Button("备忘录", action: {})
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }
        .onTapGesture {
            clipboardManager.copyToClipboard(item)
        }
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
        .contextMenu {
            // 保持与原先相同的上下文菜单
            // ... 上下文菜单代码 ...
        }
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

// 网格视图组件
struct GridClipboardItemView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let item: ClipboardContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 内容预览区域
            ZStack {
                Rectangle()
                    .fill(Color(white: 0.2))
                    .aspectRatio(1.0, contentMode: .fit)
                    .cornerRadius(8)
                
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(8)
                } else {
                    contentPreview
                }
                
                // 类型指示器
                VStack {
                    HStack {
                        Spacer()
                        contentTypeIcon
                            .frame(width: 16, height: 16)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(6)
            }
            .frame(height: 90)
            
            // 时间戳
            Text(item.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.15))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .contextMenu {
            // 保持与原先相同的上下文菜单
            // ... 上下文菜单代码 ...
        }
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
    
    // 内容预览
    private var contentPreview: some View {
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
