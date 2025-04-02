//
//  FishCopyApp.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import SwiftData

@main
struct FishCopyApp: App {
    // 状态管理
    @StateObject private var clipboardManager = ClipboardManager()
    // 设置存储
    @AppStorage("launchAtStartup") private var launchAtStartup = true
    
    // SwiftData模型容器配置
    var sharedModelContainer: ModelContainer = {
        do {
            // 配置持久化存储选项
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false
            )
            
            // 创建具有错误恢复和迁移选项的ModelContainer
            let container = try ModelContainer(
                for: ClipboardItem.self, ClipboardCategory.self,
                configurations: modelConfiguration
            )
            print("SwiftData模型容器成功初始化")
            return container
        } catch {
            // 如果创建失败，尝试使用内存存储模式作为备用
            print("初始化持久化ModelContainer失败，错误: \(error.localizedDescription)")
            print("尝试使用内存存储作为备用...")
            
            do {
                let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: ClipboardItem.self, ClipboardCategory.self,
                    configurations: fallbackConfiguration
                )
            } catch {
                fatalError("无法创建任何ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        // 状态栏菜单
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(clipboardManager)
                .frame(width: 350)
                .modelContainer(sharedModelContainer)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window) // 使用窗口样式显示菜单
        
        // 主窗口
        WindowGroup {
            MainView()
                .environmentObject(clipboardManager)
                .preferredColorScheme(.dark) // 强制使用深色模式
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar) // 使用无标题栏风格
    }
}
