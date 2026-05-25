// BattleCatsMenu.m
// Menu Mod Battle Cats - Mã nguồn đầy đủ (tiếng Việt trong comment)
// Dịch: clang -arch arm64 -dynamiclib -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -mios-version-min=13.0 -O2 -o BattleCatsMenu.dylib BattleCatsMenu.m

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

// ============================================================
// OFFSETS - CẦN CẬP NHẬT THEO PHIÊN BẢN GAME (dùng Cheat Engine)
// ============================================================
// CÁCH TÌM: Vào trận, tìm giá trị tiền (float hoặc 4 byte) -> lấy địa chỉ
// Tính offset = địa chỉ - base_address (base của libil2cpp.so)
#define OFFSET_MONEY              0x12345678   // TIỀN TRONG TRẬN
#define OFFSET_CATFOOD            0x1234567C   // CAT FOOD (menu chính)
#define OFFSET_PLAYER_DAMAGE      0x12345680   // SÁT THƯƠNG CỦA MÈO
#define OFFSET_ENEMY_HEALTH       0x12345684   // MÁU KẺ ĐỊCH
#define OFFSET_ALL_CATS_UNLOCKED  0x12345688   // CỜ MỞ KHÓA TẤT CẢ MÈO

// ============================================================
// CÁC CÔNG TẮC TOÀN CỤC
// ============================================================
static BOOL oneHitKillEnabled = YES;   // BẬT MỘT ĐÒN GIẾT
static BOOL maxMoneyEnabled = YES;     // BẬT MAX TIỀN TRONG TRẬN
static BOOL maxCatFoodEnabled = YES;   // BẬT MAX CAT FOOD
static BOOL allCatsEnabled = YES;      // BẬT MỞ KHÓA TẤT CẢ MÈO

// ============================================================
// HÀM THAY ĐỔI GIÁ TRỊ BỘ NHỚ (CẦN VIẾT PHẦN ĐỌC/GHI)
// ============================================================
void setOneHitKill(BOOL enable) {
    // Nếu enable == YES: ghi 999999 vào OFFSET_PLAYER_DAMAGE
    // và ghi 1 vào OFFSET_ENEMY_HEALTH (mỗi đòn chết luôn)
    // Cần dùng vm_write hoặc task_for_pid
}

void setMaxMoney(BOOL enable) {
    // Ghi 999999 vào OFFSET_MONEY mỗi khi giá trị thay đổi
}

void setMaxCatFood(BOOL enable) {
    // Ghi 999999 vào OFFSET_CATFOOD
}

void unlockAllCats(BOOL enable) {
    // Ghi giá trị toàn 1 vào vùng nhớ chứa danh sách mèo
}

// ============================================================
// MENU CHÍNH - NÚT NỔI CÓ HIỆU ỨNG ĐỘNG ĐẸP, KÉO THẢ, HÚT CẠNH
// ============================================================
@interface ModMenu : UIViewController
+ (void)show;
@end

@implementation ModMenu {
    UIWindow *menuWindow;
    UIWindow *optionsWindow;
    UIButton *floatingBtn;
    BOOL isOptionsVisible;
    UISwitch *oneHitSwitch;
    UISwitch *moneySwitch;
    UISwitch *catFoodSwitch;
    UISwitch *allCatsSwitch;
    CADisplayLink *animationLink;
    CGFloat rotationAngle;
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
        // Tạo cửa sổ nổi 70x70, góc phải màn hình
        self->menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 90, 100, 70, 70)];
        self->menuWindow.backgroundColor = [UIColor clearColor];
        self->menuWindow.windowLevel = UIWindowLevelStatusBar + 2;
        self->menuWindow.alpha = 0.0;
        self->menuWindow.hidden = NO;
        
        // Hiệu ứng xuất hiện mờ dần
        [UIView animateWithDuration:0.3 animations:^{
            self->menuWindow.alpha = 1.0;
        }];
        
        // Nút bấm với gradient, bóng đổ, bo tròn
        self->floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self->floatingBtn.frame = self->menuWindow.bounds;
        self->floatingBtn.layer.cornerRadius = 35;
        self->floatingBtn.clipsToBounds = YES;
        self->floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self->floatingBtn.layer.shadowOffset = CGSizeMake(0, 2);
        self->floatingBtn.layer.shadowRadius = 4;
        self->floatingBtn.layer.shadowOpacity = 0.5;
        
        // Tạo màu gradient đỏ - tím
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = self->floatingBtn.bounds;
        gradient.colors = @[(id)[UIColor systemRedColor].CGColor, (id)[UIColor systemPurpleColor].CGColor];
        gradient.startPoint = CGPointMake(0, 0);
        gradient.endPoint = CGPointMake(1, 1);
        gradient.cornerRadius = 35;
        [self->floatingBtn.layer insertSublayer:gradient atIndex:0];
        
        // Biểu tượng con mèo (text)
        UILabel *catIcon = [[UILabel alloc] initWithFrame:self->floatingBtn.bounds];
        catIcon.text = @"🐱";
        catIcon.font = [UIFont systemFontOfSize:40];
        catIcon.textAlignment = NSTextAlignmentCenter;
        catIcon.userInteractionEnabled = NO;
        [self->floatingBtn addSubview:catIcon];
        
        // Hiệu ứng phồng to/thu nhỏ liên tục (pulse)
        [UIView animateWithDuration:1.0 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat animations:^{
            self->floatingBtn.transform = CGAffineTransformMakeScale(1.05, 1.05);
        } completion:nil];
        
        // Gắn sự kiện kéo thả và bấm
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self->floatingBtn addGestureRecognizer:pan];
        [self->floatingBtn addTarget:self action:@selector(toggleOptions) forControlEvents:UIControlEventTouchUpInside];
        
        [self->menuWindow addSubview:self->floatingBtn];
        [self createOptionsPanel];
        
        // Khởi tạo animation xoay (chỉ xoay khi menu mở)
        self->rotationAngle = 0;
        self->animationLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(animateRotation)];
        self->animationLink.paused = YES;
        [self->animationLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}

- (void)animateRotation {
    if (isOptionsVisible) {
        rotationAngle += 0.05;
        floatingBtn.transform = CGAffineTransformRotate(CGAffineTransformIdentity, rotationAngle);
    } else {
        floatingBtn.transform = CGAffineTransformIdentity;
    }
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
    
    // Khi thả tay, hút vào cạnh gần nhất
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
    optionsWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 300, 320)];
    optionsWindow.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
    optionsWindow.layer.cornerRadius = 20;
    optionsWindow.layer.borderWidth = 2;
    optionsWindow.layer.borderColor = [UIColor systemOrangeColor].CGColor;
    optionsWindow.windowLevel = UIWindowLevelStatusBar + 3;
    optionsWindow.hidden = YES;
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    optionsWindow.rootViewController = vc;
    
    CGFloat y = 20;
    // Tiêu đề
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 260, 35)];
    title.text = @"🐱 BATTLE CATS MOD MENU 🐱";
    title.textColor = [UIColor systemYellowColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:title];
    y += 50;
    
    // One-Hit Kill (một đòn giết)
    UILabel *ohkLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 180, 30)];
    ohkLabel.text = @"⚡ MỘT ĐÒN GIẾT";
    ohkLabel.textColor = [UIColor whiteColor];
    [vc.view addSubview:ohkLabel];
    oneHitSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(220, y, 51, 31)];
    oneHitSwitch.on = YES;
    [oneHitSwitch addTarget:self action:@selector(toggleOneHit:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:oneHitSwitch];
    y += 45;
    
    // Max Money in battle (max tiền trong trận)
    UILabel *moneyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 180, 30)];
    moneyLabel.text = @"💰 MAX TIỀN TRONG TRẬN";
    moneyLabel.textColor = [UIColor whiteColor];
    [vc.view addSubview:moneyLabel];
    moneySwitch = [[UISwitch alloc] initWithFrame:CGRectMake(220, y, 51, 31)];
    moneySwitch.on = YES;
    [moneySwitch addTarget:self action:@selector(toggleMoney:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:moneySwitch];
    y += 45;
    
    // Max Cat Food (max thức ăn mèo)
    UILabel *foodLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 180, 30)];
    foodLabel.text = @"🍣 MAX CAT FOOD";
    foodLabel.textColor = [UIColor whiteColor];
    [vc.view addSubview:foodLabel];
    catFoodSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(220, y, 51, 31)];
    catFoodSwitch.on = YES;
    [catFoodSwitch addTarget:self action:@selector(toggleCatFood:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:catFoodSwitch];
    y += 45;
    
    // All Cats Unlocked (mở khóa tất cả mèo)
    UILabel *catsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 180, 30)];
    catsLabel.text = @"🐾 MỞ KHÓA TẤT CẢ MÈO";
    catsLabel.textColor = [UIColor whiteColor];
    [vc.view addSubview:catsLabel];
    allCatsSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(220, y, 51, 31)];
    allCatsSwitch.on = YES;
    [allCatsSwitch addTarget:self action:@selector(toggleAllCats:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:allCatsSwitch];
    y += 55;
    
    // Nút đóng menu
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(110, y, 80, 40);
    [closeBtn setTitle:@"ĐÓNG" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor darkGrayColor];
    closeBtn.layer.cornerRadius = 10;
    [closeBtn addTarget:self action:@selector(closeOptions) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:closeBtn];
    
    optionsWindow.frame = CGRectMake([UIScreen mainScreen].bounds.size.width/2 - 150, [UIScreen mainScreen].bounds.size.height/2 - 160, 300, 320);
    
    // Đặt tỷ lệ ban đầu để hiệu ứng bật ra
    optionsWindow.transform = CGAffineTransformMakeScale(0.1, 0.1);
}

- (void)toggleOptions {
    isOptionsVisible = !isOptionsVisible;
    if (isOptionsVisible) {
        optionsWindow.hidden = NO;
        animationLink.paused = NO;
        // Hiệu ứng bật ra với lò xo
        optionsWindow.transform = CGAffineTransformMakeScale(0.1, 0.1);
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
            self->optionsWindow.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        animationLink.paused = YES;
        [UIView animateWithDuration:0.2 animations:^{
            self->optionsWindow.transform = CGAffineTransformMakeScale(0.1, 0.1);
        } completion:^(BOOL finished) {
            self->optionsWindow.hidden = YES;
            self->optionsWindow.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)closeOptions {
    [self toggleOptions];
}

- (void)toggleOneHit:(UISwitch *)sender {
    oneHitKillEnabled = sender.on;
    setOneHitKill(oneHitKillEnabled);
}

- (void)toggleMoney:(UISwitch *)sender {
    maxMoneyEnabled = sender.on;
    setMaxMoney(maxMoneyEnabled);
}

- (void)toggleCatFood:(UISwitch *)sender {
    maxCatFoodEnabled = sender.on;
    setMaxCatFood(maxCatFoodEnabled);
}

- (void)toggleAllCats:(UISwitch *)sender {
    allCatsEnabled = sender.on;
    unlockAllCats(allCatsEnabled);
}

@end

// ============================================================
// HÀM KHỞI TẠO - CHẠY NGAY KHI DYLIB ĐƯỢC LOAD
// ============================================================
__attribute__((constructor))
static void initialize() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [ModMenu show];
        // Áp dụng các cài đặt mặc định
        setOneHitKill(oneHitKillEnabled);
        setMaxMoney(maxMoneyEnabled);
        setMaxCatFood(maxCatFoodEnabled);
        unlockAllCats(allCatsEnabled);
    });
}
