//
//  ViewController.swift
//  LFLiveKitSwiftDemo
//
//  Created by feng on 16/7/19.
//  Copyright © 2016年 zhanqi.tv. All rights reserved.
//

import UIKit
import LFLiveKit

class ViewController: UIViewController, LFLiveSessionDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.requestAccessForVideo()
        self.requestAccessForAudio()
        self.view.backgroundColor = UIColor.clear
        self.view.addSubview(containerView)
        containerView.addSubview(stateLabel)
        containerView.addSubview(closeButton)
        containerView.addSubview(beautyButton)
        containerView.addSubview(cameraButton)
        containerView.addSubview(startLiveButton)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: AccessAuth
    
    func requestAccessForVideo() -> Void {
        let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch status  {
        // 许可对话没有出现，发起授权许可
        case AVAuthorizationStatus.NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted) in
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.session.running = true;
                    });
                }
            })
            break;
        // 已经开启授权，可继续
        case AVAuthorizationStatus.Authorized:
            session.running = true;
            break;
        // 用户明确地拒绝授权，或者相机设备无法访问
        case AVAuthorizationStatus.Denied: break
        case AVAuthorizationStatus.Restricted:break;
        default:
            break;
        }
    }
    
    func requestAccessForAudio() -> Void {
        let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeAudio)
        switch status  {
        // 许可对话没有出现，发起授权许可
        case AVAuthorizationStatus.NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio, completionHandler: { (granted) in
            })
            break;
        // 已经开启授权，可继续
        case AVAuthorizationStatus.Authorized:
            break;
        // 用户明确地拒绝授权，或者相机设备无法访问
        case AVAuthorizationStatus.Denied: break
        case AVAuthorizationStatus.Restricted:break;
        default:
            break;
        }
    }
    
    //MARK: - Callbacks
    
    // 回调
    func liveSession(_ session: LFLiveSession?, debugInfo: LFLiveDebug?) {
        print("debugInfo: \(debugInfo?.currentBandwidth)")
    }
    
    func liveSession(_ session: LFLiveSession?, errorCode: LFLiveSocketErrorCode) {
        print("errorCode: \(errorCode.rawValue)")
    }
    
    func liveSession(_ session: LFLiveSession?, liveStateDidChange state: LFLiveState) {
        print("liveStateDidChange: \(state.rawValue)")
        switch state {
        case LFLiveState.Ready:
            stateLabel.text = "未连接"
            break;
        case LFLiveState.Pending:
            stateLabel.text = "连接中"
            break;
        case LFLiveState.Start:
            stateLabel.text = "已连接"
            break;
        case LFLiveState.Error:
            stateLabel.text = "连接错误"
            break;
        case LFLiveState.Stop:
            stateLabel.text = "未连接"
            break;
        }
    }
    
    //MARK: - Events
    
    // 开始直播
    func didTappedStartLiveButton(_ button: UIButton) -> Void {
        startLiveButton.isSelected = !startLiveButton.isSelected;
        if (startLiveButton.isSelected) {
            startLiveButton.setTitle("结束直播", for: UIControlState())
            let stream = LFLiveStreamInfo()
            stream.url = "rtmp://live.hkstv.hk.lxdns.com:1935/live/stream153"
            session.startLive(stream)
        } else {
            startLiveButton.setTitle("开始直播", for: UIControlState())
            session.stopLive()
        }
    }
    
    // 美颜
    func didTappedBeautyButton(_ button: UIButton) -> Void {
        session.beautyFace = !session.beautyFace;
        beautyButton.selected = !session.beautyFace;
    }
    
    // 摄像头
    func didTappedCameraButton(_ button: UIButton) -> Void {
        let devicePositon = session.captureDevicePosition;
        session.captureDevicePosition = (devicePositon == AVCaptureDevicePosition.Back) ? AVCaptureDevicePosition.Front : AVCaptureDevicePosition.Back;
    }
    
    // 关闭
    func didTappedCloseButton(_ button: UIButton) -> Void  {
        
    }
    
    //MARK: - Getters and Setters
    
    //  默认分辨率368 ＊ 640  音频：44.1 iphone6以上48  双声道  方向竖屏
    lazy var session: LFLiveSession = {
        let audioConfiguration = LFLiveAudioConfiguration.defaultConfiguration()
        let videoConfiguration = LFLiveVideoConfiguration.defaultConfigurationForQuality(LFLiveVideoQuality.Low3)
        let session = LFLiveSession(audioConfiguration: audioConfiguration, videoConfiguration: videoConfiguration)
        
        session?.delegate = self
        session?.preView = self.view
        return session!
    }()
    
    // 视图
    lazy var containerView: UIView = {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
        containerView.backgroundColor = UIColor.clear
        containerView.autoresizingMask = [UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleHeight]
        return containerView
    }()
    
    // 状态Label
    lazy var stateLabel: UILabel = {
        let stateLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 80, height: 40))
        stateLabel.text = "未连接"
        stateLabel.textColor = UIColor.white
        stateLabel.font = UIFont.systemFont(ofSize: 14)
        return stateLabel
    }()
    
    // 关闭按钮
    lazy var closeButton: UIButton = {
        let closeButton = UIButton(frame: CGRect(x: self.view.frame.width - 10 - 44, y: 20, width: 44, height: 44))
        closeButton.setImage(UIImage(named: "close_preview"), for: UIControlState())
        closeButton.addTarget(self, action: #selector(didTappedCloseButton(_:)), for: UIControlEvents.touchUpInside)
        return closeButton
    }()
    
    // 摄像头
    lazy var cameraButton: UIButton = {
        let cameraButton = UIButton(frame: CGRect(x: self.view.frame.width - 54 * 2, y: 20, width: 44, height: 44))
        cameraButton.setImage(UIImage(named: "camra_preview"), for: UIControlState())
        cameraButton.addTarget(self, action: #selector(didTappedCameraButton(_:)), for: UIControlEvents.touchUpInside)
        return cameraButton
    }()
    
    // 摄像头
    lazy var beautyButton: UIButton = {
        let beautyButton = UIButton(frame: CGRect(x: self.view.frame.width - 54 * 3, y: 20, width: 44, height: 44))
        beautyButton.setImage(UIImage(named: "camra_preview"), for: UIControlState.selected)
        beautyButton.setImage(UIImage(named: "camra_beauty_close"), for: UIControlState())
        beautyButton.addTarget(self, action: #selector(didTappedBeautyButton(_:)), for: UIControlEvents.touchUpInside)
        return beautyButton
    }()
    
    // 开始直播按钮
    lazy var startLiveButton: UIButton = {
        let startLiveButton = UIButton(frame: CGRect(x: 30, y: self.view.frame.height - 50, width: self.view.frame.width - 10 - 44, height: 44))
        startLiveButton.layer.cornerRadius = 22
        startLiveButton.setTitleColor(UIColor.black, for:UIControlState())
        startLiveButton.setTitle("开始直播", for: UIControlState())
        startLiveButton.titleLabel!.font = UIFont.systemFont(ofSize: 14)
        startLiveButton.backgroundColor = UIColor(colorLiteralRed: 50, green: 32, blue: 245, alpha: 1)
        startLiveButton.addTarget(self, action: #selector(didTappedStartLiveButton(_:)), for: UIControlEvents.touchUpInside)
        return startLiveButton
    }()
    
    // 转屏
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override var shouldAutorotate : Bool {
        return true
    }
}

