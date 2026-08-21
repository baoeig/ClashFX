#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Selects an exact captured dictionary or an explicit path removal.  It is
/// intentionally Foundation-only so regression tests can exercise the same
/// rule as the privileged helper without touching SystemConfiguration.
@interface ProxySettingRestorationPolicy : NSObject

+ (nullable NSDictionary *)proxyDictionaryForServiceID:(NSString *)serviceID
                                               snapshot:(NSDictionary *)snapshot
                                           shouldRemove:(BOOL *)shouldRemove;

@end

NS_ASSUME_NONNULL_END
