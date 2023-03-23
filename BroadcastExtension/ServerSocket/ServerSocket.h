//
//  ServerSocket.h
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 20.07.2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LogsHandler <NSObject>

- (void)log:(nonnull NSString *)string;

@end

typedef void (^ClientConnectCallback)(bool timeout);

@interface ServerSocket : NSObject

@property (weak, nonatomic) id<LogsHandler> logsHandler;
@property (assign, nonatomic) NSTimeInterval connectionTimeout;
@property (assign, nonatomic, readonly) BOOL isSocketsAlive;

- (instancetype _Nonnull)initWithApplicationGroupIdentifier:(NSString *)identifier;

- (BOOL)startServerWithClientConnectCallback:(ClientConnectCallback)callback;
- (void)terminateConnection;

- (void)sendData:(NSData *)data firstPacketSentCallback:(void(^)(void))callback;

@end
NS_ASSUME_NONNULL_END
