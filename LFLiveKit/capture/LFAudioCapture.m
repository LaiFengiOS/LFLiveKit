//
//  LFAudioCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFAudioCapture.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

NSString *const LFAudioComponentFailedToCreateNotification = @"LFAudioComponentFailedToCreateNotification";

@interface LFAudioCapture ()

@property (nonatomic, assign) AudioComponentInstance componetInstance;
@property (nonatomic, assign) AudioComponent component;
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong,nullable) LFLiveAudioConfiguration *configuration;

@end

@implementation LFAudioCapture

#pragma mark -- LiftCycle
- (instancetype)initWithAudioConfiguration:(LFLiveAudioConfiguration *)configuration{
    if(self = [super init]){
        _configuration = configuration;
        self.isRunning = NO;
        self.taskQueue = dispatch_queue_create("com.youku.Laifeng.audioCapture.Queue", NULL);
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleRouteChange:)
                                                     name: AVAudioSessionRouteChangeNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleInterruption:)
                                                     name: AVAudioSessionInterruptionNotification
                                                   object: session];
        
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

        if (source.muted) {
            for (int i = 0; i < buffers.mNumberBuffers; i++) {
                AudioBuffer ab = buffers.mBuffers[i];
                memset(ab.mData, 0, ab.mDataByteSize);
            }
        } else if (source.isMixer) {
            if (!source.isLoadingAudioFile) {
                source.dataSizeCount = 0;
                                
                AVURLAsset *asset = [AVURLAsset URLAssetWithURL:source.audioPath options:nil];
                NSError *assetError = nil;
                AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&assetError];
                
                NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                                [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                                [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                                [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                                [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                                [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                                [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                                nil];
                
                AVAssetReaderOutput *assetReaderOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings: outputSettings];
                
                if ([assetReader canAddOutput: assetReaderOutput]) {
                    [assetReader addOutput: assetReaderOutput];
                    [assetReader startReading];
                    
                    NSMutableData *data = [NSMutableData data];
                    CMSampleBufferRef nextBuffer = [assetReaderOutput copyNextSampleBuffer];
                    while (nextBuffer) {
                        AudioBufferList audioBufferList;
                        CMBlockBufferRef blockBuffer;
                        
                        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer,
                                                                                nil,
                                                                                &audioBufferList,
                                                                                sizeof(audioBufferList),
                                                                                nil,
                                                                                nil,
                                                                                0,
                                                                                &blockBuffer);
                        
                        AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
                        NSData *audioData = [NSData dataWithBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
                        char *audioBytes;
                        audioBytes = malloc([audioData length]);
                        [audioData getBytes:audioBytes length:audioBuffer.mDataByteSize];
                        source.dataSizeTotal += audioBuffer.mDataByteSize;
                        [data appendBytes:audioBytes length:audioBuffer.mDataByteSize];
                        nextBuffer = [assetReaderOutput copyNextSampleBuffer];
                    }
                    [assetReader cancelReading];
                    
                    source.mp3Data = malloc(source.dataSizeTotal);
                    [data getBytes:source.mp3Data length:source.dataSizeTotal];
                    source.isLoadingAudioFile = YES;
                }
            }
            
            if (source.dataSizeTotal >= source.dataSizeCount) {
                for (int i = 0; i < buffers.mNumberBuffers; i++) {
                    AudioBuffer ab = buffers.mBuffers[i];
                    NSData *audioData = [NSData dataWithBytes:ab.mData length:ab.mDataByteSize];
                    char *audioBytes;
                    audioBytes = malloc([audioData length]);
                    [audioData getBytes:audioBytes length:[audioData length]];
                    
                    NSUInteger diffSize = source.dataSizeTotal - source.dataSizeCount;
                    NSInteger dataByteSize = diffSize >= ab.mDataByteSize ? ab.mDataByteSize : diffSize;
                    for (int j = 0; j < dataByteSize; j++) {
                        audioBytes[j] += (source.mp3Data[j + source.dataSizeCount] / 2);
                        if (audioBytes[j] >= 127) audioBytes[j] = 127;
                        else if (audioBytes[j] <= -128) audioBytes[j] = -128;
                    }
                    
                    memcpy(ab.mData, audioBytes, ab.mDataByteSize);
                    source.dataSizeCount += ab.mDataByteSize;
                }
            } else {
                source.isMixer = NO;
            }
        }
        
        if ([source.delegate respondsToSelector:@selector(captureOutput:audioDataBeforeMixing:)]) {
            [source.delegate captureOutput:source audioDataBeforeMixing:[NSData dataWithBytes:buffers.mBuffers[0].mData length:buffers.mBuffers[0].mDataByteSize]];
        }
        
        if (source.inputAudioDataArray.count > 0) {
            AudioBuffer ab = buffers.mBuffers[0];
            NSData *captureAudioData = [NSData dataWithBytes:ab.mData length:ab.mDataByteSize];
            char *captureAudioBytes = malloc([captureAudioData length]);
            [captureAudioData getBytes:captureAudioBytes length:[captureAudioData length]];
            
            NSData *inputAudioData = source.inputAudioDataArray.firstObject;
            char *inputAudioBytes = malloc(inputAudioData.length);
            [inputAudioData getBytes:inputAudioBytes length:inputAudioData.length];
            
            for (int i = 0; i < ab.mDataByteSize; i += 2) {
                short captureAudioShort = (short) (((captureAudioBytes[i + 1] & 0xFF) << 8) | (captureAudioBytes[i] & 0xFF));
                short inputAudioShort = (short) (((inputAudioBytes[source.inputAudioDataCurrentIndex + 1] & 0xFF) << 8) | (inputAudioBytes[source.inputAudioDataCurrentIndex] & 0xFF));
                
                int outputAudioData = captureAudioShort / 2 + inputAudioShort / 2;
                captureAudioBytes[i] = (outputAudioData & 0xFF);
                captureAudioBytes[i + 1] = ((outputAudioData >> 8) & 0xFF);
                
                source.inputAudioDataCurrentIndex += 2;
                if (source.inputAudioDataCurrentIndex >= inputAudioData.length) {
                    source.inputAudioDataCurrentIndex = 0;
                    [source.inputAudioDataArray removeObjectAtIndex:0];
                    inputAudioData = source.inputAudioDataArray.firstObject;
                    
                    if (!inputAudioData) {
                        break;
                    }
                    
                    inputAudioBytes = malloc(inputAudioData.length);
                    [inputAudioData getBytes:inputAudioBytes length:inputAudioData.length];
                }
            }
            
            memcpy(ab.mData, captureAudioBytes, ab.mDataByteSize);
        }

        if (!status) {
            if (source.delegate && [source.delegate respondsToSelector:@selector(captureOutput:audioData:)]) {
                [source.delegate captureOutput:source audioData:[NSData dataWithBytes:buffers.mBuffers[0].mData length:buffers.mBuffers[0].mDataByteSize]];
            }
        }
        return status;
    }
}

@end
