//
//  CreateSmartListView.swift
//  FishPaste
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI

struct CreateSmartListView: View {
    @Binding var listName: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // 匹配类型（所有/任意）
    @State private var matchType = "所有"
    
    // 条件列表 - 每个条件包含类型和值
    @State private var conditions: [(id: UUID, type: String, value: String)] = [
        (id: UUID(), type: "创建日期", value: "是今天")
    ]
    
    // 条件选项
    let matchTypes = ["所有", "任意"]
    let conditionTypes = ["创建日期", "内容类型", "包含文本", "来自 App"]
    
    // 条件值选项 - 根据条件类型显示不同的选项
    let dateConditions = ["是今天", "是昨天", "是本周", "是本月", "是今年", "是"]
    let contentTypeConditions = ["文本", "图像", "链接", "文件", "颜色"]
    let textConditions = ["包含", "不包含", "等于", "以...开头", "以...结尾"]
    let appSourceConditions = ["Safari", "Notes", "Mail", "Messages", "Third-Party"]
    
    // 是否显示文本输入框（用于包含文本条件）
    @State private var showingTextField = false
    @State private var textFieldValue = ""
    
    // 获取条件值选项
    func getValueOptions(for type: String) -> [String] {
        switch type {
        case "创建日期": return dateConditions
        case "内容类型": return contentTypeConditions
        case "包含文本": return textConditions
        case "来自 App": return appSourceConditions
        default: return []
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 列表名称
            VStack(alignment: .leading, spacing: 10) {
                Text("智能列表名称")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("输入智能列表名称", text: $listName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // 匹配条件选择
            HStack(spacing: 8) {
                Text("包含匹配下列")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $matchType) {
                    ForEach(matchTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                
                Text("条件的内容:")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // 条件容器
            VStack(alignment: .leading, spacing: 0) {
                // 条件背景区域
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.15) : Color.white.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(conditions, id: \.id) { condition in
                                HStack(spacing: 12) {
                                    // 条件类型选择
                                    Picker("", selection: Binding(
                                        get: { condition.type },
                                        set: { updateConditionType(condition.id, newType: $0) }
                                    )) {
                                        ForEach(conditionTypes, id: \.self) { option in
                                            Text(option).tag(option)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 140)
                                    
                                    // 条件值选择
                                    Picker("", selection: Binding(
                                        get: { condition.value },
                                        set: { updateConditionValue(condition.id, newValue: $0) }
                                    )) {
                                        ForEach(getValueOptions(for: condition.type), id: \.self) { option in
                                            Text(option).tag(option)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 140)
                                    
                                    // 文本输入框 - 仅在"包含文本"条件且选择了文本操作时显示
                                    if condition.type == "包含文本" && textConditions.contains(condition.value) {
                                        TextField("关键词...", text: $textFieldValue)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    
                                    Spacer()
                                    
                                    // 控制按钮区域
                                    HStack(spacing: 8) {
                                        // 删除按钮
                                        Button(action: {
                                            removeCondition(condition.id)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.8))
                                                .font(.system(size: 20))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(conditions.count <= 1)
                                        .opacity(conditions.count <= 1 ? 0.3 : 1)
                                        
                                        // 添加按钮
                                        Button(action: {
                                            addCondition()
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.green.opacity(0.8))
                                                .font(.system(size: 20))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 220)
                }
            }
            .frame(minHeight: 120)
            
            Spacer()
            
            // 底部按钮
            HStack {
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("保存") {
                    onSave()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(listName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 600, height: 450)
        .background(colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.windowBackgroundColor))
    }
    
    // 更新条件类型
    private func updateConditionType(_ id: UUID, newType: String) {
        if let index = conditions.firstIndex(where: { $0.id == id }) {
            var condition = conditions[index]
            condition.type = newType
            
            // 更新对应的值为该类型的第一个选项
            let valueOptions = getValueOptions(for: newType)
            if !valueOptions.isEmpty {
                condition.value = valueOptions[0]
            }
            
            conditions[index] = condition
        }
    }
    
    // 更新条件值
    private func updateConditionValue(_ id: UUID, newValue: String) {
        if let index = conditions.firstIndex(where: { $0.id == id }) {
            var condition = conditions[index]
            condition.value = newValue
            conditions[index] = condition
        }
    }
    
    // 添加新条件
    private func addCondition() {
        let newCondition = (id: UUID(), type: "创建日期", value: "是今天")
        conditions.append(newCondition)
    }
    
    // 移除条件
    private func removeCondition(_ id: UUID) {
        // 确保至少保留一个条件
        if conditions.count > 1 {
            conditions.removeAll(where: { $0.id == id })
        }
    }
} 