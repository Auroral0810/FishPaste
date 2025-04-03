//
//  EditViews.swift
//  FishPaste
//
//  Created by 俞云烽 on 2025/04/04.
//

import SwiftUI
import AppKit

// 文本编辑视图
struct EditTextView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    // 关闭回调
    var onClose: () -> Void
    
    // 当前编辑的剪贴板项
    let clipboardItem: ClipboardContent
    
    // 内部状态
    @State private var editedText: String = ""
    @State private var editedTitle: String = ""
    @State private var isEditing: Bool = false
    
    @State private var textFieldFocused: Bool = false
    @FocusState private var titleFieldFocused: Bool
    
    init(clipboardItem: ClipboardContent, onClose: @escaping () -> Void) {
        self.clipboardItem = clipboardItem
        self.onClose = onClose
        
        // 初始化状态值
        _editedText = State(initialValue: clipboardItem.text ?? "")
        _editedTitle = State(initialValue: clipboardItem.title ?? "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题区域
            HStack {
                Text("编辑文本内容")
                    .font(.headline)
                    .padding(.top, 8)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // 标题编辑区域
            HStack {
                Text("标题:")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#49b1f5") ?? .blue)
                
                TextField("添加标题...", text: $editedTitle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .focused($titleFieldFocused)
                    .onAppear {
                        // 自动聚焦到标题字段
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.titleFieldFocused = true
                        }
                    }
            }
            .padding(.horizontal, 16)
            
            // 内容编辑区域
            VStack(alignment: .leading, spacing: 6) {
                Text("内容")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                ZStack {
                    TextEditor(text: $editedText)
                        .font(.body)
                        .frame(minHeight: 150)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // 底部操作栏
            HStack {
                Button("取消") {
                    onClose()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                Spacer()
                
                Button(action: {
                    isEditing = true
                    
                    // 更新剪贴板内容
                    clipboardManager.updateTextContent(
                        for: clipboardItem.id,
                        newText: editedText,
                        newTitle: editedTitle.isEmpty ? nil : editedTitle
                    )
                    
                    isEditing = false
                    onClose()
                }) {
                    if isEditing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("保存")
                    }
                }
                .disabled(isEditing || (editedText.isEmpty && editedTitle.isEmpty))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isEditing || (editedText.isEmpty && editedTitle.isEmpty) ? Color.blue.opacity(0.3) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 450, minHeight: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// 图片编辑视图
struct EditImageView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    // 关闭回调
    var onClose: () -> Void
    
    // 当前编辑的剪贴板项
    let clipboardItem: ClipboardContent
    
    // 内部状态
    @State private var editedImage: NSImage?
    @State private var editedTitle: String = ""
    @State private var isEditing: Bool = false
    @State private var isLoading: Bool = false
    @State private var showTitleEditor: Bool = true
    
    @FocusState private var titleFieldFocused: Bool
    
    init(clipboardItem: ClipboardContent, onClose: @escaping () -> Void) {
        self.clipboardItem = clipboardItem
        self.onClose = onClose
        
        // 初始化状态值
        _editedImage = State(initialValue: clipboardItem.image)
        _editedTitle = State(initialValue: clipboardItem.title ?? "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题区域
            HStack {
                Text("编辑图片内容")
                    .font(.headline)
                    .padding(.top, 8)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // 标题编辑区域 - 简化为一行
            if showTitleEditor {
                HStack {
                    Text("标题:")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#49b1f5") ?? .blue)
                    
                    TextField("添加标题...", text: $editedTitle)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .focused($titleFieldFocused)
                        .onAppear {
                            // 自动聚焦到标题字段
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.titleFieldFocused = true
                            }
                        }
                }
                .padding(.horizontal, 16)
            }
            
            // 图片编辑区域
            VStack(alignment: .center, spacing: 12) {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(height: 200)
                } else if let image = editedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(4)
                        .shadow(radius: 2)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 150)
                        .cornerRadius(4)
                        .overlay(
                            Text("无图片")
                                .foregroundColor(.gray)
                        )
                }
                
                HStack(spacing: 20) {
                    Button("从文件选择") {
                        openImageFile()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    
                    Button("从剪贴板获取") {
                        getImageFromClipboard()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // 底部操作栏
            HStack {
                Button("取消") {
                    onClose()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                Spacer()
                
                Button(action: {
                    isEditing = true
                    
                    // 更新剪贴板内容
                    if let image = editedImage {
                        clipboardManager.updateImageContent(
                            for: clipboardItem.id,
                            newImage: image,
                            newTitle: editedTitle.isEmpty ? nil : editedTitle
                        )
                    } else {
                        // 如果只更新标题
                        clipboardManager.updateTitle(
                            for: clipboardItem.id,
                            newTitle: editedTitle
                        )
                    }
                    
                    isEditing = false
                    onClose()
                }) {
                    if isEditing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("保存")
                    }
                }
                .disabled(isEditing || (editedTitle.isEmpty && editedImage == nil))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isEditing || (editedTitle.isEmpty && editedImage == nil) ? Color.blue.opacity(0.3) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 450, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // 从文件选择图片
    private func openImageFile() {
        isLoading = true
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic"]
        panel.allowsOtherFileTypes = true
        
        NSApp.activate(ignoringOtherApps: true)
        
        panel.begin { response in
            defer { isLoading = false }
            
            if response == .OK, let url = panel.urls.first {
                // 使用主线程更新UI
                DispatchQueue.main.async {
                    if let image = NSImage(contentsOf: url) {
                        self.editedImage = image
                        print("图片加载成功: \(url.lastPathComponent)")
                    } else {
                        print("无法加载图片: \(url.path)")
                    }
                }
            }
        }
    }
    
    // 从剪贴板获取图片
    private func getImageFromClipboard() {
        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            self.editedImage = image
            print("从剪贴板获取图片成功")
        } else {
            print("剪贴板中没有图片")
        }
    }
}

// 图片选择器视图
struct ImagePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    var onImageSelected: (NSImage?) -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("选择图片")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
            
            Button("从文件选择") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedFileTypes = ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic"]
                
                panel.begin { response in
                    if response == .OK, let url = panel.urls.first {
                        if let image = NSImage(contentsOf: url) {
                            onImageSelected(image)
                        }
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
            Button("从剪贴板获取") {
                if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                    onImageSelected(image)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 350, height: 300)
    }
}

// 添加/编辑标题视图 - 简化版本
struct EditTitleView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    // 关闭回调
    var onClose: () -> Void
    
    // 当前编辑的剪贴板项
    let clipboardItem: ClipboardContent
    
    // 内部状态
    @State private var editedTitle: String = ""
    @State private var isEditing: Bool = false
    
    @FocusState private var titleFieldFocused: Bool
    
    init(clipboardItem: ClipboardContent, onClose: @escaping () -> Void) {
        self.clipboardItem = clipboardItem
        self.onClose = onClose
        
        // 初始化状态值
        _editedTitle = State(initialValue: clipboardItem.title ?? "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题区域
            HStack {
                Text("编辑标题")
                    .font(.headline)
                    .padding(.top, 8)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // 简化的标题编辑区域
            HStack {
                Text("标题:")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#49b1f5") ?? .blue)
                
                TextField("添加标题...", text: $editedTitle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .focused($titleFieldFocused)
                    .onAppear {
                        // 自动聚焦到标题字段
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.titleFieldFocused = true
                        }
                    }
            }
            .padding(.horizontal, 16)
            
            // 内容预览区域（仅显示内容类型图标和简短预览）
            HStack(spacing: 12) {
                // 内容类型图标
                if clipboardItem.image != nil {
                    Image(nsImage: clipboardItem.image!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(4)
                } else if let text = clipboardItem.text {
                    VStack(alignment: .leading) {
                        Image(systemName: text.hasPrefix("http") ? "link" : "doc.text")
                            .font(.system(size: 24))
                            .foregroundColor(text.hasPrefix("http") ? .purple : .blue)
                            .frame(width: 30, height: 30)
                        
                        Text(text.prefix(50) + (text.count > 50 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                } else {
                    Image(systemName: "questionmark.square")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                        .frame(width: 40, height: 40)
                }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor).opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            
            Spacer()
            
            // 底部操作栏
            HStack {
                Button("取消") {
                    onClose()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    isEditing = true
                    
                    // 更新标题
                    clipboardManager.updateTitle(
                        for: clipboardItem.id,
                        newTitle: editedTitle
                    )
                    
                    isEditing = false
                    onClose()
                }) {
                    if isEditing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("保存")
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(isEditing)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 400, height: 250)
        .background(Color(NSColor.windowBackgroundColor))
    }
}


// 颜色扩展已移至 Extensions/Color+Hex.swift 文件
