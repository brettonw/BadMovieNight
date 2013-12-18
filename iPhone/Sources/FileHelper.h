@interface FileHelper : NSObject

+ (NSString*) fullPathFromFileName:(NSString*)fileName;
+ (void) deleteFile:(NSString*)fileName;

@end
