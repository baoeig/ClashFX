//
//  TrayIconPickerView.swift
//  ClashFX
//
//  Created by copilot on 2026/4/15.
//

import Cocoa
import UniformTypeIdentifiers

class TrayIconPickerView: ImagePickerView {
    private let builtInStack = NSStackView()
    private var iconButtons: [String: NSButton] = [:]

    private lazy var _config = ImagePickerConfig(
        imagePreviewSize: 32,
        descriptionText: NSLocalizedString("Drag and drop a PNG image, or click to select.\nRecommended: 36x36 px (72x72 for Retina @2x), PNG format.", comment: ""),
        selectPanelTitle: NSLocalizedString("Select Tray Icon Image", comment: ""),
        dragUTI: "public.png",
        maxDimension: 256,
        customImagePath: StatusItemTool.customImagePath,
        changeFailedText: NSLocalizedString("Failed to change tray icon", comment: ""),
        resetFailedText: NSLocalizedString("Failed to reset tray icon", comment: ""),
        sizeWarningFormat: NSLocalizedString("Image is too large (%d×%d). Maximum allowed size is %d×%d pixels. Recommended size is 36×36 pixels (72×72 for Retina @2x).", comment: ""),
        allowedFileTypes: ["png"],
        allowedContentTypesProvider: {
            if #available(macOS 11.0, *) { return [UTType.png] }
            return []
        }
    )

    override var pickerConfig: ImagePickerConfig {
        _config
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    override func currentImage() -> NSImage {
        StatusItemTool.menuImage
    }

    override func makeAdditionalContentView() -> NSView? {
        builtInStack.translatesAutoresizingMaskIntoConstraints = false
        builtInStack.orientation = .vertical
        builtInStack.alignment = .leading
        builtInStack.spacing = 6

        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Built-in menu bar icons", comment: ""))
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        builtInStack.addArrangedSubview(titleLabel)

        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 6
        grid.columnSpacing = 6

        let defaultButton = makeIconButton(
            id: StatusItemTool.defaultMenuIconID,
            title: NSLocalizedString("Default", comment: ""),
            image: StatusItemTool.loadDefaultPreviewIcon()
        )
        let buttons = [defaultButton] + StatusItemTool.builtInMenuIcons.map { icon in
            makeIconButton(id: icon.id, title: icon.title, image: StatusItemTool.loadBuiltInMenuIcon(icon))
        }

        for rowStart in stride(from: 0, to: buttons.count, by: 3) {
            grid.addRow(with: Array(buttons[rowStart ..< min(rowStart + 3, buttons.count)]))
        }
        builtInStack.addArrangedSubview(grid)
        updateIconSelection()

        return builtInStack
    }

    override func didReloadImage() {
        if FileManager.default.fileExists(atPath: StatusItemTool.customImagePath) {
            StatusItemTool.selectCustomMenuIcon()
        } else {
            StatusItemTool.selectDefaultMenuIcon()
        }
        refreshStatusItemImage()
        updateIconSelection()
    }

    override func updatePreview() {
        imageView.image = currentImage()
        resetButton.isEnabled = !StatusItemTool.isDefaultMenuIconSelected || FileManager.default.fileExists(atPath: pickerConfig.customImagePath)
        updateIconSelection()
    }

    private func makeIconButton(id: String, title: String, image: NSImage?) -> NSButton {
        let button = NSButton(title: "", target: self, action: #selector(selectBuiltInIcon(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.identifier = NSUserInterfaceItemIdentifier(id)
        button.isBordered = false
        button.setButtonType(.toggle)
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1

        let iconView = NSImageView(image: image ?? NSImage())
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        button.addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        button.addSubview(titleLabel)

        iconButtons[id] = button

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 86),
            button.heightAnchor.constraint(equalToConstant: 76),

            iconView.topAnchor.constraint(equalTo: button.topAnchor, constant: 8),
            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 5),
            titleLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -5),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: button.bottomAnchor, constant: -5)
        ])

        return button
    }

    @objc private func selectBuiltInIcon(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        if id == StatusItemTool.defaultMenuIconID {
            StatusItemTool.selectDefaultMenuIcon()
        } else {
            StatusItemTool.selectBuiltInMenuIcon(id: id)
        }
        refreshStatusItemImage()
        updatePreview()
    }

    private func updateIconSelection() {
        let selectedID = StatusItemTool.selectedMenuIconID
        for (id, button) in iconButtons {
            let isSelected = id == selectedID
            button.state = isSelected ? .on : .off
            button.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor : NSColor.clear.cgColor
            button.layer?.borderColor = isSelected ? NSColor.controlAccentColor.cgColor : NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        }
    }

    private func refreshStatusItemImage() {
        if let view = AppDelegate.shared.statusItemView as? StatusItemView {
            view.imageView.image = StatusItemTool.menuImage
        }
    }
}
