#import "VSPassthroughWindow.h"

@implementation VSPassthroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    // Bỏ qua chính Window hoặc rootViewController view để cử chỉ đi xuyên thấu vào VideoStar
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}

@end
