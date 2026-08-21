#import <XCTest/XCTest.h>
#import "ProxySettingRestorationPolicy.h"

@interface ProxySettingRestorationPolicyTests : XCTestCase
@end

@implementation ProxySettingRestorationPolicyTests

- (NSDictionary *)dictionaryForService:(NSString *)service inSnapshot:(NSDictionary *)snapshot action:(ProxySettingRestorationAction *)action {
    return [ProxySettingRestorationPolicy proxyDictionaryForServiceID:service snapshot:snapshot action:action];
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
    ProxySettingRestorationAction action = ProxySettingRestorationActionLeaveUntouched;
    NSDictionary *result = [self dictionaryForService:@"wifi" inSnapshot:@{ @"wifi": partial } action:&action];
    XCTAssertEqual(action, ProxySettingRestorationActionApplyDictionary);
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
    ProxySettingRestorationAction action = ProxySettingRestorationActionLeaveUntouched;
    XCTAssertEqualObjects([self dictionaryForService:@"wifi" inSnapshot:@{ @"wifi": socksOnly } action:&action], socksOnly);
    XCTAssertEqual(action, ProxySettingRestorationActionApplyDictionary);
    XCTAssertEqualObjects([self dictionaryForService:@"ethernet" inSnapshot:@{ @"ethernet": disabled } action:&action], disabled);
    XCTAssertEqual(action, ProxySettingRestorationActionApplyDictionary);
}

- (void)testClashShapedDictionaryIsNotSilentlyChanged {
    NSDictionary *clashLike = @{
        @"HTTPEnable": @1, @"HTTPProxy": @"127.0.0.1", @"HTTPPort": @7890,
        @"HTTPSEnable": @1, @"HTTPSProxy": @"127.0.0.1", @"HTTPSPort": @7890,
        @"SOCKSEnable": @1, @"SOCKSProxy": @"127.0.0.1", @"SOCKSPort": @7891,
    };
    ProxySettingRestorationAction action = ProxySettingRestorationActionLeaveUntouched;
    XCTAssertEqualObjects([self dictionaryForService:@"wifi" inSnapshot:@{ @"wifi": clashLike } action:&action], clashLike);
    XCTAssertEqual(action, ProxySettingRestorationActionApplyDictionary);
}

- (void)testCapturedServiceWithoutProxyPathRequestsRemoval {
    ProxySettingRestorationAction action = ProxySettingRestorationActionLeaveUntouched;
    NSDictionary *snapshot = @{ @"__ClashFXCapturedServiceIDs": @[@"wifi"] };
    XCTAssertNil([self dictionaryForService:@"wifi" inSnapshot:snapshot action:&action]);
    XCTAssertEqual(action, ProxySettingRestorationActionRemovePath);
}

- (void)testNewAndLegacyUnknownServicesAreLeftUntouched {
    ProxySettingRestorationAction action = ProxySettingRestorationActionApplyDictionary;
    NSDictionary *newSnapshot = @{ @"__ClashFXCapturedServiceIDs": @[@"wifi"] };
    XCTAssertNil([self dictionaryForService:@"new-service" inSnapshot:newSnapshot action:&action]);
    XCTAssertEqual(action, ProxySettingRestorationActionLeaveUntouched);

    NSDictionary *legacySnapshot = @{ @"wifi": @{ @"HTTPEnable": @0 } };
    XCTAssertNil([self dictionaryForService:@"new-service" inSnapshot:legacySnapshot action:&action]);
    XCTAssertEqual(action, ProxySettingRestorationActionLeaveUntouched);
}

@end
