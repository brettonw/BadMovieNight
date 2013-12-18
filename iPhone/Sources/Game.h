@interface Game : NSObject {
    NSArray*                currentPage;
    NSInteger               currentPageIndex;
    NSInteger               currentQuestionIndex;
    
    NSMutableDictionary*    pages;
}

@end
