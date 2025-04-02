//
//  CategoryManagerView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct CategoryManagerView: View {
    // 模型上下文，用于数据库操作
    let modelContext: ModelContext
    
    // 查询所有分类
    @Query(sort: \ClipboardCategory.sortOrder) private var categories: [ClipboardCategory]
    
    // 显示确认删除对话框
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: ClipboardCategory? = nil
    
    // 拖拽状态
    @State private var draggingItem: ClipboardCategory?
    
    // 定义默认分类（不可删除）
    private let defaultCategories = ["全部", "钉选", "今天", "文本", "图像", "链接"]
    
    // 自定义分类列表（可排序、删除）
    private var customCategories: [ClipboardCategory] {
        categories.filter { !defaultCategories.contains($0.name) }
    }
    
    // 初始化并确保SwiftData查询正确设置
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("CategoryManagerView初始化，modelContext: \(modelContext)")
        
        // 明确设置关联模型上下文
        var descriptor = FetchDescriptor<ClipboardCategory>()
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]
        
        let query = Query(descriptor)
        print("初始化Query: \(query)")
        _categories = query
    }
    
    // 定义一个计算属性，用于实时检查查询结果
    private var categoriesInfo: String {
        "分类总数: \(categories.count)，自定义分类: \(customCategories.count)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 默认分类列表（不可删除）
            GroupBox(label: Text("默认分类").font(.headline)) {
                VStack(spacing: 0) {
                    ForEach(defaultCategories, id: \.self) { category in
                        HStack {
                            Image(systemName: getCategoryIcon(category))
                                .foregroundColor(getCategoryColor(category))
                                .frame(width: 20)
                            
                            Text(category)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .padding(.vertical, 8)
                        
                        if category != defaultCategories.last {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // 自定义分类列表（可排序、删除）
            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("自定义分类")
                            .font(.headline)
                        
                        if customCategories.isEmpty {
                            Text("(无自定义分类)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("(\(customCategories.count)个)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    if customCategories.isEmpty {
                        Text("您还没有创建任何自定义分类")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        // 使用ScrollView固定高度且允许滚动
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(customCategories) { category in
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(Color(hex: category.color) ?? .blue)
                                            .frame(width: 20)
                                        
                                        Text(category.name)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        // 拖动图标提示
                                        Image(systemName: "line.3.horizontal")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 12))
                                            .padding(.trailing, 6)
                                        
                                        // 删除按钮
                                        Button(action: {
                                            categoryToDelete = category
                                            showDeleteAlert = true
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                                    .background(Color.clear)
                                    .onDrag {
                                        self.draggingItem = category
                                        // 创建包含分类ID的拖拽项目
                                        return NSItemProvider(object: category.name as NSString)
                                    }
                                    
                                    if category != customCategories.last {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 180) // 固定最大高度
                        .background(Color(NSColor.textBackgroundColor).opacity(0.2))
                        .cornerRadius(4)
                        .onDrop(of: [UTType.plainText], delegate: CategoryDropDelegate(
                            categories: customCategories,
                            draggingItem: $draggingItem,
                            modelContext: modelContext
                        ))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // 底部按钮 - 确保保存按钮可见
            HStack {
                // 添加保存按钮
                Button("保存") {
                    saveAndClose()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("取消") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400, height: 400)
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("删除分类"),
                message: Text("确定要删除分类 \"\(categoryToDelete?.name ?? "")\" 吗？这将会移除该分类下的所有剪贴板项目的分类标签。"),
                primaryButton: .destructive(Text("删除")) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .onAppear {
            print("CategoryManagerView 出现")
            refreshCategories()
            ensureSortOrderIsSet()
        }
    }
    
    // 确保所有分类都有排序顺序
    private func ensureSortOrderIsSet() {
        var needsUpdate = false
        
        // 检查是否有分类没有设置sortOrder
        for (index, category) in customCategories.enumerated() {
            if category.sortOrder != index {
                category.sortOrder = index
                needsUpdate = true
            }
        }
        
        // 如果有更新，保存到数据库
        if needsUpdate {
            do {
                try modelContext.save()
                print("更新了分类排序顺序")
            } catch {
                print("更新分类排序顺序时出错: \(error)")
            }
        }
    }
    
    // 获取分类图标
    private func getCategoryIcon(_ category: String) -> String {
        switch category {
        case "全部": return "tray.full.fill"
        case "钉选": return "pin.fill"
        case "今天": return "calendar"
        case "文本": return "doc.text.fill"
        case "图像": return "photo.fill"
        case "链接": return "link"
        default: return "folder.fill"
        }
    }
    
    // 获取分类颜色
    private func getCategoryColor(_ category: String) -> Color {
        switch category {
        case "全部": return .blue
        case "钉选": return .orange
        case "今天": return .green
        case "文本": return .purple
        case "图像": return .pink
        case "链接": return .yellow
        default: return .gray
        }
    }
    
    // 删除指定的分类
    private func deleteCategory(_ indexSet: IndexSet) {
        let categoriesToDelete = indexSet.map { customCategories[$0] }
        for category in categoriesToDelete {
            deleteCategory(category)
        }
    }
    
    // 删除指定的分类
    private func deleteCategory(_ category: ClipboardCategory) {
        do {
            // 找到所有剪贴板项目
            let descriptor = FetchDescriptor<ClipboardItem>()
            let allItems = try modelContext.fetch(descriptor)
            
            // 筛选出属于此分类的项目并清除其分类标签
            for item in allItems {
                if item.category == category.name {
                    item.category = nil
                }
            }
            
            // 删除分类
            modelContext.delete(category)
            
            // 保存更改
            try modelContext.save()
            
            // 更新剩余分类的排序顺序
            updateSortOrderAfterDelete()
            
            print("成功删除分类: \(category.name)")
        } catch {
            print("删除分类时出错: \(error.localizedDescription)")
            
            // 显示错误提示
            let errorAlert = NSAlert()
            errorAlert.messageText = "删除分类失败"
            errorAlert.informativeText = "无法删除分类: \(error.localizedDescription)"
            errorAlert.alertStyle = .critical
            errorAlert.addButton(withTitle: "确定")
            errorAlert.runModal()
        }
    }
    
    // 移动分类排序
    private func moveCategory(from source: IndexSet, to destination: Int) {
        // 获取当前的自定义分类数组
        var categories = customCategories
        
        // 执行移动
        categories.move(fromOffsets: source, toOffset: destination)
        
        // 更新排序顺序
        for (index, category) in categories.enumerated() {
            category.sortOrder = index
        }
        
        // 保存更改
        do {
            try modelContext.save()
            print("已更新分类排序顺序")
        } catch {
            print("更新分类排序时出错: \(error)")
        }
    }
    
    // 删除后更新排序顺序
    private func updateSortOrderAfterDelete() {
        for (index, category) in customCategories.enumerated() {
            category.sortOrder = index
        }
        
        do {
            try modelContext.save()
        } catch {
            print("更新删除后的排序顺序时出错: \(error)")
        }
    }
    
    // 关闭窗口
    private func closeWindow() {
        if let window = NSApp.keyWindow {
            window.close()
        }
    }
    
    // 添加刷新分类的方法
    private func refreshCategories() {
        // 尝试刷新数据
        do {
            let descriptor = FetchDescriptor<ClipboardCategory>()
            let allCategories = try modelContext.fetch(descriptor)
            print("从数据库直接查询到的分类: \(allCategories.map { $0.name }.joined(separator: ", "))")
        } catch {
            print("查询分类时出错: \(error)")
        }
    }
    
    // 添加保存并关闭方法
    private func saveAndClose() {
        // 确保所有分类的排序顺序正确
        for (index, category) in customCategories.enumerated() {
            category.sortOrder = index
        }
        
        // 保存更改到数据库
        do {
            try modelContext.save()
            print("保存分类顺序成功")
            
            // 发送通知，通知导航栏更新分类顺序
            NotificationCenter.default.post(name: Notification.Name("CategoryOrderChanged"), object: nil)
            
            // 关闭窗口
            closeWindow()
        } catch {
            print("保存分类顺序时出错: \(error)")
            
            // 显示错误提示
            let errorAlert = NSAlert()
            errorAlert.messageText = "保存失败"
            errorAlert.informativeText = "无法保存分类顺序: \(error.localizedDescription)"
            errorAlert.alertStyle = .critical
            errorAlert.addButton(withTitle: "确定")
            errorAlert.runModal()
        }
    }
}

// 拖放委托
struct CategoryDropDelegate: DropDelegate {
    let categories: [ClipboardCategory]
    @Binding var draggingItem: ClipboardCategory?
    let modelContext: ModelContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingItem = draggingItem else { return false }
        
        // 获取拖放位置
        let dropLocation = info.location.y
        
        // 计算目标索引
        var target = 0
        for (i, category) in categories.enumerated() {
            let frame = info.location
            if Double(i) * 40 < dropLocation && dropLocation < Double(i + 1) * 40 {
                target = i
                break
            }
            target = i + 1
        }
        
        // 如果源和目标相同，不进行操作
        let source = categories.firstIndex(where: { $0.name == draggingItem.name }) ?? 0
        if source == target {
            return false
        }
        
        // 更新排序顺序
        var updatedCategories = categories
        
        // 从源位置移除
        updatedCategories.remove(at: source)
        
        // 确保目标位置在有效范围内
        let safeTarget = min(max(target, 0), updatedCategories.count)
        
        // 插入到目标位置
        updatedCategories.insert(draggingItem, at: safeTarget)
        
        // 更新所有项目的排序顺序
        for (index, category) in updatedCategories.enumerated() {
            category.sortOrder = index
        }
        
        // 保存更改
        do {
            try modelContext.save()
            print("通过拖放更新了分类排序")
            return true
        } catch {
            print("保存拖放排序时出错: \(error)")
            return false
        }
    }
    
    func dropEntered(info: DropInfo) {
        // 可以在这里实现高亮效果
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
} 
