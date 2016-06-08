//
//  LFFlvPackage.m
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFFlvPackage.h"
#include "flv/flv.h"
#include "flv/info.h"

#define kTagLength (4)
#define kAVCPacketHeaderSize  (5)
static const byte kAudioDataHeader = 0xAF;
#define swap_uint32_ htonl

@interface LFFlvPackage (){
    dispatch_semaphore_t _lock;
    NSData *_sps;
    NSData *_pps;
    NSData *_spec;
    CGSize _videoSize;
    FILE *fp;
    BOOL enabledWriteVideoFile;
    BOOL enabledWriteFlvHeaderVideoFile;
}

@end

@implementation LFFlvPackage

- (instancetype)initWithVideoSize:(CGSize)videoSize{
    if(CGSizeEqualToSize(videoSize, CGSizeZero)) @throw [NSException exceptionWithName:@"LFFlvPackage init error" reason:@"video size is zero" userInfo:nil];
    if(self = [super init]){
        _videoSize = videoSize;
        _lock = dispatch_semaphore_create(1);
#ifdef DEBUG
        enabledWriteVideoFile = NO;
        [self initForFilePath];
#endif
    }
    return self;
}

- (void)dealloc{
    
}

#pragma mark -- LFStreamPackage Delegate
- (NSData*)aaCPacket:(LFAudioFrame*)audioFrame{
    NSMutableData *result = [[NSMutableData alloc] init];
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    if(!_spec){
        _spec = audioFrame.audioInfo;
    }
    
    if(!_sps || !_pps){
        dispatch_semaphore_signal(_lock);
        return nil;
    }
    
    // write audio data
    uint32 kAACPacketSize = 2;
    
    NSInteger buffer_size = kAACPacketSize + audioFrame.data.length + FLV_TAG_SIZE;
    NSInteger packet_size = buffer_size + kTagLength;
    
    [result appendData:[[self class] flvTagHeader:FLV_TAG_TYPE_AUDIO size:(int32_t)audioFrame.data.length + kAACPacketSize timeStamp:(uint32)audioFrame.timestamp]];
    
    byte format[2] = { kAudioDataHeader, 0x01};
    [result appendBytes:format length:sizeof(format)];
    [result appendData:audioFrame.data];
    
    uint32 pre_size = swap_uint32_(packet_size-4);
    [result appendBytes:&pre_size length:sizeof(uint32)];
    
    audioFrame.header = [[self class] flvHeads:_videoSize.width videoHeight:_videoSize.height sps:_sps pps:_pps audioHeader:_spec];
    if(enabledWriteVideoFile){
        if(!enabledWriteFlvHeaderVideoFile){
            enabledWriteFlvHeaderVideoFile = YES;
            fwrite(audioFrame.header.bytes, 1,audioFrame.header.length,self->fp);
        }
    }
    
    if(enabledWriteVideoFile) {
        fwrite(result.bytes, 1, result.length,self->fp);
    }
    
    dispatch_semaphore_signal(_lock);
    return result;
}

- (NSData*)h264Packet:(LFVideoFrame*)videoFrame{
    NSMutableData *result = [[NSMutableData alloc] init];
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    if(!_sps || !_pps){
        _sps = videoFrame.sps;
        _pps = videoFrame.pps;
    }
    
    if(!_spec){
        dispatch_semaphore_signal(_lock);
        return nil;
    }
    
    videoFrame.header = [[self class] flvHeads:_videoSize.width videoHeight:_videoSize.height sps:_sps pps:_pps audioHeader:_spec];
    if(enabledWriteVideoFile){
        if(!enabledWriteFlvHeaderVideoFile){
            enabledWriteFlvHeaderVideoFile = YES;
            fwrite(videoFrame.header.bytes, 1,videoFrame.header.length,self->fp);
        }
    }
    
    // write video data
    //   Size + buffer size(4 bytes)
    uint32 kAVCPacketSize = kAVCPacketHeaderSize + 4;
    
    size_t buffer_size = kAVCPacketSize + videoFrame.data.length + FLV_TAG_SIZE;
    size_t packet_size = buffer_size + kTagLength;
    
    [result appendData:[[self class] flvTagHeader:FLV_TAG_TYPE_VIDEO size:(int32_t)videoFrame.data.length + kAVCPacketSize  timeStamp:(uint32)videoFrame.timestamp]];
    [result appendData:[[self class] h264PacketHeader:videoFrame.isKeyFrame nalu:true]];
    
    // write length
    size_t size = videoFrame.data.length;
    byte length[4] = { 0x00, 0x00, 0x00, 0x00 };
    length[0]  = (size >> 24) & 0xff;
    length[1]  = (size >> 16) & 0xff;
    length[2]  = (size >>  8) & 0xff;
    length[3]  = (size >>  0) & 0xff;
    [result appendBytes:length length:sizeof(length)];
    
    // write tag data
    [result appendData:videoFrame.data];
    
    uint32 pre_size = swap_uint32_(packet_size-4);
    [result appendBytes:&pre_size length:sizeof(uint32)];
    
    if(enabledWriteVideoFile) {
        fwrite(result.bytes, 1, result.length,self->fp);
    }
    
    dispatch_semaphore_signal(_lock);
    return  result;
}

#pragma mark -- FLV
int stream_buffer_write_offset = 0;
static size_t stream_buffer_write(const void * in_buffer, size_t size, void * user_data) {
    memcpy(user_data+stream_buffer_write_offset, in_buffer, size);
    stream_buffer_write_offset += size;
    return size;
}

+ (NSData*)flvHeader{
    NSMutableData *result = [[NSMutableData alloc] init];
    // 写入 flv header信息 /*<464c5601 05000000 09000000 00>*/
    flv_header header = { };
    uint32_be offset = swap_uint32_(FLV_HEADER_SIZE);
    byte extend[kTagLength] = { 0x00, 0x00, 0x00, 0x00 };
    
    [result appendBytes:FLV_SIGNATURE length:sizeof(header.signature)];
    uint8 version[] = {FLV_VERSION};
    [result appendBytes:&version length:1];
    uint8 flag[] = {FLV_FLAG_VIDEO | FLV_FLAG_AUDIO};
    [result appendBytes:&flag length:1];
    [result appendBytes:&offset length:sizeof(uint32_be)];
    [result appendBytes:extend length:kTagLength];
    
    return result;
}

+ (NSData*)flvTagHeader:(uint8)type size:(uint32)size timeStamp:(uint32)timeStamp{
    flv_tag tag;
    tag.type          =  type;
    tag.body_length   =  uint32_to_uint24_be(size);
    flv_tag_set_timestamp(&tag, timeStamp);
    tag.stream_id     =  uint32_to_uint24_be(0);
    
    return [NSData dataWithBytes:&tag length:FLV_TAG_SIZE];
}

+ (NSData*)h264PacketHeader:(BOOL)keyFrame nalu:(BOOL)nalu{
    byte header[kAVCPacketHeaderSize] = { 0x00, 0x00, 0x00, 0x00, 0x00 };
    header[0]  = (keyFrame ? 0x10 : 0x20) | 0x07;
    header[1]  = nalu ? 0x01 : 0x00;    // 1: AVC NALU  0: AVC sequence header
    // 后三个字节为Composition time,在AVC中无用
    return [NSData dataWithBytes:header length:sizeof(header)];
}

+ (NSData*)metaData:(NSInteger)width height:(NSInteger)height{
    NSMutableData *result = [[NSMutableData alloc] init];
    
    flv_metadata meta;
    meta.on_metadata_name = amf_str("onMetaData");
    meta.on_metadata = amf_associative_array_new();
    amf_associative_array_add(meta.on_metadata, "width",
                              amf_number_new(width));
    amf_associative_array_add(meta.on_metadata, "height",
                              amf_number_new(height));
    amf_associative_array_add(meta.on_metadata, "videocodecid",
                              amf_number_new((number64)FLV_VIDEO_TAG_CODEC_AVC));
    //usage = base::IntToString(params_.audio_sample_rate);
    //amf_associative_array_add(meta.on_metadata, "audiosamplerate",
    //	amf_str(usage.c_str()));
    //usage = base::IntToString(params_.audio_sample_size);
    //amf_associative_array_add(meta.on_metadata, "audiosamplesize",
    //	amf_str(usage.c_str()));
    amf_associative_array_add(meta.on_metadata, "stereo", amf_boolean_new(1)); // 对AAC格式: 总为 1
    amf_associative_array_add(meta.on_metadata, "audiocodecid",
                              amf_number_new((number64)FLV_AUDIO_TAG_SOUND_FORMAT_AAC));
    // create the onMetaData tag
    uint32 on_metadata_name_size = (uint32)amf_data_size(meta.on_metadata_name);
    uint32 on_metadata_size = (uint32)amf_data_size(meta.on_metadata);
    uint32 meta_size = on_metadata_name_size + on_metadata_size;

    size_t buffer_size = meta_size + FLV_TAG_SIZE;
    size_t packet_size = true ? buffer_size + kTagLength : buffer_size;
    [result appendData:[[self class] flvTagHeader:FLV_TAG_TYPE_META size:meta_size timeStamp:0]];
    
    byte metaName[1024] = {0};
    byte metaData[1024] = {0};
    
    stream_buffer_write_offset = 0;
    size_t metanamelen = amf_data_write(meta.on_metadata_name, stream_buffer_write, metaName);
    
    stream_buffer_write_offset = 0;
    size_t metalen = amf_data_write(meta.on_metadata, stream_buffer_write, metaData);
    
    amf_data_free(meta.on_metadata_name);
    amf_data_free(meta.on_metadata);
    
    [result appendBytes:metaName length:metanamelen];
    [result appendBytes:metaData length:metalen];
    uint32 pre_size = swap_uint32_(packet_size-4);//为解决第一个pretagsize多了4个而减去4
    [result appendBytes:&pre_size length:sizeof(uint32)];
    
    return result;
}

+ (NSData*)flvTagWithVideoHeader:(NSData*)sps pps:(NSData*)pps{
    NSMutableData *result = [[NSMutableData alloc] init];
    // 封装AVC sequence header
    const size_t kExtendSize = 11;
    size_t buffer_size = sps.length + pps.length + kExtendSize;
    
    // AVCPacket header size
    size_t body_size = kAVCPacketHeaderSize + buffer_size;
    size_t packet_size = body_size + FLV_TAG_SIZE;
    // AVCDecoderConfigurationRecord
    [result appendData:[[self class] flvTagHeader:FLV_TAG_TYPE_VIDEO size:(UInt32)body_size timeStamp:0]];
    [result appendData:[[self class] h264PacketHeader:YES nalu:NO]];
    
    uint8 configuration1[] = {0x01};
    [result appendBytes:&configuration1 length:1];
    [result appendBytes:&sps.bytes[1] length:1];
    [result appendBytes:&sps.bytes[2] length:1];
    [result appendBytes:&sps.bytes[3] length:1];
    uint8 configuration2[] = {0xff};
    [result appendBytes:&configuration2 length:1];
    
    // sps
    uint8 sps1[] = {0xe1};
    [result appendBytes:&sps1 length:1];
    uint8 sps2[] = {(sps.length >> 8) & 0xff};
    [result appendBytes:&sps2 length:1];
    uint8 sps3[] = {sps.length & 0xff};
    [result appendBytes:&sps3 length:1];
    [result appendBytes:sps.bytes length:sps.length];
    
    
    // pps
    uint8 pps1[] = {0x01};
    [result appendBytes:&pps1 length:1];
    uint8 pps2[] = {(pps.length >> 8) & 0xff};
    [result appendBytes:&pps2 length:1];
    uint8 pps3[] = {pps.length & 0xff};
    [result appendBytes:&pps3 length:1];
    [result appendBytes:pps.bytes length:pps.length];
    
    uint32 pre_size = swap_uint32_(packet_size);
    [result appendBytes:&pre_size length:sizeof(uint32)];

    return result;
}

+ (NSData*)flvTagWithAudioHeader:(NSData*)audioInfo timeStamp:(uint32)timeStamp{
    NSMutableData *result = [[NSMutableData alloc] init];
    const size_t kAACPacketHeaderSize = 2;
    
    size_t body_size = kAACPacketHeaderSize + audioInfo.length;
    size_t packet_size = body_size + FLV_TAG_SIZE;

    [result appendData:[[self class] flvTagHeader:FLV_TAG_TYPE_AUDIO size:(UInt32)body_size timeStamp:timeStamp]];
    
    byte format[kAACPacketHeaderSize] = { kAudioDataHeader, 0x01};
    format[1] = 0x00;
    [result appendBytes:format length:sizeof(format)];
    [result appendBytes:audioInfo.bytes length:audioInfo.length];
    
    uint32 pre_size = swap_uint32_(packet_size);
    [result appendBytes:&pre_size length:sizeof(uint32)];
    
    return result;
}

+ (NSData*)flvHeads:(NSInteger)videoWidth videoHeight:(NSInteger)videoHeight sps:(NSData*)sps pps:(NSData*)pps audioHeader:(NSData*)audioHeader{
    NSMutableData *result = [[NSMutableData alloc] init];
    // 写FLV头
    [result appendData:[[self class] flvHeader]];
    // 写 Meta 相关信息
    [result appendData:[[self class] metaData:videoWidth height:videoHeight]];
    // 写音频编码头信息
    [result appendData:[[self class] flvTagWithAudioHeader:audioHeader timeStamp:0]];
    // 写视频编码头信息
    [result appendData:[[self class] flvTagWithVideoHeader:sps pps:pps]];
    
    return result;
}


#pragma mark -- Debug.. store video to local
- (void)initForFilePath{
    NSString *path = [self GetFilePathByfileName:"flv_publish_x1.flv"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding],"wb");
}

- (NSString*)GetFilePathByfileName:(char*)filename{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *strName = [NSString stringWithFormat:@"%s",filename];
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:strName];
    
    
    return writablePath;
}

@end
