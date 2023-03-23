//
//  ClientSocket.h
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 20.07.2021.
//

#import <Foundation/Foundation.h>

@interface ClientSocket : NSObject

@property (nonatomic, readonly) BOOL isSocketAlive;

- (instancetype _Nonnull)initWithApplicationGroupIdentifier:(NSString * _Nonnull)identifier;

- (void)connectToServer;
- (void)terminateConnection;
- (void)terminateConnectionAfterDelay:(BOOL)shouldDelay;

- (NSData * _Nullable)read:(int)size;

@end
