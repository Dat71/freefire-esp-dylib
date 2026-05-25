// BattleCats_UltimateMenu.m
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

// Định nghĩa các tính năng bật/tắt toàn cục
static BOOL isMaxCatFoodActive = NO;
static BOOL isMaxXPActive = NO;
static BOOL isOneHitActive = NO;
static BOOL isMaxBattleMoneyActive = NO;

#pragma mark - ========== PHẦN HOOK CORE LOGIC (LIÊN KẾT VÀO GAME) ==========

// 1. Hook Tiền Trong Trận Đấu (In-Game Wallet)
int (*old_getBattleMoney)(void *instance);
int new_getBattleMoney(void *instance) {
    if (isMaxBattleMoneyActive) {
        return 999999; // Luôn đầy tiền để ra quân liên tục trong trận
    }
    return old_getBattleMoney(instance);
}

// 2. Hook Sát Thương One-Hit (Cơ chế phân biệt phe để tránh địch One-Hit lại ta)
int (*old_getAttackPower)(void *unitInstance);
int new_getAttackPower(void *unitInstance) {
    if (isOneHitActive && unitInstance != NULL) {
        // Cấu trúc kiểm tra phe của PONOS: Thông thường offset 0x18 hoặc 0x20 quản lý ID phe
        // 0 là phe Mèo của ta, 1 là phe Địch.
        int *teamPtr = (int *)((uintptr_t)unitInstance + 0x18); 
        if (teamPtr && *teamPtr == 0) { 
            return 9999999; // Chỉ Mèo của ta được One-Hit
        }
    }
    return old_getAttackPower(unitInstance);
}

// 3. Hook Cat Food & XP Ngoài Sảnh
int (*old_getCatFood)(void *instance);
int new_getCatFood(void *instance) {
    if (isMaxCatFoodActive) return 45000; // Mức an toàn tránh ban
    return old_getCatFood(instance);
}

#pragma mark - ========== GIAO DIỆN MENU NỀN ĐỘNG CYBERPUNK ==========

@interface UltimateModMenu : UIViewController
+ (void)LoadMenu;
@end

@implementation UltimateModMenu {
    UIWindow *menuWindow;
    UIWindow *panelWindow;
    UIButton *floatingBtn;
    BOOL isPanelVisible;
}

+ (void)LoadMenu {
    static UltimateModMenu *menu = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ menu = [UltimateModMenu new]; });
    [menu initFloatingButton];
}

- (void)initFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Khởi tạo cửa sổ nút nổi kích thước 60x60
        self->menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(40, 150, 60, 60)];
        self->menuWindow.backgroundColor = [UIColor clearColor];
        self->menuWindow.windowLevel = UIWindowLevelStatusBar + 999;
        self->menuWindow.hidden = NO;
        
        self->floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self->floatingBtn.frame = self->menuWindow.bounds;
        self->floatingBtn.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.1 alpha:0.9];
        self->floatingBtn.layer.cornerRadius = 30;
        self->floatingBtn.layer.borderWidth = 2.5;
        self->floatingBtn.layer.borderColor = [UIColor cyanColor].CGColor;
        
        // Hiệu ứng phát sáng Neon cho nút bấm ngoài game
        self->floatingBtn.layer.shadowColor = [UIColor cyanColor].CGColor;
        self->floatingBtn.layer.shadowRadius = 8.0;
        self->floatingBtn.layer.shadowOpacity = 1.0;
        self->floatingBtn.layer.shadowOffset = CGSizeMake(0, 0);
        
        [self->floatingBtn setTitle:@"🐱" forState:UIControlStateNormal];
        self->floatingBtn.titleLabel.font = [UIFont systemFontOfSize:28];
        
        UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuDrag:)];
        [self->floatingBtn addGestureRecognizer:drag];
        [self->floatingBtn addTarget:self action:@selector(openClosePanel) forControlEvents:UIControlEventTouchUpInside];
        
        [self->menuWindow addSubview:self->floatingBtn];
        [self initControlPanel];
    });
}

// SỬA LỖI ĐƠ MENU VÀ LỖI CẢNH BÁO KEYWINDOW
- (void)handleMenuDrag:(UIPanGestureRecognizer *)gesture {
    // nil thay thế cho keyWindow để lấy tọa độ trực tiếp toàn màn hình (Fix warning)
    CGPoint touchPoint = [gesture locationInView:nil]; 
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        self->menuWindow.center = touchPoint; // Di chuyển vùng thấu kính Window theo tay
    }
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGPoint finalCenter = self->menuWindow.center;
        
        // Tự động hít chặt vào mép màn hình trái hoặc phải
        if (finalCenter.x > screenWidth / 2) {
            finalCenter.x = screenWidth - 30;
        } else {
            finalCenter.x = 30;
        }
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->menuWindow.center = finalCenter;
        } completion:nil];
    }
}

- (void)initControlPanel {
    panelWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 300, 380)];
    panelWindow.center = [UIScreen mainScreen].preferredMode ? CGPointMake([UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/2) : CGPointMake(200, 200);
    panelWindow.backgroundColor = [UIColor clearColor];
    panelWindow.layer.cornerRadius = 22;
    panelWindow.clipsToBounds = YES;
    panelWindow.windowLevel = UIWindowLevelStatusBar + 1000;
    panelWindow.hidden = YES;
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    panelWindow.rootViewController = rootVC;
    
    // --- NỀN ĐỘNG GRADIENT THAY ĐỔI THEO THỜI GIAN ---
    CAGradientLayer *liveWallpaper = [CAGradientLayer layer];
    liveWallpaper.frame = panelWindow.bounds;
    liveWallpaper.colors = @[
        (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.10 alpha:0.85].CGColor,
        (id)[UIColor colorWithRed:0.15 green:0.02 blue:0.25 alpha:0.85].CGColor,
        (id)[UIColor colorWithRed:0.02 green:0.10 blue:0.20 alpha:0.85].CGColor
    ];
    liveWallpaper.startPoint = CGPointMake(0, 0);
    liveWallpaper.endPoint = CGPointMake(1, 1);
    
    CABasicAnimation *shiftColors = [CABasicAnimation animationWithKeyPath:@"colors"];
    shiftColors.toValue = @[
        (id)[UIColor colorWithRed:0.15 green:0.02 blue:0.25 alpha:0.85].CGColor,
        (id)[UIColor colorWithRed:0.02 green:0.10 blue:0.20 alpha:0.85].CGColor,
        (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.10 alpha:0.85].CGColor
    ];
    shiftColors.duration = 5.0;
    shiftColors.autoreverses = YES;
    shiftColors.repeatCount = HUGE_VALF;
    [liveWallpaper addAnimation:shiftColors forKey:@"waveAnimation"];
    [rootVC.view.layer addSublayer:liveWallpaper];
    
    // Nền kính mờ đè lên trên nền động
    UIBlurEffect *glassBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:glassBlur];
    glassView.frame = panelWindow.bounds;
    glassView.alpha = 0.6;
    [rootVC.view addSubview:glassView];
    
    panelWindow.layer.borderWidth = 1.8;
    panelWindow.layer.borderColor = [UIColor colorWithRed:0.0 green:1.0 blue:1.0 alpha:0.5].CGColor;
    
    // --- THÀNH PHẦN CHỨC NĂNG ---
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 300, 30)];
    titleLabel.text = @"THE BATTLE CATS ULTIMATE";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont fontWithName:@"AvenirNext-Heavy" size:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.layer.shadowColor = [UIColor magentaColor].CGColor;
    titleLabel.layer.shadowRadius = 4.0;
    titleLabel.layer.shadowOpacity = 0.9;
    [rootVC.view addSubview:titleLabel];
    
    CGFloat itemY = 70;
    [self createRow:@"Hack Max Cat Food" yPos:itemY view:rootVC.view action:@selector(onFoodChanged:)]; itemY += 55;
    [self createRow:@"Hack Max Kim Cương/XP" yPos:itemY view:rootVC.view action:@selector(onXPChanged:)]; itemY += 55;
    [self createRow:@"⚡ One-Hit Kill (Phe Ta)" yPos:itemY view:rootVC.view action:@selector(onOneHitChanged:)]; itemY += 55;
    [self createRow:@"💰 Vô Hạn Tiền Trong Trận" yPos:itemY view:rootVC.view action:@selector(onBattleMoneyChanged:)]; itemY += 65;
    
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(75, itemY, 150, 42);
    [close setTitle:@"THOÁT MENU" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    close.backgroundColor = [UIColor colorWithRed:0.9 green:0.1 blue:0.3 alpha:0.8];
    close.layer.cornerRadius = 21;
    close.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [close addTarget:self action:@selector(openClosePanel) forControlEvents:UIControlEventTouchUpInside];
    [rootVC.view addSubview:close];
}

// ĐÃ SỬA LỖI BIẾN `ACTION` TẠI ĐÂY
- (void)createRow:(NSString *)text yPos:(CGFloat)y view:(UIView *)pView action:(SEL)sel {
    UIView *rowBg = [[UIView alloc] initWithFrame:CGRectMake(15, y, 270, 44)];
    rowBg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    rowBg.layer.cornerRadius = 12;
    [pView addSubview:rowBg];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 190, 44)];
    lbl.text = text;
    lbl.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    lbl.font = [UIFont boldSystemFontOfSize:14];
    [rowBg addSubview:lbl];
    
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(210, 6, 50, 31)];
    toggle.onTintColor = [UIColor colorWithRed:0.0 green:0.9 blue:0.9 alpha:1.0];
    // Thay đổi chữ 'action' thành biến 'sel' truyền vào
    [toggle addTarget:self action:sel forControlEvents:UIControlEventValueChanged];
    [rowBg addSubview:toggle];
}

- (void)openClosePanel {
    isPanelVisible = !isPanelVisible;
    if (isPanelVisible) {
        panelWindow.hidden = NO;
        panelWindow.alpha = 0;
        panelWindow.transform = CGAffineTransformMakeScale(0.85, 0.85);
        [UIView animateWithDuration:0.25 animations:^{
            self->panelWindow.alpha = 1.0;
            self->panelWindow.transform = CGAffineTransformIdentity;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self->panelWindow.alpha = 0;
            self->panelWindow.transform = CGAffineTransformMakeScale(0.85, 0.85);
        } completion:^(BOOL f) { self->panelWindow.hidden = YES; }];
    }
}

#pragma mark - ========== ĐIỀU HƯỚNG SỰ KIỆN NÚT BẤM KHI BẬT TẮT ==========

- (void)onFoodChanged:(UISwitch *)sw { isMaxCatFoodActive = sw.on; }
- (void)onXPChanged:(UISwitch *)sw { isMaxXPActive = sw.on; }
- (void)onOneHitChanged:(UISwitch *)sw { isOneHitActive = sw.on; }
- (void)onBattleMoneyChanged:(UISwitch *)sw { isMaxBattleMoneyActive = sw.on; }

@end

#pragma mark - ========== LOADER INITIALIZATION ==========

__attribute__((constructor))
static void entryPoint() {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [UltimateModMenu LoadMenu];
        });
    });
}
