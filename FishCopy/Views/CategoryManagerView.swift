//
//  CategoryManagerView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData
import AppKit

struct CategoryManagerView: View {
    // 模型上下文，用于数据库操作
    let modelContext: ModelContext
    
    // 查询所有分类
    @Query(sort: \ClipboardCategory.name) private var categories: [ClipboardCategory]
    
    // 显示确认删除对话框
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: ClipboardCategory? = nil
    
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
        descriptor.sortBy = [SortDescriptor(\.name)]
        
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
                        List {
                            ForEach(customCategories) { category in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(Color(hex: category.color) ?? .blue)
                                        .frame(width: 20)
                                    
                                    Text(category.name)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
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
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteCategory)
                        }
                        .listStyle(.inset)
                        .frame(minHeight: 150, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // 底部按钮
            HStack {
                Spacer()
                
                Button("完成") {
                    closeWindow()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
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
} 
