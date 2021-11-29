//
//  PixelBufferPoolBackedImageRenderer.swift
//  LFLiveKit
//
//  Created by finn on 2021/11/29.
//

import Foundation
import MetalPetal
import VideoToolbox

class PixelBufferPoolBackedImageRenderer {
    private var pixelBufferPool: MTICVPixelBufferPool?
    private let renderSemaphore: DispatchSemaphore

    init(renderTaskQueueCapacity: Int = 3) {
        renderSemaphore = DispatchSemaphore(value: renderTaskQueueCapacity)
    }

    func render(_ image: MTIImage, using context: MTIContext) throws -> (pixelBuffer: CVPixelBuffer, cgImage: CGImage) {
        let pixelBufferPool: MTICVPixelBufferPool
        if let pool = self.pixelBufferPool, pool.pixelBufferWidth == image.dimensions.width, pool.pixelBufferHeight == image.dimensions.height {
            pixelBufferPool = pool
        } else {
            pixelBufferPool = try MTICVPixelBufferPool(pixelBufferWidth: Int(image.dimensions.width), pixelBufferHeight: Int(image.dimensions.height), pixelFormatType: kCVPixelFormatType_32BGRA, minimumBufferCount: 30)
            self.pixelBufferPool = pixelBufferPool
        }
        let pixelBuffer = try pixelBufferPool.makePixelBuffer(allocationThreshold: 30)

        renderSemaphore.wait()
        do {
            try context.startTask(toRender: image, to: pixelBuffer, sRGB: false, completion: { _ in
                self.renderSemaphore.signal()
            })
        } catch {
            renderSemaphore.signal()
            throw error
        }

        var cgImage: CGImage!
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        return (pixelBuffer, cgImage)
    }
}
