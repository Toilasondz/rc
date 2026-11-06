#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, VSButtonMode) {
    VSButtonModeIdle = 0,       // Trạng thái chờ: Nút xanh lá - "REC"
    VSButtonModeRecording = 1,  // Trạng thái ghi: Nút đỏ nhấp nháy - "STOP"
    VSButtonModePlaying = 2     // Trạng thái tự động: Nút xanh dương - "PLAY"
};

NS_ASSUME_NONNULL_BEGIN

@protocol VSFloatingButtonDelegate <NSObject>
- (void)floatingButtonDidTapped;
@end

@interface VSFloatingButton : UIButton

@property (nonatomic, weak) id<VSFloatingButtonDelegate> delegate;
@property (nonatomic, assign, readonly) VSButtonMode currentMode;

- (instancetype)initWithInitialFrame:(CGRect)frame;
- (void)switchMode:(VSButtonMode)mode;

@end

NS_ASSUME_NONNULL_END
