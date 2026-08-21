//
//  TerminalCleanUpAction.swift
//  ClashX
//
//  Created by yicheng on 2023/9/5.
//  Copyright © 2023 west2online. All rights reserved.
//

import AppKit
import Foundation
import RxSwift

enum TerminalConfirmAction {
    static func run() -> NSApplication.TerminateReply {
        guard confirmAction() else {
            return .terminateCancel
        }
        let policy = TerminationCleanupPolicy.make(observation: TerminationCleanupObservation(
            enhancedModeActive: ConfigManager.shared.isEnhancedModeActive,
            proxyPortAutoSet: ConfigManager.shared.proxyPortAutoSet,
            isProxySetByOther: ConfigManager.shared.isProxySetByOtherVariable.value,
            currentSystemSetToClash: NetworkChangeNotifier.isCurrentSystemSetToClash(looser: true),
            hasInterfaceProxySetToClash: NetworkChangeNotifier.hasInterfaceProxySetToClash()
        ))
        let group = DispatchGroup()

        if policy.cleanEnhancedMode {
            Logger.log("ClashFX quit need clean Enhanced Mode")
            group.enter()
            AppDelegate.shared.cleanupEnhancedModeForTermination {
                group.leave()
            }
        }

        if policy.cleanSystemProxy {
            Logger.log("ClashFX quit need clean proxy setting")
            group.enter()

            SystemProxyManager.shared.disableProxy(forceDisable: policy.forceDisableProxy) {
                group.leave()
            }
        }

        if !policy.shouldWait {
            Logger.log("ClashFX quit without clean waiting")
            return .terminateNow
        }

        DispatchQueue.main.async {
            if let statusItem = AppDelegate.shared.statusItem, statusItem.menu != nil {
                let quittingMenu = NSMenu()
                let quittingItem = NSMenuItem(
                    title: NSLocalizedString("Quitting…", comment: ""),
                    action: nil,
                    keyEquivalent: ""
                )
                quittingItem.isEnabled = false
                quittingMenu.addItem(quittingItem)
                statusItem.menu = quittingMenu
            }
            AppDelegate.shared.disposeBag = DisposeBag()
        }

        let terminationSettlement = ManagedOperationSettlement<Void> { _ in
            DispatchQueue.main.async {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        terminationSettlement.scheduleTimeout(after: 10, queue: .global(qos: .default), outcome: { () })

        DispatchQueue.global(qos: .default).async {
            let res = group.wait(timeout: .now() + 9.8)
            switch res {
            case .success:
                Logger.log("ClashFX quit after clean up finish")
                _ = terminationSettlement.finish(())
            case .timedOut:
                Logger.log("ClashFX quit after clean up timeout")
                _ = terminationSettlement.finish(())
            }
        }

        Logger.log("ClashFX quit wait for clean up")
        return .terminateLater
    }

    static func confirmAction() -> Bool {
        if NSApp.activationPolicy() == .regular {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Quit ClashFX?", comment: "")
            alert.informativeText = NSLocalizedString("The active connections will be interrupted.", comment: "")
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            return alert.runModal() == .alertFirstButtonReturn
        }
        return true
    }
}
