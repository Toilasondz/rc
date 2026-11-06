#import "VSFloatingButton.h"
#import <QuartzCore/QuartzCore.h>

@interface VSFloatingButton ()
@property (nonatomic, assign, readwrite) VSButtonMode currentMode;
@end

@implementation VSFloatingButton

- (instancetype)initWithInitialFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.clipsToBounds = NO;

        // Đổ bóng (Shadow)
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0.0, 3.0);
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowRadius = 4.0;
        self.layer.borderWidth = 2.0;
        self.layer.borderColor = [UIColor whiteColor].CGColor;

        // Cử chỉ kéo thả (Pan)
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];

        // Cử chỉ chạm (Tap)
        [self addTarget:self action:@selector(buttonAction) forControlEvents:UIControlEventTouchUpInside];

        [self switchMode:VSButtonModeIdle];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *btn = pan.view;
    CGPoint translation = [pan translationInView:btn.superview];

    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        btn.center = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
        [pan setTranslation:CGPointZero inView:btn.superview];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // Tự động hít dính nhẹ về mép màn hình gần nhất
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat padding = 12.0;
        CGFloat targetX = (btn.center.x < screen.size.width / 2.0) ? (btn.bounds.size.width / 2.0 + padding) : (screen.size.width - btn.bounds.size.width / 2.0 - padding);
        CGFloat targetY = MIN(MAX(btn.center.y, btn.bounds.size.height / 2.0 + 44.0), screen.size.height - btn.bounds.size.height / 2.0 - 44.0);

        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            btn.center = CGPointMake(targetX, targetY);
        } completion:nil];
    }
}

- (void)buttonAction {
    if ([self.delegate respondsToSelector:@selector(floatingButtonDidTapped)]) {
        [self.delegate floatingButtonDidTapped];
    }
}

- (void)switchMode:(VSButtonMode)mode {
    self.currentMode = mode;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layer removeAllAnimations];
        self.alpha = 1.0;

        switch (mode) {
            case VSButtonModeIdle:
                self.backgroundColor = [UIColor colorWithRed:0.18 green:0.80 blue:0.44 alpha:0.95];
                [self setTitle:@"REC" forState:UIControlStateNormal];
                self.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
                break;

            case VSButtonModeRecording:
                self.backgroundColor = [UIColor colorWithRed:0.92 green:0.23 blue:0.23 alpha:0.95];
                [self setTitle:@"STOP" forState:UIControlStateNormal];
                self.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
                [UIView animateWithDuration:0.55 delay:0.0
                                    options:(UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction)
                                 animations:^{ self.alpha = 0.35; } completion:nil];
                break;

            case VSButtonModePlaying:
                self.backgroundColor = [UIColor colorWithRed:0.11 green:0.63 blue:0.95 alpha:0.95];
                [self setTitle:@"PLAY" forState:UIControlStateNormal];
                self.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
                break;
        }
    });
}

@end
