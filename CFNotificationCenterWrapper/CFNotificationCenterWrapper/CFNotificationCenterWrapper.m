//
//  CFNotificationCenterWrapper.m
//  CFNotificationCenterWrapper
//
//  Created by Marta Korol on 25.07.2021.
//

#import "CFNotificationCenterWrapper.h"

typedef NSHashTable<id<CFNotificationCenterWrapperObserver>> WeakObserverList;

void notificationCallback(CFNotificationCenterRef center,
                          void* observer,
                          CFStringRef name,
                          const void* object,
                          CFDictionaryRef userInfo)
{
    [((__bridge CFNotificationCenterWrapper *)observer) handleNotificationWithNameFromCFNotificationCenter:name];
}


@interface CFNotificationCenterWrapper()

@property (strong, nonatomic) NSMutableDictionary<NSString*, WeakObserverList*> *observers;

@end

@implementation CFNotificationCenterWrapper

- (instancetype)init {
    self = [super init];
    if (self) {
        _observers = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc {
    NSDictionary<NSString*, WeakObserverList*> *observers = [self.observers copy];
    for (NSString *notificationName in observers.allKeys) {
        for (id<CFNotificationCenterWrapperObserver> observer in [observers[notificationName] copy]) {
            [self removeObserver:observer forNotificationName:notificationName];
        }
    }
}

- (void)    addObserver:(__autoreleasing id<CFNotificationCenterWrapperObserver>)observer
    forNotificationName:(NSString *)notificationName {
    
    WeakObserverList *objects = [self.observers valueForKey:notificationName];
    if (objects == nil) {
        objects = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge void*)self,
                                        notificationCallback,
                                        (__bridge CFStringRef)notificationName,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    
    [objects addObject:observer];
    [self.observers setObject:objects forKey:notificationName];
}

- (void)removeObserver:(id<CFNotificationCenterWrapperObserver>)observer
   forNotificationName:(NSString *)notificationName {
    
    WeakObserverList *subscribers = self.observers[notificationName];
    if (subscribers == nil) {
        return;
    }
    [subscribers removeObject:observer];
    if (subscribers.count == 0) {
        [self.observers removeObjectForKey:notificationName];
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                           (__bridge void*)self,
                                           (__bridge CFStringRef)notificationName,
                                           NULL);
    }
}

- (void)postNotificationWithName:(NSString *)name {
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center, (__bridge CFStringRef)name, NULL, NULL, TRUE);
}

- (void)handleNotificationWithNameFromCFNotificationCenter:(CFStringRef)name {
    NSHashTable *observers = [[self.observers valueForKey:(__bridge NSString *)name] copy];
    
    for (id<CFNotificationCenterWrapperObserver> observer in observers) {
        [observer onDarwinNotificationWithName:(__bridge NSString *)name];
    }
}

@end

