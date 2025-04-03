import SwiftUI

struct AboutView: View {
    // 获取应用信息
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "FishPaste"
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(version) (\(build))"
    }
    
    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© 2025 俞云烽. 保留所有权利。"
    }
    
    // 加载应用程序图标
    private var appIcon: NSImage? {
        // 尝试加载自定义图标
        if let logoPath = Bundle.main.path(forResource: "logo-circle", ofType: "svg"),
           let logoData = try? Data(contentsOf: URL(fileURLWithPath: logoPath)),
           let svgImage = NSImage(data: logoData) {
            return svgImage
        }
        
        // 尝试加载普通logo
        if let logoPath = Bundle.main.path(forResource: "logo", ofType: "svg"),
           let logoData = try? Data(contentsOf: URL(fileURLWithPath: logoPath)),
           let svgImage = NSImage(data: logoData) {
            return svgImage
        }
        
        // 尝试加载应用程序图标
        if let appIconSet = NSImage(named: "AppIcon") {
            return appIconSet
        }
        
        // 尝试加载状态栏图标
        if let statusIconPath = Bundle.main.path(forResource: "statusBarIcon", ofType: "png"),
           let statusIcon = NSImage(contentsOfFile: statusIconPath) {
            return statusIcon
        }
        
        // 使用状态栏图标作为备用
        return NSImage(named: NSImage.applicationIconName)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                // 最后的备用选项
                Image(systemName: "doc.on.clipboard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .foregroundColor(.blue)
            }
            
            // 应用名称
            Text(appName)
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 10)
            
            // 版本信息
            Text(appVersion)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            // 版权信息
            Text(copyright)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 20)
            
            // 功能描述
            Text("强大的剪贴板管理工具")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            
            Spacer()
        }
        .frame(width: 400, height: 300)
        .padding(.top, 20)
        .background(Color(NSColor.windowBackgroundColor))
    }
} 