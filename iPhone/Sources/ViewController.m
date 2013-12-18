#import "ViewController.h"
#import "AppDelegate.h"
#import "WebApi.h"
#import "FileHelper.h"

#define TAG_KEY @"tag"
#define PAGES_KEY @"Pages"

@implementation ViewController

- (BOOL) loadPage:(NSInteger)pageIndex
{
    BOOL        success = NO;
    NSArray*    page;
    if (pageIndex >= 1) {
        // check to see if we already have that page
        NSNumber*   pageNumber = [NSNumber numberWithInt:pageIndex];
        page = [pages objectForKey:pageNumber.stringValue];
        if ((page == nil) OR (page.count == 0)) {
            // we try to load it
            NSMutableDictionary*    postParams = [NSMutableDictionary dictionary];
            [postParams setValue:@"top-movies" forKey:@"command"];
            [postParams setValue:[pageNumber stringValue] forKey:@"page"];
            NSMutableDictionary*    response = [WEB_API fetchDictionary:postParams];
            
            // handle the response
            if (response != nil) {
                NSNumber*   errorCode = [response valueForKey:@"errorCode"];
                // look to see if the server was happy
                if (errorCode.integerValue == 0) {
                    // if we don't already have it, grab our user id
                    if ([[WEB_API valueAtPath:@"Settings/UserIdentifier"] isEqualToString:@"0"]) {
                        NSString*   userIdentifier = [response valueForKey:@"userIdentifier"];
                        [WEB_API.settings setValue:userIdentifier forKey:@"UserIdentifier"];
                        [WEB_API saveSettings];
                        NSLog(@"Captured User Identifier: %@", userIdentifier);
                    }
                    page = [response valueForKey:@"movies"];
                    if (page.count > 0) {
                        [pages setObject:page forKey:pageNumber.stringValue];
                        success = YES;
                    }
                } else {
                    NSLog(@"Server Error loading page %d (%@)", pageIndex, [response valueForKey:@"errorMessage"]);
                }
            } else {
                NSLog(@"Clent Error loading page %d", pageIndex);
            }
        } else {
            success = YES;
        }
    }
    
    if (success) {
        currentPage = page;
        currentPageIndex = pageIndex;
        currentQuestionIndex = -1;
    }
    
    NSLog(@"Load page %d (%@)", pageIndex, (success ? @"SUCCESS" : @"FAIL"));
    return success;
}

- (void) sendPage
{
    NSMutableDictionary*    postParams = [NSMutableDictionary dictionary];
    [postParams setValue:@"rate" forKey:@"command"];
    [postParams setValue:[NSNumber numberWithInt:transactionIndex].stringValue forKey:@"txIdentifier"];
    ++transactionIndex;
    
    // create an array of movies of dictionary objects
    NSMutableArray*         moviesArray = [NSMutableArray arrayWithCapacity:currentPage.count];
    for (NSInteger i = 0; i < currentPage.count; ++i) {
        NSMutableDictionary*    question = [currentPage objectAtIndex:i];
        NSNumber*               tag = [question valueForKey:@"tag"];
        if (tag != nil) {
            //NSLog(@"Reporting %d for %@", tag.integerValue, [question valueForKey:@"title"]);
            NSMutableDictionary*    movieDict = [NSMutableDictionary dictionaryWithCapacity:2];
            [movieDict setValue:[question valueForKey:@"tag"] forKey:@"rating"];
            [movieDict setValue:[question valueForKey:@"id"] forKey:@"movieid"];
            [moviesArray addObject:movieDict];
        }
    }
    NSMutableDictionary*    ratings = [NSMutableDictionary dictionaryWithCapacity:1];
    [ratings setObject:moviesArray forKey:@"movies"];
    [postParams setObject:ratings forKey:@"ratings"];
    NSMutableDictionary*    response = [WEB_API fetchDictionary:postParams];
    NSNumber*   errorCode = [response valueForKey:@"errorCode"];
    if (errorCode.integerValue != 0) {
        // XXX what should I do if it's not...
        NSLog(@"Send page failed...");
    }
    
    // save the page dictionary
    NSString*   fullPathFileName = [FileHelper fullPathFromFileName:PAGES_KEY];
    BOOL        successfulWrite = [pages writeToFile:fullPathFileName atomically:YES];
    NSLog(@"Write Dictionary %@ (%@)", (successfulWrite ? @"SUCCESS" : @"FAIL"), fullPathFileName);
    
    // save the settings
    [WEB_API.settings setValue:[NSNumber numberWithInt:transactionIndex] forKey:@"TransactionIndex"];
    [WEB_API saveSettings];
}

- (void) loadCurrentQuestion
{
    NSLog(@"Load Page %d, question %d", currentPageIndex, currentQuestionIndex);
    if ((currentPage != nil) AND (currentPage.count > currentQuestionIndex)) {
        NSMutableDictionary*    question = [currentPage objectAtIndex:currentQuestionIndex];
        NSString*               posterUrlString = [question objectForKey:@"poster"];
        //NSLog(@"URL: %@", posterUrlString);
        NSURL*                  posterUrl = [NSURL URLWithString:posterUrlString];
        NSURLRequest*           posterUrlRequest = [NSURLRequest requestWithURL:posterUrl];
        [posterWebView loadRequest:posterUrlRequest];
        
        // set the button backgrounds depending on the tag state
        // no tag, -1, 0, or 1
        NSNumber*               tagNumber = [question objectForKey:TAG_KEY];
        NSArray*                buttonKeys = [buttons allKeys];
        for (NSUInteger i = 0; i < buttonKeys.count; ++i) {
            UIButton*   button = [buttons objectForKey:[buttonKeys objectAtIndex:i]];
            UIColor*    backgroundColor = [UIColor whiteColor];
            if ((tagNumber != nil) AND (tagNumber.integerValue == button.tag)) {
                backgroundColor = [UIColor colorWithRed:0.75 green:0.75 blue:1.0 alpha:1.0];
            }
            button.backgroundColor = backgroundColor;
        }
    }
}

- (void) nextQuestion
{
    // if we are at the last question...
    if (currentQuestionIndex == (currentPage.count - 1)) {
        [self sendPage];
        NSUInteger  offset = 1;
        while (NOT [self loadPage:(currentPageIndex + offset)]) {
            // skip pages that fail
            if (++offset > 5) {
                return;
            }
        }
        
        // save the settings
        [WEB_API.settings setValue:[NSNumber numberWithInt:currentPageIndex] forKey:@"CurrentPageIndex"];
        [WEB_API saveSettings];
        currentQuestionIndex = 0;
    } else {
        ++currentQuestionIndex;
    }
    [self loadCurrentQuestion];
}

- (void) previousQuestion
{
    if (currentQuestionIndex == 0) {
        if (currentPageIndex == 1) {
            // can't go back
        } else {
            // implicitly assuming that page 1 worked?
            NSUInteger  offset = 1;
            while (NOT [self loadPage:(currentPageIndex - offset)]) {
                ++offset;
            }
            currentQuestionIndex = currentPage.count - 1;
        }
    } else {
        --currentQuestionIndex;
    }
    [self loadCurrentQuestion];
}

- (void) handleNextButtonPush:(id)sender
{
    [self nextQuestion];
}

- (void) handleBackButtonPush:(id)sender
{
    [self previousQuestion];
}

- (void) handleButtonPush:(id)sender
{
    UIButton*   button = (UIButton*) sender;
    NSInteger   tag = button.tag;
    // add the tag to the current list
    if (currentPage != nil) {
        NSMutableDictionary*    question = [currentPage objectAtIndex:currentQuestionIndex];
        [question setValue:[[NSNumber numberWithInt:tag] stringValue] forKey:TAG_KEY];
    }
    [self nextQuestion];
}

- (UIButton*) createButtonWithTag:(NSInteger)tag frame:(CGRect)frame action:(SEL)selector andText:(NSString*)text inParentView:(UIView*)parentView
{
    UIButton*   button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    button.tag = tag;
    [buttons setObject:button forKey:[NSNumber numberWithInt:tag]];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor whiteColor];
    button.layer.borderColor = [UIColor blueColor].CGColor;
    button.layer.borderWidth = 2.0;
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [parentView addSubview:button];
    return button;
}

- (UIButton*) addRatingButtonWithTag:(NSInteger)tag frame:(CGRect)frame andText:(NSString*)text
{
    return [self createButtonWithTag:tag frame:frame action:@selector(handleButtonPush:) andText:text inParentView:baseView];
}

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
    baseView.backgroundColor = [UIColor colorWithRed:0.85 green:0.85 blue:1.0 alpha:1.0];
    baseView.clipsToBounds = YES;
    [self.view addSubview:baseView];
    
    // create the poster view and the buttons - poster is 2x3 aspect ratio, with
    // enough pixel offset to leave space at the top, and at bottom for the
    // "yes", "no", and "skip" buttons
    CGFloat     edgeBuffer = 5;
    CGFloat     buttonHeight = 40;
    CGFloat     posterHeight = baseViewFrameSize.height - ((edgeBuffer * 3) + buttonHeight);
    CGFloat     posterWidth = (posterHeight / 3.0) * 2.0;
    CGFloat     maxPosterWidth = (baseViewFrameSize.width - (edgeBuffer * 2));
    if (posterWidth > maxPosterWidth) {
        posterWidth = maxPosterWidth;
        posterHeight = (posterWidth / 2.0) * 3.0;
    }
    CGFloat     left = (baseViewFrameSize.width - posterWidth) / 2.0;
    CGRect      posterViewFrame = CGRectMake(left, edgeBuffer, posterWidth, posterHeight);
    posterWebView = [[UIWebView alloc] initWithFrame:posterViewFrame];
    posterWebView.scalesPageToFit = YES;
    posterWebView.layer.borderWidth = 2.0;
    posterWebView.layer.borderColor = [UIColor blueColor].CGColor;
    [baseView addSubview:posterWebView];
    
    // create the button views
    CGFloat buttonWidth = (posterWidth - (edgeBuffer * 2)) / 3.0;
    CGFloat buttonY = posterHeight + (edgeBuffer * 2.0);
    buttonHeight = baseViewFrameSize.height - (buttonY + edgeBuffer);
    CGRect  buttonLeftFrame = CGRectMake(left, buttonY, buttonWidth, buttonHeight);
    CGRect  buttonMiddleFrame = CGRectMake(buttonLeftFrame.origin.x + (buttonWidth + edgeBuffer), buttonY, buttonWidth, buttonHeight);
    CGRect  buttonRightFrame = CGRectMake(buttonMiddleFrame.origin.x + (buttonWidth + edgeBuffer), buttonY, buttonWidth, buttonHeight);
    buttons = [NSMutableDictionary dictionaryWithCapacity:3];
    [self addRatingButtonWithTag:1 frame:buttonRightFrame andText:@"Yes"];
    [self addRatingButtonWithTag:0 frame:buttonMiddleFrame andText:@"Skip"];
    [self addRatingButtonWithTag:-1 frame:buttonLeftFrame andText:@"No"];
    
    // put a little next button in the upper right
    CGRect nextButtonFrame = CGRectMake(posterWebView.frame.size.width - (edgeBuffer + 40.0), edgeBuffer, 40.0, 40.0);
    [self createButtonWithTag:100 frame:nextButtonFrame action:@selector(handleNextButtonPush:) andText:@"+" inParentView:posterWebView];
    
    // put a little back button in the upper left
    CGRect backButtonFrame = CGRectMake(edgeBuffer, edgeBuffer, 40.0, 40.0);
    [self createButtonWithTag:100 frame:backButtonFrame action:@selector(handleBackButtonPush:) andText:@"-" inParentView:posterWebView];
    
    // set up the pages dictionary
    NSString*               fullPathFileName = [FileHelper fullPathFromFileName:PAGES_KEY];
    pages = [NSMutableDictionary dictionaryWithContentsOfFile:fullPathFileName];
    if (pages == nil) {
        pages = [NSMutableDictionary dictionary];
    }
    
    // load the settings
    transactionIndex = ((NSNumber*)[WEB_API valueAtPath:@"Settings/TransactionIndex"]).integerValue;
    currentPageIndex = ((NSNumber*)[WEB_API valueAtPath:@"Settings/CurrentPageIndex"]).integerValue;
    currentPage = nil;
    if ([self loadPage:currentPageIndex]) {
        currentQuestionIndex = 0;
        [self loadCurrentQuestion];
    } else {
        // XXX Gonna have to figure this out eventually...
    }
}

@end
