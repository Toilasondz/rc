#import "VSMacroEngine.h"

// 1. Can thiệp luồng phát tán sự kiện chạm
%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;
    @autoreleasepool {
        [[VSMacroEngine sharedEngine] processCapturedEvent:event];
    }
}

%end

// 2. Can thiệp luồng Action Control
%hook UIControl

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    %orig;
    @autoreleasepool {
        if ([VSMacroEngine sharedEngine].isRecording) {
            [[VSMacroEngine sharedEngine] recordControlAction:NSStringFromSelector(action)
                                                       target:target
                                                      control:self];
        }
    }
}

%end

// 3. Khởi tạo trễ an toàn sau 2.5s khi App đã sẵn sàng
%ctor {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[VSMacroEngine sharedEngine] setupFloatingUI];
            });
        }];
    }
}
