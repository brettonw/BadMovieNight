#import "FileHelper.h"

@implementation FileHelper
+ (NSString*) fullPathFromFileName:(NSString*)fileName
{
    NSArray*        paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString*       documentsDirectory = [paths objectAtIndex:0];
    NSString*       version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    //NSString*       build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString*       fileNameWithVersion = [NSString stringWithFormat:@"v_%@-%@", version, fileName];
    NSString*       fullPath = [documentsDirectory stringByAppendingPathComponent:fileNameWithVersion];
    //NSLog(@"Filename: %@", fullPath);
    return fullPath;
}

+ (void) deleteFile:(NSString*)fileName
{
    NSString*       fullPath = [self fullPathFromFileName:fileName];
    NSFileManager*  fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:fullPath error:nil];
}


@end
