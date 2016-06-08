//
//  LFStreamTcpSocket.m
//  LFLiveKit
//
//  Created by admin on 16/5/3.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFStreamTcpSocket.h"
#import "GCDAsyncSocket.h"
#import "LFFlvPackage.h"

static const NSInteger RetryTimesBreaken = 20;///<  重连3分钟  3秒一次 一共60次
static const NSInteger RetryTimesMargin = 3;
const NSInteger TCP_RECEIVE_TIMEOUT = -1;

@interface LFStreamTcpSocket () <LFStreamingBufferDelegate,GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket * socket;
@property (nonatomic, strong) dispatch_queue_t socketQueue;
@property (nonatomic, strong) LFStreamingBuffer *buffer;
@property (nonatomic, strong) LFLiveStreamInfo *stream;
@property (nonatomic, weak) id<LFStreamSocketDelegate> delegate;
@property (nonatomic, strong) id<LFStreamPackage> package;
@property (nonatomic, strong) LFLiveDebug *debugInfo;
@property (nonatomic, assign) CGSize videoSize;

@property (nonatomic, assign) BOOL isSending;
@property (nonatomic, assign) BOOL isConnecting;
@property (nonatomic, assign) BOOL isReconnecting;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) NSInteger retryTimes4netWorkBreaken;
@property (nonatomic, assign) NSInteger reconnectInterval;
@property (nonatomic, assign) NSInteger reconnectCount;
@property (nonatomic, assign) BOOL needSendHeader;

@end

@implementation LFStreamTcpSocket

- (nullable instancetype)initWithStream:(nullable LFLiveStreamInfo*)stream videoSize:(CGSize)videoSize reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount{
    if(!stream) @throw [NSException exceptionWithName:@"LFStreamTcpSocket init error" reason:@"stream is nil" userInfo:nil];
    if(CGSizeEqualToSize(videoSize, CGSizeZero)) @throw [NSException exceptionWithName:@"LFStreamTcpSocket init error" reason:@"videoSize is zero" userInfo:nil];
    if(self = [super init]){
        _stream = stream;
        _videoSize = videoSize;
        if(reconnectInterval > 0) _reconnectInterval = reconnectInterval;
        else _reconnectInterval = RetryTimesMargin;
     
        if(reconnectCount > 0) _reconnectCount = reconnectCount;
        else _reconnectCount = RetryTimesBreaken;
    }
    return self;
}

#pragma mark -- LFStreamSocket
- (void) start{
    if(!_stream) return;
    if(_isConnecting) return;
    if(_socket.isConnected) return;
    [self clean];
    
    self.debugInfo.streamId = self.stream.streamId;
    self.debugInfo.uploadUrl = self.stream.url;
    self.debugInfo.videoSize = self.videoSize;
    self.debugInfo.isRtmp = NO;
    
    if(![self.socket connectToHost:_stream.host onPort:_stream.port withTimeout:5 error:nil]){
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
            [self.delegate socketStatus:self status:LFLiveError];
        }
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]){
            [self.delegate socketDidError:self errorCode:LFLiveSocketError_ConnectSocket];
        }
        return;
    }
    if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
        [self.delegate socketStatus:self status:LFLivePending];
    }
    _isConnecting = YES;
    
}

- (void) stop{
    [self.socket disconnect];
    [self clean];
}

- (void)sendFrame:(LFFrame *)frame{
    __weak typeof(self) _self = self;
    dispatch_async(self.socketQueue, ^{
        __strong typeof(_self) self = _self;
        if(!frame) return;
        if([frame isKindOfClass:[LFAudioFrame class]]){
            NSData *packageData = [self.package aaCPacket:(LFAudioFrame*)frame];///< 打包flv
            if(!packageData) return;
            frame.data = packageData;
        }else{
            NSData *packageData = [self.package h264Packet:(LFVideoFrame*)frame];///< 打包flv
            if(!packageData) return;
            frame.data = packageData;
        }
        
        [self.buffer appendObject:frame];
        [self sendFrame];
    });
}

- (void)setDelegate:(id<LFStreamSocketDelegate>)delegate{
    _delegate = delegate;
}

#pragma mark -- CustomMethod
- (void)sendFrame{
    if(!self.isSending && self.buffer.list.count > 0 && _isConnected){
        self.isSending = YES;
        LFFrame *frame = [self.buffer popFirstObject];
        if(self.needSendHeader){///< flvHeader 插入到队列最前面去
            NSMutableData * mutableData = [[NSMutableData alloc] init];
            [mutableData appendData:frame.header];
            [mutableData appendData:frame.data];
            frame.data = mutableData;
            self.needSendHeader = NO;
        }
        [self.socket writeData:frame.data withTimeout:TCP_RECEIVE_TIMEOUT tag:1];
        
        self.debugInfo.dataFlow += frame.data.length;
        if(CACurrentMediaTime()*1000 - self.debugInfo.timeStamp < 1000) {
            self.debugInfo.bandwidth += frame.data.length;
            if([frame isKindOfClass:[LFAudioFrame class]]){
                self.debugInfo.capturedAudioCount ++;
            }else{
                self.debugInfo.capturedVideoCount ++;
            }
            self.debugInfo.unSendCount = self.buffer.list.count;
        }else {
            self.debugInfo.currentBandwidth = self.debugInfo.bandwidth;
            self.debugInfo.currentCapturedAudioCount = self.debugInfo.capturedAudioCount;
            self.debugInfo.currentCapturedVideoCount = self.debugInfo.capturedVideoCount;
            if(self.delegate && [self.delegate respondsToSelector:@selector(socketDebug:debugInfo:)]){
                [self.delegate socketDebug:self debugInfo:self.debugInfo];
            }
            
            self.debugInfo.bandwidth = 0;
            self.debugInfo.capturedAudioCount = 0;
            self.debugInfo.capturedVideoCount = 0;
            self.debugInfo.timeStamp = CACurrentMediaTime()*1000;
        }

    }
}

- (void)clean{
    _isConnected = NO;
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _retryTimes4netWorkBreaken = 0;
    _needSendHeader = NO;
    self.debugInfo = nil;
    [self.buffer removeAllObject];
}

// 断线重连
-(void) reconnect {
    _isReconnecting = NO;
    if(_isConnected) return;
    if([self.socket isConnected]) return;
    
    if(![self.socket connectToHost:_stream.host onPort:_stream.port withTimeout:5 error:nil]){
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
            [self.delegate socketStatus:self status:LFLiveError];
        }
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]){
            [self.delegate socketDidError:self errorCode:LFLiveSocketError_ConnectSocket];
        }
        return;
    }
}


#pragma mark -- GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    NSLog(@"onSocket:%p didConnectToHost:%@ port:%hu", sock, host, port);
    [sock readDataWithTimeout:-1 tag:0];
    if(_isConnected) return;
    [self.socket writeData:self.verificationData withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [sock readDataWithTimeout:-1 tag:0];
    if(_isConnected) return;
    if([self verificationDataValid:data]){
        NSLog(@"服务器验证成功，准备发送数据");
        _isConnected = YES;
        _isConnecting = NO;
        _isReconnecting = NO;
        _retryTimes4netWorkBreaken = 0;// 计数器清零
        _needSendHeader = YES;
        self.isSending = NO;
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
            [self.delegate socketStatus:self status:LFLiveStart];
        }
    }else{
        NSLog(@"服务器验证失败");
        [self clean];
        [self.socket disconnect];
        
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
            [self.delegate socketStatus:self status:LFLiveError];
        }
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]){
            [self.delegate socketDidError:self errorCode:LFLiveSocketError_Verification];
        }
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"onSocket:%p socketDidDisconnectWithError:%@", sock, err);
    if(err){
        if(self.retryTimes4netWorkBreaken++ < _reconnectCount && !self.isReconnecting){
            _isConnected = NO;
            _isConnecting = NO;
            _isReconnecting = YES;
            
            [self.socket disconnect];
            ///< 连接超时
            if(err.code == 3){
                if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
                    [self.delegate socketStatus:self status:LFLiveError];
                }
                if(self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]){
                    [self.delegate socketDidError:self errorCode:LFLiveSocketError_ConnectSocket];
                }
                return;
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reconnectInterval * NSEC_PER_SEC)), self.socketQueue, ^{
                [self reconnect];
            });
            
            if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
                [self.delegate socketStatus:self status:LFLivePending];
            }
        }else if(self.retryTimes4netWorkBreaken >= _reconnectCount){
            if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
                [self.delegate socketStatus:self status:LFLiveError];
            }
            if(self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]){
                [self.delegate socketDidError:self errorCode:LFLiveSocketError_ReConnectTimeOut];
            }
        }
    }else{
        [self clean];
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
            [self.delegate socketStatus:self status:LFLiveStop];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    if(tag > 0){
        self.isSending = NO;
        [self sendFrame];
    }
}

#pragma mark --BufferDelegate
- (void)streamingBuffer:(nullable LFStreamingBuffer*)buffer bufferState:(LFLiveBuffferState)state{
    if(self.isConnected){
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketBufferStatus:status:)]){
            [self.delegate socketBufferStatus:self status:state];
        }
    }
}

#pragma mark -- Getter Setter
- (dispatch_queue_t)socketQueue{
    if(!_socketQueue){
        _socketQueue = dispatch_queue_create("com.youku.LaiFeng.live.socketQueue", NULL);
    }
    return _socketQueue;
}

- (GCDAsyncSocket*)socket{
    if(!_socket){
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue socketQueue:self.socketQueue];
    }
    return _socket;
}

- (LFStreamingBuffer*)buffer{
    if(!_buffer){
        _buffer = [[LFStreamingBuffer alloc] init];
        _buffer.delegate = self;
    }
    return _buffer;
}

- (id<LFStreamPackage>)package{
    if(!_package){
        _package = [[LFFlvPackage alloc] initWithVideoSize:self.videoSize];
    }
    return _package;
}

- (LFLiveDebug*)debugInfo{
    if(!_debugInfo){
        _debugInfo = [[LFLiveDebug alloc] init];
    }
    return _debugInfo;
}

#pragma mark -- 服务器验证
- (NSData*)verificationData{
    /**  结构体专为NSData **/
    if(!self.stream) return nil;
    #warning TODO send verficationData to server
    return nil;
}

- (BOOL)verificationDataValid:(NSData*)data{
    /**  NSData专为结构体 **/
    if(!self.stream) return NO;
    if(!data) return NO;
    #warning TODO server give client data,verification
    return NO;
}


@end
