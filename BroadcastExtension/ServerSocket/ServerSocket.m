//
//  ServerSocket.m
//  BroadcastExtension
//
//  Created by Marta Korol on 20.07.2021.
//

#import "ServerSocket.h"
#import <sys/socket.h>
#import <sys/un.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <SystemConfiguration/SCNetworkReachability.h>

NSString * const socketIndexKey = @"binded_socket_index";
int const packetSize = 8192;
static NSTimeInterval const kDefaultConnectionTimeout = 2.0f;
static NSUInteger const kMaxBindAttemptsCount = 1000;

typedef struct {
    dispatch_fd_t socket;
    int index;
} BindedSocketInfo;


@interface ServerSocket() {
    dispatch_source_t listeningSource;
}

@property (assign) dispatch_fd_t socket;
@property (assign) dispatch_fd_t clientSocket;
@property (strong, nonatomic) NSString *appGroupIdentifier;
@property (strong, nonatomic) NSUserDefaults *sharedUserDefaults;

@end

@implementation ServerSocket

- (instancetype)initWithApplicationGroupIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _appGroupIdentifier = identifier;
        _sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:identifier];
        _socket = 0;
        _clientSocket = 0;
        _connectionTimeout = kDefaultConnectionTimeout;
    }
    return self;
}

- (BOOL)startServerWithClientConnectCallback:(ClientConnectCallback)callback {
    BindedSocketInfo bindedSocket = [self bindedSocket:0];
    if (bindedSocket.socket == 0) {
        return NO;
    }
    
    self.socket = bindedSocket.socket;
    [self.sharedUserDefaults setInteger:bindedSocket.index forKey:socketIndexKey];
    [self.sharedUserDefaults synchronize];
    
    listen(self.socket, SOMAXCONN);
    
    [self cleanupExistingDataBeforeUsage];
    
    dispatch_queue_t q = dispatch_get_global_queue(0, 0);
    listeningSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, self.socket, 0,  q);
    dispatch_source_set_event_handler(listeningSource, ^ {
        struct sockaddr client_addr;
        socklen_t client_addrlen = sizeof(client_addr);
        self.clientSocket = accept(self.socket, &client_addr, &client_addrlen);
        callback(false);
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.connectionTimeout * NSEC_PER_SEC)), q, ^{
        if (self.clientSocket > 0) {
            return;
        }
        callback(true);
    });
    
    dispatch_resume(listeningSource);
    
    return YES;
}

- (void)terminateConnection {
    if (self.socket > 0) {
        close(self.socket);
    }
    self.socket = 0;
    if (self.clientSocket > 0) {
        close(self.clientSocket);
    }
    self.clientSocket = 0;
}

- (void)sendData:(NSData *)data firstPacketSentCallback:(void(^)(void))callback {
    if (![self isSocketsAlive]) {
        return;
    }
    
    int packetsNum = (int)ceil((double)data.length/packetSize);
    dispatch_fd_t receiverSocket = self.clientSocket;
    for (int i = 0; i < packetsNum; i++) {
        @autoreleasepool {
            int location = i*packetSize;
            int currentPacketLength = (int)MIN(data.length - location, packetSize);
            NSData *packet = [data subdataWithRange:NSMakeRange(location, currentPacketLength)];
            write(receiverSocket, packet.bytes, packet.length);
            if (i == 0) {
                callback();
            }
        }
    }
}

- (void)cleanupExistingDataBeforeUsage {
    char bufferRead[packetSize];
    while (read(self.socket, bufferRead, packetSize/16) > 0) {
        [self.logsHandler log:@"Draining"];
    }
}

- (BindedSocketInfo)bindedSocket:(int)index {
    if (index > kMaxBindAttemptsCount) {
        return (BindedSocketInfo){ .socket = 0, .index = 0 };
    }
    
    NSURL *groupContainerURL = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.appGroupIdentifier];
    if (groupContainerURL == nil) {
        return (BindedSocketInfo){ .socket = 0, .index = 0 };
    }
    
    NSURL *socketURL = [groupContainerURL URLByAppendingPathComponent:[NSString stringWithFormat:@"socket_%i", index]];
    
    dispatch_fd_t fd = socket(AF_UNIX, SOCK_STREAM, 0);
    
    struct sockaddr_un addr;
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, socketURL.fileSystemRepresentation, sizeof(addr.sun_path));
    addr.sun_len = SUN_LEN(&addr);
    unlink(addr.sun_path);
    
    int len = (int)strlen(addr.sun_path) + sizeof(addr.sun_family);
    
    if (bind(fd, (struct sockaddr *)&addr, len) < 0) {
        perror("unix bind");
        close(fd);
        return [self bindedSocket:index + 1];
    } else {
        return (BindedSocketInfo){ .socket = fd, .index = index };
    }
}

- (BOOL)isSocketsAlive {
    return (self.socket > 0) && (self.clientSocket > 0);
}

@end
