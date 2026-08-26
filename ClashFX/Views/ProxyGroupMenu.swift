//
//  ProxyGroupMenu.swift
//  ClashX
//
//  Created by yicheng on 2020/2/22.
//  Copyright © 2020 west2online. All rights reserved.
//
import AppKit

@objc protocol ProxyGroupMenuHighlightDelegate: AnyObject {
    func highlight(item: NSMenuItem?)
}

class ProxyGroupMenu: NSMenu {
    var highlightDelegates = NSHashTable<ProxyGroupMenuHighlightDelegate>.weakObjects()
    private var preparationState = ProxyMenuPreparationState()
    private var prepareHandler: ((ProxyGroupMenu) -> Void)?

    override init(title: String) {
        super.init(title: title)
        delegate = self
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    convenience init(title: String, prepareHandler: @escaping (ProxyGroupMenu) -> Void) {
        self.init(title: title)
        self.prepareHandler = prepareHandler
        let placeholder = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        placeholder.isEnabled = false
        addItem(placeholder)
    }

    func prepareIfNeeded() {
        guard preparationState.begin(), let prepareHandler else { return }
        self.prepareHandler = nil
        removeAllItems()
        prepareHandler(self)
    }

    func add(delegate: ProxyGroupMenuHighlightDelegate) {
        highlightDelegates.add(delegate)
    }

    func remove(_ delegate: ProxyGroupMenuHighlightDelegate) {
        highlightDelegates.remove(delegate)
    }
}

extension ProxyGroupMenu: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        prepareIfNeeded()
    }

    func menuDidClose(_ menu: NSMenu) {
        highlightDelegates.allObjects.forEach { $0.highlight(item: nil) }
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        highlightDelegates.allObjects.forEach { $0.highlight(item: item) }
    }
}
