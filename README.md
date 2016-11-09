LFLiveKit
==============
![icon~](https://raw.github.com/LaiFengiOS/LFLiveKit/master/samples/Icon.png)


[![Build Status](https://travis-ci.org/LaiFengiOS/LFLiveKit.svg)](https://travis-ci.org/LaiFengiOS/LFLiveKit)&nbsp;
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://raw.githubusercontent.com/chenliming777/LFLiveKit/master/LICENSE)&nbsp;
[![CocoaPods](http://img.shields.io/cocoapods/v/LFLiveKit.svg?style=flat)](http://cocoapods.org/?q=LFLiveKit)&nbsp;
[![Support](https://img.shields.io/badge/ios-7-orange.svg)](https://www.apple.com/nl/ios/)&nbsp;
![platform](https://img.shields.io/badge/platform-ios-ff69b4.svg)&nbsp;


**LFLiveKit is a opensource RTMP streaming SDK for iOS.**  

## Features

- [x] 	Background recording
- [x] 	Support horizontal vertical recording
- [x] 	Support Beauty Face With GPUImage
- [x] 	Support H264+AAC Hardware Encoding
- [x] 	Drop frames on bad network 
- [x] 	Dynamic switching rate
- [x] 	Audio configuration
- [x] 	Video configuration
- [x] 	RTMP Transport
- [x] 	Switch camera position
- [x] 	Audio Mute
- [x] 	Support Send Buffer
- [x] 	Support WaterMark
- [x] 	Swift Support
- [x] 	Support Single Video or Audio 
- [x] 	Support External input video or audio(Screen recording or Peripheral)
- [ ] 	~~FLV package and send~~

## Requirements
    - iOS 7.0+
    - Xcode 7.3
  
## Installation

#### CocoaPods
	# To integrate LFLiveKit into your Xcode project using CocoaPods, specify it in your Podfile:

	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '7.0'
	pod 'LFLiveKit'
	
	# Then, run the following command:
	$ pod install


#### Carthage
    1. Add `github "LaiFengiOS/LFLiveKit"` to your Cartfile.
    2. Run `carthage update --platform ios` and add the framework to your project.
    3. Import \<LFLiveKit/LFLiveKit.h\>.


#### Manually

    1. Download all the files in the `LFLiveKit` subdirectory.
    2. Add the source files to your Xcode project.
    3. Link with required frameworks:
        * UIKit
        * Foundation
        * AVFoundation
        * VideoToolbox
        * AudioToolbox
        * libz
        * libstdc++
	
## Usage example 

#### Objective-C
```objc
- (LFLiveSession*)session {
	if (!_session) {
	    _session = [[LFLiveSession alloc] initWithAudioConfiguration:[LFLiveAudioConfiguration defaultConfiguration] videoConfiguration:[LFLiveVideoConfiguration defaultConfiguration]];
	    _session.preView = self;
	    _session.delegate = self;
	}
	return _session;
}

- (void)startLive {	
	LFLiveStreamInfo *streamInfo = [LFLiveStreamInfo new];
	streamInfo.url = @"your server rtmp url";
	[self.session startLive:streamInfo];
}

- (void)stopLive {
	[self.session stopLive];
}

//MARK: - CallBack:
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange: (LFLiveState)state;
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug*)debugInfo;
- (void)liveSession:(nullable LFLiveSession*)session errorCode:(LFLiveSocketErrorCode)errorCode;
```
#### Swift
```swift
// import LFLiveKit in [ProjectName]-Bridging-Header.h
#import <LFLiveKit.h> 

//MARK: - Getters and Setters
lazy var session: LFLiveSession = {
	let audioConfiguration = LFLiveAudioConfiguration.defaultConfiguration()
	let videoConfiguration = LFLiveVideoConfiguration.defaultConfigurationForQuality(LFLiveVideoQuality.Low3, landscape: false)
	let session = LFLiveSession(audioConfiguration: audioConfiguration, videoConfiguration: videoConfiguration)
	    
	session?.delegate = self
	session?.preView = self.view
	return session!
}()

//MARK: - Event
func startLive() -> Void { 
	let stream = LFLiveStreamInfo()
	stream.url = "your server rtmp url";
	session.startLive(stream)
}

func stopLive() -> Void {
	session.stopLive()
}

//MARK: - Callback
func liveSession(session: LFLiveSession?, debugInfo: LFLiveDebug?) 
func liveSession(session: LFLiveSession?, errorCode: LFLiveSocketErrorCode)
func liveSession(session: LFLiveSession?, liveStateDidChange state: LFLiveState)
```

## Release History
    * 2.0.0
        * CHANGE: modify bugs,support ios7 live.
    * 2.2.4.3
        * CHANGE: modify bugs,support swift import.
    * 2.5 
        * CHANGE: modify bugs,support bitcode.


## License
 **LFLiveKit is released under the MIT license. See LICENSE for details.**




