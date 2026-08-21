//
//  ProxySettingTool.m
//  com.clashfx.app.Helper
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

#import "ProxySettingTool.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <AppKit/AppKit.h>
#import "CommonUtils.h"
#import "ProxySettingRestorationPolicy.h"

static NSString * const ClashFXProxyCaptureErrorKey = @"__ClashFXProxyCaptureError";
static NSString * const ClashFXCapturedServiceIDsKey = @"__ClashFXCapturedServiceIDs";

@interface ProxySettingTool()
@property (nonatomic, assign) AuthorizationRef authRef;

@end

@implementation ProxySettingTool

- (instancetype)init {
    if (self = [super init]) {
        [self localAuth];
    }
    return self;
}

// MARK: - Public

- (nullable NSString *)enableProxyWithport:(int)port socksPort:(int)socksPort
                     pacUrl:(NSString *)pacUrl
            filterInterface:(BOOL)filterInterface
                 ignoreList:(NSArray<NSString *>*)ignoreList {

    return [self applySCNetworkSettingWithRef:^NSString *(SCPreferencesRef ref) {
        __block NSString *error = nil;
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:filterInterface devices:^(NSString *key, NSDictionary *dict) {
            if (!error) {
                error = [self enableProxySettings:ref interface:key port:port socksPort:socksPort ignoreList:ignoreList pac:pacUrl];
            }
        }];
        return error;
    }];
}

- (nullable NSString *)disableProxyWithfilterInterface:(BOOL)filterInterface {
    return [self applySCNetworkSettingWithRef:^NSString *(SCPreferencesRef ref) {
        __block NSString *error = nil;
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:filterInterface devices:^(NSString *key, NSDictionary *dict) {
            if (!error) {
                error = [self disableProxySetting:ref interface:key];
            }
        }];
        return error;
    }];
}

- (nullable NSString *)restoreProxySetting:(NSDictionary *)savedInfo
                currentPort:(int)port
           currentSocksPort:(int)socksPort
            filterInterface:(BOOL)filterInterface{
    return [self applySCNetworkSettingWithRef:^NSString *(SCPreferencesRef ref) {
        __block NSString *error = nil;
        // Restore every current service. Captured dictionaries can be applied
        // idempotently; the tri-state policy leaves services added after the
        // capture untouched even if the user changed the filter while active.
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:NO devices:^(NSString *key, NSDictionary *dict) {
            if (error) {
                return;
            }
            ProxySettingRestorationAction action = ProxySettingRestorationActionLeaveUntouched;
            NSDictionary *proxySetting = [ProxySettingRestorationPolicy proxyDictionaryForServiceID:key
                                                                                           snapshot:savedInfo
                                                                                             action:&action];
            if (action == ProxySettingRestorationActionRemovePath) {
                error = [self removeProxyConfig:ref interface:key];
            } else if (action == ProxySettingRestorationActionApplyDictionary) {
                error = [self setProxyConfig:ref interface:key proxySetting:proxySetting];
            }
        }];
        return error;
    }];
}

+ (NSMutableDictionary<NSString *, id> *)currentProxySettings {
    __block NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionary];
    SCPreferencesRef ref = SCPreferencesCreate(nil, CFSTR("ClashFX"), nil);
    if (!ref) {
        info[ClashFXProxyCaptureErrorKey] = @"Unable to create system network preferences for proxy capture";
        return info;
    }
    NSMutableArray<NSString *> *serviceIDs = [NSMutableArray array];
    [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:NO devices:^(NSString *key, NSDictionary *dev) {
        [serviceIDs addObject:key];
        NSDictionary *proxySettings = dev[(__bridge NSString *)kSCEntNetProxies];
        if ([proxySettings isKindOfClass:[NSDictionary class]]) {
            // Keep the property-list payload byte-for-byte. Do not synthesize
            // disabled keys for a partial/PAC-only proxy configuration.
            info[key] = [proxySettings copy];
        }
    }];
    info[ClashFXCapturedServiceIDsKey] = [serviceIDs copy];
    CFRelease(ref);
    
    return info;
}

// MARK: - Private

- (void)dealloc {
    [self freeAuth];
}


- (NSDictionary *)getProxySetting:(BOOL)enable port:(int) port
                        socksPort: (int)socksPort pac:(NSString *)pac
                       ignoreList:(NSArray<NSString *>*)ignoreList {
    
    NSMutableDictionary *proxySettings = [NSMutableDictionary dictionary];
    
    NSString *ip = enable ? @"127.0.0.1" : @"";
    NSInteger enableInt = enable ? 1 : 0;
    NSInteger enablePac = [pac length] > 0;
    
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPProxy] = ip;
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPEnable] = @(enableInt);
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSProxy] = ip;
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSEnable] = @(enableInt);
    
    proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSProxy] = ip;
    proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSEnable] = @(enableInt);
    
    if (enable) {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPPort] = @(port);
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSPort] = @(port);
        proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSPort] = @(socksPort);
        proxySettings[(__bridge NSString *)kCFNetworkProxiesExcludeSimpleHostnames] = @(YES);
    } else {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPPort] = nil;
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSPort] = nil;
        proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSPort] = nil;
    }
    
    proxySettings[(__bridge NSString *)kCFNetworkProxiesProxyAutoConfigEnable] = @(enablePac);
    if (enablePac) {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesProxyAutoConfigURLString] = pac;
    } else {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesProxyAutoConfigURLString] = nil;
    }
    
    if (enable) {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesExceptionsList] = ignoreList;
    } else {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesExceptionsList] = @[];
    }
    
    return proxySettings;
}

- (NSString *)proxySettingPathWithInterface:(NSString *)interfaceKey {
    return [NSString stringWithFormat:@"/%@/%@/%@",
            (NSString *)kSCPrefNetworkServices,
            interfaceKey,
            (NSString *)kSCEntNetProxies];
}

- (nullable NSString *)enableProxySettings:(SCPreferencesRef)prefs
                  interface:(NSString *)interfaceKey
                       port:(int) port
                  socksPort:(int) socksPort
                 ignoreList:(NSArray<NSString *>*)ignoreList
                        pac:(NSString *)pac {
    
    NSDictionary *proxySettings = [self getProxySetting:YES port:port socksPort:socksPort pac:pac ignoreList:ignoreList];
    return [self setProxyConfig:prefs interface:interfaceKey proxySetting:proxySettings];
    
}

- (nullable NSString *)disableProxySetting:(SCPreferencesRef)prefs
                  interface:(NSString *)interfaceKey {
    NSDictionary *proxySettings = [self getProxySetting:NO port:0 socksPort:0 pac:nil ignoreList:@[]];
    return [self setProxyConfig:prefs interface:interfaceKey proxySetting:proxySettings];
}

- (nullable NSString *)setProxyConfig:(SCPreferencesRef)prefs
             interface:(NSString *)interfaceKey
          proxySetting:(NSDictionary *)proxySettings {
    NSString *path = [self proxySettingPathWithInterface:interfaceKey];
    if (!SCPreferencesPathSetValue(prefs,
                                   (__bridge CFStringRef)path,
                                   (__bridge CFDictionaryRef)proxySettings)) {
        return [self preferenceErrorMessageForOperation:@"setting proxy preferences"];
    }
    return nil;
}

- (nullable NSString *)removeProxyConfig:(SCPreferencesRef)prefs interface:(NSString *)interfaceKey {
    NSString *path = [self proxySettingPathWithInterface:interfaceKey];
    if (!SCPreferencesPathRemoveValue(prefs, (__bridge CFStringRef)path)) {
        return [self preferenceErrorMessageForOperation:@"removing proxy preferences"];
    }
    return nil;
}

+ (void)getDiviceListWithPrefRef:(SCPreferencesRef)ref
                 filterInterface:(BOOL)filterInterface
                         devices:(void(^)(NSString *, NSDictionary *))callback {
    NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(ref, kSCPrefNetworkServices);
    if (![sets isKindOfClass:[NSDictionary class]]) {
        return;
    }
    for (NSString *key in [sets allKeys]) {
        NSMutableDictionary *dict = [sets objectForKey:key];
        NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
        if (!filterInterface || [hardware isEqualToString:@"AirPort"]
            || [hardware isEqualToString:@"Wi-Fi"]
            || [hardware isEqualToString:@"Ethernet"]
            ) {
            callback(key,dict);
        }
    }
}

- (NSString *)preferenceErrorMessageForOperation:(NSString *)operation {
    const char *errorString = SCErrorString(SCError());
    NSString *detail = errorString ? [NSString stringWithUTF8String:errorString] : @"unknown error";
    return [NSString stringWithFormat:@"Unable to %@: %@", operation, detail];
}

- (nullable NSString *)applySCNetworkSettingWithRef:(NSString *(^)(SCPreferencesRef))callback {
    SCPreferencesRef ref = SCPreferencesCreateWithAuthorization(nil, CFSTR("com.clashfx.app.Helper.config"), nil, self.authRef);
    if (!ref) {
        return @"Unable to create authorized system network preferences";
    }
    NSString *callbackError = callback(ref);
    if (callbackError) {
        CFRelease(ref);
        return callbackError;
    }
    
    if (!SCPreferencesCommitChanges(ref)) {
        NSString *error = [self preferenceErrorMessageForOperation:@"committing system network preferences"];
        CFRelease(ref);
        return error;
    }
    if (!SCPreferencesApplyChanges(ref)) {
        NSString *error = [self preferenceErrorMessageForOperation:@"applying system network preferences"];
        CFRelease(ref);
        return error;
    }
    // SystemConfiguration exposes synchronization as a void operation, so it
    // cannot provide a reliable per-call failure result. In particular, do
    // not inspect SCError() here: it may describe an earlier operation.
    SCPreferencesSynchronize(ref);
    CFRelease(ref);
    return nil;
}

- (AuthorizationFlags)authFlags {
    AuthorizationFlags authFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    return authFlags;
}

- (void)localAuth {
    OSStatus myStatus;
    AuthorizationFlags myFlags = [self authFlags];
    myStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, myFlags, &_authRef);
    
    if (myStatus != errAuthorizationSuccess)
    {
        return;
    }
    
    AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights myRights = {1, &myItems};
    myStatus = AuthorizationCopyRights (self.authRef, &myRights, NULL, myFlags, NULL );
}


- (void)freeAuth {
    if (self.authRef) {
        AuthorizationFree(self.authRef, [self authFlags]);
    }
}

// MARK: - DNS

- (NSString *)dnsSettingPathWithInterface:(NSString *)interfaceKey {
    return [NSString stringWithFormat:@"/%@/%@/%@",
            (NSString *)kSCPrefNetworkServices,
            interfaceKey,
            (NSString *)kSCEntNetDNS];
}

- (void)overrideDNSWithServers:(NSArray<NSString *> *)servers
               filterInterface:(BOOL)filterInterface {
    [self applySCNetworkSettingWithRef:^NSString *(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:filterInterface devices:^(NSString *key, NSDictionary *dict) {
            NSString *path = [self dnsSettingPathWithInterface:key];
            NSDictionary *dnsSettings = @{
                (__bridge NSString *)kSCPropNetDNSServerAddresses: servers
            };
            SCPreferencesPathSetValue(ref,
                                      (__bridge CFStringRef)path,
                                      (__bridge CFDictionaryRef)dnsSettings);
        }];
        return nil;
    }];
}

- (void)restoreDNS:(NSDictionary *)savedInfo
    filterInterface:(BOOL)filterInterface {
    [self applySCNetworkSettingWithRef:^NSString *(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:filterInterface devices:^(NSString *key, NSDictionary *dict) {
            NSString *path = [self dnsSettingPathWithInterface:key];
            NSDictionary *dnsSettings = savedInfo[key];
            if ([dnsSettings isKindOfClass:[NSDictionary class]]) {
                SCPreferencesPathSetValue(ref,
                                          (__bridge CFStringRef)path,
                                          (__bridge CFDictionaryRef)dnsSettings);
            } else {
                SCPreferencesPathRemoveValue(ref, (__bridge CFStringRef)path);
            }
        }];
        return nil;
    }];
}

+ (NSMutableDictionary<NSString *,NSDictionary *> *)currentDNSSettings {
    __block NSMutableDictionary<NSString *,NSDictionary *> *info = [NSMutableDictionary dictionary];
    SCPreferencesRef ref = SCPreferencesCreate(nil, CFSTR("ClashFX"), nil);
    [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:YES devices:^(NSString *key, NSDictionary *dev) {
        NSDictionary *dnsSettings = dev[(__bridge NSString *)kSCEntNetDNS];
        if (dnsSettings) {
            info[key] = [dnsSettings copy];
        }
    }];
    CFRelease(ref);
    return info;
}

@end
