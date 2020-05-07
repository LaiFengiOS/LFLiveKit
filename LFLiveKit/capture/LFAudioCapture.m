//
//  LFAudioCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFAudioCapture.h"
#import "RKSoundMix.h"
#import "RKMultiAudioMix.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

NSString *const LFAudioComponentFailedToCreateNotification = @"LFAudioComponentFailedToCreateNotification";

@interface LFAudioCapture ()

@property (nonatomic, assign) AudioComponentInstance componetInstance;
@property (nonatomic, assign) AudioComponent component;
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong,nullable) LFLiveAudioConfiguration *configuration;

@property (strong, nonatomic) NSMutableArray<RKAudioMixPart *> *urlmixPartQueue;

@property (strong, nonatomic) NSMutableDictionary<NSURL *, RKAudioURLMixSrc *> *urlSrcCache;

@property (strong, nonatomic) NSMutableDictionary<NSURL *, RKAudioMixPart *> *urlMixParts;

@property (strong, nonatomic) RKAudioMixPart *sideDataPart;

@property (weak, nonatomic) RKAudioMixPart *playingPartSingle;
@property (weak, nonatomic) RKAudioMixPart *playingPartInQueue;

@end

@implementation LFAudioCapture

#pragma mark -- LiftCycle
- (instancetype)initWithAudioConfiguration:(LFLiveAudioConfiguration *)configuration{
    if(self = [super init]){
        _configuration = configuration;
        self.isRunning = NO;
        self.taskQueue = dispatch_queue_create("com.youku.Laifeng.audioCapture.Queue", NULL);
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setMode:AVAudioSessionModeDefault error:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleRouteChange:)
                                                     name: AVAudioSessionRouteChangeNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleInterruption:)
                                                     name: AVAudioSessionInterruptionNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(didBecomeActive:)
                                                     name: UIApplicationDidBecomeActiveNotification
                                                   object: nil];
        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
//        acd.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        acd.componentSubType = configuration.echoCancellation ? kAudioUnitSubType_VoiceProcessingIO : kAudioUnitSubType_RemoteIO;
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;
        
        self.component = AudioComponentFindNext(NULL, &acd);
        
        OSStatus status = noErr;
        status = AudioComponentInstanceNew(self.component, &_componetInstance);
        
        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }
        
        UInt32 flagOne = 1;
        
        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
        
        AudioStreamBasicDescription desc = {0};
        desc.mSampleRate = _configuration.audioSampleRate;
        desc.mFormatID = kAudioFormatLinearPCM;
        desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        desc.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;
        desc.mFramesPerPacket = 1;
        desc.mBitsPerChannel = 16;
        desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
        desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
        
        AURenderCallbackStruct cb;
        cb.inputProcRefCon = (__bridge void *)(self);
        cb.inputProc = handleInputBuffer;
        AudioUnitSetProperty(self.componetInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc, sizeof(desc));
        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
        
        status = AudioUnitInitialize(self.componetInstance);
        
        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }
        
        [session setPreferredSampleRate:_configuration.audioSampleRate error:nil];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];
        [session setActive:YES withOptions:kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation error:nil];
        
        [session setActive:YES error:nil];
        
        _urlmixPartQueue = [NSMutableArray new];
        _urlSrcCache = [NSMutableDictionary  new];
        _urlMixParts = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    dispatch_sync(self.taskQueue, ^{
        if (self.componetInstance) {
            self.isRunning = NO;
            AudioOutputUnitStop(self.componetInstance);
            AudioComponentInstanceDispose(self.componetInstance);
            self.componetInstance = nil;
            self.component = nil;
        }
    });
}

- (RKAudioURLMixSrc *)sourceWithURL:(NSURL *)url {
    RKAudioURLMixSrc *src = self.urlSrcCache[url];
    if (!src) {
        src = [[RKAudioURLMixSrc alloc] initWithURL:url];
        src.mixingChannels = self.configuration.numberOfChannels;
        self.urlSrcCache[url] = src;
    }
    return src;
}

- (void)mixSound:(nonnull NSURL *)url weight:(float)weight {
    [self mixSound:url weight:weight repeated:NO];
}

- (void)mixSound:(nonnull NSURL *)url weight:(float)weight repeated:(BOOL)repeated {
    RKAudioMixPart *part = self.urlMixParts[url];
    if (part) {
        [(RKAudioURLMixSrc*)part.source reset];
        ((RKAudioURLMixSrc*)part.source).repeated = repeated;
    } else {
        if ([self.playingPartSingle.source isKindOfClass:RKAudioURLMixSrc.class]) {
            NSURL *url = ((RKAudioURLMixSrc*)self.playingPartSingle.source).soundURL;
            self.urlMixParts[url] = nil;
        }
        RKAudioURLMixSrc *src = [self sourceWithURL:url];
        [src reset];
        src.repeated = repeated;
        part = [[RKAudioMixPart alloc] init];
        part.source = src;
        self.urlMixParts[url] = part;
    }
    part.weight = weight;
    self.playingPartSingle = part;
}

- (void)mixSounds:(nonnull NSArray<NSURL *> *)urls weights:(nonnull NSArray<NSNumber *> *)weights {
    for (int i = 0; i < urls.count; i++) {
        NSURL *url = urls[i];
        RKAudioMixPart *part = self.urlMixParts[url];
        if (part) {
            [(RKAudioURLMixSrc*)part.source reset];
            ((RKAudioURLMixSrc*)part.source).repeated = NO;
        } else {
            RKAudioURLMixSrc *src = [self sourceWithURL:url];
            [src reset];
            src.repeated = NO;
            part = [[RKAudioMixPart alloc] init];
            part.source = src;
            self.urlMixParts[url] = part;
        }
        part.weight = i < weights.count ? weights[i].floatValue : 0.5;
    }
}

- (void)mixSoundSequences:(nonnull NSArray<NSURL *> *)urls weight:(float)weight {
    @synchronized (_urlmixPartQueue) {
        for (NSURL *url in urls) {
            RKAudioURLMixSrc *src = [self sourceWithURL:url];
            [src reset];
            src.repeated = NO;
            RKAudioMixPart *part = [[RKAudioMixPart alloc] init];
            part.source = src;
            part.weight = weight;
            [self.urlmixPartQueue addObject:part];
        }
    }
}

- (void)prepareNextMixSound {
    @synchronized (_urlmixPartQueue) {
        RKAudioMixPart *part = self.urlmixPartQueue.firstObject;
        if (part) {
            [(RKAudioURLMixSrc*)part.source reset];
            NSURL *url = ((RKAudioURLMixSrc*)part.source).soundURL;
            self.urlMixParts[url] = part;
            self.playingPartInQueue = part;
            [self.urlmixPartQueue removeObjectAtIndex:0];
        }
    }
}

- (void)mixSideData:(nonnull NSData *)data weight:(float)weight {
    if (!self.sideDataPart) {
        self.sideDataPart = [[RKAudioMixPart alloc] init];
        self.sideDataPart.source = [[RKAudioDataMixSrc alloc] init];
    }
    self.sideDataPart.weight = weight;
    [(RKAudioDataMixSrc*)self.sideDataPart.source pushData:data];
}

- (void)stopMixSound:(NSURL *)url {
    self.urlMixParts[url] = nil;
}

- (void)stopMixAllSounds {
    @synchronized(_urlmixPartQueue) {
        [self.urlmixPartQueue removeAllObjects];
    }
    [self.urlMixParts removeAllObjects];
}

- (void)processAudio:(AudioBufferList)buffers {
    for (NSURL *url in self.urlMixParts.allKeys) {
        RKAudioMixPart *part = self.urlMixParts[url];
        RKAudioURLMixSrc *src = part.source;
        if (src.isFinished) {
            self.urlMixParts[url] = nil;
        }
    }
    if (!self.playingPartInQueue && self.urlmixPartQueue.count > 0) {
        [self prepareNextMixSound];
    }
    
    [RKMultiAudioMix mixParts:self.urlMixParts.allValues onAudio:buffers];
    
    [self.delegate captureOutput:self audioBeforeSideMixing:[NSData dataWithBytes:buffers.mBuffers[0].mData length:buffers.mBuffers[0].mDataByteSize]];

    if (self.sideDataPart) {
        [RKMultiAudioMix mixParts:@[self.sideDataPart] onAudio:buffers];
    }

    if (self.muted) {
        for (int i = 0; i < buffers.mNumberBuffers; i++) {
            AudioBuffer ab = buffers.mBuffers[i];
            memset(ab.mData, 0, ab.mDataByteSize);
        }
    }
    
    // samples: 一個audio frame所涵蓋的sample數, 因為mBitsPerChannel=16, 1 byte=8 bits, 一個audio frame有32 bits(雙聲道的話), 換算起來就是總bytes / 2(一個聲道有16 bits) / 2(雙聲道)
    [self.delegate captureOutput:self didFinishAudioProcessing:buffers samples:(buffers.mBuffers[0].mDataByteSize / (2 * _configuration.numberOfChannels))];
}

#pragma mark -- Setter
- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    if (_running) {
        dispatch_async(self.taskQueue, ^{
            self.isRunning = YES;
            NSLog(@"MicrophoneSource: startRunning");
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];
            AudioOutputUnitStart(self.componetInstance);
        });
    } else {
        dispatch_sync(self.taskQueue, ^{
            self.isRunning = NO;
            NSLog(@"MicrophoneSource: stopRunning");
            AudioOutputUnitStop(self.componetInstance);
        });
    }
}

#pragma mark -- CustomMethod
- (void)handleAudioComponentCreationFailure {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:LFAudioComponentFailedToCreateNotification object:nil];
    });
}

#pragma mark -- NSNotification

- (void)didBecomeActive:(NSNotification *)notification {
    if (self.isRunning) {
        dispatch_async(self.taskQueue, ^{
            NSLog(@"didBecomeActive MicrophoneSource: startRunning");
            AudioOutputUnitStart(self.componetInstance);
        });
    }
}

- (void)handleRouteChange:(NSNotification *)notification {
    AVAudioSession *session = [ AVAudioSession sharedInstance ];
    NSString *seccReason = @"";
    NSInteger reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    //  AVAudioSessionRouteDescription* prevRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    switch (reason) {
    case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
        seccReason = @"The route changed because no suitable route is now available for the specified category.";
        break;
    case AVAudioSessionRouteChangeReasonWakeFromSleep:
        seccReason = @"The route changed when the device woke up from sleep.";
        break;
    case AVAudioSessionRouteChangeReasonOverride:
        seccReason = @"The output route was overridden by the app.";
        break;
    case AVAudioSessionRouteChangeReasonCategoryChange:
        seccReason = @"The category of the session object changed.";
        break;
    case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        seccReason = @"The previous audio output path is no longer available.";
        break;
    case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        seccReason = @"A preferred new audio output path is now available.";
        break;
    case AVAudioSessionRouteChangeReasonUnknown:
    default:
        seccReason = @"The reason for the change is unknown.";
        break;
    }
    NSLog(@"handleRouteChange reason is %@", seccReason);

    AVAudioSessionPortDescription *input = [[session.currentRoute.inputs count] ? session.currentRoute.inputs : nil objectAtIndex:0];
    if (input.portType == AVAudioSessionPortHeadsetMic) {

    }
}

- (void)handleInterruption:(NSNotification *)notification {
    NSInteger reason = 0;
    NSString *reasonStr = @"";
    if ([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        //Posted when an audio interruption occurs.
        reason = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
        if (reason == AVAudioSessionInterruptionTypeBegan) {
            if (self.isRunning) {
                dispatch_sync(self.taskQueue, ^{
                    NSLog(@"MicrophoneSource: stopRunning");
                    AudioOutputUnitStop(self.componetInstance);
                });
            }
        }

        if (reason == AVAudioSessionInterruptionTypeEnded) {
            reasonStr = @"AVAudioSessionInterruptionTypeEnded";
            NSNumber *seccondReason = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
            switch ([seccondReason integerValue]) {
            case AVAudioSessionInterruptionOptionShouldResume:
                if (self.isRunning) {
                    dispatch_async(self.taskQueue, ^{
                        NSLog(@"MicrophoneSource: startRunning");
                        AudioOutputUnitStart(self.componetInstance);
                    });
                }
                // Indicates that the audio session is active and immediately ready to be used. Your app can resume the audio operation that was interrupted.
                break;
            default:
                break;
            }
        }

    }
    ;
    NSLog(@"handleInterruption: %@ reason %@", [notification name], reasonStr);
}

#pragma mark -- CallBack
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    @autoreleasepool {
        LFAudioCapture *source = (__bridge LFAudioCapture *)inRefCon;
        if (!source) return -1;

        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;

        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;

        OSStatus status = AudioUnitRender(source.componetInstance,
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          &buffers);
        if (!status) {
            [source processAudio:buffers];
        }
        return status;
    }
}

@end
