@interface ViewController : UIViewController {
    UIView*                 baseView;
    UIWebView*              posterWebView;
    
    NSArray*                currentPage;
    NSInteger               currentPageIndex;
    NSInteger               currentQuestionIndex;
    NSInteger               transactionIndex;
    
    NSMutableDictionary*    buttons;
    NSMutableDictionary*    pages;
}

@end
