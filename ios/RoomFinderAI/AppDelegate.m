#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  
  // Create a simple view controller with a React Native placeholder
  UIViewController *rootViewController = [[UIViewController alloc] init];
  if (@available(iOS 13.0, *)) {
    rootViewController.view.backgroundColor = [UIColor systemBackgroundColor];
  } else {
    rootViewController.view.backgroundColor = [UIColor whiteColor];
  }
  
  // Add a label to show this is where React Native will be integrated
  UILabel *label = [[UILabel alloc] init];
  label.text = @"Room Finder AI\n\nReact Native Integration";
  label.numberOfLines = 0;
  label.textAlignment = NSTextAlignmentCenter;
  label.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  
  [rootViewController.view addSubview:label];
  
  // Center the label
  [NSLayoutConstraint activateConstraints:@[
    [[label centerXAnchor] constraintEqualToAnchor:rootViewController.view.centerXAnchor],
    [[label centerYAnchor] constraintEqualToAnchor:rootViewController.view.centerYAnchor],
    [[label leadingAnchor] constraintGreaterThanOrEqualToAnchor:rootViewController.view.leadingAnchor constant:20],
    [[label trailingAnchor] constraintLessThanOrEqualToAnchor:rootViewController.view.trailingAnchor constant:-20]
  ]];
  
  self.window.rootViewController = rootViewController;
  [self.window makeKeyAndVisible];
  
  return YES;
}

@end