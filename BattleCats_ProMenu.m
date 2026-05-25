// BattleCats_ProMenu.m
// Pro Mod Menu với Giao diện Kính mờ, Nền động & Anti-Ban
// Build yêu cầu: -framework UIKit -framework Foundation -framework QuartzCore

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>

#pragma mark - ========== CƠ CHẾ ANTI-BAN (BẢO VỆ TÀI KHOẢN) ==========

static BOOL (*original_fileExistsAtPath)(id self, SEL _cmd, NSString *path);

void setupAntiBan() {
    // 1. Gỡ cờ Debug (Chống Anti-Cheat quét bộ nhớ đang bị can thiệp)
    int name[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    sysctl(name, 4, &info, &info_size, NULL, 0);
    info.kp_proc.p_flag &= ~0x00000800;
    
    // 2. Ẩn toàn bộ dấu vết Jailbreak/Sideload khỏi game
    Method m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    original_fileExistsAtPath = (void*)method_getImplementation(m);
    method_setImplementation(m, imp_implementationWithBlock(^BOOL(id self, NSString *path) {
        NSArray *blacklistedPaths = @[
            @"/Applications/Cydia.app", 
            @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/bin/bash",
            @"/usr/sbin/sshd",
            @"/etc/apt"
        ];
        for (NSString *jailPath in blacklistedPaths) {
            if ([path hasPrefix:jailPath]) return NO; // Ép game tin rằng máy hoàn toàn "sạch"
        }
        return original_fileExistsAtPath(self, @selector(fileExistsAtPath:), path);
    }));
    
    NSLog(@"[ProMenu] Anti-Ban & Stealth Mode đã kích hoạt!");
}

#pragma mark - ========== GIAO DIỆN MENU NỀN ĐỘNG (ANIMATED UI) ==========

@interface ProModMenu : UIViewController
+ (void)showMenu;
@end

@implementation ProModMenu {
    UIWindow *menuWindow;
    UIWindow *panelWindow;
    UIButton *floatingBtn;
    BOOL isPanelVisible;
}

+ (void)showMenu {
    static ProModMenu *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [ProModMenu new];
    });
    [instance setupFloatingButton];
}

- (void)setupFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. Khởi tạo nút nổi (Floating Button)
        self->menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(50, 100, 60, 60)];
        self->menuWindow.backgroundColor = [UIColor clearColor];
        self->menuWindow.windowLevel = UIWindowLevelStatusBar + 1;
        self->menuWindow.hidden = NO;
        
        self->floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self->floatingBtn.frame = self->menuWindow.bounds;
        self->floatingBtn.backgroundColor = [UIColor blackColor];
        self->floatingBtn.layer.cornerRadius = 30;
        self->floatingBtn.layer.borderWidth = 2;
        self->floatingBtn.layer.borderColor = [UIColor cyanColor].CGColor;
        self->floatingBtn.clipsToBounds = YES;
        
        // Thêm biểu tượng hoặc chữ cho nút nổi
        [self->floatingBtn setTitle:@"PRO" forState:UIControlStateNormal];
        self->floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        [self->floatingBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
        
        // Cử chỉ kéo thả và nhấn
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
        [self->floatingBtn addGestureRecognizer:pan];
        [self->floatingBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
        
        [self->menuWindow addSubview:self->floatingBtn];
        
        // 2. Khởi tạo Bảng điều khiển (Panel)
        [self setupControlPanel];
    });
}

- (void)setupControlPanel {
    // Cửa sổ Panel chính
    panelWindow = [[UIWindow alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2 - 160, [UIScreen mainScreen].bounds.size.height/2 - 200, 320, 400)];
    panelWindow.backgroundColor = [UIColor clearColor]; // Để trong suốt cho hiệu ứng mờ
    panelWindow.layer.cornerRadius = 20;
    panelWindow.clipsToBounds = YES;
    panelWindow.windowLevel = UIWindowLevelStatusBar + 2;
    panelWindow.hidden = YES;
    
    UIViewController *vc = [[UIViewController alloc] init];
    panelWindow.rootViewController = vc;
    
    // --- HIỆU ỨNG 1: HÌNH NỀN ĐỘNG CHUYỂN MÀU (ANIMATED GRADIENT) ---
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = panelWindow.bounds;
    gradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.1 green:0.0 blue:0.2 alpha:0.8].CGColor, // Tím đen
        (id)[UIColor colorWithRed:0.0 green:0.2 blue:0.4 alpha:0.8].CGColor, // Xanh biển
        (id)[UIColor colorWithRed:0.2 green:0.0 blue:0.1 alpha:0.8].CGColor  // Đỏ mận
    ];
    gradientLayer.startPoint = CGPointMake(0, 0);
    gradientLayer.endPoint = CGPointMake(1, 1);
    
    // Tạo animation cho nền chuyển động liên tục
    CABasicAnimation *colorAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
    colorAnim.toValue = @[
        (id)[UIColor colorWithRed:0.0 green:0.2 blue:0.4 alpha:0.8].CGColor,
        (id)[UIColor colorWithRed:0.2 green:0.0 blue:0.1 alpha:0.8].CGColor,
        (id)[UIColor colorWithRed:0.1 green:0.0 blue:0.2 alpha:0.8].CGColor
    ];
    colorAnim.duration = 4.0; // Tốc độ chuyển màu (giây)
    colorAnim.autoreverses = YES;
    colorAnim.repeatCount = HUGE_VALF; // Chạy vô hạn
    [gradientLayer addAnimation:colorAnim forKey:@"colorChange"];
    [vc.view.layer addSublayer:gradientLayer];
    
    // --- HIỆU ỨNG 2: KÍNH MỜ (GLASSMORPHISM BLUR) ---
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = panelWindow.bounds;
    blurView.alpha = 0.85; // Điều chỉnh độ trong suốt của kính
    [vc.view addSubview:blurView];
    
    // Viền sáng chói (Neon Border)
    panelWindow.layer.borderWidth = 1.5;
    panelWindow.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    
    // --- CÁC THÀNH PHẦN MENU ---
    CGFloat yOffset = 25;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, yOffset, 320, 35)];
    title.text = @"THE BATTLE CATS VIP";
    title.textColor = [UIColor cyanColor];
    title.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:24];
    title.textAlignment = NSTextAlignmentCenter;
    // Hiệu ứng đổ bóng chữ
    title.layer.shadowColor = [UIColor cyanColor].CGColor;
    title.layer.shadowRadius = 5.0;
    title.layer.shadowOpacity = 0.8;
    title.layer.shadowOffset = CGSizeMake(0, 0);
    [vc.view addSubview:title];
    yOffset += 60;
    
    // Các công tắc chức năng
    [self addSwitchItem:@"Max Cat Food (An toàn)" yPos:yOffset view:vc.view target:@selector(toggleFood:)]; yOffset += 55;
    [self addSwitchItem:@"Max XP (99M)" yPos:yOffset view:vc.view target:@selector(toggleXP:)]; yOffset += 55;
    [self addSwitchItem:@"Mở khóa tất cả Mèo" yPos:yOffset view:vc.view target:@selector(toggleCats:)]; yOffset += 65;
    
    // Nút đóng Menu có bo góc và gradient
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(85, yOffset, 150, 40);
    [closeBtn setTitle:@"ĐÓNG MENU" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.4 alpha:0.8];
    closeBtn.layer.cornerRadius = 20;
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:closeBtn];
}

// Hàm hỗ trợ tạo dòng công tắc đẹp mắt
- (void)addSwitchItem:(NSString *)name yPos:(CGFloat)y view:(UIView *)parentView target:(SEL)action {
    UIView *bgRow = [[UIView alloc] initWithFrame:CGRectMake(20, y, 280, 45)];
    bgRow.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    bgRow.layer.cornerRadius = 10;
    [parentView addSubview:bgRow];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 190, 45)];
    label.text = name;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:15];
    [bgRow addSubview:label];
    
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(215, 7, 50, 31)];
    sw.onTintColor = [UIColor cyanColor];
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [bgRow addSubview:sw];
}

// Logic kéo thả mượt mà
- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    CGPoint translation = [gesture translationInView:view.superview];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;
    view.center = center;
    [gesture setTranslation:CGPointZero inView:view.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // Hút vào mép màn hình với animation đàn hồi (spring)
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat destX = (center.x > screenWidth/2) ? screenWidth - 30 : 30;
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            view.center = CGPointMake(destX, center.y);
        } completion:nil];
    }
}

- (void)togglePanel {
    isPanelVisible = !isPanelVisible;
    if (isPanelVisible) {
        panelWindow.hidden = NO;
        panelWindow.transform = CGAffineTransformMakeScale(0.8, 0.8);
        panelWindow.alpha = 0;
        // Animation pop-up xịn xò
        [UIView animateWithDuration:0.3 animations:^{
            self->panelWindow.transform = CGAffineTransformIdentity;
            self->panelWindow.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self->panelWindow.transform = CGAffineTransformMakeScale(0.8, 0.8);
            self->panelWindow.alpha = 0;
        } completion:^(BOOL finished) {
            self->panelWindow.hidden = YES;
        }];
    }
}

// Các hàm xử lý tính năng (Bạn sẽ nối logic Hook vào đây)
- (void)toggleFood:(UISwitch *)sender {
    if(sender.on) NSLog(@"[VIP] Bật Max Cat Food");
    // Gắn code Hook Cat Food vào đây
}
- (void)toggleXP:(UISwitch *)sender {
    if(sender.on) NSLog(@"[VIP] Bật Max XP");
}
- (void)toggleCats:(UISwitch *)sender {
    if(sender.on) NSLog(@"[VIP] Mở khóa tất cả Mèo");
}

@end

#pragma mark - ========== ĐIỂM KHỞI CHẠY (LOADER) ==========

__attribute__((constructor))
static void start_menu_engine() {
    // Chạy ngầm khi game khởi động
    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. Kích hoạt lớp bảo vệ tài khoản ngay lập tức
        setupAntiBan();
        
        // 2. Chờ 3 giây để màn hình loading của game qua đi rồi hiện Menu
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [ProModMenu showMenu];
        });
    });
}
