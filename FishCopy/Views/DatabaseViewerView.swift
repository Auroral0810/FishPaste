//
//  DatabaseViewerView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData

struct DatabaseViewerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 模型上下文
    let modelContext: ModelContext
    
    // 查询所有剪贴板项目 - 使用State而不是Query以便我们可以手动更新
    @State private var clipboardItems: [ClipboardItem] = []
    
    // 时间格式器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    // 列排序
    @State private var sortOrder = [KeyPathComparator(\ClipboardItem.timestamp, order: .reverse)]
    
    // 初始化
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // 不要在这里尝试加载数据，SwiftUI的初始化器中不能进行异步操作
        // 我们会在onAppear中加载数据
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Button(action: {
                    shareDatabase()
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                
                Spacer()
                
                // 添加刷新按钮
                Button(action: {
                    refreshData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .keyboardShortcut("r", modifiers: .command)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            
            if clipboardItems.isEmpty {
                // 显示无数据状态
                VStack(spacing: 20) {
                    Image(systemName: "database.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("暂无数据记录")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Button("刷新数据") {
                        refreshData()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 表格视图
                Table(clipboardItems, sortOrder: $sortOrder) {
                    TableColumn("Content") { item in
                        HStack {
                            // 如果有图片数据，显示缩略图
                            if let imageData = item.imageData, let image = NSImage(data: imageData) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 32)
                                    .cornerRadius(4)
                                
                                if let text = item.textContent, !text.isEmpty {
                                    Text(text)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                } else {
                                    Text("[图片]").foregroundColor(.secondary)
                                }
                            } else if let text = item.textContent {
                                Text(text)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            } else if item.fileURLStrings != nil && !(item.fileURLStrings?.isEmpty ?? true) {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                Text("[文件]").foregroundColor(.secondary)
                            } else {
                                Text("未知内容").foregroundColor(.secondary)
                            }
                        }
                    }
                    .width(min: 300, ideal: 400)
                    
                    TableColumn("Timestamp", value: \.timestamp) { item in
                        Text(dateFormatter.string(from: item.timestamp))
                    }
                    .width(200)
                    
                    TableColumn("Text Length") { item in
                        Text("\(item.textContent?.count ?? 0)")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(100)
                }
                .onChange(of: sortOrder) { newOrder in
                    // 当排序改变时手动排序数据
                    sortData(with: newOrder)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            // 在视图出现时加载数据
            refreshData()
        }
    }
    
    // 手动排序数据
    private func sortData(with newOrder: [KeyPathComparator<ClipboardItem>]) {
        if let comparator = newOrder.first {
            switch comparator.keyPath {
            case \.timestamp:
                clipboardItems.sort { first, second in
                    if comparator.order == .forward {
                        return first.timestamp < second.timestamp
                    } else {
                        return first.timestamp > second.timestamp
                    }
                }
            default:
                break
            }
        }
    }
    
    // 刷新数据 - 完全重写这个方法
    private func refreshData() {
        do {
            // 创建获取描述符
            let descriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            
            // 执行查询
            let items = try modelContext.fetch(descriptor)
            
            // 更新状态变量
            self.clipboardItems = items
            
            print("数据库查询成功: 找到 \(items.count) 条记录")
        } catch {
            print("刷新数据库视图出错: \(error.localizedDescription)")
            
            // 显示错误警告
            let alert = NSAlert()
            alert.messageText = "查询数据失败"
            alert.informativeText = "无法从数据库加载剪贴板记录: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    // 分享数据库
    private func shareDatabase() {
        // 导出数据库内容为CSV或其他格式
        var csvString = "Text,Timestamp,TextLength\n"
        
        for item in clipboardItems {
            let text = (item.textContent ?? "").replacingOccurrences(of: ",", with: " ")
            let timestamp = dateFormatter.string(from: item.timestamp)
            let length = item.textContent?.count ?? 0
            
            csvString += "\"\(text)\",\(timestamp),\(length)\n"
        }
        
        // 创建临时文件
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent("fishcopy_database.csv")
        
        do {
            try csvString.write(to: tempFileURL, atomically: true, encoding: .utf8)
            
            // 显示分享表单
            let sharingPicker = NSSharingServicePicker(items: [tempFileURL])
            if let window = NSApplication.shared.keyWindow {
                sharingPicker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
            }
        } catch {
            print("导出CSV出错: \(error)")
        }
    }
}

// 预览
#Preview {
    let container = try! ModelContainer(for: ClipboardItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    
    // 添加一些预览数据
    for i in 1...10 {
        let item = ClipboardItem(textContent: "示例文本 \(i)", timestamp: Date().addingTimeInterval(-Double(i) * 3600))
        context.insert(item)
    }
    
    return DatabaseViewerView(modelContext: context)
} 