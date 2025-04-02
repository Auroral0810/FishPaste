//
//  SettingsView.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import SwiftUI
import AppKit

// 定义设置选项卡
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case shortcuts = "快捷键"
    case rules = "排除规则"
    case sync = "同步"
    case advanced = "高级"
    case about = "关于"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .shortcuts: return "command"
        case .rules: return "hand.raised"
        case .sync: return "arrow.triangle.2.circlepath.circle"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    var clipboardManager: ClipboardManager
    @State private var selectedTab: SettingsTab = .general
    
    // 通用设置
    @AppStorage("launchAtStartup") private var launchAtStartup = true
    @AppStorage("enableSounds") private var enableSounds = true
    
    // 高级设置
    @State private var useVimKeys = false
    @State private var useQwertyLayout = false
    @State private var showStatusIcon = true
    @State private var statusIconMode = "出现在状态栏图标旁"
    
    // 粘贴设置
    @State private var pasteToActiveApp = true
    @State private var moveToFront = false 
    @State private var pasteFormat = "粘贴为原始文本"
    
    // 历史项目设置
    @State private var deleteAfter = "一个月以后"
    
    let statusIconModes = ["出现在状态栏图标旁", "重置状态"]
    let pasteFormats = ["粘贴为原始文本", "保持格式粘贴", "智能粘贴"]
    let deleteOptions = ["永不", "一周以后", "一个月以后", "三个月以后"]
    
    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                HStack {
                    Image(systemName: tab.icon)
                        .frame(width: 20)
                    Text(tab.rawValue)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 150)
        } detail: {
            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { 
                        Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon) 
                    }
                    .tag(SettingsTab.general)
                
                shortcutsTab
                    .tabItem { 
                        Label(SettingsTab.shortcuts.rawValue, systemImage: SettingsTab.shortcuts.icon) 
                    }
                    .tag(SettingsTab.shortcuts)
                
                rulesTab
                    .tabItem { 
                        Label(SettingsTab.rules.rawValue, systemImage: SettingsTab.rules.icon) 
                    }
                    .tag(SettingsTab.rules)
                
                syncTab
                    .tabItem { 
                        Label(SettingsTab.sync.rawValue, systemImage: SettingsTab.sync.icon) 
                    }
                    .tag(SettingsTab.sync)
                
                advancedTab
                    .tabItem { 
                        Label(SettingsTab.advanced.rawValue, systemImage: SettingsTab.advanced.icon) 
                    }
                    .tag(SettingsTab.advanced)
                
                aboutTab
                    .tabItem { 
                        Label(SettingsTab.about.rawValue, systemImage: SettingsTab.about.icon) 
                    }
                    .tag(SettingsTab.about)
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
        }
        .frame(width: 650, height: 480)
        .environmentObject(clipboardManager)
    }
    
    // 通用设置选项卡
    var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Text("启动:")) {
                Toggle("随系统启动", isOn: $launchAtStartup)
                    .padding(.vertical, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("声音:")) {
                Toggle("启用音效", isOn: $enableSounds)
                    .padding(.vertical, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("支持:")) {
                Button("发送反馈") {
                    // 发送反馈的操作
                    if let url = URL(string: "mailto:feedback@example.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .padding(.vertical, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("更新:")) {
                Button("检查更新") {
                    // 检查更新的操作
                }
                .padding(.vertical, 5)
                
                Text("当前版本: 2.16 (466)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("退出:")) {
                Button("退出 FishCopy") {
                    NSApplication.shared.terminate(nil)
                }
                .padding(.vertical, 5)
            }
            .padding(.vertical, 5)
            
            Spacer()
        }
        .padding()
    }
    
    // 快捷键设置选项卡
    var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("定制快捷键以使用更加快速的方式操作 FishCopy。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
            
            Group {
                HStack {
                    Text("激活 FishCopy:")
                        .frame(width: 150, alignment: .trailing)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 180, height: 30)
                        
                        Text("⌘⌥V")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                
                HStack {
                    Text("重置界面状态:")
                        .frame(width: 150, alignment: .trailing)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 180, height: 30)
                        
                        Text("⌘R")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                
                HStack {
                    Text("选择上个列表:")
                        .frame(width: 150, alignment: .trailing)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 180, height: 30)
                        
                        Text("⌘⌃[")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                
                HStack {
                    Text("选择下个列表:")
                        .frame(width: 150, alignment: .trailing)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 180, height: 30)
                        
                        Text("⌘⌃]")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                
                HStack {
                    Text("快速选择列表:")
                        .frame(width: 150, alignment: .trailing)
                    
                    Button("录制快捷键") {
                        // 录制快捷键的操作
                    }
                    .controlSize(.regular)
                }
                
                HStack {
                    Text("清除剪贴板内容:")
                        .frame(width: 150, alignment: .trailing)
                    
                    Button("录制快捷键") {
                        // 录制快捷键的操作
                    }
                    .controlSize(.regular)
                }
                
                HStack {
                    Text("清空已保存的项目:")
                        .frame(width: 150, alignment: .trailing)
                    
                    Button("录制快捷键") {
                        // 录制快捷键的操作
                    }
                    .controlSize(.regular)
                }
                
                HStack {
                    Text("将最近一个项目以纯文本粘贴:")
                        .frame(width: 150, alignment: .trailing)
                    
                    Button("录制快捷键") {
                        // 录制快捷键的操作
                    }
                    .controlSize(.regular)
                }
            }
            
            Spacer(minLength: 20)
            
            Group {
                HStack {
                    Text("快速粘贴:")
                        .frame(width: 150, alignment: .trailing)
                    
                    HStack {
                        Text("按住")
                        Text("⌘")
                            .fontWeight(.bold)
                        Text("键")
                    }
                    
                    Picker("", selection: .constant("Command")) {
                        Text("Command").tag("Command")
                        Text("Option").tag("Option")
                        Text("Control").tag("Control")
                    }
                    .frame(width: 120)
                }
                
                HStack {
                    Text("纯文本模式:")
                        .frame(width: 150, alignment: .trailing)
                    
                    HStack {
                        Text("按住")
                        Text("⌥")
                            .fontWeight(.bold)
                        Text("键")
                    }
                    
                    Picker("", selection: .constant("Option")) {
                        Text("Command").tag("Command")
                        Text("Option").tag("Option")
                        Text("Control").tag("Control")
                    }
                    .frame(width: 120)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // 排除规则选项卡
    var rulesTab: some View {
        VStack(alignment: .leading, spacing: 15) {
            TabView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("如果当前 App 在\"排除列表\"中，则 FishCopy 会忽略复制操作。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                    
                    List {
                        HStack {
                            Image(systemName: "key.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.blue)
                            Text("Passwords")
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.blue)
                            Text("1Password")
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    HStack {
                        Button(action: {
                            // 添加应用
                        }) {
                            Image(systemName: "plus")
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            // 移除应用
                        }) {
                            Image(systemName: "minus")
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                    }
                }
                .padding()
                .tabItem {
                    Text("根据App")
                }
                
                VStack {
                    Text("其他规则设置")
                        .font(.title2)
                        .padding()
                    
                    Spacer()
                }
                .padding()
                .tabItem {
                    Text("其他规则")
                }
            }
        }
        .padding()
    }
    
    // 同步选项卡
    var syncTab: some View {
        VStack(alignment: .center, spacing: 20) {
            Spacer()
            
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("iCloud 同步")
                .font(.title2)
                .fontWeight(.semibold)
            
            Toggle("", isOn: .constant(false))
                .labelsHidden()
                .padding(.bottom, 20)
            
            Button("立刻同步") {
                // 同步操作
            }
            .controlSize(.large)
            .disabled(true)
            
            Text("最近同步: 从未同步")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 10)
            
            Spacer()
        }
        .padding()
    }
    
    // 高级设置选项卡
    var advancedTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Text("Vim 键绑定:")) {
                Toggle("使用 HJKL 键在项目与列表间导航", isOn: $useVimKeys)
                    .padding(.vertical, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("键盘布局:")) {
                Toggle("使用德沃夏克键盘布局", isOn: $useQwertyLayout)
                    .padding(.vertical, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("菜单栏:")) {
                Toggle("显示状态图标", isOn: $showStatusIcon)
                    .padding(.vertical, 5)
                
                HStack {
                    Text("使用快捷键激活时:")
                    Spacer()
                    Picker("", selection: $statusIconMode) {
                        ForEach(statusIconModes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    .frame(width: 200)
                }
                .padding(.top, 5)
                
                HStack {
                    Text("显示界面时:")
                    Spacer()
                    Picker("", selection: .constant("有新内容时重置状态")) {
                        Text("有新内容时重置状态").tag("有新内容时重置状态")
                    }
                    .frame(width: 200)
                }
                .padding(.top, 5)
                
                Text("有新内容时滚动到顶部并退出搜索状态")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("粘贴选项:")) {
                Toggle("粘贴至当前激活的 App", isOn: $pasteToActiveApp)
                    .padding(.vertical, 5)
                
                Text("需要辅助功能权限")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Toggle("粘贴后将项目移至最前", isOn: $moveToFront)
                    .padding(.vertical, 5)
                
                HStack {
                    Text("当粘贴文本时:")
                    Spacer()
                    Picker("", selection: $pasteFormat) {
                        ForEach(pasteFormats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                    .frame(width: 200)
                }
                .padding(.top, 5)
                
                Text("按住 ⌥ Option 键以粘贴纯文本")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .padding(.vertical, 5)
            
            GroupBox(label: Text("移除历史项目:")) {
                HStack {
                    Picker("", selection: $deleteAfter) {
                        ForEach(deleteOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .frame(width: 200)
                }
                .padding(.vertical, 5)
                
                Text("添加至普通列表的项目不会被移除")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 5)
            
            Spacer()
        }
        .padding()
    }
    
    // 关于选项卡
    var aboutTab: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.on.clipboard")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("FishCopy")
                .font(.title)
                .fontWeight(.bold)
            
            Text("版本 2.16 (466)")
                .foregroundColor(.secondary)
            
            Text("© 2025 俞云烽. 保留所有权利。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 30)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView(clipboardManager: ClipboardManager())
} 
