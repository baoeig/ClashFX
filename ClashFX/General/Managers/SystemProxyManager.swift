//
//  SystemProxyManager.swift
//  ClashX
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

import AppKit
import ServiceManagement

class SystemProxyManager: NSObject {
    static let shared = SystemProxyManager()

    private var savedProxyInfo: [String: Any] {
        get {
            return UserDefaults.standard.dictionary(forKey: "kSavedProxyInfo") ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kSavedProxyInfo")
        }
    }

    private var helper: ProxyConfigRemoteProcessProtocol? {
        PrivilegedHelperManager.shared.helper()
    }

    func saveProxy() {
        guard !Settings.disableRestoreProxy else { return }
        Logger.log("saveProxy", level: .debug)
        helper?.getCurrentProxySetting { [weak self] info in
            Logger.log("saveProxy done", level: .debug)
            if let info = info as? [String: Any] {
                self?.savedProxyInfo = info
            }
        }
    }

    func enableProxy() {
        let port = ConfigManager.shared.currentConfig?.usedHttpPort ?? 0
        let socketPort = ConfigManager.shared.currentConfig?.usedSocksPort ?? 0
        enableProxy(port: port, socksPort: socketPort)
    }

    func enableProxy(port: Int, socksPort: Int) {
        guard port > 0 && socksPort > 0 else {
            Logger.log("enableProxy fail: \(port) \(socksPort)", level: .error)
            return
        }
        if SSIDSuspendTool.shared.shouldSuspend() {
            Logger.log("not enableProxy due to ssid in disabled list", level: .info)
            return
        }
        Logger.log("enableProxy", level: .debug)
        helper?.enableProxy(withPort: Int32(port),
                            socksPort: Int32(socksPort),
                            pac: nil,
                            filterInterface: Settings.filterInterface,
                            ignoreList: Settings.proxyIgnoreList,
                            error: { error in
                                if let error = error {
                                    Logger.log("enableProxy \(error)", level: .error)
                                }
                            })
    }

    func disableProxy(forceDisable: Bool = false, complete: (() -> Void)? = nil) {
        let port = ConfigManager.shared.currentConfig?.usedHttpPort ?? 0
        let socketPort = ConfigManager.shared.currentConfig?.usedSocksPort ?? 0
        SystemProxyManager.shared.disableProxy(port: port, socksPort: socketPort, forceDisable: forceDisable, complete: complete)
    }

    func disableProxy(port: Int, socksPort: Int, forceDisable: Bool = false, complete: (() -> Void)? = nil) {
        Logger.log("disableProxy", level: .debug)
        let settlement = ManagedOperationSettlement<Void> { _ in
            DispatchQueue.main.async {
                complete?()
            }
        }
        settlement.scheduleTimeout(after: 8, queue: .global(qos: .utility), outcome: {
            Logger.log("disableProxy timed out", level: .error)
            return ()
        })

        let finish: (String?) -> Void = { error in
            if let error = error {
                Logger.log("disableProxy \(error)", level: .error)
            }
            _ = settlement.finish(())
        }

        guard let proxy = PrivilegedHelperManager.shared.helper(failture: {
            finish("Helper connection failed")
        }) else {
            finish("Helper unavailable")
            return
        }

        if Settings.disableRestoreProxy || forceDisable {
            proxy.disableProxy(withFilterInterface: Settings.filterInterface, reply: finish)
            return
        }

        proxy.restoreProxy(withCurrentPort: Int32(port), socksPort: Int32(socksPort), info: savedProxyInfo, filterInterface: Settings.filterInterface, error: finish)
    }
}
