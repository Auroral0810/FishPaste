import Foundation
import AppKit
import Carbon
import Cocoa

class ShortcutManager {
    static let shared = ShortcutManager()
    
    // 注册的快捷键集合
    private var registeredShortcuts: [String: GlobalHotKey] = [:]
    
    // 检查快捷键是否与系统已有的快捷键冲突
    func checkForSystemConflicts(shortcut: String) -> String? {
        // 将快捷键字符串转换为键码和修饰键
        let (keyCode, modifiers) = parseShortcutString(shortcut)
        
        // 检查本应用内已注册的快捷键
        for (action, hotkey) in registeredShortcuts {
            if hotkey.keyCode == keyCode && hotkey.modifiers == modifiers {
                return "FishCopy → \(action)"
            }
        }
        
        // 如果无法获取键码，则无法检查冲突
        guard keyCode > 0 else {
            return nil
        }
        
        // 检查菜单项快捷键冲突
        if let menuConflict = checkMenuItemConflicts(keyCode: keyCode, modifiers: modifiers) {
            return menuConflict
        }
        
        // 检查已知的系统快捷键冲突
        if let systemConflict = checkSystemShortcutConflicts(keyCode: keyCode, modifiers: modifiers) {
            return systemConflict
        }
        
        // 尝试注册为全局热键，看是否会冲突
        if !canRegisterHotKey(keyCode: keyCode, modifiers: modifiers) {
            return "系统或其他应用程序"
        }
        
        return nil
    }
    
    // 解析快捷键字符串为键码和修饰键
    private func parseShortcutString(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32) {
        var keyCode: UInt32 = 0
        var modifiers: UInt32 = 0
        
        // 处理修饰键
        if shortcut.contains("⌘") { modifiers |= UInt32(1 << 8) } // cmdKey
        if shortcut.contains("⌥") { modifiers |= UInt32(1 << 11) } // optionKey
        if shortcut.contains("⌃") { modifiers |= UInt32(1 << 12) } // controlKey
        if shortcut.contains("⇧") { modifiers |= UInt32(1 << 9) } // shiftKey
        
        // 提取主键
        let mainKey = shortcut.replacingOccurrences(of: "[⌘⌥⌃⇧]", with: "", options: .regularExpression)
        
        // 常见键映射
        let keyMapping: [String: UInt32] = [
            "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4, "I": 34,
            "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35, "Q": 12, 
            "R": 15, "S": 1, "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6,
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
            "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42, ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
            "`": 50, "Tab": 48, "Space": 49, "Delete": 51, "Escape": 53,
            "F1": 122, "F2": 120, "F3": 99, "F4": 118, "F5": 96, "F6": 97,
            "F7": 98, "F8": 100, "F9": 101, "F10": 109, "F11": 103, "F12": 111,
            "↑": 126, "↓": 125, "←": 123, "→": 124, "⏎": 36, "⇞": 116, "⇟": 121, 
            "⌫": 51, "⌦": 117, "⇭": 114, "⌧": 71
        ]
        
        if let code = keyMapping[mainKey.uppercased()] {
            keyCode = code
        }
        
        return (keyCode, modifiers)
    }
    
    // 检查菜单项快捷键冲突
    private func checkMenuItemConflicts(keyCode: UInt32, modifiers: UInt32) -> String? {
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        
        for app in runningApps {
            if let appName = app.localizedName {
                // 检查常见应用的常见快捷键
                if let conflict = checkCommonMenuItemsFor(app: appName, keyCode: keyCode, modifiers: modifiers) {
                    return "\(appName) → \(conflict)"
                }
            }
        }
        
        return nil
    }
    
    // 检查常见应用的常见菜单项
    private func checkCommonMenuItemsFor(app: String, keyCode: UInt32, modifiers: UInt32) -> String? {
        // 常见的应用菜单项快捷键检查
        // 这里只包含部分常见快捷键冲突检查
        
        // Command+C (复制)
        if keyCode == 8 && modifiers == UInt32(1 << 8) {
            return "编辑 → 复制"
        }
        
        // Command+V (粘贴)
        if keyCode == 9 && modifiers == UInt32(1 << 8) {
            return "编辑 → 粘贴"
        }
        
        // Command+X (剪切)
        if keyCode == 7 && modifiers == UInt32(1 << 8) {
            return "编辑 → 剪切"
        }
        
        // Command+Z (撤销)
        if keyCode == 6 && modifiers == UInt32(1 << 8) {
            return "编辑 → 撤销"
        }
        
        // Command+Shift+L (特定应用的搜索)
        if keyCode == 37 && modifiers == (UInt32(1 << 8) | UInt32(1 << 9)) {
            return "服务 → 用搜索"
        }
        
        // Command+Option+V (Finder粘贴项目)
        if keyCode == 9 && modifiers == (UInt32(1 << 8) | UInt32(1 << 11)) {
            if app == "Finder" {
                return "编辑 → 粘贴项目"
            }
        }
        
        return nil
    }
    
    // 检查系统级快捷键冲突
    private func checkSystemShortcutConflicts(keyCode: UInt32, modifiers: UInt32) -> String? {
        let systemShortcuts: [(keyCode: UInt32, modifiers: UInt32, description: String)] = [
            // 系统级快捷键列表
            (36, UInt32(1 << 8), "系统 → 打开所选项"),
            (53, 0, "系统 → 取消"),
            (96, UInt32(1 << 12), "系统 → 显示帮助菜单"),
            (126, UInt32(1 << 8) | UInt32(1 << 11), "系统 → 使用快照"),
            (125, UInt32(1 << 8) | UInt32(1 << 11), "系统 → 显示所有窗口"),
            (123, UInt32(1 << 8) | UInt32(1 << 12), "系统 → 向前"),
            (124, UInt32(1 << 8) | UInt32(1 << 12), "系统 → 向后"),
            (36, UInt32(1 << 8) | UInt32(1 << 12), "系统 → 强制退出"),
            // 可以添加更多系统快捷键
        ]
        
        for shortcut in systemShortcuts {
            if shortcut.keyCode == keyCode && shortcut.modifiers == modifiers {
                return shortcut.description
            }
        }
        
        return nil
    }
    
    // 尝试注册热键检查是否成功
    private func canRegisterHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4653484B) // 'FSHK'
        hotKeyID.id = UInt32(registeredShortcuts.count + 1)
        
        var hotKeyRef: EventHotKeyRef? = nil
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        let success = status == noErr
        
        // 如果成功注册了热键，立即注销它
        if success && hotKeyRef != nil {
            UnregisterEventHotKey(hotKeyRef!)
        }
        
        return success
    }
    
    // 注册快捷键
    func registerShortcut(for action: String, shortcut: String) -> Bool {
        // 解析快捷键
        let (keyCode, modifiers) = parseShortcutString(shortcut)
        
        // 创建并保存全局热键
        let hotKey = GlobalHotKey(keyCode: keyCode, modifiers: modifiers, action: action)
        registeredShortcuts[action] = hotKey
        
        return true
    }
    
    // 注销快捷键
    func unregisterShortcut(for action: String) {
        registeredShortcuts.removeValue(forKey: action)
    }
}

// 全局热键结构
struct GlobalHotKey {
    let keyCode: UInt32
    let modifiers: UInt32
    let action: String
    var hotKeyRef: EventHotKeyRef? = nil
} 