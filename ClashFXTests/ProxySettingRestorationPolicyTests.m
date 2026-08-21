#import <XCTest/XCTest.h>
#import "ProxySettingRestorationPolicy.h"

@interface ProxySettingRestorationPolicyTests : XCTestCase
@end

@implementation ProxySettingRestorationPolicyTests

- (NSDictionary *)dictionaryForService:(NSString *)service inSnapshot:(NSDictionary *)snapshot remove:(BOOL *)remove {
    return [ProxySettingRestorationPolicy proxyDictionaryForServiceID:service snapshot:snapshot shouldRemove:remove];
}

- (void)testPartialAndPACSettingsAreReturnedUnchanged {
    NSDictionary *partial = @{
        @"HTTPEnable": @1,
        @"HTTPProxy": @"proxy.example",
        @"HTTPPort": @8080,
        @"HTTPSEnable": @1,
        @"HTTPSProxy": @"secure.example",
        @"HTTPSPort": @8443,
        @"SOCKSEnable": @0,
        @"ProxyAutoConfigEnable": @1,
        @"ProxyAutoConfigURLString": @"https://pac.example/proxy.pac",
        @"ExceptionsList": @[@"localhost", @"*.local"],
        @"ExcludeSimpleHostnames": @1,
    };
    BOOL remove = YES;
    NSDictionary *result = [self dictionaryForService:@"wifi" inSnapshot:@{ @"wifi": partial } remove:&remove];
    XCTAssertFalse(remove);
    XCTAssertEqualObjects(result, partial);
}

- (void)testSOCKSOnlyAndDisabledDictionariesArePreserved {
    NSDictionary *socksOnly = @{
        @"HTTPEnable": @0,
        @"HTTPSEnable": @0,
        @"SOCKSEnable": @1,
        @"SOCKSProxy": @"socks.example",
        @"SOCKSPort": @1080,
    };
    NSDictionary *disabled = @{
        @"HTTPEnable": @0,
        @"HTTPSEnable": @0,
        @"SOCKSEnable": @0,
        @"ExceptionsList": @[@"localhost"],
    };
    BOOL remove = YES;
    XCTAssertEqualObjects([self dictionaryForService:@"wifi" inSnapshot:@{ @"wifi": socksOnly } remove:&remove], socksOnly);
    XCTAssertFalse(remove);
    XCTAssertEqualObjects([self dictionaryForService:@"ethernet" inSnapshot:@{ @"ethernet": disabled } remove:&remove], disabled);
    XCTAssertFalse(remove);
}

- (void)testClashShapedDictionaryIsNotSilentlyChanged {
    NSDictionary *clashLike = @{
        @"HTTPEnable": @1, @"HTTPProxy": @"127.0.0.1", @"HTTPPort": @7890,
        @"HTTPSEnable": @1, @"HTTPSProxy": @"127.0.0.1", @"HTTPSPort": @7890,
        @"SOCKSEnable": @1, @"SOCKSProxy": @"127.0.0.1", @"SOCKSPort": @7891,
    };
    BOOL remove = YES;
    XCTAssertEqualObjects([self dictionaryForService:@"wifi" inSnapshot:@{ @"wifi": clashLike } remove:&remove], clashLike);
    XCTAssertFalse(remove);
}

- (void)testCapturedServiceWithoutProxyPathRequestsRemoval {
    BOOL remove = NO;
    NSDictionary *snapshot = @{ @"__ClashFXCapturedServiceIDs": @[@"wifi"] };
    XCTAssertNil([self dictionaryForService:@"wifi" inSnapshot:snapshot remove:&remove]);
    XCTAssertTrue(remove);
}

@end
