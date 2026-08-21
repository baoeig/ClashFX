#import "ProxySettingRestorationPolicy.h"

@implementation ProxySettingRestorationPolicy

+ (nullable NSDictionary *)proxyDictionaryForServiceID:(NSString *)serviceID
                                               snapshot:(NSDictionary *)snapshot
                                           shouldRemove:(BOOL *)shouldRemove {
    id value = snapshot[serviceID];
    if ([value isKindOfClass:[NSDictionary class]]) {
        if (shouldRemove) {
            *shouldRemove = NO;
        }
        return value;
    }

    // New captures record every service, including ones that did not have a
    // Proxies dictionary. Older raw captures safely retain the old fallback of
    // removing a missing path. Metadata is never interpreted as a service.
    if (shouldRemove) {
        *shouldRemove = YES;
    }
    return nil;
}

@end
