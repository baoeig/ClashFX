#import "ProxySettingRestorationPolicy.h"

@implementation ProxySettingRestorationPolicy

+ (nullable NSDictionary *)proxyDictionaryForServiceID:(NSString *)serviceID
                                               snapshot:(NSDictionary *)snapshot
                                                action:(ProxySettingRestorationAction *)action {
    id value = snapshot[serviceID];
    if ([value isKindOfClass:[NSDictionary class]]) {
        if (action) {
            *action = ProxySettingRestorationActionApplyDictionary;
        }
        return value;
    }

    // New captures record every service, including ones that did not have a
    // Proxies dictionary. Only an explicitly captured, dictionary-less service
    // may have its path removed. A service created after capture must be left
    // alone. Legacy raw captures have no service list, so their unknown
    // services are likewise left untouched.
    NSArray *capturedServiceIDs = snapshot[@"__ClashFXCapturedServiceIDs"];
    BOOL wasCapturedWithoutDictionary =
        [capturedServiceIDs isKindOfClass:[NSArray class]] &&
        [capturedServiceIDs containsObject:serviceID];
    if (action) {
        *action = wasCapturedWithoutDictionary
            ? ProxySettingRestorationActionRemovePath
            : ProxySettingRestorationActionLeaveUntouched;
    }
    return nil;
}

@end
