//
//  StatusItemAnimator.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import Cocoa
import AppKit
import Foundation

class StatusItemAnimator {
    // 单例模式
    static let shared = StatusItemAnimator()
    
    // 主菜单栏图标的引用尝试
    private var menuBarButton: NSStatusBarButton? = nil
    
    // 创建一个实际使用的状态栏图标
    private var statusItem: NSStatusItem?
    
    // 原始图标
    private var originalImage: NSImage?
    
    // 动画计时器
    private var animationTimer: Timer?
    
    // 动画帧计数
    private var animationFrame: Int = 0
    private let totalFrames: Int = 12
    
    // 初始化方法
    private init() {
        // 注册通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardChange),
            name: Notification.Name("ClipboardContentChanged"),
            object: nil
        )
        
        // 应用启动后延迟一段时间查找菜单图标
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.setupStatusItem()
        }
        
        // 创建备用动画图标
        setupBackupStatusItem()
    }
    
    private func setupStatusItem() {
        // 尝试查找主菜单栏中的图标
        if let mainMenuBar = NSApp.mainMenu {
            // 打印一些调试信息
            print("查找菜单栏图标：\(NSApp.windows.count) 个窗口")
            
            for window in NSApp.windows {
                print("窗口标题: \(window.title), 类型: \(type(of: window))")
                
                if window.title.contains("StatusBarWindow") || 
                   String(describing: type(of: window)).contains("StatusBar") {
                    findMenuBarButtonInWindow(window)
                }
            }
        }
    }
    
    private func findMenuBarButtonInWindow(_ window: NSWindow) {
        // 尝试在窗口中查找状态栏按钮
        if let contentView = window.contentView {
            print("查找窗口内容视图中的按钮：\(contentView)")
            findStatusBarButtonInView(contentView)
        }
    }
    
    private func findStatusBarButtonInView(_ view: NSView) {
        // 检查当前视图是否是状态栏按钮
        if let button = view as? NSStatusBarButton {
            print("找到状态栏按钮：\(button)")
            
            // 获取并保存原始图像
            if let image = button.image {
                self.menuBarButton = button
                self.originalImage = image
                
                print("成功找到并保存菜单栏图标")
            }
        }
        
        // 递归查找所有子视图
        for subview in view.subviews {
            findStatusBarButtonInView(subview)
        }
    }
    
    // 创建备用状态栏图标(隐藏)
    private func setupBackupStatusItem() {
        // 移除额外的状态栏项目创建，仅在初始化时准备好动画资源
        print("StatusItemAnimator: 准备动画资源")
        
        // 使用系统符号图像作为备用原始图像
        if originalImage == nil {
            originalImage = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "FishCopy")
        }
        
        // 尝试查找主状态栏图标
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupStatusItem()
        }
    }
    
    // 处理剪贴板变化通知
    @objc private func handleClipboardChange(_ notification: Notification) {
        print("收到剪贴板变化通知")
        performRotationAnimation()
    }
    
    // 执行旋转动画
    func performRotationAnimation() {
        print("开始执行旋转动画")
        
        // 如果已经在执行动画，先停止
        stopAnimation()
        
        // 重置动画帧
        animationFrame = 0
        
        // 检查是否有可用的菜单栏按钮
        if menuBarButton == nil {
            print("找不到菜单栏按钮，尝试重新查找...")
            setupStatusItem()
        }
        
        // 保存原始图像(如果尚未保存)
        if originalImage == nil && menuBarButton?.image != nil {
            originalImage = menuBarButton?.image
            print("保存菜单栏原始图像")
        }
        
        // 确保有要旋转的图像
        if originalImage == nil {
            print("无法找到原始图像，取消动画")
            return
        }
        
        print("使用主菜单栏图标执行动画")
        
        // 创建动画定时器
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.updateAnimationFrame()
        }
    }
    
    // 更新动画帧
    private func updateAnimationFrame(useBackupIcon: Bool = false) {
        guard let originalImage = originalImage else {
            print("没有原始图像，无法执行动画")
            stopAnimation()
            return
        }
        
        // 确保有菜单栏按钮
        guard let menuButton = menuBarButton else {
            print("没有找到菜单栏按钮，无法执行动画")
            stopAnimation()
            return
        }
        
        // 增加帧计数
        animationFrame += 1
        
        // 计算当前旋转角度
        let angle = 2.0 * .pi * CGFloat(animationFrame) / CGFloat(totalFrames)
        
        // 创建旋转的图像
        let rotatedImage = rotateImage(originalImage, byRadians: angle)
        
        // 更新状态栏图标
        menuButton.image = rotatedImage
        
        // 检查动画是否完成
        if animationFrame >= totalFrames {
            stopAnimation()
            
            // 恢复原始图标
            menuButton.image = originalImage
            
            print("动画完成")
        }
    }
    
    // 停止动画
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        // 恢复原始图标
        if let originalImage = originalImage, let menuButton = menuBarButton {
            menuButton.image = originalImage
        }
    }
    
    // 旋转图像
    private func rotateImage(_ image: NSImage, byRadians radians: CGFloat) -> NSImage {
        let size = image.size
        let newImage = NSImage(size: size)
        
        newImage.lockFocus()
        
        // 移动原点到中心
        NSGraphicsContext.current?.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
        
        // 应用旋转
        NSGraphicsContext.current?.cgContext.rotate(by: radians)
        
        // 绘制图像
        image.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2),
                  from: NSRect(x: 0, y: 0, width: size.width, height: size.height),
                  operation: .sourceOver,
                  fraction: 1.0)
        
        newImage.unlockFocus()
        
        return newImage
    }
} 