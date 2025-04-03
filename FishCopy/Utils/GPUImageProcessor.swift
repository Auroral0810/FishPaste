//
//  GPUImageProcessor.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/05.
//

import Foundation
import AppKit
import CoreImage
import Metal

/// GPU图像处理工具类
/// 负责使用GPU加速处理图像相关操作
class GPUImageProcessor {
    // 单例模式
    static let shared = GPUImageProcessor()
    
    // GPU处理上下文
    private var ciContext: CIContext?
    private var metalDevice: MTLDevice?
    
    // 是否支持GPU加速
    private(set) var supportsGPUAcceleration: Bool = false
    
    // 是否启用了GPU加速
    var isGPUAccelerationEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "useGPUAcceleration")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useGPUAcceleration")
            // 如果开启了GPU加速，确保初始化处理上下文
            if newValue {
                setupGPUContext()
            }
        }
    }
    
    // 私有初始化方法
    private init() {
        // 检查是否支持GPU加速
        checkGPUSupport()
        
        // 如果已开启GPU加速，初始化上下文
        if isGPUAccelerationEnabled {
            setupGPUContext()
        }
    }
    
    // 检查GPU支持情况
    private func checkGPUSupport() {
        // 检查Metal设备是否可用
        if let device = MTLCreateSystemDefaultDevice() {
            metalDevice = device
            supportsGPUAcceleration = true
            print("支持GPU加速: \(device.name)")
        } else {
            supportsGPUAcceleration = false
            print("不支持GPU加速")
        }
    }
    
    // 设置GPU处理上下文
    private func setupGPUContext() {
        guard supportsGPUAcceleration else {
            print("不支持GPU加速，无法设置上下文")
            return
        }
        
        // 如果上下文已存在，不重复创建
        if ciContext != nil {
            return
        }
        
        // 创建基于Metal的CIContext
        if let device = metalDevice {
            let options = [CIContextOption.useSoftwareRenderer: false,
                           CIContextOption.priorityRequestLow: false]
            ciContext = CIContext(mtlDevice: device, options: options)
            print("已创建基于Metal的CIContext")
        } else {
            // 创建基于软件渲染的CIContext作为备用
            ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: true])
            print("已创建基于软件渲染的CIContext")
        }
    }
    
    // 处理图像 - 根据设置决定是否使用GPU加速
    func processImage(_ image: NSImage, operation: ImageOperation) -> NSImage {
        if isGPUAccelerationEnabled && supportsGPUAcceleration {
            return processImageWithGPU(image, operation: operation)
        } else {
            return processImageWithCPU(image, operation: operation)
        }
    }
    
    // 使用GPU处理图像
    private func processImageWithGPU(_ image: NSImage, operation: ImageOperation) -> NSImage {
        // 确保已初始化GPU上下文
        if ciContext == nil {
            setupGPUContext()
        }
        
        guard let ciContext = ciContext else {
            print("GPU上下文不可用，回退到CPU处理")
            return processImageWithCPU(image, operation: operation)
        }
        
        // 转换NSImage为CIImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("无法获取CGImage，回退到CPU处理")
            return processImageWithCPU(image, operation: operation)
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // 应用操作
        let processedCIImage: CIImage
        
        switch operation {
        case .resize(let targetSize):
            let scale = min(targetSize.width / ciImage.extent.width, 
                           targetSize.height / ciImage.extent.height)
            processedCIImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
        case .rotate(let angle):
            processedCIImage = ciImage.transformed(by: CGAffineTransform(rotationAngle: angle))
            
        case .crop(let rect):
            processedCIImage = ciImage.cropped(to: rect)
            
        case .filter(let filterName, let parameters):
            if let filter = CIFilter(name: filterName) {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                
                // 应用额外参数
                for (key, value) in parameters {
                    filter.setValue(value, forKey: key)
                }
                
                if let output = filter.outputImage {
                    processedCIImage = output
                } else {
                    return image
                }
            } else {
                return image
            }
        }
        
        // 从CIImage转回NSImage
        if let cgImage = ciContext.createCGImage(processedCIImage, from: processedCIImage.extent) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            return nsImage
        }
        
        return image
    }
    
    // 使用CPU处理图像
    private func processImageWithCPU(_ image: NSImage, operation: ImageOperation) -> NSImage {
        // 创建处理图像的副本
        let processedImage = NSImage(size: image.size)
        
        switch operation {
        case .resize(let targetSize):
            // 创建新尺寸的图像
            let newImage = NSImage(size: targetSize)
            newImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: targetSize), 
                     from: NSRect(origin: .zero, size: image.size),
                     operation: .copy, fraction: 1.0)
            newImage.unlockFocus()
            return newImage
            
        case .rotate(let angle):
            processedImage.lockFocus()
            
            // 移动原点到中心
            let context = NSGraphicsContext.current?.cgContext
            context?.translateBy(x: image.size.width / 2, y: image.size.height / 2)
            
            // 旋转
            context?.rotate(by: angle)
            
            // 绘制图像
            image.draw(at: NSPoint(x: -image.size.width / 2, y: -image.size.height / 2),
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .copy, fraction: 1.0)
            
            processedImage.unlockFocus()
            return processedImage
            
        case .crop(let rect):
            // 确保剪裁区域在图像范围内
            let validRect = NSRect(x: max(0, rect.origin.x),
                                 y: max(0, rect.origin.y),
                                 width: min(rect.width, image.size.width - rect.origin.x),
                                 height: min(rect.height, image.size.height - rect.origin.y))
            
            let newImage = NSImage(size: validRect.size)
            newImage.lockFocus()
            image.draw(at: .zero, 
                     from: validRect,
                     operation: .copy, fraction: 1.0)
            newImage.unlockFocus()
            return newImage
            
        case .filter(let filterName, let parameters):
            // 简单的滤镜效果，真实实现会更复杂
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let ciImage = CIImage(cgImage: cgImage)
                
                if let filter = CIFilter(name: filterName) {
                    filter.setValue(ciImage, forKey: kCIInputImageKey)
                    
                    // 应用额外参数
                    for (key, value) in parameters {
                        filter.setValue(value, forKey: key)
                    }
                    
                    if let output = filter.outputImage {
                        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: true])
                        if let cgImage = context.createCGImage(output, from: output.extent) {
                            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                            return nsImage
                        }
                    }
                }
            }
            return image
        }
    }
    
    // 图像操作枚举
    enum ImageOperation {
        case resize(targetSize: NSSize)
        case rotate(angle: CGFloat)
        case crop(rect: CGRect)
        case filter(name: String, parameters: [String: Any])
    }
}

// 便捷扩展，为NSImage添加GPU加速处理方法
extension NSImage {
    // 使用GPU加速调整大小
    func resizedWithGPU(to newSize: NSSize) -> NSImage {
        return GPUImageProcessor.shared.processImage(self, operation: .resize(targetSize: newSize))
    }
    
    // 使用GPU加速旋转
    func rotatedWithGPU(byAngle angle: CGFloat) -> NSImage {
        return GPUImageProcessor.shared.processImage(self, operation: .rotate(angle: angle))
    }
    
    // 使用GPU加速裁剪
    func croppedWithGPU(to rect: CGRect) -> NSImage {
        return GPUImageProcessor.shared.processImage(self, operation: .crop(rect: rect))
    }
    
    // 使用GPU加速应用滤镜
    func filteredWithGPU(filterName: String, parameters: [String: Any] = [:]) -> NSImage {
        return GPUImageProcessor.shared.processImage(self, operation: .filter(name: filterName, parameters: parameters))
    }
} 