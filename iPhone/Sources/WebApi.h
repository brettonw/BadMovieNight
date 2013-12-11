@interface WebApi : NSObject {
    NSMutableDictionary*    settings;
    NSMutableDictionary*    cache;
    NSMutableDictionary*    versions;
    NSMutableDictionary*    device;
    NSMutableDictionary*    root;
}

+ (WebApi*) sharedWebApi;
- (id) valueAtPath:(NSString*)path;

- (void) updateCache;
- (NSURL*) getCachedFileUrl:(NSString*)name;

- (void) checkVersions:(BOOL)fromWeb;

- (NSMutableDictionary*) fetchDictionary:(NSMutableDictionary*)postParams;


@end

#define WEB_API [WebApi sharedWebApi]