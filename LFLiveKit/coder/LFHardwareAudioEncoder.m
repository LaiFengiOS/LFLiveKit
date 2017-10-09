//
//  LFHardwareAudioEncoder.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFHardwareAudioEncoder.h"

@interface LFHardwareAudioEncoder (){
    AudioConverterRef m_converter;
    char *leftBuf;
    char *aacBuf;
    NSInteger leftLength;
    FILE *fp;
    BOOL enabledWriteVideoFile;
}
@property (nonatomic, strong) LFLiveAudioConfiguration *configuration;
@property (nonatomic, weak) id<LFAudioEncodingDelegate> aacDeleage;

@end

@implementation LFHardwareAudioEncoder

- (instancetype)initWithAudioStreamConfiguration:(nullable LFLiveAudioConfiguration *)configuration {
    if (self = [super init]) {
        NSLog(@"USE LFHardwareAudioEncoder");
        _configuration = configuration;
        
        if (!leftBuf) {
            leftBuf = malloc(_configuration.bufferLength);
        }
        
        if (!aacBuf) {
            aacBuf = malloc(_configuration.bufferLength);
        }
        
        
#ifdef DEBUG
        enabledWriteVideoFile = NO;
        [self initForFilePath];
#endif
    }
    return self;
}

- (void)dealloc {
    if (aacBuf) free(aacBuf);
    if (leftBuf) free(leftBuf);
}

#pragma mark -- LFAudioEncoder
- (void)setDelegate:(id<LFAudioEncodingDelegate>)delegate {
    _aacDeleage = delegate;
}

- (void)encodeAudioData:(nullable NSData*)audioData timeStamp:(uint64_t)timeStamp {
    if (![self createAudioConvert]) {
        return;
    }
    
    
    if(leftLength + audioData.length >= self.configuration.bufferLength){
        ///<  发送  达到发送大小
        NSInteger totalSize = leftLength + audioData.length;
        NSInteger encodeCount = totalSize/self.configuration.bufferLength;//audioData.length比较大，totalSize可能会是bufferLengthleft多倍
        char *totalBuf = malloc(totalSize);
        char *p = totalBuf;
        
        memset(totalBuf, 0, (int)totalSize);//初始化totalBuf
        memcpy(totalBuf, leftBuf, leftLength);//copy上次剩余
        memcpy(totalBuf + leftLength, audioData.bytes, audioData.length);////copy此次数据
        
        for(NSInteger index = 0;index < encodeCount;index++){
            //从p的位置开始发送，发送bufferLength大小
            [self encodeBuffer:p  timeStamp:timeStamp];
            p += self.configuration.bufferLength;
        }
        
        leftLength = totalSize%self.configuration.bufferLength;//改变发送剩余数据大小leftLength
        memset(leftBuf, 0, self.configuration.bufferLength);//将leftBuf起始位置到bufferLength置0
        memcpy(leftBuf, totalBuf + (totalSize -leftLength), leftLength);//将totalBuf剩余的放倒leftBuf当中，下次发送
        
        free(totalBuf);
        
    }else{
        ///< 积累  未达到发送大小
        memcpy(leftBuf+leftLength, audioData.bytes, audioData.length);
        leftLength = leftLength + audioData.length;
    }
}

- (void)encodeBuffer:(char*)buf timeStamp:(uint64_t)timeStamp{
    
    AudioBuffer inBuffer;
    inBuffer.mNumberChannels = 1;
    inBuffer.mData = buf;
    inBuffer.mDataByteSize = (UInt32)self.configuration.bufferLength;
    
    // 初始化一个输入缓冲列表 
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;//只有一个inBuffer
    buffers.mBuffers[0] = inBuffer;
    
    
    // 初始化一个输出缓冲列表 
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers = 1;//只有一个outBuffer
    outBufferList.mBuffers[0].mNumberChannels = inBuffer.mNumberChannels;
    outBufferList.mBuffers[0].mDataByteSize = inBuffer.mDataByteSize;   // 设置缓冲区大小
    outBufferList.mBuffers[0].mData = aacBuf;           // 设置AAC缓冲区 编码后数据存放的位置
    UInt32 outputDataPacketSize = 1;
    if (AudioConverterFillComplexBuffer(m_converter, inputDataProc, &buffers, &outputDataPacketSize, &outBufferList, NULL) != noErr) {
        return;
    }
    //封装为LFAudioFrame方便以后推流使用
    LFAudioFrame *audioFrame = [LFAudioFrame new];
    audioFrame.timestamp = timeStamp;
    audioFrame.data = [NSData dataWithBytes:aacBuf length:outBufferList.mBuffers[0].mDataByteSize];
    
    char exeData[2];//flv编码音频头 44100 为0x12 0x10
    exeData[0] = _configuration.asc[0];
    exeData[1] = _configuration.asc[1];
    audioFrame.audioInfo = [NSData dataWithBytes:exeData length:2];
    if (self.aacDeleage && [self.aacDeleage respondsToSelector:@selector(audioEncoder:audioFrame:)]) {
        [self.aacDeleage audioEncoder:self audioFrame:audioFrame];//调用编码完成后代理
    }
    
    if (self->enabledWriteVideoFile) {//写入本地文件中，debug时调用
        NSData *adts = [self adtsData:_configuration.numberOfChannels rawDataLength:audioFrame.data.length];
        fwrite(adts.bytes, 1, adts.length, self->fp);
        fwrite(audioFrame.data.bytes, 1, audioFrame.data.length, self->fp);
    }
    
}

- (void)stopEncoder {
    
}

#pragma mark -- CustomMethod
- (BOOL)createAudioConvert { //根据输入样本初始化一个编码转换器
    if (m_converter != nil) {
        return TRUE;
    }
    // 音频输入描述
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mSampleRate = _configuration.audioSampleRate;// 采样率
    inputFormat.mFormatID = kAudioFormatLinearPCM;// 数据格式
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;// 格式标识
    inputFormat.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;// 声道数
    inputFormat.mFramesPerPacket = 1;//packet中包含的frame数目，无压缩时为1，可变比特率时，一个大点儿的固定值例如在ACC中1024。
    inputFormat.mBitsPerChannel = 16;// 每个声道比特数，语音每采样点占用位数 
    inputFormat.mBytesPerFrame = inputFormat.mBitsPerChannel / 8 * inputFormat.mChannelsPerFrame;// 每帧多少字节
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;// 一个packet中的字节数目，如果时可变的packet则为0
    
    // 音频输出描述
    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));// 初始化
    outputFormat.mSampleRate = inputFormat.mSampleRate;       // 采样率保持一致
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;            // AAC编码 kAudioFormatMPEG4AAC kAudioFormatMPEG4AAC_HE_V2
    outputFormat.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;;
    outputFormat.mFramesPerPacket = 1024;                     // AAC一帧是1024个字节
    
    const OSType subtype = kAudioFormatMPEG4AAC;
    //两种编码方式  软编码 硬编码
    AudioClassDescription requestedCodecs[2] = {
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer// 软编码
        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer// 硬编码
        }
    };
    
    OSStatus result = AudioConverterNewSpecific(&inputFormat, &outputFormat, 2, requestedCodecs, &m_converter);//创建AudioConverter ：输入描述，输出描述，requestedCodecs的数量，支持的编码方式，AudioConverter
    UInt32 outputBitrate = _configuration.audioBitrate;
    UInt32 propSize = sizeof(outputBitrate);
    
    
    if(result == noErr) {
        result = AudioConverterSetProperty(m_converter, kAudioConverterEncodeBitRate, propSize, &outputBitrate);//设置码率
    }
    
    return YES;
}


#pragma mark -- AudioCallBack
OSStatus inputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription * *outDataPacketDescription, void *inUserData) { //<span style="font-family: Arial, Helvetica, sans-serif;">AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据</span>
    AudioBufferList bufferList = *(AudioBufferList *)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = bufferList.mBuffers[0].mDataByteSize;
    return noErr;
}


#pragma mark -- Custom Method
/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData *)adtsData:(NSInteger)channel rawDataLength:(NSInteger)rawDataLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    NSInteger freqIdx = [self sampleRateIndex:self.configuration.audioSampleRate];  //44.1KHz
    int chanCfg = (int)channel;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + rawDataLength;
    // fill in ADTS data
    packet[0] = (char)0xFF;     // 11111111     = syncword
    packet[1] = (char)0xF9;     // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

- (NSInteger)sampleRateIndex:(NSInteger)frequencyInHz {
    NSInteger sampleRateIndex = 0;
    switch (frequencyInHz) {
        case 96000:
            sampleRateIndex = 0;
            break;
        case 88200:
            sampleRateIndex = 1;
            break;
        case 64000:
            sampleRateIndex = 2;
            break;
        case 48000:
            sampleRateIndex = 3;
            break;
        case 44100:
            sampleRateIndex = 4;
            break;
        case 32000:
            sampleRateIndex = 5;
            break;
        case 24000:
            sampleRateIndex = 6;
            break;
        case 22050:
            sampleRateIndex = 7;
            break;
        case 16000:
            sampleRateIndex = 8;
            break;
        case 12000:
            sampleRateIndex = 9;
            break;
        case 11025:
            sampleRateIndex = 10;
            break;
        case 8000:
            sampleRateIndex = 11;
            break;
        case 7350:
            sampleRateIndex = 12;
            break;
        default:
            sampleRateIndex = 15;
    }
    return sampleRateIndex;
}

- (void)initForFilePath {
    NSString *path = [self GetFilePathByfileName:@"IOSCamDemo_HW.aac"];
    NSLog(@"%@", path);
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}

@end
