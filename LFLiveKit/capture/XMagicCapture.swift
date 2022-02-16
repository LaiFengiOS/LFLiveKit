//
//  XMagicCapture.swift
//  LFLiveKit
//
//  Created by finn on 2022/2/14.
//

import Foundation
import XMagicKit

@objcMembers
public class XMagicCapture: NSObject, LFVideoCaptureInterface {

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

    
    public var delegate: LFVideoCaptureInterfaceDelegate?
    
    public var running: Bool = true
    public var captureDevicePosition: AVCaptureDevice.Position = .front
    private let configuration: LFLiveVideoConfiguration?
    
    private let capture: XMagicCameraCapture = XMagicCameraCapture()
    public func previousColorFilter() {
        
    }
    
    public func nextColorFilter() {
        
    }
    
    public func setTargetColorFilter(_ targetIndex: Int) {
        
    }
    
    public required init?(videoConfiguration configuration: LFLiveVideoConfiguration?) {
        self.configuration = configuration
        super.init()
        
        LicenseManager.sharedInstance().setup()
        displayView.layer.insertSublayer(capture.previewLayer, at: 0)
        capture.startCaputre()
    }
    
    private var displayView = UIView()

    
}

extension XMagicCapture {
    public var preView: UIView! {
        @objc(preView) get {
            return displayView.superview
        }
        set {
            if displayView.superview != nil {
                displayView.removeFromSuperview()
            }
            displayView.frame = newValue.frame
            newValue.insertSubview(displayView, at: 0)
        }
    }

}
