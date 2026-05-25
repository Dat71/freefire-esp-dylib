// ESP Free Fire cho iOS
// Dùng cho GitHub Actions compile

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FreeFireESP : NSObject
@end

@implementation FreeFireESP

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[FREE FIRE ESP] Da khoi dong!");
        
        // Tạo thông báo
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"FREE FIRE ESP" 
            message:@"ESP da duoc kich hoat!\nNhan Volume Up de mo menu" 
            preferredStyle:UIAlertControllerStyleAlert];
        
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 100;
        window.hidden = NO;
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    });
}

@end

__attribute__((constructor))
static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [FreeFireESP new];
    });
}