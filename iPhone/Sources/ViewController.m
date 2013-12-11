#import "ViewController.h"
#import "AppDelegate.h"
#import "WebApi.h"

@implementation ViewController

- (void) loadView
{
    UIWindow*   window = APP_DELEGATE.window;
    CGRect      frame = window.frame;
    
    // this view automatically gets resized to fill the window, it seems
    self.view = [[UIView alloc] initWithFrame:frame];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // decide how to frame the base view
    CGRect      statusBarFrame = APPLICATION.statusBarFrame;
    CGFloat     statusBarHeight = statusBarFrame.size.height;
    CGFloat     baseViewFrameOriginY = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0") ? statusBarHeight : 0;
    CGSize      baseViewFrameSize = frame.size;
    CGRect      baseViewFrame = CGRectMake(0, baseViewFrameOriginY, baseViewFrameSize.width, baseViewFrameSize.height);
    baseView = [[UIView alloc] initWithFrame:baseViewFrame];
    baseView.backgroundColor = [UIColor greenColor];
    baseView.clipsToBounds = YES;
    [self.view addSubview:baseView];
    
    // start the web API
    NSMutableDictionary*    postParams = [NSMutableDictionary dictionary];
    [postParams setValue:@"top-movies" forKey:@"command"];
    [postParams setValue:@"0" forKey:@"page"];
    NSMutableDictionary*    response = [WEB_API fetchDictionary:postParams];
    
    // push up a webview with the first movie poster
    NSNumber*               errorCode = [response valueForKey:@"errorCode"];
    if (errorCode.integerValue == 0) {
        NSArray*                movies = [response valueForKey:@"movies"];
        NSMutableDictionary*    movie = [movies objectAtIndex:0];
        NSString*               moviePosterUrlString = [movie objectForKey:@"poster"];
        NSURL*                  moviePosterUrl = [NSURL URLWithString:moviePosterUrlString];
        NSURLRequest*           urlRequest = [NSURLRequest requestWithURL:moviePosterUrl];
        CGRect                  webViewFrame = CGRectMake(0, 0, baseViewFrameSize.width, baseViewFrameSize.height);
        UIWebView*              webView = [[UIWebView alloc] initWithFrame:webViewFrame];
        webView.scalesPageToFit = YES;
        [baseView addSubview:webView];
        [webView loadRequest:urlRequest];
    }
}

@end
