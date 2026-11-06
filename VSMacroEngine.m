#import "VSMacroEngine.h"
#import "VSPassthroughWindow.h"
#import "VSFloatingButton.h"

@interface VSMacroEngine () <VSFloatingButtonDelegate>

@property (nonatomic, strong) VSPassthroughWindow *floatingWindow;
@property (nonatomic, strong) VSFloatingButton *floatingButton;
@property (nonatomic, strong, readwrite) NSMutableArray<NSMutableDictionary *> *recordedSteps;
@property (nonatomic, assign, readwrite) BOOL isRecording;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign) NSTimeInterval lastStepTime;
@property (nonatomic, assign) NSUInteger currentReplayIndex;
@property (nonatomic, copy) NSString *macroDirectory;

@end

@implementation VSMacroEngine

+ (instancetype)sharedEngine {
    static VSMacroEngine *engine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        engine = [[VSMacroEngine alloc] init];
    });
    return engine;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordedSteps = [NSMutableArray array];
        _isRecording = NO;
        _isPlaying = NO;
        _lastStepTime = 0.0;
        _currentReplayIndex = 0;

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _macroDirectory = [[paths firstObject] stringByAppendingPathComponent:@"VideoStarMacros"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_macroDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return self;
}

+ (UIWindow *)findAppKeyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow && ![w isKindOfClass:[VSPassthroughWindow class]]) return w;
                }
            }
        }
    }
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow && ![w isKindOfClass:[VSPassthroughWindow class]]) return w;
    }
    return [UIApplication sharedApplication].keyWindow;
}

+ (void)presentAlertOnTop:(UIAlertController *)alert {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = [self findAppKeyWindow];
        UIViewController *top = win.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        if (top) {
            if (alert.popoverPresentationController) {
                alert.popoverPresentationController.sourceView = top.view;
                alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 0, 0);
                alert.popoverPresentationController.permittedArrowDirections = 0;
            }
            [top presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void)setupFloatingUI {
    if (self.floatingWindow) return;

    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive && [s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
    }

    self.floatingWindow = scene ? [[VSPassthroughWindow alloc] initWithWindowScene:scene] : [[VSPassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.floatingWindow.windowLevel = UIWindowLevelAlert + 100.0;
    self.floatingWindow.backgroundColor = [UIColor clearColor];

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    self.floatingWindow.rootViewController = vc;

    self.floatingButton = [[VSFloatingButton alloc] initWithInitialFrame:CGRectMake(20, 140, 58, 58)];
    self.floatingButton.delegate = self;
    [vc.view addSubview:self.floatingButton];

    self.floatingWindow.hidden = NO;
}

- (void)floatingButtonDidTapped {
    if (self.isRecording) {
        [self stopRecordingAndSave];
        return;
    }
    if (self.isPlaying) {
        [self stopPlayback];
        return;
    }
    [self showMainMenu];
}

- (void)showMainMenu {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"⭐ VideoStar Macro" message:@"Bảng điều khiển tự động hóa" preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🔴 Bắt đầu Ghi (Record)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self startRecording];
    }]];

    if (self.recordedSteps.count > 0) {
        NSString *title = [NSString stringWithFormat:@"▶️ Phát Lại Bước Đã Ghi (%lu bước)", (unsigned long)self.recordedSteps.count];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self playCurrentMacro];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"📂 Quản lý Kịch Bản / Export JSON" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showScriptManager];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [VSMacroEngine presentAlertOnTop:sheet];
}

- (void)startRecording {
    [self.recordedSteps removeAllObjects];
    self.isRecording = YES;
    self.isPlaying = NO;
    self.lastStepTime = [NSDate timeIntervalSinceReferenceDate];
    [self.floatingButton switchMode:VSButtonModeRecording];
}

- (void)processCapturedEvent:(UIEvent *)event {
    if (!self.isRecording || event.type != UIEventTypeTouches) return;
    UITouch *touch = [[event allTouches] anyObject];
    if (!touch || touch.window == self.floatingWindow) return;
    if (touch.phase != UITouchPhaseBegan && touch.phase != UITouchPhaseEnded) return;

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval delay = (self.lastStepTime > 0) ? (now - self.lastStepTime) : 0.0;
    self.lastStepTime = now;

    UIWindow *win = touch.window ?: [VSMacroEngine findAppKeyWindow];
    CGSize winSize = win ? win.bounds.size : [UIScreen mainScreen].bounds.size;
    CGPoint loc = [touch locationInView:win];

    NSMutableDictionary *step = [NSMutableDictionary dictionary];
    step[@"phase"] = (touch.phase == UITouchPhaseBegan) ? @"TouchDown" : @"TouchUp";
    step[@"delay"] = @(delay);
    step[@"normX"] = @(winSize.width > 0 ? (loc.x / winSize.width) : 0.0);
    step[@"normY"] = @(winSize.height > 0 ? (loc.y / winSize.height) : 0.0);
    step[@"targetClass"] = NSStringFromClass([touch.view class]) ?: @"Unknown";

    @synchronized (self.recordedSteps) {
        [self.recordedSteps addObject:step];
    }
}

- (void)recordControlAction:(NSString *)selectorName target:(id)target control:(UIControl *)control {
    if (!self.isRecording || control.window == self.floatingWindow) return;

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval delay = (self.lastStepTime > 0) ? (now - self.lastStepTime) : 0.0;
    self.lastStepTime = now;

    NSMutableDictionary *step = [NSMutableDictionary dictionary];
    step[@"phase"] = @"ControlAction";
    step[@"delay"] = @(delay);
    step[@"selector"] = selectorName ?: @"";
    step[@"targetClass"] = NSStringFromClass([target class]) ?: @"";

    @synchronized (self.recordedSteps) {
        [self.recordedSteps addObject:step];
    }
}

- (void)stopRecordingAndSave {
    self.isRecording = NO;
    [self.floatingButton switchMode:VSButtonModeIdle];
    if (self.recordedSteps.count == 0) return;

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *fileName = [NSString stringWithFormat:@"Macro_%@.json", [df stringFromDate:[NSDate date]]];
    NSString *filePath = [self.macroDirectory stringByAppendingPathComponent:fileName];

    NSData *data = [NSJSONSerialization dataWithJSONObject:self.recordedSteps options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:filePath atomically:YES];

    UIAlertController *ok = [UIAlertController alertControllerWithTitle:@"🎉 Đã Lưu Kịch Bản"
                                                                message:[NSString stringWithFormat:@"File: %@", fileName]
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ok addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [VSMacroEngine presentAlertOnTop:ok];
}

- (void)playCurrentMacro {
    if (self.recordedSteps.count == 0) return;
    self.isPlaying = YES;
    self.currentReplayIndex = 0;
    [self.floatingButton switchMode:VSButtonModePlaying];
    [self replayNextStep];
}

- (void)stopPlayback {
    self.isPlaying = NO;
    self.currentReplayIndex = 0;
    [self.floatingButton switchMode:VSButtonModeIdle];
}

- (void)replayNextStep {
    if (!self.isPlaying || self.currentReplayIndex >= self.recordedSteps.count) {
        [self stopPlayback];
        return;
    }

    NSDictionary *step = self.recordedSteps[self.currentReplayIndex];
    NSTimeInterval delay = MAX([step[@"delay"] doubleValue], 0.08);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isPlaying) return;

        UIWindow *win = [VSMacroEngine findAppKeyWindow];
        if (win) {
            if ([step[@"phase"] isEqualToString:@"ControlAction"]) {
                SEL act = NSSelectorFromString(step[@"selector"]);
                [[UIApplication sharedApplication] sendAction:act to:nil from:nil forEvent:nil];
            } else {
                CGFloat x = [step[@"normX"] doubleValue] * win.bounds.size.width;
                CGFloat y = [step[@"normY"] doubleValue] * win.bounds.size.height;
                UIView *view = [win hitTest:CGPointMake(x, y) withEvent:nil];
                if ([view isKindOfClass:[UIControl class]] && [step[@"phase"] isEqualToString:@"TouchUp"]) {
                    [(UIControl *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
                }
            }
        }

        self.currentReplayIndex++;
        [self replayNextStep];
    });
}

- (void)showScriptManager {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.macroDirectory error:nil];
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Danh sách Kịch Bản" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *f in files) {
        if ([f hasSuffix:@".json"]) {
            [picker addAction:[UIAlertAction actionWithTitle:f style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *p = [self.macroDirectory stringByAppendingPathComponent:f];
                NSData *d = [NSData dataWithContentsOfFile:p];
                NSArray *loaded = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                [self.recordedSteps removeAllObjects];
                [self.recordedSteps addObjectsFromArray:loaded];
                [self playCurrentMacro];
            }]];
        }
    }
    [picker addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [VSMacroEngine presentAlertOnTop:picker];
}

@end
