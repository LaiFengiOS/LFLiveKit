
[![Build Status](https://travis-ci.org/LaiFengiOS/LFLiveKit.svg)](https://travis-ci.org/LaiFengiOS/LFLiveKit)&nbsp;
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://raw.githubusercontent.com/chenliming777/LFLiveKit/master/LICENSE)&nbsp;
[![CocoaPods](http://img.shields.io/cocoapods/v/LFLiveKit.svg?style=flat)](http://cocoapods.org/?q=LFLiveKit)&nbsp;
[![Support](https://img.shields.io/badge/support-ios8%2B-orange.svg)](https://www.apple.com/nl/ios/)&nbsp;

![platform](https://img.shields.io/badge/platform-ios-ff69b4.svg)&nbsp;

LFLiveKit

	LFLiveKit IOS mobile phone push code，Default format support RTMP and FLV，At the same time, the structure is very easy to extend.

Podfile
	To integrate LFLiveKit into your Xcode project using CocoaPods, specify it in your Podfile:
	
	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '8.0'
	pod 'LFLiveKit'
	
	Then, run the following command:
	$ pod install


Functional

	Background recording
	Support horizontal vertical recording
	GPUImage Beauty
	H264 Hard coding
	AAC Hard coding
	Weak network lost frame
	Dynamic switching rate
	Audio configuration
	Video configuration
	RTMP Transport
	Switch camera
	Audio Mute
	Support Send Buffer
	FLV package and send
  

Architecture

	capture: LFAudioCapture and  LFVideoCapture
	encode:  LFHardwareAudioEncoder and LFHardwareVideoEncoder
	publish: LFStreamRtmpSocket LFStreamTcpSocket
	
Usage
	
	- (LFLiveSession*)session{
    if(!_session){
_session = [[LFLiveSession alloc] initWithAudioConfiguration:[LFLiveAudioConfiguration defaultConfiguration] videoConfiguration:[LFLiveVideoConfiguration defaultConfiguration] liveType:LFLiveRTMP];
        _session.running = YES;
        _session.preView = self;
    }
    return _session;
	}
	
	- (LFLiveSession*)session{
    if(!_session){
        LFLiveAudioConfiguration *audioConfiguration = [LFLiveAudioConfiguration new];
         audioConfiguration.numberOfChannels = 2;
         audioConfiguration.audioBitrate = LFLiveAudioBitRate_128Kbps;
         audioConfiguration.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
         
         LFLiveVideoConfiguration *videoConfiguration = [LFLiveVideoConfiguration new];
         videoConfiguration.videoSize = CGSizeMake(1280, 720);
         videoConfiguration.videoBitRate = 800*1024;
         videoConfiguration.videoMaxBitRate = 1000*1024;
         videoConfiguration.videoMinBitRate = 500*1024;
         videoConfiguration.videoFrameRate = 15;
         videoConfiguration.videoMaxKeyframeInterval = 30;
         videoConfiguration.orientation = UIInterfaceOrientationLandscapeLeft;
         videoConfiguration.sessionPreset = LFCaptureSessionPreset720x1280;
         
         _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfiguration 				videoConfiguration:videoConfiguration liveType:LFLiveRTMP];
        _session.running = YES;
        _session.preView = self;
    }
    return _session;
	}
	
	LFLiveStreamInfo *streamInfo = [LFLiveStreamInfo new];
	streamInfo.url = @"your server rtmp url";
	[self.session startLive:streamInfo];
	[self.session stopLive];
	
	CallBack:
	- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange: (LFLiveState)state;
	- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug*)debugInfo;
	- (void)liveSession:(nullable LFLiveSession*)session errorCode:(LFLiveSocketErrorCode)errorCode;
	
 License
 
 	LFLiveKit is released under the MIT license. See LICENSE for details.
	






