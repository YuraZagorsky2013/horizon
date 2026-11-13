#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "horizon_ios.h"

@interface HorizonSetupViewController : UIViewController <UIDocumentPickerDelegate>
@property(nonatomic, strong) UILabel *stageLabel;
@property(nonatomic, strong) UILabel *detailLabel;
@property(nonatomic, strong) UILabel *errorLabel;
@property(nonatomic, strong) UIProgressView *progressView;
@property(nonatomic, strong) UITextField *urlField;
@property(nonatomic, strong) UIButton *startButton;
@property(nonatomic, strong) NSTimer *statusTimer;
@property(nonatomic, assign) BOOL started;
@end

@implementation HorizonSetupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.055 green:0.067 blue:0.09 alpha:1.0];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Horizon";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"Подготовка игровых ресурсов";
    subtitle.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    subtitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];

    self.stageLabel = [[UILabel alloc] init];
    self.stageLabel.text = @"Перед первым запуском нужно подготовить файлы игры.";
    self.stageLabel.textColor = UIColor.whiteColor;
    self.stageLabel.numberOfLines = 0;
    self.stageLabel.font = [UIFont systemFontOfSize:15];

    self.detailLabel = [[UILabel alloc] init];
    self.detailLabel.text = @"Импортируй horizon-derived.zip, созданный для Horizon, через приложение «Файлы».";
    self.detailLabel.textColor = [UIColor colorWithWhite:0.68 alpha:1.0];
    self.detailLabel.numberOfLines = 0;
    self.detailLabel.font = [UIFont systemFontOfSize:13];

    self.urlField = [[UITextField alloc] init];
    self.urlField.placeholder = @"Необязательная прямая ссылка на ZIP";
    self.urlField.textColor = UIColor.whiteColor;
    self.urlField.keyboardType = UIKeyboardTypeURL;
    self.urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlField.borderStyle = UITextBorderStyleRoundedRect;
    self.urlField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    self.urlField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.urlField.placeholder attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.58 alpha:1.0]}];

    UIButton *importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [importButton setTitle:@"Выбрать ZIP в «Файлах»" forState:UIControlStateNormal];
    importButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [importButton addTarget:self action:@selector(importArchive) forControlEvents:UIControlEventTouchUpInside];

    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"Начать подготовку" forState:UIControlStateNormal];
    self.startButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    self.startButton.backgroundColor = [UIColor colorWithRed:0.22 green:0.48 blue:0.96 alpha:1.0];
    [self.startButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.startButton.layer.cornerRadius = 12;
    self.startButton.contentEdgeInsets = UIEdgeInsetsMake(14, 18, 14, 18);
    [self.startButton addTarget:self action:@selector(startSetup) forControlEvents:UIControlEventTouchUpInside];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.progressTintColor = [UIColor colorWithRed:0.28 green:0.68 blue:1 alpha:1];
    self.progressView.trackTintColor = [UIColor colorWithWhite:1 alpha:0.14];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [UIColor colorWithRed:1 green:0.43 blue:0.38 alpha:1];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.font = [UIFont systemFontOfSize:12];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle, self.stageLabel, self.detailLabel, self.urlField, importButton, self.startButton, self.progressView, self.errorLabel]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-28],
        [stack.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [self.urlField.heightAnchor constraintEqualToConstant:46],
        [self.progressView.heightAnchor constraintEqualToConstant:4]
    ]];

    self.statusTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refreshStatus) userInfo:nil repeats:YES];
}

- (void)dealloc {
    [self.statusTimer invalidate];
}

- (void)importArchive {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeZipArchive] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject;
    if (!source) return;
    BOOL accessed = [source startAccessingSecurityScopedResource];
    NSError *error = nil;
    NSURL *home = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *target = [home URLByAppendingPathComponent:@"Horizon/horizon-derived.zip"];
    [[NSFileManager defaultManager] createDirectoryAtURL:target.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error];
    if (!error) {
        [[NSFileManager defaultManager] removeItemAtURL:target error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:source toURL:target error:&error];
    }
    if (accessed) [source stopAccessingSecurityScopedResource];
    if (error) {
        self.errorLabel.text = [NSString stringWithFormat:@"Не удалось импортировать ZIP: %@", error.localizedDescription];
    } else {
        self.detailLabel.text = @"Архив импортирован. Теперь можно начать подготовку ресурсов.";
        self.errorLabel.text = @"";
    }
}

- (void)startSetup {
    if (self.started) return;
    NSString *url = self.urlField.text ?: @"";
    const char *utf8 = url.UTF8String;
    horizon_setup_start(utf8);
    self.started = YES;
    self.startButton.enabled = NO;
    self.startButton.alpha = 0.55;
    self.stageLabel.text = @"Запускаю подготовку…";
    [self.urlField resignFirstResponder];
}

- (void)refreshStatus {
    if (horizon_setup_ready()) {
        [self.statusTimer invalidate];
        self.statusTimer = nil;
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    char buffer[2048] = {0};
    horizon_setup_status(buffer, sizeof(buffer));
    NSString *snapshot = [NSString stringWithUTF8String:buffer] ?: @"";
    NSArray<NSString *> *parts = [snapshot componentsSeparatedByString:@"\t"];
    if (parts.count < 7) return;

    NSString *stage = parts[0];
    unsigned long long done = parts[1].longLongValue;
    unsigned long long total = parts[2].longLongValue;
    unsigned long long bytesDone = parts[3].longLongValue;
    unsigned long long bytesTotal = parts[4].longLongValue;
    NSString *state = parts[5];
    NSString *error = parts[6];

    NSDictionary *names = @{
        @"version": @"Проверяю версию Minecraft",
        @"client": @"Загружаю клиентские файлы",
        @"index": @"Получаю индекс ресурсов",
        @"extract": @"Извлекаю встроенные данные",
        @"assets": @"Загружаю ресурсы",
        @"derived": @"Проверяю дополнительные файлы",
        @"done": @"Готово"
    };
    self.stageLabel.text = names[stage] ?: (self.started ? @"Подготавливаю ресурсы…" : self.stageLabel.text);
    if (total > 0) {
        self.detailLabel.text = [NSString stringWithFormat:@"%llu из %llu файлов · %.1f / %.1f МБ", done, total, bytesDone / 1048576.0, bytesTotal / 1048576.0];
        self.progressView.progress = MIN(1.0, (float)done / (float)total);
    } else {
        self.detailLabel.text = @"Подключаюсь к серверам ресурсов…";
        self.progressView.progress = 0;
    }

    if ([state isEqualToString:@"error"]) {
        self.errorLabel.text = error;
        self.started = NO;
        self.startButton.enabled = YES;
        self.startButton.alpha = 1.0;
        [self.startButton setTitle:@"Повторить подготовку" forState:UIControlStateNormal];
    } else if ([state isEqualToString:@"done"] || [state isEqualToString:@"idle"]) {
        self.started = NO;
        self.startButton.enabled = YES;
        self.startButton.alpha = 1.0;
    }
}
@end

static id HorizonSetupLaunchObserver;

void horizon_install_setup_ui(void) {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    HorizonSetupLaunchObserver = [center addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                       object:nil
                                                        queue:NSOperationQueue.mainQueue
                                                   usingBlock:^(__unused NSNotification *notification) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (horizon_setup_ready()) return;
            UIApplication *application = UIApplication.sharedApplication;
            UIWindow *keyWindow = nil;
            for (UIWindow *window in application.windows) {
                if (window.isKeyWindow) { keyWindow = window; break; }
            }
            UIViewController *root = keyWindow.rootViewController;
            if (!root || root.presentedViewController) return;
            HorizonSetupViewController *setup = [[HorizonSetupViewController alloc] init];
            setup.modalPresentationStyle = UIModalPresentationFullScreen;
            [root presentViewController:setup animated:NO completion:nil];
        });
    }];
}
