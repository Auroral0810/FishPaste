//
//  CreateListView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI

struct CreateListView: View {
    var title: String
    @Binding var listName: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
                .padding(.top, 20)
            
            TextField("请输入列表的名字", text: $listName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 20)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
                
                Spacer()
                
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
        .frame(width: 400)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .preferredColorScheme(.dark)
    }
} 