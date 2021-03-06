#import "AppDelegate.h"

@implementation AppDelegate

static AppDelegate*  sharedAppDelegate = nil;

@synthesize window = _window;

- (id)init
{
    if (NOT sharedAppDelegate) {
        sharedAppDelegate = [super init];
    }
    return sharedAppDelegate;
}

+ (AppDelegate*) sharedAppDelegate
{
    return sharedAppDelegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TestFlight takeOff:TEST_FLIGHT_APP_TOKEN];

    UIWindow*   window = self.window;
    if (window == nil) {
        if (SYSTEM_VERSION_LESS_THAN(@"7.0")) {
            // show the status bar on iOS 6
            APPLICATION.statusBarHidden = NO;
        }
        CGFloat statusBarHeight = [APPLICATION statusBarFrame].size.height;
        CGRect  mainScreenBounds = [[UIScreen mainScreen] bounds];
        CGRect  windowFrame = CGRectMake(mainScreenBounds.origin.x, mainScreenBounds.origin.y, mainScreenBounds.size.width, mainScreenBounds.size.height - statusBarHeight);
        window = self.window = [[UIWindow alloc] initWithFrame:windowFrame];
    }
    window.rootViewController = [ViewController new];
    window.backgroundColor = [UIColor whiteColor];
    [window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
