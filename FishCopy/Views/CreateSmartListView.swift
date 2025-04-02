//
//  CreateSmartListView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI

struct CreateSmartListView: View {
    @Binding var listName: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // 条件类型
    @State private var conditionType = "创建日期"
    @State private var conditionValue = "是今天"
    
    // 条件选项
    let conditionTypes = ["创建日期", "文本内容", "文件类型", "来源应用"]
    let dateConditions = ["是今天", "是昨天", "最近7天", "最近30天", "自定义"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题栏
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                
                Spacer()
                
                Text("编辑智能列表")
                    .font(.headline)
                
                Spacer()
                
                Image("Paste")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .padding(.trailing, 10)
            }
            .padding(.horizontal, 10)
            
            // 列表名称
            Text("智能列表名称")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            TextField("", text: $listName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 20)
            
            // 条件设置
            HStack {
                Text("包含匹配下列")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Menu {
                    Button("所有", action: {})
                    Button("任意", action: {})
                } label: {
                    HStack {
                        Text("所有")
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(5)
                }
                
                Text("条件的内容:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            // 条件编辑区域
            VStack {
                HStack {
                    Menu {
                        ForEach(conditionTypes, id: \.self) { option in
                            Button(option) {
                                conditionType = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(conditionType)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(5)
                    }
                    .frame(width: 150)
                    
                    Menu {
                        ForEach(dateConditions, id: \.self) { option in
                            Button(option) {
                                conditionValue = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(conditionValue)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(5)
                    }
                    .frame(width: 150)
                    
                    Button(action: {}) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .frame(height: 200)
            .padding(.horizontal, 20)
            .background(Color.black.opacity(0.2))
            .cornerRadius(5)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // 底部按钮
            HStack {
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
                .padding(.trailing, 10)
                
                Button("保存") {
                    onSave()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(listName.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 600, height: 400)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .preferredColorScheme(.dark)
    }
} 