//
//  CFNotificationCenterWrapper.h
//  CFNotificationCenterWrapper
//
//  Created by Marta Korol on 25.07.2021.
//

#import <UIKit/UIKit.h>

//! Project version number for CFNotificationCenterWrapper.
FOUNDATION_EXPORT double CFNotificationCenterWrapperVersionNumber;

//! Project version string for CFNotificationCenterWrapper.
FOUNDATION_EXPORT const unsigned char CFNotificationCenterWrapperVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <CFNotificationCenterWrapper/PublicHeader.h>

@protocol CFNotificationCenterWrapperObserver

- (void)onDarwinNotificationWithName:(NSString * _Nonnull)name;

@end

@interface CFNotificationCenterWrapper : NSObject

- (void)addObserver:(id<CFNotificationCenterWrapperObserver> _Nonnull)observer forNotificationName:( NSString * _Nonnull )notificationName;
- (void)removeObserver:(id<CFNotificationCenterWrapperObserver> _Nonnull)observer forNotificationName:( NSString * _Nonnull )notificationName;
- (void)postNotificationWithName:( NSString * _Nonnull )name;

- (void)handleNotificationWithNameFromCFNotificationCenter:(CFStringRef _Nonnull)name;

@end
