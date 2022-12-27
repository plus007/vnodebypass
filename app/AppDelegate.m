#import "AppDelegate.h"
#import "RootViewController.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application {
  _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  _rootViewController = [[RootViewController alloc] init];
  _window.rootViewController = _rootViewController;
  [_window makeKeyAndVisible];
}

@end
