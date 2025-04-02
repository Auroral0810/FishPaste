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
        let schema = Schema([
            ClipboardItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法创建ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // 状态栏菜单
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(clipboardManager)
                .frame(width: 350)
                // 不指定固定高度，让视图自己计算
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
