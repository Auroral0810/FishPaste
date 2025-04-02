//
//  DatabaseViewerView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData
import AppKit

struct DatabaseViewerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 模型上下文
    let modelContext: ModelContext
    
    // 查询所有剪贴板项目 - 使用State而不是Query以便我们可以手动更新
    @State private var clipboardItems: [ClipboardItem] = []
    
    // 选中的项目
    @State private var selectedItems: Set<ClipboardItem.ID> = []
    
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
                
                // 添加删除按钮
                Button(action: {
                    deleteSelectedItems()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .disabled(selectedItems.isEmpty)
                
                // 添加复制按钮
                Button(action: {
                    copySelectedItems()
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .disabled(selectedItems.isEmpty)
                
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
                Table(clipboardItems, selection: $selectedItems, sortOrder: $sortOrder) {
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
                        .contentShape(Rectangle()) // 确保整行都可以接收点击事件
                        .contextMenu {
                            Button(action: { exportItem(item) }) {
                                Label("导出", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: { copyItem(item) }) {
                                Label("复制到剪贴板", systemImage: "doc.on.doc")
                            }
                            
                            Divider()
                            
                            Button(action: { deleteItem(item) }) {
                                Label("删除", systemImage: "trash")
                                    .foregroundColor(.red)
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
    
    // 刷新数据
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
    
    // 删除所有选中的项目
    private func deleteSelectedItems() {
        guard !selectedItems.isEmpty else { return }
        
        // 创建确认对话框
        let alert = NSAlert()
        alert.messageText = "删除所选项目"
        alert.informativeText = "确定要删除所选的 \(selectedItems.count) 个项目吗？此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 用户确认删除
            for id in selectedItems {
                if let item = clipboardItems.first(where: { $0.id == id }) {
                    deleteItem(item, showConfirmation: false)
                }
            }
            
            // 清除选择
            selectedItems.removeAll()
            
            // 刷新数据
            refreshData()
        }
    }
    
    // 复制所有选中的项目到剪贴板
    private func copySelectedItems() {
        guard !selectedItems.isEmpty else { return }
        
        if let id = selectedItems.first,
           let item = clipboardItems.first(where: { $0.id == id }) {
            copyItem(item)
        }
    }
    
    // 导出单个项目
    private func exportItem(_ item: ClipboardItem) {
        // 根据内容类型，执行不同的导出操作
        if let imageData = item.imageData {
            exportImage(imageData)
        } else if let text = item.textContent {
            exportText(text)
        } else if let urlStrings = item.fileURLStrings {
            exportURLs(urlStrings)
        }
    }
    
    // 导出图片
    private func exportImage(_ imageData: Data) {
        guard let image = NSImage(data: imageData) else { 
            showError("导出图片失败", detail: "无法从数据创建图片")
            return 
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "导出图片_\(Date().timeIntervalSince1970).png"
        
        do {
            if savePanel.runModal() == .OK, let url = savePanel.url {
                // 将图像保存为PNG
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    
                    do {
                        try pngData.write(to: url)
                        print("成功保存图片到: \(url.path)")
                    } catch {
                        print("写入文件失败: \(error.localizedDescription)")
                        showError("导出图片失败", detail: error.localizedDescription)
                    }
                } else {
                    showError("导出图片失败", detail: "无法将图片转换为PNG格式")
                }
            }
        } catch {
            print("显示保存面板失败: \(error.localizedDescription)")
            showError("导出图片失败", detail: "无法显示保存对话框: \(error.localizedDescription)")
        }
    }
    
    // 导出文本
    private func exportText(_ text: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "导出文本_\(Date().timeIntervalSince1970).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showError("导出文本失败", detail: error.localizedDescription)
            }
        }
    }
    
    // 导出URL
    private func exportURLs(_ urlStrings: [String]) {
        let text = urlStrings.joined(separator: "\n")
        exportText(text)
    }
    
    // 复制到剪贴板
    private func copyItem(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let text = item.textContent {
            pasteboard.setString(text, forType: .string)
        } else if let imageData = item.imageData, let image = NSImage(data: imageData) {
            pasteboard.writeObjects([image])
        } else if let urlStrings = item.fileURLStrings {
            let urls = urlStrings.compactMap { URL(string: $0) }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
    }
    
    // 删除项目
    private func deleteItem(_ item: ClipboardItem, showConfirmation: Bool = true) {
        // 如果需要显示确认对话框
        if showConfirmation {
            let alert = NSAlert()
            alert.messageText = "删除项目"
            alert.informativeText = "确定要删除此项目吗？此操作不可撤销。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "删除")
            alert.addButton(withTitle: "取消")
            
            if alert.runModal() != .alertFirstButtonReturn {
                return // 用户取消操作
            }
        }
        
        // 从数据库中删除项目
        modelContext.delete(item)
        
        // 尝试保存更改
        do {
            try modelContext.save()
            
            // 从当前列表中移除项目
            if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
                clipboardItems.remove(at: index)
            }
        } catch {
            showError("删除失败", detail: error.localizedDescription)
        }
    }
    
    // 分享数据库
    private func shareDatabase() {
        // 导出数据库内容为CSV或其他格式
        var csvString = "Content,Timestamp,TextLength\n"
        
        for item in clipboardItems {
            let text = (item.textContent ?? "[图片或文件]").replacingOccurrences(of: ",", with: " ")
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
            showError("导出CSV出错", detail: error.localizedDescription)
        }
    }
    
    // 显示错误提示
    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
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