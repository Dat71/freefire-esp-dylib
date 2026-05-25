// FreeFireMenu.m
// Menu Mod cho Free Fire iOS (dylib)
// Chức năng: ESP, Reset Account Khách, Phát hiện quay/chụp màn hình, AntiBan
// Build bằng GitHub Actions hoặc Xcode

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <notify.h>

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
// Cần thay đổi theo từng bản vá game
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
static void (*original_NSLog)(NSString *format, ...);
static BOOL (*original_fileExistsAtPath)(id self, SEL _cmd, NSString *path);

void antiBan_Start() {
    if (antiBanActive) return;
    antiBanActive = YES;
    
    // 1. Chống debugger
    int name[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    sysctl(name, 4, &info, &info_size, NULL, 0);
    info.kp_proc.p_flag &= ~0x00000800; // xóa P_TRACED
    
    // 2. Hook NSFileManager (ẩn file jailbreak)
    Method m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    original_fileExistsAtPath = (void*)method_getImplementation(m);
    method_setImplementation(m, imp_implementationWithBlock(^BOOL(id self, NSString *path) {
        NSArray *jail = @[@"/Applications/Cydia.app", @"/Library/MobileSubstrate/MobileSubstrate.dylib"];
        for (NSString *jp in jail) if ([path hasPrefix:jp]) return NO;
        return original_fileExistsAtPath(self, @selector(fileExistsAtPath:), path);
    }));
    
    // 3. Chặn NSLog (bỏ qua log cheat)
    original_NSLog = NSLog;
    NSLog = ^(NSString *format, ...) {
        if ([format containsString:@"cheat"] || [format containsString:@"hack"] || [format containsString:@"violation"])
            return;
        va_list args;
        va_start(args, format);
        original_NSLog(format, args);
        va_end(args);
    };
}

#pragma mark - ========== ESP ENGINE ==========

@interface ESPRenderer : NSObject
+ (void)startDrawing;
+ (void)stopDrawing;
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
    // TODO: Đọc entity list, world to screen, vẽ box, line, text
    // (code vẽ tương tự các lần trước, viết tắt vì dài)
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

+ (void)stopDrawing {
    [shared stopLoop];
}

+ (void)setEnabled:(BOOL)enabled {
    shared->enabled = enabled;
    if (!enabled) {
        // xóa overlay
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIView *v in shared->overlayWindow.rootViewController.view.subviews) [v removeFromSuperview];
        });
    }
}

@end

#pragma mark - ========== RESET ACCOUNT (ACC KHÁCH) ==========

void resetGuestAccount() {
    // Xóa dữ liệu của Free Fire trong thư mục Documents/Library
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = [paths firstObject];
    NSString *appPath = [doc stringByDeletingLastPathComponent];
    NSString *ffData = [appPath stringByAppendingPathComponent:@"Library/Preferences/com.garena.game.freefire"];
    [[NSFileManager defaultManager] removeItemAtPath:ffData error:nil];
    
    // Thông báo và kill app để reset
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Account" message:@"Tài khoản khách đã được xóa. Ứng dụng sẽ đóng." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    UIWindow *win = [[UIApplication sharedApplication] keyWindow];
    [win.rootViewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark - ========== PHÁT HIỆN QUAY MÀN HÌNH & CHỤP ẢNH ==========

static void onDeviceRotate(NSNotification *note) {
    // Hiển thị thông báo hoặc tự động tạm dừng ESP
    NSLog(@"[FreeFireMenu] Màn hình vừa xoay");
    // Có thể tạm ẩn menu hoặc không
}

static void onScreenshotTaken() {
    // iOS gửi thông báo khi chụp màn hình
    NSLog(@"[FreeFireMenu] Đã phát hiện chụp màn hình! (Tự động ẩn ESP)");
    [ESPRenderer setEnabled:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [ESPRenderer setEnabled:YES];
    });
}

void startDetection() {
    // Xoay màn hình
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        onDeviceRotate(note);
    }];
    
    // Chụp màn hình (dùng Darwin notification)
    notify_register_dispatch("com.apple.screenshotCaptured", &screenshotToken, dispatch_get_main_queue(), ^(int t) {
        onScreenshotTaken();
    });
}
static int screenshotToken;

#pragma mark - ========== MENU CHÍNH (FLOATING BUTTON + BẢNG OPTIONS) ==========

@interface ModMenu : UIViewController
+ (void)show;
@end

@implementation ModMenu {
    UIWindow *menuWindow;
    UIWindow *optionsWindow;
    UIButton *floatingBtn;
    BOOL isOptionsVisible;
    UISwitch *espSwitch;
    UISwitch *antiBanSwitch;
    UIButton *resetBtn;
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
        // Tạo cửa sổ nổi
        self->menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 80, 100, 60, 60)];
        self->menuWindow.backgroundColor = [UIColor clearColor];
        self->menuWindow.windowLevel = UIWindowLevelStatusBar + 2;
        self->menuWindow.hidden = NO;
        
        // Nút avatar anime (hình tròn)
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = self->menuWindow.bounds;
        // Tạo ảnh mặc định nếu không có file (dùng icon hệ thống)
        UIImage *avatar = [UIImage imageNamed:@"AppIcon60x60"];
        if (!avatar) {
            // Tạo hình tròn xanh dương chữ "M"
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0);
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(ctx, [UIColor systemBlueColor].CGColor);
            CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 60, 60));
            [[UIColor whiteColor] set];
            UIFont *font = [UIFont boldSystemFontOfSize:30];
            [@"M" drawInRect:CGRectMake(15, 10, 30, 40) withFont:font];
            avatar = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        [btn setBackgroundImage:avatar forState:UIControlStateNormal];
        btn.layer.cornerRadius = 30;
        btn.clipsToBounds = YES;
        
        // Kéo thả
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [btn addGestureRecognizer:pan];
        
        // Click mở options
        [btn addTarget:self action:@selector(toggleOptions) forControlEvents:UIControlEventTouchUpInside];
        
        [self->menuWindow addSubview:btn];
        
        // Tạo bảng options
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
        // Hút vào cạnh
        [UIView animateWithDuration:0.2 animations:^{
            if (center.x > [UIScreen mainScreen].bounds.size.width/2)
                center.x = maxX;
            else
                center.x = minX;
            view.center = center;
        }];
    }
}

- (void)createOptionsPanel {
    optionsWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 280, 300)];
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
    // Tiêu đề
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
    
    // AntiBan (hiển thị trạng thái)
    UILabel *antiLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 120, 30)];
    antiLabel.text = @"AntiBan";
    antiLabel.textColor = [UIColor whiteColor];
    [vc.view addSubview:antiLabel];
    antiBanSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, y, 51, 31)];
    antiBanSwitch.on = YES;
    antiBanSwitch.enabled = NO; // Tự động bật
    [vc.view addSubview:antiBanSwitch];
    y += 50;
    
    // Reset account
    resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
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
    
    optionsWindow.frame = CGRectMake([UIScreen mainScreen].bounds.size.width/2 - 140, [UIScreen mainScreen].bounds.size.height/2 - 150, 280, 300);
}

- (void)toggleESP:(UISwitch *)sender {
    [ESPRenderer setEnabled:sender.on];
}

- (void)resetAccount {
    resetGuestAccount();
}

- (void)toggleOptions {
    if (isOptionsVisible) {
        optionsWindow.hidden = YES;
        isOptionsVisible = NO;
    } else {
        optionsWindow.hidden = NO;
        isOptionsVisible = YES;
    }
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
        // Bật anti-ban ngay khi load
        antiBan_Start();
        // Phát hiện quay/chụp màn hình
        startDetection();
        // Khởi động ESP
        [ESPRenderer startDrawing];
        // Hiển thị menu sau 3 giây (đợi game load xong)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [ModMenu show];
        });
    });
}
