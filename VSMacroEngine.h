#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VSMacroEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableDictionary *> *recordedSteps;

+ (instancetype)sharedEngine;
- (void)setupFloatingUI;
- (void)startRecording;
- (void)stopRecordingAndSave;
- (void)playCurrentMacro;
- (void)stopPlayback;
- (void)showMainMenu;

// Phương thức nhận sự kiện từ Hook
- (void)processCapturedEvent:(UIEvent *)event;
- (void)recordControlAction:(NSString *)selectorName target:(id)target control:(UIControl *)control;

// Tiện ích UI an toàn đa luồng
+ (UIWindow * _Nullable)findAppKeyWindow;
+ (void)presentAlertOnTop:(UIAlertController *)alert;

@end

NS_ASSUME_NONNULL_END
