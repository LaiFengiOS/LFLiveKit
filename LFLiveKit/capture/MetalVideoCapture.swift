//
//  MetalVideoCapture.swift
//  LFLiveKit
//
//  Created by finn on 2021/11/29.
//

import Foundation
import MetalPetal
import VideoIO

@objcMembers
public class MetalVideoCapture: NSObject, LFVideoCaptureInterface {
    public var running: Bool = true
    public weak var delegate: LFVideoCaptureInterfaceDelegate?

    public var captureDevicePosition: AVCaptureDevice.Position = .front {
        didSet {
            try? camera.switchToVideoCaptureDevice(with: captureDevicePosition)
        }
    }
    
    public var beautyFace: Bool = true
    public var torch: Bool = false
    public var mirror: Bool = true
    public var zoomScale: CGFloat = 1.0
    public var videoFrameRate: Int = 60
    public var watermarkView: UIView? = nil
    public var currentImage: UIImage? = nil
    public var saveLocalVideo: Bool = false
    public var saveLocalVideoPath: URL? = nil
    public var currentColorFilterName: String? = nil
    public var currentColorFilterIndex: Int = 0
    public var colorFilterNames: [String]? = nil
    public var mirrorOutput: Bool = true

    private let configuration: LFLiveVideoConfiguration?
    private let metalView: MTIImageView = MTIImageView()
    private let filter = MTIHighPassSkinSmoothingFilter()
    private let imageRenderer = PixelBufferPoolBackedImageRenderer()
    private let renderContext: MTIContext

    private let camera: Camera = {
        var configurator = Camera.Configurator()
        configurator.videoConnectionConfigurator = { camera, connection in
            connection.videoOrientation = .portrait
        }
        return Camera(captureSessionPreset: .hd1280x720, defaultCameraPosition: .front, configurator: configurator)
    }()
    
    
    @objc
    public required init?(videoConfiguration configuration: LFLiveVideoConfiguration?) {
        
        guard let device = MTLCreateSystemDefaultDevice(), let context = try? MTIContext(device: device) else { return nil }
        renderContext = context
        self.configuration = configuration
        super.init()
        metalView.resizingMode = .aspectFill

        setupCamera()
    }
    
    deinit {
        camera.stopRunningCaptureSession()
    }
    
    public func previousColorFilter() {}
    
    public func nextColorFilter() {}
    
    public func setTargetColorFilter(_ targetIndex: Int) {}

    
    private func setupCamera() {
        try? camera.enableVideoDataOutput(on: DispatchQueue.main, delegate: self)
        camera.videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        
        camera.startRunningCaptureSession()
        
    }
}

extension MetalVideoCapture {
    public var preView: UIView! {
        @objc(preView) get {
            return metalView.superview
        }
        set {
            if metalView.superview != nil {
                metalView.removeFromSuperview()
            }
            metalView.frame = newValue.frame
            newValue.insertSubview(metalView, at: 0)
        }
    }

}

extension MetalVideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let sourceImage = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .alphaIsOne)
        guard let filteredImage = filterImageIfNeeded(sourceImage) else { return }
        let mirroredImage = mirroredIfNeeded(filteredImage)

        metalView.image = mirroredImage

        guard let renderOutput = try? self.imageRenderer.render(mirroredImage, using: renderContext) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        delegate?.captureOutput?(self, pixelBuffer: renderOutput.pixelBuffer, at: time, didUpdateVideoConfiguration: false)

    }
    
    private func filterImageIfNeeded(_ image: MTIImage) -> MTIImage? {
        guard beautyFace else { return image }
        filter.inputImage = image
        return filter.outputImage
    }
    
    private func mirroredIfNeeded(_ image: MTIImage) -> MTIImage {
        guard captureDevicePosition == .front else { return image }
        return image.oriented(.upMirrored)
    }
}
