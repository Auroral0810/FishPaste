//
//  StatusBarMenuView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI

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
                    // 有内容状态 - 优化列表渲染
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
                    .environment(\.defaultMinListRowHeight, 0)
                }
            }
            .frame(height: contentHeight)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 底部工具栏 - 固定高度
            HStack {
                // 设置按钮
                Button(action: {
                    // 打开设置
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 打开主窗口按钮
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title != "FishCopy" }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }) {
                    Text("打开主窗口")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
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

// 优化的剪贴板项目视图
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
            Button(action: {
                clipboardManager.copyToClipboard(item)
            }) {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: {
                // 切换钉选状态
                var updatedItem = item
                updatedItem.isPinned.toggle()
                // 更新项目
            }) {
                Label(item.isPinned ? "取消钉选" : "钉选", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            
            Divider()
            
            Button(action: {
                clipboardManager.deleteItems(withIDs: [item.id])
            }) {
                Label("删除", systemImage: "trash")
            }
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