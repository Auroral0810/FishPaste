//
//  UpdateChecker.swift
//  FishPaste
//
//  Created by 俞云烽 on 2025/04/05.
//

import Foundation
import AppKit

class UpdateChecker {
    // 单例模式
    static let shared = UpdateChecker()
    
    // 远程版本检查地址 - 更新为实际的仓库地址
    private let updateCheckURL = "https://api.github.com/repos/Auroral0810/FishPaste/releases/latest"
    
    // 应用内部版本号
    private var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    
    // 检查更新状态
    private var isCheckingForUpdates = false
    
    // 下载更新相关
    private var downloadTask: URLSessionDownloadTask?
    private var downloadProgress: Progress?
    private var progressObserver: NSKeyValueObservation?
    
    // 私有初始化
    private init() {}
    
    // 检查更新
    func checkForUpdates(silent: Bool = false, completion: ((Bool, String, String, URL?) -> Void)? = nil) {
        // 避免多次检查
        if isCheckingForUpdates {
            print("已经在检查更新中...")
            return
        }
        
        isCheckingForUpdates = true
        
        // 创建URL请求
        guard let url = URL(string: updateCheckURL) else {
            print("更新检查URL无效")
            isCheckingForUpdates = false
            completion?(false, "错误", "更新检查URL无效", nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            // 重置检查状态
            defer { 
                self.isCheckingForUpdates = false 
            }
            
            // 处理错误
            if let error = error {
                print("检查更新失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if !silent {
                        self.showUpdateAlert(title: "更新检查失败", message: "无法连接到更新服务器，请检查网络连接后重试。\n错误: \(error.localizedDescription)")
                    }
                    completion?(false, "更新检查失败", error.localizedDescription, nil)
                }
                return
            }
            
            // 确保收到数据
            guard let data = data else {
                print("检查更新失败: 未接收到数据")
                DispatchQueue.main.async {
                    if !silent {
                        self.showUpdateAlert(title: "更新检查失败", message: "未从服务器收到任何数据，请稍后再试。")
                    }
                    completion?(false, "更新检查失败", "未接收到数据", nil)
                }
                return
            }
            
            // 解析JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let tagName = json["tag_name"] as? String {
                    
                    // 修复：移除 if let 条件绑定，因为 replacingOccurrences 返回非可选类型
                    let remoteVersion = tagName.replacingOccurrences(of: "v", with: "")
                    
                    if let assets = json["assets"] as? [[String: Any]] {
                        let body = json["body"] as? String ?? "暂无更新说明"
                        
                        // 寻找macOS版本的资产
                        var downloadURL: URL? = nil
                        for asset in assets {
                            if let name = asset["name"] as? String,
                               name.lowercased().contains("macos") || name.lowercased().contains("mac") || name.hasSuffix(".dmg") || name.hasSuffix(".zip"),
                               let urlString = asset["browser_download_url"] as? String,
                               let url = URL(string: urlString) {
                                downloadURL = url
                                break
                            }
                        }
                        
                        // 如果没有找到直接下载链接，使用发布页面链接
                        if downloadURL == nil, let htmlURL = json["html_url"] as? String, let url = URL(string: htmlURL) {
                            downloadURL = url
                        }
                        
                        guard let finalDownloadURL = downloadURL else {
                            throw NSError(domain: "UpdateCheckerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法找到下载链接"])
                        }
                        
                        // 比较版本号
                        let shouldUpdate = self.compareVersions(self.currentVersion, remoteVersion)
                        
                        print("当前版本: \(self.currentVersion), 远程版本: \(remoteVersion), 需要更新: \(shouldUpdate)")
                        
                        DispatchQueue.main.async {
                            if shouldUpdate {
                                // 检测到新版本
                                if !silent {
                                    self.showUpdateAlert(
                                        title: "发现新版本",
                                        message: "当前版本: \(self.currentVersion)\n最新版本: \(remoteVersion)\n\n更新内容:\n\(body)",
                                        downloadURL: finalDownloadURL
                                    )
                                }
                                completion?(true, remoteVersion, body, finalDownloadURL)
                            } else {
                                // 已经是最新版本
                                if !silent {
                                    self.showUpdateAlert(title: "已是最新版本", message: "您当前使用的 FishPaste（版本 \(self.currentVersion)）已是最新版本。")
                                }
                                completion?(false, self.currentVersion, "已是最新版本", nil)
                            }
                        }
                    } else {
                        throw NSError(domain: "UpdateCheckerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法解析资源信息"])
                    }
                } else {
                    throw NSError(domain: "UpdateCheckerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法解析版本信息"])
                }
            } catch {
                print("解析更新数据失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if !silent {
                        self.showUpdateAlert(title: "更新检查失败", message: "无法解析服务器数据，请稍后再试。\n错误: \(error.localizedDescription)")
                    }
                    completion?(false, "更新检查失败", error.localizedDescription, nil)
                }
            }
        }
        
        task.resume()
    }
    
    // 版本比较函数
    private func compareVersions(_ current: String, _ remote: String) -> Bool {
        let currentComponents = current.components(separatedBy: ".").compactMap { Int($0) }
        let remoteComponents = remote.components(separatedBy: ".").compactMap { Int($0) }
        
        // 确保有效的版本号
        guard !currentComponents.isEmpty, !remoteComponents.isEmpty else {
            return false
        }
        
        // 比较主要版本号
        for i in 0..<min(currentComponents.count, remoteComponents.count) {
            if remoteComponents[i] > currentComponents[i] {
                return true // 远程版本较新
            } else if remoteComponents[i] < currentComponents[i] {
                return false // 当前版本较新或相同
            }
        }
        
        // 如果所有共同的部分都相同，但远程版本有更多的组件
        return remoteComponents.count > currentComponents.count
    }
    
    // 显示更新提示对话框
    private func showUpdateAlert(title: String, message: String, downloadURL: URL? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        
        if let downloadURL = downloadURL {
            alert.addButton(withTitle: "立即更新")
            alert.addButton(withTitle: "稍后提醒")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 用户选择立即更新
                if downloadURL.absoluteString.hasSuffix(".dmg") || downloadURL.absoluteString.hasSuffix(".zip") {
                    // 直接下载安装包
                    downloadUpdate(from: downloadURL)
                } else {
                    // 打开网页下载
                    NSWorkspace.shared.open(downloadURL)
                }
            }
        } else {
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    // 下载更新文件
    private func downloadUpdate(from url: URL) {
        // 创建下载会话
        let session = URLSession(configuration: .default)
        
        // 创建下载任务
        downloadTask = session.downloadTask(with: url) { (tempURL, response, error) in
            // 清理进度监视器
            self.progressObserver?.invalidate()
            self.progressObserver = nil
            self.downloadProgress = nil
            
            // 处理错误
            if let error = error {
                print("下载更新失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showUpdateAlert(title: "更新下载失败", message: "无法下载更新文件，请稍后再试或访问官网手动下载。\n错误: \(error.localizedDescription)")
                }
                return
            }
            
            // 确保我们有临时文件
            guard let tempURL = tempURL else {
                print("下载更新失败: 未获得临时文件")
                return
            }
            
            // 确保我们有响应并可以获取MIME类型
            guard let response = response as? HTTPURLResponse,
                  let mimeType = response.mimeType else {
                print("下载更新失败: 无效的响应")
                return
            }
            
            // 确保文件类型正确
            let isZip = mimeType.contains("zip") || url.absoluteString.hasSuffix(".zip")
            let isDmg = mimeType.contains("dmg") || url.absoluteString.hasSuffix(".dmg")
            
            if !isZip && !isDmg {
                print("下载更新失败: 不支持的文件类型 - \(mimeType)")
                return
            }
            
            // 创建目标文件路径
            let fileName = url.lastPathComponent
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let destinationURL = downloadsURL.appendingPathComponent(fileName)
            
            // 如果已存在，则移除旧文件
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                do {
                    try FileManager.default.removeItem(at: destinationURL)
                } catch {
                    print("无法移除现有文件: \(error.localizedDescription)")
                }
            }
            
            // 移动临时文件到下载文件夹
            do {
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                print("更新文件下载完成: \(destinationURL.path)")
                
                // 在主线程中显示提示并打开文件
                DispatchQueue.main.async {
                    // 显示成功通知
                    let notification = NSUserNotification()
                    notification.title = "下载完成"
                    notification.informativeText = "FishPaste更新已下载完成，点击安装"
                    notification.soundName = NSUserNotificationDefaultSoundName
                    notification.hasActionButton = true
                    notification.actionButtonTitle = "安装"
                    
                    NSUserNotificationCenter.default.deliver(notification)
                    
                    // 设置通知处理程序
                    NSUserNotificationCenter.default.delegate = NSUserNotificationCenter.default.delegate ?? self as? NSUserNotificationCenterDelegate
                    
                    // 打开包含更新文件的文件夹
                    NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: "")
                    
                    // 如果是dmg文件，直接打开
                    if isDmg {
                        NSWorkspace.shared.open(destinationURL)
                    }
                }
            } catch {
                print("无法保存下载文件: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showUpdateAlert(title: "更新保存失败", message: "无法保存更新文件到下载文件夹，请稍后再试或访问官网手动下载。\n错误: \(error.localizedDescription)")
                }
            }
        }
        
        // 创建进度跟踪
        downloadProgress = Progress(totalUnitCount: 1)
        progressObserver = downloadProgress?.observe(\.fractionCompleted, options: [.new]) { progress, _ in
            // 更新UI进度指示
            print("下载进度: \(Int(progress.fractionCompleted * 100))%")
            
            // 这里可以更新UI上的进度条
            DispatchQueue.main.async {
                // 可以在这里更新进度条UI
            }
        }
        
        // 开始下载
        downloadTask?.resume()
        
        // 显示下载开始通知
        let notification = NSUserNotification()
        notification.title = "开始下载更新"
        notification.informativeText = "FishPaste正在下载最新版本，下载完成后将通知您"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
} 