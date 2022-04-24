#import "RootViewController.h"

@interface RootViewController ()
@end

@implementation RootViewController

- (void)loadView {
  [super loadView];

  self.view.backgroundColor = UIColor.blackColor;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  _titleLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(0, 50, UIScreen.mainScreen.bounds.size.width, 100)];
  _titleLabel.text = @"vnodebypass";
  _titleLabel.textAlignment = NSTextAlignmentCenter;
  _titleLabel.textColor = UIColor.whiteColor;
  _titleLabel.font = [UIFont systemFontOfSize:40];
  [self.view addSubview:_titleLabel];

  _subtitleLabel = [[UILabel alloc]
      initWithFrame:CGRectMake(0, 100, UIScreen.mainScreen.bounds.size.width, 100)];
  _subtitleLabel.text = @"USE IT AT YOUR OWN RISK!";
  _subtitleLabel.textAlignment = NSTextAlignmentCenter;
  _subtitleLabel.textColor = UIColor.whiteColor;
  _subtitleLabel.font = [UIFont systemFontOfSize:20];
  [self.view addSubview:_subtitleLabel];

  _button = [UIButton buttonWithType:UIButtonTypeSystem];
  _button.frame = CGRectMake(UIScreen.mainScreen.bounds.size.width / 2 - 30,
                             UIScreen.mainScreen.bounds.size.height / 2 - 25, 60, 50);
  [_button setTitle:access("/bin/bash", F_OK) == 0 ? @"Enable" : @"Disable"
           forState:UIControlStateNormal];
  [_button addTarget:self
                action:@selector(buttonPressed:)
      forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:_button];
}

- (void)buttonPressed:(UIButton *)sender {
  BOOL disabled = access("/bin/bash", F_OK) == 0;
  NSArray *opts;
  if (disabled) {
    opts = @[ @"-s", @"-h" ];
  } else {
    opts = @[ @"-r", @"-R" ];
  }

  NSString *launchPath =
      [NSString stringWithFormat:@"/usr/bin/%@", NSProcessInfo.processInfo.processName];
  NSTask *task = [NSTask launchedTaskWithLaunchPath:launchPath arguments:@[ opts[0] ]];
  [task waitUntilExit];
  task = [NSTask launchedTaskWithLaunchPath:launchPath arguments:@[ opts[1] ]];
  [task waitUntilExit];
  disabled = access("/bin/bash", F_OK) == 0;
  if (disabled) {
    [_button setTitle:@"Enable" forState:UIControlStateNormal];
  } else {
    [_button setTitle:@"Disable" forState:UIControlStateNormal];
  }
}

@end
