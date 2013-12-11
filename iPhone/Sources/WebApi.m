#import "WebApi.h"
#include <sys/utsname.h>

@implementation WebApi
#pragma mark - Dictionary Helpers

- (id) valueAtPath:(NSString*)path inDictionary:(NSMutableDictionary*)dictionary
{
    id              result = nil;
    NSArray*        components = [path componentsSeparatedByString:@"/"];
    if (components.count > 0) {
        NSUInteger      last = components.count - 1;
        for (NSUInteger i = 0; i < last; ++i) {
            if (dictionary != nil) {
                dictionary = [dictionary objectForKey:[components objectAtIndex:i]];
            }
        }
        if (dictionary != nil) {
            result = [dictionary objectForKey:[components objectAtIndex:last]];
        }
    }
    return result;
}

#pragma mark - File Helpers

- (NSString*) fullPathFromFileName:(NSString*)fileName
{
    NSArray*        paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString*       documentsDirectory = [paths objectAtIndex:0];
    NSString*       version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString*       build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString*       fileNameWithVersion = [NSString stringWithFormat:@"v_%@-b_%@-%@", version, build, fileName];
    NSString*       fullPath = [documentsDirectory stringByAppendingPathComponent:fileNameWithVersion];
    //NSLog(@"Filename: %@", fullPath);
    return fullPath;
}

- (void) deleteFile:(NSString*)fileName
{
    NSString*       fullPath = [self fullPathFromFileName:fileName];
    NSFileManager*  fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:fullPath error:nil];
}

#pragma mark - Dictionary Helpers

#pragma mark - Fetch Helpers
- (NSMutableDictionary*) validateResponse:(NSMutableDictionary*)response forName:(NSString*)name withSaveToFile:(BOOL)saveToFile
{
    NSMutableDictionary*    result = nil;
    NSString*               status = [response valueForKey:@"Status"];
    if ([status isEqualToString:@"OK"]) {
        result = [response valueForKey:name];
        if (result != nil) {
            [root setObject:result forKey:name];
            if (saveToFile) {
                NSString*   fullPathFileName = [self fullPathFromFileName:name];
                BOOL        successfulWrite = [result writeToFile:fullPathFileName atomically:YES];
                NSLog(@"Write Dictionary %@ (%@)", (successfulWrite ? @"SUCCESS" : @"FAIL"), fullPathFileName);
            }
        }
    } else {
        NSLog(@"Validate Response FAILED (%@) - %@", name, status);
    }
    return result;
}

- (NSMutableDictionary*) fetchDictionary:(NSString*)name fromWeb:(BOOL)fromWeb fromFile:(BOOL)fromFile
{
    // generic error object
    NSError*        error;
    
    // try to load the file from the web first, note this is synchronous and
    // might fail if the network is down, we're ok with that happening
    if (fromWeb) {
        NSMutableDictionary*    postParams = [NSMutableDictionary dictionary];
        [postParams setValue:name forKey:@"dictionary"];
        NSMutableDictionary*   response = [self fetchDictionary:postParams];
        if (response != nil) {
            NSMutableDictionary*   result = [self validateResponse:response forName:name withSaveToFile:fromFile];
            if (result != nil) {
                NSLog(@"Fetch Dictionary from url = %@", name);
                return result;
            }
        }
    }
    
    // if the web load failed or was skipped, let's load from a stored file
    if (fromFile == YES) {
        NSString*               fileName = [self fullPathFromFileName:name];
        NSMutableDictionary*    result = [NSMutableDictionary dictionaryWithContentsOfFile:fileName];
        if (result != nil) {
            NSLog(@"Fetch Dictionary from file = %@", fileName);
            // this was a file saved by the validation step, so it doesn't need
            // to be further processed, but it does need to be added to the root
            // dictionary
            [root setObject:result forKey:name];
            return result;
        }
    }
    
    // if the file load failed, let's load from a stored resource
    NSString*   filePath = [[NSBundle mainBundle] pathForResource:name ofType:@"json"];
    if (filePath != nil) {
        NSData*     responseData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingUncached error:&error];
        if (responseData != nil) {
            NSLog(@"Fetch Dictionary from stored resource = %@", name);
            NSMutableDictionary*    response = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
            NSMutableDictionary*    result = [self validateResponse:response forName:name withSaveToFile:fromFile];
            if (result != nil) {
                return result;
            }
        }
    }
    
    // if nothing validated to this point, return failure
    NSLog(@"No Dictionary found for %@", name);
    return nil;
}

- (void) checkVersions:(BOOL)fromWeb
{
    NSLog(@"Checking Versions");
    versions = [self fetchDictionary:@"Versions" fromWeb:fromWeb fromFile:YES];
    if (versions != nil) {
        // check that the version of the Cache is up to date
        BOOL needCache = YES;
        if (cache != nil) {
            NSString*   newVersion = [self valueAtPath:@"Files/Cache/Version" inDictionary:versions];
            NSString*   oldVersion = [cache objectForKey:@"Version"];
            needCache = (NOT [newVersion isEqualToString:oldVersion]);
        }
        if (needCache) {
            NSLog(@"Updating Cache");
            cache = [self fetchDictionary:@"Cache" fromWeb:fromWeb fromFile:YES];
        }
    }
}

#pragma mark - Cache Helpers
- (NSString*) getCachedFileName:(NSString*)name withSpec:(NSDictionary*)spec
{
    // spec is a dictionary that contains the "URL" and "Version" for the file
    // we want to download and cache. figure out the filename from the name and
    // version, and the extension in the url
    NSString*       urlString = [spec objectForKey:@"URL"];
    NSString*       fileName = [NSString stringWithFormat:@"%@-v%@", name, [spec objectForKey:@"Version"]];
    NSString*       ext = [urlString pathExtension];
    if (ext.length > 0) {
        fileName = [NSString stringWithFormat:@"%@.%@", fileName, ext];
    }
    return fileName;
}

- (void) clearCachedFile:(NSString*)name withSpec:(NSDictionary*)spec
{
    // look to see if the file exists
    NSString*       fileName = [self getCachedFileName:name withSpec:spec];
    NSString*       fullPathFileName = [self fullPathFromFileName:fileName];
    NSFileManager*  fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:fullPathFileName]) {
        NSError*    error;
        if ([fileManager removeItemAtPath:fullPathFileName error:&error]) {
            NSLog(@"Removed cached file for %@", fileName);
        }
    }
}

- (void) clearCache
{
    // loop over all of the file descriptors in the cache dictionary
    NSDictionary*   cacheFiles = [self valueAtPath:@"Cache/Files" inDictionary:root];
    if (cacheFiles != nil) {
        NSArray*    names = [cacheFiles allKeys];
        for (NSUInteger i = 0, count = names.count; i < count; ++i) {
            NSString*       name = [names objectAtIndex:i];
            NSDictionary*   spec = [cacheFiles objectForKey:name];
            [self clearCachedFile:name withSpec:spec];
        }
    }
}

- (NSURL*) getUrlForCachedFile:(NSString*)name withSpec:(NSDictionary*)spec
{
    // look to see if the file exists
    NSString*       fileName = [self getCachedFileName:name withSpec:spec];
    NSString*       fullPathFileName = [self fullPathFromFileName:fileName];
    NSFileManager*  fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:fullPathFileName]) {
        NSLog(@"Returning cached file for %@", fileName);
        return [NSURL fileURLWithPath:fullPathFileName];
    } else {
        // asynch download of a file from a url to a file in cache
        NSString*       urlString = [spec objectForKey:@"URL"];
        NSURL*          url = [NSURL URLWithString:urlString];
        NSURLRequest*   urlRequest = [NSURLRequest requestWithURL:url];
        [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue mainQueue] completionHandler:
         ^(NSURLResponse* response, NSData* data, NSError* error) {
             if (error.code == 0) {
                 NSLog(@"Caching file for %@", fileName);
                 [data writeToFile:fullPathFileName atomically:YES];
             } else {
                 NSLog(@"Failed to cache file for %@ (%d, %@)", fileName, error.code, error.localizedDescription);
             }
         }
         ];
        return url;
    }
}

- (NSURL*) getCachedFileUrl:(NSString*)name
{
    NSString*       specPath = [NSString stringWithFormat:@"Cache/%@", name];
    NSDictionary*   spec = [self valueAtPath:specPath inDictionary:root];
    return (spec != nil) ? [self getUrlForCachedFile:name withSpec:spec] : nil;
}

- (void) updateCache
{
    // loop over all of the file descriptors in the cache dictionary
    NSDictionary*   cacheFiles = [self valueAtPath:@"Cache/Files" inDictionary:root];
    if (cacheFiles != nil) {
        NSArray*    names = [cacheFiles allKeys];
        for (NSUInteger i = 0, count = names.count; i < count; ++i) {
            NSString*       name = [names objectAtIndex:i];
            NSDictionary*   spec = [cacheFiles objectForKey:name];
            [self getUrlForCachedFile:name withSpec:spec];
        }
    }
}

#pragma mark - Internal

- (void) getDevice
{
    device = [NSMutableDictionary dictionary];
    
    // get some of the system details
    struct utsname          systemInfo;
    uname(&systemInfo);
    [device setObject:@"iOS" forKey:@"OperatingSystem"];
    [device setObject:SYSTEM_VERSION forKey:@"OperatingSystemVersion"];
    [device setObject:[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] forKey:@"Model"];
    
    // get the screen size
    UIScreen*               mainScreen = [UIScreen mainScreen];
    [device setObject:[NSString stringWithFormat:@"%d", (int)(mainScreen.bounds.size.width)] forKey:@"DisplayWidth"];
    [device setObject:[NSString stringWithFormat:@"%d", (int)(mainScreen.bounds.size.height)] forKey:@"DisplayHeight"];
    [device setObject:[NSString stringWithFormat:@"%.02f", mainScreen.scale] forKey:@"DisplayScale"];
    /*
     iPhone3               320x480  163 ppi
     iPhone4               640×960  326 ppi
     iPhone4S              640×960  326 ppi
     iPhone5               640×1136 326 ppi
     iPhone5C              640×1136 326 ppi
     iPhone5S              640×1136 326 ppi
     iPad                 1024x768  132 ppi
     iPad2                1024x768  132 ppi
     iPad (3gen)          2048x1536 264 ppi
     iPad (4gen)          2048x1536 264 ppi
     iPad Air             2048x1536 264 ppi
     iPad mini            1024x768  163 ppi
     iPad mini (retina)   2048x1536 326 ppi
     */

    [root setValue:device forKey:@"Device"];
}


- (void) initCommon
{
    root = [NSMutableDictionary dictionary];
    [self getDevice];
    settings = [self fetchDictionary:@"Settings" fromWeb:NO fromFile:YES];
}

- (void) reset:(BOOL)resetSettings
{
    // remove any stored asset files
    [self clearCache];
    
    // forcibly delete all the stored data
    [self deleteFile:@"Versions"];
    [self deleteFile:@"Cache"];
    
    // if we mean to reset the settings too...
    if (resetSettings) {
        [self deleteFile:@"Settings"];
    }
    
    // and set all my references to nil
    settings = nil;
    device = nil;
    versions = nil;
    cache = nil;
    root = nil;
    
    // start over
    [self initCommon];
}

- (id) init
{
    self = [super init];
    if (self) {
        [self initCommon];
    }
    return self;
}

#pragma mark - Public Interface
+ (WebApi*) sharedWebApi
{
    static WebApi* singleton = nil;
    if (singleton == nil) {
        singleton = [WebApi new];
    }
    return singleton;
}

- (id) valueAtPath:(NSString*)path
{
    return [self valueAtPath:path inDictionary:root];
}

- (NSMutableDictionary*) fetchDictionary:(NSMutableDictionary*)postParams
{
    // build the full request string up...
    NSString*               urlString = [NSString stringWithFormat:@"%@%@/%@",
                                 [settings objectForKey:@"Scheme"],
                                 [settings objectForKey:@"Authority"],
                                 [settings objectForKey:@"Runner"]
                                 ];
    NSURL*                  url = [NSURL URLWithString:urlString];
    NSLog(@"%@", url);
    NSMutableURLRequest*    request = [NSMutableURLRequest requestWithURL:url];
    
    // add in any generally required parameters
    [postParams setValue:[settings objectForKey:@"Language"] forKey:@"language"];
    
    // convert the postParams dictionary to a json string we can post
    NSError*                error;
    NSData*                 jsonData = [NSJSONSerialization dataWithJSONObject:postParams options:0 error:&error];
    NSString*               jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonString = [jsonString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    NSString*               postString = [NSString stringWithFormat:@"json=%@", jsonString];
#define DEBUG_POST      1
#if DEBUG_POST
    NSLog(@"postString (%@)", postString);
#endif
    
    // set the post params
    [request setHTTPMethod:@"POST"];
    [request setValue: [NSString stringWithFormat:@"application/x-www-form-urlencoded"] forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[postString dataUsingEncoding:NSASCIIStringEncoding]];
    
    // do the web request and return the resulting dictionary (if any)
    NSURLResponse*          urlResponse;
    NSData*                 responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
    if (responseData != nil) {
        return [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
    }
    return nil;
}

@end
