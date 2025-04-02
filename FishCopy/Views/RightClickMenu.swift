//
//  RightClickMenu.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI

// 右键菜单修饰符
struct ClipboardItemContextMenu: ViewModifier {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var showingEditTextView = false
    @State private var showingEditImageView = false
    @State private var showingEditTitleView = false
    @State private var delegate: Any? = nil
    @State private var popover: NSPopover? = nil
    let item: ClipboardContent
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                // 粘贴至FishCopy选项
                Button(action: {
                    // 粘贴到应用程序中的操作
                }) {
                    Label("粘贴至\"FishCopy\"", systemImage: "arrow.right.doc.on.clipboard")
                }
                
                // 粘贴为子菜单
                Menu {
                    Button("文本", action: {})
                    Button("富文本", action: {})
                    Button("HTML", action: {})
                    Divider()
                    Button("无格式文本", action: {})
                    Button("带源代码格式", action: {})
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
                
                // 钉选选项
                Button(action: {
                    clipboardManager.togglePinStatus(for: item.id)
                }) {
                    Label(item.isPinned ? "取消钉选" : "钉选", 
                          systemImage: item.isPinned ? "pin.slash" : "pin.fill")
                }
                
                Divider()
                
                // 内容特定选项
                Group {
                    // 图片相关选项
                    if item.image != nil {
                        Button(action: {
                            // 编辑图片逻辑
                            createAndShowEditImageWindow()
                        }) {
                            Label("编辑图片", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            // 保存图片逻辑
                            saveImage()
                        }) {
                            Label("保存图片", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: {
                            // 添加标题逻辑
                            createAndShowEditTitleWindow()
                        }) {
                            Label((item.title?.isEmpty ?? true) ? "添加标题" : "编辑标题", systemImage: "text.badge.plus")
                        }
                        
                        Divider()
                    }
                    // 文本相关选项
                    else if item.text != nil {
                        Button(action: {
                            // 编辑文本逻辑
                            createAndShowEditTextWindow()
                        }) {
                            Label("编辑文本", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            // 编辑标题逻辑
                            createAndShowEditTitleWindow()
                        }) {
                            Label((item.title?.isEmpty ?? true) ? "添加标题" : "编辑标题", systemImage: "text.badge.star")
                        }
                        
                        Divider()
                    }
                }
                
                // 添加到列表子菜单
                Menu {
                    Button(action: {
                        // 添加到钉选逻辑
                        clipboardManager.setPinStatus(for: item.id, isPinned: true)
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
    }
    
    // 创建并显示编辑文本窗口
    private func createAndShowEditTextWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "编辑文本内容"
        window.isReleasedWhenClosed = false
        
        // 创建并设置视图
        let contentView = EditTextView(clipboardItem: item) {
            window.close()
        }
        .environmentObject(clipboardManager)
        
        // 使用NSHostingView包装SwiftUI视图
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用
        FishCopyApp.activeWindows.append(window)
    }
    
    // 创建并显示编辑图片窗口
    private func createAndShowEditImageWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "编辑图片内容"
        window.isReleasedWhenClosed = false
        
        // 创建并设置视图
        let contentView = EditImageView(clipboardItem: item) {
            window.close()
        }
        .environmentObject(clipboardManager)
        
        // 使用NSHostingView包装SwiftUI视图
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保持窗口引用
        FishCopyApp.activeWindows.append(window)
    }
    
    // 创建并显示编辑标题窗口
    private func createAndShowEditTitleWindow() {
        // 获取当前窗口
        guard let window = NSApp.keyWindow else { return }
        
        // 创建输入框
        let titleField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        titleField.stringValue = item.title ?? ""
        titleField.placeholderString = "请输入标题..."
        titleField.isBezeled = true
        titleField.bezelStyle = .roundedBezel
        titleField.drawsBackground = true
        titleField.isEditable = true
        titleField.isSelectable = true
        titleField.font = NSFont.systemFont(ofSize: 13)
        titleField.textColor = NSColor(hex: "#49b1f5")
        
        // 设置委托处理完成编辑事件
        let delegate = TitleFieldDelegate(item: item, clipboardManager: clipboardManager, field: titleField)
        titleField.delegate = delegate
        
        // 在剪贴板项目上方显示输入框
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 40)
        popover.behavior = .transient
        
        // 创建一个容器视图来包装文本框
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 40))
        containerView.addSubview(titleField)
        
        // 居中放置文本框
        titleField.frame.origin = NSPoint(x: 10, y: (40 - titleField.frame.height) / 2)
        titleField.frame.size.width = 300
        
        // 设置内容视图
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = containerView
        
        // 获取事件位置
        if let event = NSApp.currentEvent {
            // 获取点击位置对应的视图
            let position = event.locationInWindow
            
            // 找到适合显示的视图
            if let contentView = window.contentView {
                // 转换坐标
                let positionInWindow = window.convertPoint(fromScreen: position)
                
                // 创建一个虚拟的源矩形，在点击位置
                let sourceRect = NSRect(x: positionInWindow.x, y: positionInWindow.y, width: 1, height: 1)
                
                // 显示popover - 确保在上方显示
                popover.show(relativeTo: sourceRect, of: contentView, preferredEdge: .maxY)
                
                // 使文本框成为第一响应者
                titleField.window?.makeFirstResponder(titleField)
                
                // 保存引用以防止过早释放
                self.delegate = delegate
                self.popover = popover
            }
        }
    }
    
    // 保存图片到文件
    private func saveImage() {
        guard let image = item.image else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["png", "jpg", "jpeg", "tiff"]
        savePanel.nameFieldStringValue = "剪贴板图片"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffRepresentation = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    
                    do {
                        try pngData.write(to: url)
                        print("图片已保存到 \(url.path)")
                    } catch {
                        print("保存图片失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// 文本框委托
class TitleFieldDelegate: NSObject, NSTextFieldDelegate {
    let item: ClipboardContent
    let clipboardManager: ClipboardManager
    let textField: NSTextField
    
    init(item: ClipboardContent, clipboardManager: ClipboardManager, field: NSTextField) {
        self.item = item
        self.clipboardManager = clipboardManager
        self.textField = field
        super.init()
    }
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        updateTitleAndNotify()
        closePopover()
        return true
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        updateTitleAndNotify()
    }
    
    private func updateTitleAndNotify() {
        // 当用户完成编辑时更新标题
        clipboardManager.updateTitle(
            for: item.id,
            newTitle: textField.stringValue.isEmpty ? "" : textField.stringValue
        )
        
        // 直接更新ClipboardContent对象
        DispatchQueue.main.async {
            // 更新当前对象的标题
            self.item.title = self.textField.stringValue.isEmpty ? "" : self.textField.stringValue
            
            // 发送多个通知以确保UI更新
            // 1. 发送ClipboardItemUpdated通知
            NotificationCenter.default.post(
                name: Notification.Name("ClipboardItemUpdated"),
                object: nil,
                userInfo: ["itemID": self.item.id]
            )
            
            // 2. 发送通用的UI刷新通知
            NotificationCenter.default.post(
                name: Notification.Name("RefreshClipboardView"),
                object: nil
            )
            
            // 3. 发送剪贴板内容变化通知
            NotificationCenter.default.post(
                name: Notification.Name("ClipboardContentChanged"),
                object: nil
            )
        }
    }
    
    private func closePopover() {
        if let popover = textField.window?.contentViewController?.view.window?.contentViewController?.view.window?.attachedSheet as? NSPopover {
            popover.close()
        } else if let popover = textField.superview?.enclosingMenuItem?.view?.window?.attachedSheet as? NSPopover {
            popover.close()
        } else if let window = textField.window {
            window.close()
        }
    }
}

// View扩展，提供简便的修饰符方法
extension View {
    func clipboardItemContextMenu(item: ClipboardContent) -> some View {
        self.modifier(ClipboardItemContextMenu(item: item))
    }
}

// 颜色扩展，用于从十六进制字符串创建颜色
extension NSColor {
    convenience init?(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var hexValue: UInt64 = 0
        
        guard Scanner(string: hexString).scanHexInt64(&hexValue) else {
            return nil
        }
        
        let r, g, b, a: CGFloat
        switch hexString.count {
        case 3: // RGB (12-bit)
            r = CGFloat((hexValue & 0xF00) >> 8) / 15.0
            g = CGFloat((hexValue & 0x0F0) >> 4) / 15.0
            b = CGFloat(hexValue & 0x00F) / 15.0
            a = 1.0
        case 6: // RGB (24-bit)
            r = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(hexValue & 0x0000FF) / 255.0
            a = 1.0
        case 8: // RGBA (32-bit)
            r = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(hexValue & 0x000000FF) / 255.0
        default:
            return nil
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
} 
