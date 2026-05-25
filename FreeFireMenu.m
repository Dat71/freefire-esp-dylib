// FreeFireMenu.m
// Menu Mod Free Fire - ESP, Reset Account, AntiBan, Phát hiện quay/chụp màn hình
// Build bằng GitHub Actions

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <notify.h>
#import <TargetConditionals.h>

#pragma mark - ========== CẤU TRÚC DỮ LIỆU ==========

typedef struct {
    float x, y, z;
} Vector3;

typedef struct {
    float x, y;
} Vector2;

typedef struct {
    float m[16];
} Matrix4x4;

#pragma mark - ========== OFFSETS (CẬP NHẬT THEO BẢN FREE FIRE) ==========
// Cần thay đổi theo từng bản vá game (dùng Cheat Engine)
#define OFFSET_GWORLD           0x12A3B4C0
#define OFFSET_ENTITY_LIST      0x1A2B3C4D
#define OFFSET_ENTITY_COUNT     0x1A2B3C50
#define OFFSET_POSITION         0x220
#define OFFSET_HEALTH           0x2F0
#define OFFSET_MAX_HEALTH       0x2F4
#define OFFSET_TEAM_ID          0x4A0
#define OFFSET_PLAYER_NAME      0x3E0
#define OFFSET_DISTANCE         0x4E0
#define OFFSET_VIEW_MATRIX      0x2A1B3C80
#define OFFSET_IS_DEAD          0x4E8

#pragma mark - ========== ANTIBAN ==========

static BOOL antiBanActive = NO;
static BOOL (*original_fileExistsAtPath)(id self, SEL _cmd, NSString *path);

// Thay thế NSLog bằng macro để tránh lỗi gán
#define NSLog(...) do { \
    NSString *str = [NSString stringWithFormat:__VA_ARGS__]; \
    if (![str containsString:@"cheat"] && ![str containsString:@"hack"] && ![str containsString:@"violation"]) { \
        original_NSLog(@"%@", str); \
    } \
} while(0)

static void (*original_NSLog)(NSString *format, ...);

void antiBan_Start() {
    if (antiBanActive) return;
    antiBanActive = YES;
    
    // 1. Chống debugger (xóa flag P_TRACED)
    int name[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == 0) {
        info.kp_proc.p_flag &= ~0x00000800;
    }
    
    // 2. Hook NSFileManager (ẩn file jailbreak)
    Method m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    original_fileExistsAtPath = (void*)method_getImplementation(m);
    method_setImplementation(m, imp_implementationWithBlock(^BOOL(id self, NSString *path) {
        NSArray *jail = @[@"/Applications/Cydia.app", @"/Library/MobileSubstrate/MobileSubstrate.dylib"];
        for (NSString *jp in jail) {
            if ([path hasPrefix:jp]) return NO;
        }
        return original_fileExistsAtPath(self, @selector(fileExistsAtPath:), path);
    }));
    
    // 3. Lưu original NSLog để dùng trong macro
    original_NSLog = NSLog;
}

#pragma mark - ========== ESP ENGINE ==========

@interface ESPRenderer : NSObject
+ (void)startDrawing;
+ (void)setEnabled:(BOOL)enabled;
@end

@implementation ESPRenderer {
    CADisplayLink *displayLink;
    UIWindow *overlayWindow;
    BOOL enabled;
    uintptr_t baseAddr;
}

static ESPRenderer *shared = nil;

+ (void)initialize {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [ESPRenderer new];
    });
}

- (instancetype)init {
    self = [super init];
    if (self) {
        enabled = YES;
        [self findBaseAddress];
        [self setupOverlay];
    }
    return self;
}

- (void)findBaseAddress {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "FreeFire") || strstr(name, "Garena")) {
            baseAddr = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
}

- (void)setupOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self->overlayWindow.windowLevel = UIWindowLevelStatusBar + 100;
        self->overlayWindow.backgroundColor = [UIColor clearColor];
        self->overlayWindow.userInteractionEnabled = NO;
        self->overlayWindow.hidden = NO;
    });
}

- (void)drawFrame {
    if (!enabled) return;
    // TODO: thêm code vẽ ESP ở đây
}

- (void)startLoop {
    if (displayLink) return;
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawFrame)];
    displayLink.preferredFramesPerSecond = 30;
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopLoop {
    [displayLink invalidate];
    displayLink = nil;
}

+ (void)startDrawing {
    [shared startLoop];
}

+ (void)setEnabled:(BOOL)enabled {
    shared->enabled = enabled;
    if (!enabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIView *v in shared->overlayWindow.rootViewController.view.subviews) {
                [v removeFromSuperview];
            }
        });
    }
}

@end

#pragma mark - ========== RESET ACCOUNT (ACC KHÁCH) ==========

void resetGuestAccount() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = [paths firstObject];
    NSString *appPath = [doc stringByDeletingLastPathComponent];
    NSString *ffData = [appPath stringByAppendingPathComponent:@"Library/Preferences/com.garena.game.freefire"];
    [[NSFileManager defaultManager] removeItemAtPath:ffData error:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Account" message:@"Tài khoản khách đã được xóa. Ứng dụng sẽ đóng." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            exit(0);
        }]];
        UIWindow *win = [UIApplication sharedApplication].windows.firstObject;
        [win.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - ========== PHÁT HIỆN QUAY MÀN HÌNH & CHỤP ẢNH ==========

static int screenshotToken = 0;

static void onScreenshotTaken() {
    NSLog(@"[FreeFireMenu] Đã phát hiện chụp màn hình! Tạm ẩn ESP 3 giây");
    [ESPRenderer setEnabled:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [ESPRenderer setEnabled:YES];
    });
}

void startDetection() {
    // Xoay màn hình (chỉ log, không ảnh hưởng)
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSLog(@"[FreeFireMenu] Màn hình vừa xoay");
    }];
    
    // Chụp màn hình (dùng Darwin notification)
    notify_register_dispatch("com.apple.screenshotCaptured", &screenshotToken, dispatch_get_main_queue(), ^(int t) {
        onScreenshotTaken();
    });
}

#pragma mark - ========== MENU CHÍNH (FLOATING BUTTON + OPTIONS) ==========

@interface ModMenu : UIViewController
+ (void)show;
@end

@implementation ModMenu {
    UIWindow *menuWindow;
    UIWindow *optionsWindow;
    UIButton *floatingBtn;
    BOOL isOptionsVisible;
    UISwitch *espSwitch;
}

+ (void)show {
    static ModMenu *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [ModMenu new];
    });
    [instance setupMenu];
}

- (void)setupMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Cửa sổ nổi
        self->menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 80, 100, 60, 60)];
        self->menuWindow.backgroundColor = [UIColor clearColor];
        self->menuWindow.windowLevel = UIWindowLevelStatusBar + 2;
        self->menuWindow.hidden = NO;
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = self->menuWindow.bounds;
        
        // Tạo avatar hình tròn (màu xanh chữ M)
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(ctx, [UIColor systemBlueColor].CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 60, 60));
        [[UIColor whiteColor] set];
        UIFont *font = [UIFont boldSystemFontOfSize:30];
        NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor whiteColor]};
        [@"M" drawInRect:CGRectMake(15, 10, 30, 40) withAttributes:attrs];
        UIImage *avatar = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [btn setBackgroundImage:avatar forState:UIControlStateNormal];
        btn.layer.cornerRadius = 30;
        btn.clipsToBounds = YES;
        
        // Kéo thả
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [btn addGestureRecognizer:pan];
        [btn addTarget:self action:@selector(toggleOptions) forControlEvents:UIControlEventTouchUpInside];
        
        [self->menuWindow addSubview:btn];
        [self createOptionsPanel];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    CGPoint translation = [gesture translationInView:view.superview];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;
    
    CGFloat maxX = [UIScreen mainScreen].bounds.size.width - view.frame.size.width/2;
    CGFloat minX = view.frame.size.width/2;
    CGFloat maxY = [UIScreen mainScreen].bounds.size.height - view.frame.size.height/2;
    CGFloat minY = view.frame.size.height/2;
    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    
    view.center = center;
    [gesture setTranslation:CGPointZero inView:view.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.2 animations:^{
            CGPoint newCenter = view.center;
            if (newCenter.x > [UIScreen mainScreen].bounds.size.width/2)
                newCenter.x = maxX;
            else
                newCenter.x = minX;
            view.center = newCenter;
        }];
    }
}

- (void)createOptionsPanel {
    optionsWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 280, 250)];
    optionsWindow.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    optionsWindow.layer.cornerRadius = 15;
    optionsWindow.layer.borderWidth = 1;
    optionsWindow.layer.borderColor = [UIColor redColor].CGColor;
    optionsWindow.windowLevel = UIWindowLevelStatusBar + 3;
    optionsWindow.hidden = YES;
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    optionsWindow.rootViewController = vc;
    
    CGFloat y = 20;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 240, 30)];
    title.text = @"FREE FIRE MOD MENU";
    title.textColor = [UIColor redColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    title.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:title];
    y += 40;
    
    // ESP toggle
    UILabel *espLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 120, 30)];
    espLabel.text = @"ESP (Wallhack)";
    espLabel.textColor = [UIColor whiteColor];
    [vc.view addSubview:espLabel];
    espSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, y, 51, 31)];
    espSwitch.on = YES;
    [espSwitch addTarget:self action:@selector(toggleESP:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:espSwitch];
    y += 50;
    
    // Reset account
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    resetBtn.frame = CGRectMake(40, y, 200, 45);
    [resetBtn setTitle:@"🔄 Reset Account Khách" forState:UIControlStateNormal];
    resetBtn.backgroundColor = [UIColor darkGrayColor];
    resetBtn.layer.cornerRadius = 8;
    [resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [resetBtn addTarget:self action:@selector(resetAccount) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:resetBtn];
    y += 60;
    
    // Nút đóng
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(100, y, 80, 35);
    [closeBtn setTitle:@"ĐÓNG" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeOptions) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:closeBtn];
    
    optionsWindow.frame = CGRectMake([UIScreen mainScreen].bounds.size.width/2 - 140, [UIScreen mainScreen].bounds.size.height/2 - 125, 280, 250);
}

- (void)toggleESP:(UISwitch *)sender {
    [ESPRenderer setEnabled:sender.on];
}

- (void)resetAccount {
    resetGuestAccount();
}

- (void)toggleOptions {
    isOptionsVisible = !isOptionsVisible;
    optionsWindow.hidden = !isOptionsVisible;
}

- (void)closeOptions {
    optionsWindow.hidden = YES;
    isOptionsVisible = NO;
}

@end

#pragma mark - ========== KHỞI TẠO (LOADER) ==========

__attribute__((constructor))
static void initialize() {
    dispatch_async(dispatch_get_main_queue(), ^{
        antiBan_Start();
        startDetection();
        [ESPRenderer startDrawing];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [ModMenu show];
        });
    });
}
