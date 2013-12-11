#import "ViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    ViewController* viewController;
}

@property (strong, nonatomic) UIWindow* window;

+ (AppDelegate*) sharedAppDelegate;

@end

#define APP_DELEGATE    [AppDelegate sharedAppDelegate]
