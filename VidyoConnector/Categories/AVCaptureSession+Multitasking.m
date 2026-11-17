//
//  AVCaptureSession+Multitasking.m
//  VidyoConnector
//
//  System PiP helper (iOS 16+): swizzle AVCaptureSession.startRunning so any session the
//  Vidyo SDK starts gets isMultitaskingCameraAccessEnabled = YES when supported.
//  That allows the local camera to keep capturing while the app is backgrounded and the
//  System PiP window is showing. Safe to omit if you do not need local camera in PiP.
//

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@implementation AVCaptureSession (VidyoMultitasking)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [AVCaptureSession class];
        SEL originalSEL = @selector(startRunning);
        SEL swizzledSEL = @selector(vidyo_swizzledStartRunning);
        Method originalMethod = class_getInstanceMethod(cls, originalSEL);
        Method swizzledMethod = class_getInstanceMethod(cls, swizzledSEL);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

- (void)vidyo_swizzledStartRunning {
    if (@available(iOS 16.0, *)) {
        if (self.isMultitaskingCameraAccessSupported && !self.isMultitaskingCameraAccessEnabled) {
            self.multitaskingCameraAccessEnabled = YES;
            NSLog(@"[VidyoPiP] enabled isMultitaskingCameraAccessEnabled on AVCaptureSession %p", self);
        }
    }
    // Call the original implementation (after exchange this selector is the original).
    [self vidyo_swizzledStartRunning];
}

@end
