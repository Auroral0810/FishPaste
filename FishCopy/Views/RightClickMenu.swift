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
                        }) {
                            Label("编辑图片", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            // 保存图片逻辑
                        }) {
                            Label("保存图片", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: {
                            // 添加标题逻辑
                        }) {
                            Label("添加标题", systemImage: "text.badge.plus")
                        }
                        
                        Divider()
                    }
                    // 文本相关选项
                    else if item.text != nil {
                        Button(action: {
                            // 编辑文本逻辑
                        }) {
                            Label("编辑文本", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            // 编辑标题逻辑
                        }) {
                            Label("编辑标题", systemImage: "text.badge.star")
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
}

// View扩展，提供简便的修饰符方法
extension View {
    func clipboardItemContextMenu(item: ClipboardContent) -> some View {
        self.modifier(ClipboardItemContextMenu(item: item))
    }
} 
