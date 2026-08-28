//
//  GlobalShortCutViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2023/5/26.
//  Copyright © 2023 west2online. All rights reserved.
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSystemProxyMode = Self("shortCut.toggleSystemProxyMode")
    static let copyShellCommand = Self(
        "shortCut.copyShellCommand",
        default: .init(.c, modifiers: [.control, .option])
    )
    static let copyExternalShellCommand = Self(
        "shortCut.copyExternalShellCommand",
        default: .init(.c, modifiers: [.control, .option, .shift])
    )

    static let modeDirect = Self("shortCut.modeDirect")
    static let modeRule = Self("shortCut.modeRule")
    static let modeGlobal = Self("shortCut.modeGlobal")

    static let toggleEnhancedMode = Self(
        "shortCut.toggleEnhancedMode",
        default: .init(.e, modifiers: [.control, .option])
    )

    static let log = Self("shortCut.log")
    static let dashboard = Self("shortCut.dashboard")
    static let benchmark = Self("shortCut.benchmark")
    static let openMenu = Self("shortCut.openMenu")
    static let nativeDashboard = Self("shortCut.nativeDashboard")
}

enum KeyboardShortCutManager {
    private static let copyShortcutMigrationKey = "kCopyShortcutMigrationV2"
    private static let unsafeCommandShortcutMigrationKey = "kUnsafeCommandShortcutMigrationV1"
    private static let defaultProxyModeShortcutMigrationKey =
        "kDefaultProxyModeShortcutMigrationV1"
    static let actionShortcutNames: [KeyboardShortcuts.Name] = [
        .toggleSystemProxyMode,
        .copyShellCommand,
        .copyExternalShellCommand,
        .modeDirect,
        .modeRule,
        .modeGlobal,
        .toggleEnhancedMode,
        .log,
        .dashboard,
        .benchmark,
        .nativeDashboard
    ]
    static let allShortcutNames: [KeyboardShortcuts.Name] = actionShortcutNames + [.openMenu]
    private static var didSetup = false
    private static var didInstallActionHandlers = false
    private static var isStatusMenuTracking = false

    static func setup() {
        guard !didSetup else { return }
        didSetup = true

        migrateUnsafeCopyShortcutsIfNeeded()
        migrateUnsafeCommandShortcutsIfNeeded()
        migrateDefaultProxyModeShortcutsIfNeeded()

        KeyboardShortcuts.onKeyUp(for: .openMenu) {
            AppDelegate.shared.statusItem.button?.performClick(nil)
        }
        syncActionShortcutRegistration()
    }

    static func setActionScope(_ scope: ShortcutScope) {
        Settings.actionShortcutScope = scope
        syncActionShortcutRegistration()
    }

    static func shortcutDidChange(_ name: KeyboardShortcuts.Name) {
        guard actionShortcutNames.contains(name) else { return }
        syncActionShortcutRegistration()
    }

    static func statusMenuWillOpen() {
        isStatusMenuTracking = true
        syncActionShortcutRegistration()
    }

    static func statusMenuDidClose() {
        isStatusMenuTracking = false
        syncActionShortcutRegistration()
    }

    private static func syncActionShortcutRegistration() {
        let shouldRegisterGlobally = ShortcutRegistrationPolicy.shouldRegisterActionShortcutsGlobally(
            scope: Settings.actionShortcutScope,
            isMenuTracking: isStatusMenuTracking
        )

        guard shouldRegisterGlobally else {
            KeyboardShortcuts.disable(actionShortcutNames)
            return
        }

        installActionHandlersIfNeeded()
        KeyboardShortcuts.enable(actionShortcutNames)
    }

    private static func installActionHandlersIfNeeded() {
        guard !didInstallActionHandlers else { return }
        didInstallActionHandlers = true

        KeyboardShortcuts.onKeyUp(for: .toggleSystemProxyMode) {
            AppDelegate.shared.actionSetSystemProxy(nil)
        }

        KeyboardShortcuts.onKeyUp(for: .copyShellCommand) {
            AppDelegate.shared.actionCopyExportCommand(AppDelegate.shared.copyExportCommandMenuItem)
        }

        KeyboardShortcuts.onKeyUp(for: .copyExternalShellCommand) {
            AppDelegate.shared.actionCopyExportCommand(AppDelegate.shared.copyExportCommandExternalMenuItem)
        }

        KeyboardShortcuts.onKeyUp(for: .modeDirect) {
            AppDelegate.shared.switchProxyMode(mode: .direct, source: .globalShortcut)
        }

        KeyboardShortcuts.onKeyUp(for: .modeRule) {
            AppDelegate.shared.switchProxyMode(mode: .rule, source: .globalShortcut)
        }

        KeyboardShortcuts.onKeyUp(for: .modeGlobal) {
            AppDelegate.shared.switchProxyMode(mode: .global, source: .globalShortcut)
        }

        KeyboardShortcuts.onKeyUp(for: .toggleEnhancedMode) {
            AppDelegate.shared.actionToggleEnhancedMode(nil)
        }

        KeyboardShortcuts.onKeyUp(for: .log) {
            AppDelegate.shared.actionShowLog(nil)
        }

        KeyboardShortcuts.onKeyUp(for: .dashboard) {
            AppDelegate.shared.actionDashboard(nil)
        }

        KeyboardShortcuts.onKeyUp(for: .benchmark) {
            AppDelegate.shared.actionSpeedTest(AppDelegate.shared)
        }
        if #available(macOS 10.15, *) {
            KeyboardShortcuts.onKeyUp(for: .nativeDashboard) {
                ClashWindowController<DashboardViewController>.create().showWindow(self)
            }
        }
    }

    private static func migrateUnsafeCopyShortcutsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: copyShortcutMigrationKey) else { return }

        let legacyCopy = KeyboardShortcuts.Shortcut(.c, modifiers: .command)
        let legacyExternalCopy = KeyboardShortcuts.Shortcut(.c, modifiers: [.command, .option])
        var migrated = false

        if KeyboardShortcuts.getShortcut(for: .copyShellCommand) == legacyCopy {
            KeyboardShortcuts.setShortcut(
                KeyboardShortcuts.Shortcut(.c, modifiers: [.control, .option]),
                for: .copyShellCommand
            )
            migrated = true
        }

        if KeyboardShortcuts.getShortcut(for: .copyExternalShellCommand) == legacyExternalCopy {
            KeyboardShortcuts.setShortcut(
                KeyboardShortcuts.Shortcut(.c, modifiers: [.control, .option, .shift]),
                for: .copyExternalShellCommand
            )
            migrated = true
        }

        UserDefaults.standard.set(true, forKey: copyShortcutMigrationKey)
        guard migrated else { return }

        Logger.log("Migrated unsafe copy shortcuts away from Command-C")
        NSUserNotificationCenter.default.post(
            title: NSLocalizedString("Global Shortcut Updated", comment: ""),
            info: NSLocalizedString("Copy shortcuts were changed to avoid intercepting Command-C. You can customize them in Settings > Global Shortcut.", comment: "")
        )
    }

    private static func migrateUnsafeCommandShortcutsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: unsafeCommandShortcutMigrationKey) else { return }

        let unsafeShortcuts: [(KeyboardShortcuts.Name, KeyboardShortcuts.Shortcut)] = [
            (.toggleSystemProxyMode, .init(.s, modifiers: .command)),
            (.log, .init(.l, modifiers: .command)),
            (.dashboard, .init(.d, modifiers: .command)),
            (.nativeDashboard, .init(.d, modifiers: [.command, .shift]))
        ]
        var migrated = false

        for (name, unsafeShortcut) in unsafeShortcuts
            where KeyboardShortcuts.getShortcut(for: name) == unsafeShortcut {
            KeyboardShortcuts.setShortcut(nil, for: name)
            migrated = true
        }

        UserDefaults.standard.set(true, forKey: unsafeCommandShortcutMigrationKey)
        guard migrated else { return }

        Logger.log("Removed unsafe Command-key global shortcuts")
        NSUserNotificationCenter.default.post(
            title: NSLocalizedString("Global Shortcut Updated", comment: ""),
            info: NSLocalizedString("Unsafe Command-key shortcuts were removed to restore standard macOS shortcuts. You can assign custom combinations in Settings > Global Shortcut.", comment: "")
        )
    }

    private static func migrateDefaultProxyModeShortcutsIfNeeded() {
        guard !UserDefaults.standard.bool(
            forKey: defaultProxyModeShortcutMigrationKey
        ) else {
            return
        }

        let legacyShortcuts: [(KeyboardShortcuts.Name, KeyboardShortcuts.Shortcut)] = [
            (.modeDirect, .init(.d, modifiers: .option)),
            (.modeRule, .init(.r, modifiers: .option)),
            (.modeGlobal, .init(.g, modifiers: .option))
        ]
        var migrated = false

        for (name, legacyShortcut) in legacyShortcuts
            where KeyboardShortcuts.getShortcut(for: name) == legacyShortcut {
            KeyboardShortcuts.setShortcut(nil, for: name)
            migrated = true
        }

        UserDefaults.standard.set(
            true,
            forKey: defaultProxyModeShortcutMigrationKey
        )
        guard migrated else { return }

        Logger.log("Removed default global shortcuts for outbound proxy modes")
        NSUserNotificationCenter.default.post(
            title: NSLocalizedString("Global Shortcut Updated", comment: ""),
            info: NSLocalizedString(
                "Default proxy-mode shortcuts were removed to prevent accidental background mode changes. You can assign custom combinations in Settings > Global Shortcut.",
                comment: ""
            )
        )
    }
}

private final class ClashFXShortcutRecorder: NSButton {
    typealias ProposalHandler = (
        KeyboardShortcuts.Name,
        KeyboardShortcuts.Shortcut?,
        NSEvent?
    ) -> Bool

    private let shortcutName: KeyboardShortcuts.Name
    private let proposalHandler: ProposalHandler
    private var eventMonitor: Any?
    private var windowObserver: NSObjectProtocol?

    init(
        name: KeyboardShortcuts.Name,
        proposalHandler: @escaping ProposalHandler
    ) {
        shortcutName = name
        self.proposalHandler = proposalHandler
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopRecording()
    }

    @objc private func beginRecording() {
        stopRecording()
        title = NSLocalizedString("Press shortcut", comment: "")
        state = .on
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            self?.handle(event) ?? event
        }
        if let window = window {
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.stopRecording()
            }
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 {
            stopRecording()
            return nil
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            commit(nil, event: nil)
            return nil
        }

        let modifiers = event.modifierFlags.intersection([
            .command, .control, .option, .shift
        ])
        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else {
            NSSound.beep()
            return nil
        }
        let functionKeys: Set<KeyboardShortcuts.Key> = [
            .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
            .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20
        ]
        guard !modifiers.isEmpty || shortcut.key.map(functionKeys.contains) == true else {
            NSSound.beep()
            return nil
        }
        commit(shortcut, event: event)
        return nil
    }

    private func commit(
        _ shortcut: KeyboardShortcuts.Shortcut?,
        event: NSEvent?
    ) {
        stopRecording()
        guard proposalHandler(shortcutName, shortcut, event) else {
            updateTitle()
            return
        }
        let previous = KeyboardShortcuts.getShortcut(for: shortcutName)
        KeyboardShortcuts.setShortcut(shortcut, for: shortcutName)
        guard KeyboardShortcuts.getShortcut(for: shortcutName) == shortcut else {
            KeyboardShortcuts.setShortcut(previous, for: shortcutName)
            NSAlert.alert(with: NSLocalizedString("Shortcut registration failed", comment: ""))
            updateTitle()
            return
        }
        KeyboardShortCutManager.shortcutDidChange(shortcutName)
        updateTitle()
    }

    private func stopRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
            self.windowObserver = nil
        }
        state = .off
        updateTitle()
    }

    private func updateTitle() {
        title = KeyboardShortcuts.getShortcut(for: shortcutName)
            .map { "\($0)" }
            ?? NSLocalizedString("Record Shortcut", comment: "")
    }
}

class GlobalShortCutViewController: NSViewController {
    @IBOutlet var proxyBox: NSBox!
    @IBOutlet var modeBoxView: NSView!
    @IBOutlet var otherBoxView: NSView!
    @IBOutlet var scopeDescriptionTextField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        let systemProxy = getRecoder(for: .toggleSystemProxyMode)
        let copyShellCommand = getRecoder(for: .copyShellCommand)
        let copyShellCommandExternal = getRecoder(for: .copyExternalShellCommand)
        addGridView(in: proxyBox.contentView!, with: [
            [NSTextField(labelWithString: NSLocalizedString("System Proxy", comment: "")), systemProxy],
            [NSTextField(labelWithString: NSLocalizedString("Copy Shell Command", comment: "")), copyShellCommand],
            [NSTextField(labelWithString: NSLocalizedString("Copy Shell Command (External)", comment: "")), copyShellCommandExternal]
        ])

        addGridView(in: modeBoxView, with: [
            [NSTextField(labelWithString: NSLocalizedString("Direct Mode", comment: "")), getRecoder(for: .modeDirect)],
            [NSTextField(labelWithString: NSLocalizedString("Rule Mode", comment: "")), getRecoder(for: .modeRule)],
            [NSTextField(labelWithString: NSLocalizedString("Global Mode", comment: "")), getRecoder(for: .modeGlobal)],
            [NSTextField(labelWithString: NSLocalizedString("Enhanced Mode", comment: "")), getRecoder(for: .toggleEnhancedMode)]
        ])

        var otherItems: [[NSView]] = [
            [NSTextField(labelWithString: NSLocalizedString("Shortcut Scope", comment: "")), makeGlobalShortcutsCheckbox()],
            [NSTextField(labelWithString: NSLocalizedString("Benchmark", comment: "")), getRecoder(for: .benchmark)],
            [NSTextField(labelWithString: NSLocalizedString("Open Menu", comment: "")), getRecoder(for: .openMenu)],
            [NSTextField(labelWithString: NSLocalizedString("Open Log", comment: "")), getRecoder(for: .log)],
            [NSTextField(labelWithString: NSLocalizedString("Open Dashboard", comment: "")), getRecoder(for: .dashboard)]
        ]
        if #available(macOS 10.15, *) {
            otherItems.append([NSTextField(labelWithString: NSLocalizedString("Open Connection Details", comment: "")), getRecoder(for: .nativeDashboard)])
        }
        addGridView(in: otherBoxView, with: otherItems)
        scopeDescriptionTextField.stringValue = NSLocalizedString(
            "Shortcuts work while the ClashFX menu is open. Enable global shortcuts to use them in other apps. Open Menu is always global.",
            comment: ""
        )
    }

    private func getRecoder(for name: KeyboardShortcuts.Name) -> NSView {
        let view = ClashFXShortcutRecorder(
            name: name,
            proposalHandler: { [weak self] name, shortcut, event in
                self?.acceptShortcutProposal(
                    name: name,
                    shortcut: shortcut,
                    event: event
                ) ?? false
            }
        )
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    private func acceptShortcutProposal(
        name: KeyboardShortcuts.Name,
        shortcut: KeyboardShortcuts.Shortcut?,
        event: NSEvent?
    ) -> Bool {
        let assignments = Dictionary(uniqueKeysWithValues:
            KeyboardShortCutManager.allShortcutNames.compactMap { candidate in
                KeyboardShortcuts.getShortcut(for: candidate).map {
                    (candidate.rawValue, signature(for: $0))
                }
            })
        if let duplicate = ShortcutRegistrationPolicy.duplicateOwner(
            command: name.rawValue,
            proposedSignature: shortcut.map { signature(for: $0) },
            assignments: assignments
        ) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("Shortcut already used", comment: "")
            alert.informativeText = String(
                format: NSLocalizedString("This shortcut is already assigned to %@.", comment: ""),
                duplicate
            )
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.runModal()
            return false
        }

        guard let shortcut else { return true }
        let menuItem = event.flatMap(matchingMainMenuItem(for:))
        let systemReserved = isKnownSystemShortcut(shortcut)
        guard ShortcutRegistrationPolicy.shouldWarnBeforeOverride(
            matchesMainMenu: menuItem != nil,
            isKnownSystemShortcut: systemReserved
        ) else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Shortcut conflicts with macOS", comment: "")
        if let menuItem = menuItem {
            alert.informativeText = String(
                format: NSLocalizedString("This shortcut is used by the “%@” menu command. Use it anyway?", comment: ""),
                menuItem.title
            )
        } else {
            alert.informativeText = NSLocalizedString(
                "This shortcut is commonly reserved by macOS. Use it anyway?",
                comment: ""
            )
        }
        alert.addButton(withTitle: NSLocalizedString("Use Anyway", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func signature(for shortcut: KeyboardShortcuts.Shortcut) -> String {
        "\(shortcut.carbonKeyCode):\(shortcut.carbonModifiers)"
    }

    private func matchingMainMenuItem(for event: NSEvent) -> NSMenuItem? {
        guard let menu = NSApp.mainMenu,
              let character = event.charactersIgnoringModifiers?.lowercased() else {
            return nil
        }
        let modifiers = event.modifierFlags.intersection([
            .command, .control, .option, .shift
        ])
        return matchingMenuItem(
            in: menu,
            keyEquivalent: character,
            modifiers: modifiers
        )
    }

    private func matchingMenuItem(
        in menu: NSMenu,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags
    ) -> NSMenuItem? {
        for item in menu.items {
            let itemModifiers = item.keyEquivalentModifierMask.intersection([
                .command, .control, .option, .shift
            ])
            if item.keyEquivalent.lowercased() == keyEquivalent,
               itemModifiers == modifiers {
                return item
            }
            if let submenu = item.submenu,
               let match = matchingMenuItem(
                   in: submenu,
                   keyEquivalent: keyEquivalent,
                   modifiers: modifiers
               ) {
                return match
            }
        }
        return nil
    }

    private func isKnownSystemShortcut(
        _ shortcut: KeyboardShortcuts.Shortcut
    ) -> Bool {
        let modifiers = shortcut.modifiers.intersection([
            .command, .control, .option, .shift
        ])
        guard let key = shortcut.key else { return false }
        if key == .space, modifiers == .command { return true }
        if key == .tab, modifiers == .command { return true }
        if [.leftArrow, .rightArrow, .upArrow, .downArrow].contains(key),
           modifiers == .control { return true }
        return false
    }

    private func makeGlobalShortcutsCheckbox() -> NSButton {
        let checkbox = NSButton(
            checkboxWithTitle: NSLocalizedString("Enable Global Shortcuts", comment: ""),
            target: self,
            action: #selector(toggleGlobalShortcuts(_:))
        )
        checkbox.state = Settings.actionShortcutScope == .global ? .on : .off
        return checkbox
    }

    @objc private func toggleGlobalShortcuts(_ sender: NSButton) {
        let scope: ShortcutScope = sender.state == .on ? .global : .menuOnly
        KeyboardShortCutManager.setActionScope(scope)
    }

    private func addGridView(in superView: NSView, with views: [[NSView]]) {
        let gridView = NSGridView(views: views)
        gridView.rowSpacing = 10
        superView.addSubview(gridView)
        gridView.makeConstraintsToBindToSuperview(NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        gridView.setContentHuggingPriority(.required, for: .vertical)
        gridView.setContentCompressionResistancePriority(.required, for: .vertical)
        gridView.xPlacement = .trailing
        gridView.column(at: 0).xPlacement = .leading
    }
}
