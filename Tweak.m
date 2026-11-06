#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "VSMacroEngine.h"

// Con trỏ hàm gốc cho UIApplication -sendEvent:
static void (*orig_UIApplication_sendEvent)(id, SEL, UIEvent *) = NULL;

// Hàm Swizzle bắt cử chỉ cảm ứng của VideoStar
static void custom_UIApplication_sendEvent(UIApplication *self, SEL _cmd, UIEvent *event) {
    if (orig_UIApplication_sendEvent) {
        orig_UIApplication_sendEvent(self, _cmd, event);
    }
    @autoreleasepool {
        [[VSMacroEngine sharedEngine] processCapturedEvent:event];
    }
}

// Con trỏ hàm gốc cho UIControl -sendAction:to:forEvent:
static void (*orig_UIControl_sendAction)(id, SEL, SEL, id, UIEvent *) = NULL;

// Hàm Swizzle bắt sự kiện bấm nút
static void custom_UIControl_sendAction(UIControl *self, SEL _cmd, SEL action, id target, UIEvent *event) {
    if (orig_UIControl_sendAction) {
        orig_UIControl_sendAction(self, _cmd, action, target, event);
    }
    @autoreleasepool {
        if ([VSMacroEngine sharedEngine].isRecording) {
            [[VSMacroEngine sharedEngine] recordControlAction:NSStringFromSelector(action)
                                                       target:target
                                                      control:self];
        }
    }
}

// Constructor nạp cùng ứng dụng
__attribute__((constructor)) static void InitializeVideoStarRecorder(void) {
    @autoreleasepool {
        NSLog(@"[VideoStarRecorder] >>> Dynamic Library Injected Successfully!");

        Method mSendEvent = class_getInstanceMethod([UIApplication class], @selector(sendEvent:));
        if (mSendEvent) {
            orig_UIApplication_sendEvent = (void (*)(id, SEL, UIEvent *))method_getImplementation(mSendEvent);
            method_setImplementation(mSendEvent, (IMP)custom_UIApplication_sendEvent);
        }

        Method mSendAction = class_getInstanceMethod([UIControl class], @selector(sendAction:to:forEvent:));
        if (mSendAction) {
            orig_UIControl_sendAction = (void (*)(id, SEL, SEL, id, UIEvent *))method_getImplementation(mSendAction);
            method_setImplementation(mSendAction, (IMP)custom_UIControl_sendAction);
        }

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[VSMacroEngine sharedEngine] setupFloatingUI];
                NSLog(@"[VideoStarRecorder] >>> Floating UI Controller Ready!");
            });
        }];
    }
}
