//
//  ClientSocket.m
//  BroadcastExtension
//
//  Created by Marta Korol on 20.07.2021.
//

#import <sys/socket.h>
#import <sys/un.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import "ClientSocket.h"

NSString * const socketIndexKey = @"binded_socket_index";
int const packetSize = 8192;

static const NSTimeInterval kTerminateDelay = 2;

@interface ClientSocket()

@property (assign) dispatch_fd_t socket;

@property (strong, nonatomic) NSString *appGroupIdentifier;
@property (strong, nonatomic) NSUserDefaults *sharedUserDefaults;

@end

@implementation ClientSocket

- (instancetype)initWithApplicationGroupIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _appGroupIdentifier = identifier;
        _sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:identifier];
        _socket = 0;
    }
    return self;
}


- (void)connectToServer {
    NSURL *urls =  [[NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.appGroupIdentifier] URLByAppendingPathComponent:[NSString stringWithFormat:@"socket_%li", (long)[self.sharedUserDefaults integerForKey:socketIndexKey]]];
    
    dispatch_fd_t fd = socket(AF_UNIX, SOCK_STREAM, 0);
    
    struct sockaddr_un addr;
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, urls.fileSystemRepresentation, sizeof(addr.sun_path));
    addr.sun_len = SUN_LEN(&addr);
    
    int len = (int)strlen(addr.sun_path) + sizeof(addr.sun_family);
    if (connect(fd, (struct sockaddr *)&addr, len) < 0) {
        perror("unix bind");
    } else {
        self.socket = fd;
    }
}

- (void)terminateConnectionAfterDelay:(BOOL)shouldDelay {
    if (![self isSocketAlive]) {
        return;
    }
    
    dispatch_fd_t socket = self.socket;
    void (^closeBlock)(void) = ^() {
        close(socket);
    };
    
    shutdown(self.socket, SHUT_RDWR);
    self.socket = 0;
    
    if (shouldDelay) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kTerminateDelay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            closeBlock();
        });
    } else {
        closeBlock();
    }
}

- (void)terminateConnection {
    [self terminateConnectionAfterDelay:YES];
}

- (NSData *)read:(int)size  {
    if (![self isSocketAlive]) {
        return NULL;
    }
    
    dispatch_fd_t providerSocket = self.socket;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:size];
    @autoreleasepool {
        while (data.length < size) {
            int currentPacketSize = (int)MIN((size - data.length), packetSize);
            char bufferRead[currentPacketSize];
            read(providerSocket, bufferRead, currentPacketSize);
            [data appendBytes:bufferRead length:currentPacketSize];
        }
    }
    return data;
}

- (BOOL)isSocketAlive {
    return self.socket > 0;
}

@end
