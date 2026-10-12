import AppKit

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class ThemePreviewButton: NSButton {
    let themeID: String
    var isChosen = false { didSet { needsDisplay = true } }

    init(themeID: String, title: String) {
        self.themeID = themeID
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        setButtonType(.momentaryChange)
        setAccessibilityLabel("\(title) theme")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let frame = bounds.insetBy(dx: 1, dy: 1)
        let card = NSBezierPath(roundedRect: frame, xRadius: 13, yRadius: 13)
        let base: NSColor = themeID == "noir" ? NSColor(white: 0.045, alpha: 1) : themeID == "graphite" ? NSColor(white: 0.19, alpha: 1) : NSColor(red: 0.075, green: 0.13, blue: 0.1, alpha: 1)
        base.setFill(); card.fill()
        let borderAccent: NSColor = themeID == "evergreen" ? NSColor(red: 0.6, green: 0.84, blue: 0.68, alpha: 1) : themeID == "graphite" ? NSColor(white: 0.82, alpha: 1) : .white
        (isChosen ? borderAccent : NSColor.white.withAlphaComponent(0.2)).setStroke()
        card.lineWidth = isChosen ? 2 : 1; card.stroke()

        let preview = NSRect(x: frame.minX + 10, y: frame.minY + 38, width: frame.width - 20, height: frame.height - 49)
        let canvas = NSBezierPath(roundedRect: preview, xRadius: 8, yRadius: 8)
        (themeID == "noir" ? NSColor(white: 0.075, alpha: 1) : themeID == "graphite" ? NSColor(white: 0.24, alpha: 1) : NSColor(red: 0.07, green: 0.18, blue: 0.12, alpha: 1)).setFill(); canvas.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke(); canvas.lineWidth = 0.8; canvas.stroke()
        let titleColor = NSColor.white.withAlphaComponent(0.9)
        let detailColor = NSColor.white.withAlphaComponent(themeID == "noir" ? 0.45 : 0.56)
        let accent: NSColor = themeID == "evergreen" ? NSColor(red: 0.6, green: 0.84, blue: 0.68, alpha: 1) : themeID == "graphite" ? NSColor(white: 0.82, alpha: 1) : NSColor.white
        let titleStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: titleColor]
        ("Untitled Note" as NSString).draw(at: NSPoint(x: preview.minX + 11, y: preview.minY + 12), withAttributes: titleStyle)
        let headingStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: titleColor]
        ("A better note" as NSString).draw(at: NSPoint(x: preview.minX + 11, y: preview.minY + 40), withAttributes: headingStyle)
        for index in 0..<3 {
            let line = NSRect(x: preview.minX + 11, y: preview.minY + 65 + CGFloat(index * 13), width: (preview.width - 25) * (index == 2 ? 0.58 : 0.9), height: 3)
            let path = NSBezierPath(roundedRect: line, xRadius: 1.5, yRadius: 1.5)
            detailColor.setFill(); path.fill()
        }
        let dot = NSBezierPath(ovalIn: NSRect(x: preview.minX + 11, y: preview.maxY - 22, width: 5, height: 5))
        accent.setFill(); dot.fill()
        let glass = NSBezierPath(roundedRect: NSRect(x: preview.midX - 26, y: preview.maxY - 29, width: 52, height: 17), xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(themeID == "noir" ? 0.2 : 0.27).setFill(); glass.fill()
        NSColor.white.withAlphaComponent(0.28).setStroke(); glass.lineWidth = 0.8; glass.stroke()
        let labelStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.white]
        (title as NSString).draw(at: NSPoint(x: frame.minX + 13, y: frame.minY + 12), withAttributes: labelStyle)
        if isChosen {
            let checkStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: accent]
            ("✓" as NSString).draw(at: NSPoint(x: frame.maxX - 23, y: frame.minY + 12), withAttributes: checkStyle)
        }
    }
}

private final class SettingsNavigationButton: NSButton {
    private let symbolView = NSImageView()
    private let titleView = NSTextField(labelWithString: "")

    init(title: String, symbol: String) {
        super.init(frame: .zero)
        self.title = ""
        isBordered = false
        setAccessibilityLabel(title)
        wantsLayer = true
        layer?.cornerRadius = 8
        symbolView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
        symbolView.imageScaling = .scaleProportionallyDown
        titleView.stringValue = title
        titleView.font = .systemFont(ofSize: 12, weight: .medium)
        for view in [symbolView, titleView] { view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view) }
        NSLayoutConstraint.activate([
            symbolView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 17), symbolView.heightAnchor.constraint(equalToConstant: 17),
            titleView.leadingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 12),
            titleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    func style(selected: Bool, accent: NSColor) {
        layer?.backgroundColor = selected ? accent.withAlphaComponent(0.16).cgColor : NSColor.clear.cgColor
        let color = selected ? accent : NSColor.white.withAlphaComponent(0.68)
        symbolView.contentTintColor = color
        titleView.textColor = color
    }
}

private final class GlassToggleButton: NSButton {
    var accent: NSColor = .white { didSet { needsDisplay = true } }

    init() {
        super.init(frame: .zero)
        title = ""
        isBordered = false
        setButtonType(.switch)
        setAccessibilityLabel("Liquid Glass")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        (state == .on ? accent : NSColor.white.withAlphaComponent(0.22)).setFill(); track.fill()
        NSColor.white.withAlphaComponent(0.22).setStroke(); track.lineWidth = 1; track.stroke()
        let thumbX = state == .on ? bounds.maxX - 22 : bounds.minX + 4
        let thumb = NSBezierPath(ovalIn: NSRect(x: thumbX, y: bounds.midY - 9, width: 18, height: 18))
        (state == .on && accent == .white ? NSColor.black : NSColor.white).setFill(); thumb.fill()
    }
}

struct ShortcutEntry: Decodable {
    let id: String
    let label: String
    let group: String
    var shortcut: String
    let defaultShortcut: String
}

final class NativeSettingsWindowController: NSWindowController, NSWindowDelegate, NSSearchFieldDelegate {
    var onShortcutChange: ((String, String) -> Void)?
    var onResetShortcuts: (() -> Void)?
    var onThemeChange: ((String) -> Void)?
    var onGlassChange: ((Bool, Int) -> Void)?

    private var entries: [ShortcutEntry] = []
    private var recordingID: String?
    private var keyMonitor: Any?
    private var searchKeyMonitor: Any?
    private let serverPath: String
    private let dataPath: String
    private var selectedSection = 0
    private var selectedTheme = "noir"
    private var settingsGlass: NSView?
    private var navButtons: [SettingsNavigationButton] = []
    private let appearancePane = NSView()
    private let themeCards = [ThemePreviewButton(themeID: "noir", title: "Noir"), ThemePreviewButton(themeID: "graphite", title: "Graphite"), ThemePreviewButton(themeID: "evergreen", title: "Evergreen")]
    private let glassSwitch = GlassToggleButton()
    private let glassSlider = NSSlider(value: 60, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let glassValue = NSTextField(labelWithString: "60%")
    private let shortcutsPane = NSView()
    private let mcpPane = NSView()
    private let search = NSSearchField()
    private let shortcutScroll = NSScrollView()
    private let rows = NSStackView()
    private let status = NSTextField(labelWithString: "Click a shortcut to record new keys.")
    private let agentPicker = NSPopUpButton()
    private let configPath = NSTextField(labelWithString: "")
    private let configText = NSTextView()
    private let copyButton = NSButton(title: "Copy Configuration", target: nil, action: nil)

    init(serverPath: String, dataPath: String) {
        self.serverPath = serverPath
        self.dataPath = dataPath
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 690, height: 625), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.titleVisibility = .visible
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(entries: [ShortcutEntry], tab: String) {
        self.entries = entries
        search.stringValue = ""
        refreshRows()
        selectedSection = tab == "mcp" ? 2 : tab == "shortcuts" ? 1 : 0
        switchTab()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(nil)
        window?.contentView?.layoutSubtreeIfNeeded()
        shortcutScroll.contentView.scroll(to: .zero)
        shortcutScroll.reflectScrolledClipView(shortcutScroll.contentView)
        installSearchKeyMonitor()
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording()
        if let searchKeyMonitor { NSEvent.removeMonitor(searchKeyMonitor); self.searchKeyMonitor = nil }
    }

    private func installSearchKeyMonitor() {
        guard searchKeyMonitor == nil else { return }
        searchKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window, self.selectedSection == 1, self.recordingID == nil else { return event }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "f" {
                self.window?.makeFirstResponder(self.search)
                self.search.selectText(nil)
                return nil
            }
            guard self.search.currentEditor() == nil,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  let characters = event.characters,
                  !characters.isEmpty,
                  characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return event }
            self.search.stringValue += characters
            self.refreshRows()
            self.window?.makeFirstResponder(self.search)
            self.search.currentEditor()?.selectedRange = NSRange(location: self.search.stringValue.utf16.count, length: 0)
            return nil
        }
    }

    private func buildUI() {
        guard let window else { return }
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.tintColor = NSColor(white: 0.18, alpha: 0.16)
            glass.contentView = content
            window.contentView = glass
            settingsGlass = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .windowBackground
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.addSubview(content)
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: effect.leadingAnchor), content.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                content.topAnchor.constraint(equalTo: effect.topAnchor), content.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
            ])
            window.contentView = effect
        }

        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.14).cgColor
        content.addSubview(sidebar)
        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.13).cgColor
        content.addSubview(divider)
        let sectionLabel = NSTextField(labelWithString: "NOTES")
        sectionLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        sectionLabel.textColor = .tertiaryLabelColor
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sectionLabel)
        for (index, item) in [("Appearance", "paintpalette"), ("Shortcuts", "keyboard"), ("MCP Server", "point.3.connected.trianglepath.dotted")].enumerated() {
            let button = SettingsNavigationButton(title: item.0, symbol: item.1)
            button.target = self
            button.action = #selector(navigationClicked(_:))
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            sidebar.addSubview(button)
            navButtons.append(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 13),
                button.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -13),
                button.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 14 + CGFloat(index * 39)),
                button.heightAnchor.constraint(equalToConstant: 33)
            ])
        }
        for pane in [appearancePane, shortcutsPane, mcpPane] {
            pane.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(pane)
            NSLayoutConstraint.activate([
                pane.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 24),
                pane.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
                pane.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
                pane.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
            ])
        }
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor), sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor), sidebar.widthAnchor.constraint(equalToConstant: 170),
            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor), divider.topAnchor.constraint(equalTo: content.topAnchor),
            divider.bottomAnchor.constraint(equalTo: content.bottomAnchor), divider.widthAnchor.constraint(equalToConstant: 1),
            sectionLabel.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 25),
            sectionLabel.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 31)
        ])
        buildAppearancePane()
        buildShortcutsPane()
        buildMCPPane()
        switchTab()
    }

    func setTheme(_ theme: String) {
        selectedTheme = theme
        for card in themeCards { card.isChosen = card.themeID == theme }
        updateNavigationStyle()
        let accent: NSColor = theme == "evergreen" ? NSColor(red: 0.6, green: 0.84, blue: 0.68, alpha: 1) : theme == "graphite" ? NSColor(white: 0.82, alpha: 1) : .white
        glassSwitch.accent = accent
        glassSlider.trackFillColor = accent
        setGlass(enabled: glassSwitch.state == .on, strength: glassSlider.integerValue)
    }

    func setGlass(enabled: Bool, strength: Int) {
        glassSwitch.state = enabled ? .on : .off
        glassSlider.integerValue = max(0, min(100, strength))
        glassSlider.isEnabled = enabled
        glassValue.stringValue = "\(glassSlider.integerValue)%"
        glassValue.textColor = enabled ? .secondaryLabelColor : .tertiaryLabelColor
        if #available(macOS 26.0, *) {
            let tint: NSColor = selectedTheme == "evergreen" ? NSColor(red: 0.12, green: 0.17, blue: 0.14, alpha: 1) : selectedTheme == "graphite" ? NSColor(white: 0.23, alpha: 1) : NSColor(white: 0.1, alpha: 1)
            (settingsGlass as? NSGlassEffectView)?.tintColor = tint.withAlphaComponent(enabled ? CGFloat(100 - glassSlider.integerValue) / 350 : 1)
        }
    }

    private func buildAppearancePane() {
        let heading = NSTextField(labelWithString: "Theme")
        heading.font = .systemFont(ofSize: 16, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString: "Choose the look of your notes. Your choice is saved and restored when Notes opens.")
        description.font = .systemFont(ofSize: 12)
        description.textColor = .secondaryLabelColor
        let cardRow = NSStackView(views: themeCards)
        cardRow.orientation = .horizontal
        cardRow.spacing = 10
        cardRow.distribution = .fillEqually
        cardRow.alignment = .centerY
        for card in themeCards {
            card.target = self
            card.action = #selector(themeChanged(_:))
            card.heightAnchor.constraint(equalToConstant: 178).isActive = true
        }
        setTheme("noir")
        let detail = NSTextField(wrappingLabelWithString: "The preview reflects the editor, text, accent, selection, and glass controls. Themes apply immediately across the app.")
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        let glassHeading = NSTextField(labelWithString: "Liquid Glass")
        glassHeading.font = .systemFont(ofSize: 14, weight: .semibold)
        let glassDescription = NSTextField(labelWithString: "Translucent windows, menus, and controls")
        glassDescription.font = .systemFont(ofSize: 11)
        glassDescription.textColor = .secondaryLabelColor
        let strengthLabel = NSTextField(labelWithString: "Strength")
        strengthLabel.font = .systemFont(ofSize: 12)
        glassValue.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        glassValue.textColor = .secondaryLabelColor
        glassValue.alignment = .right
        glassSwitch.target = self
        glassSwitch.action = #selector(glassChanged(_:))
        glassSlider.target = self
        glassSlider.action = #selector(glassChanged(_:))
        for view in [heading, description, cardRow, detail, separator, glassHeading, glassDescription, glassSwitch, strengthLabel, glassSlider, glassValue] {
            view.translatesAutoresizingMaskIntoConstraints = false
            appearancePane.addSubview(view)
        }
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), heading.topAnchor.constraint(equalTo: appearancePane.topAnchor, constant: 6),
            description.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), description.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor),
            description.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 9),
            cardRow.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), cardRow.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor),
            cardRow.topAnchor.constraint(equalTo: description.bottomAnchor, constant: 24), cardRow.heightAnchor.constraint(equalToConstant: 178),
            detail.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), detail.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor),
            detail.topAnchor.constraint(equalTo: cardRow.bottomAnchor, constant: 18),
            separator.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), separator.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor),
            separator.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 22), separator.heightAnchor.constraint(equalToConstant: 1),
            glassHeading.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), glassHeading.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 22),
            glassDescription.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), glassDescription.topAnchor.constraint(equalTo: glassHeading.bottomAnchor, constant: 5),
            glassSwitch.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor), glassSwitch.centerYAnchor.constraint(equalTo: glassHeading.centerYAnchor),
            glassSwitch.widthAnchor.constraint(equalToConstant: 42), glassSwitch.heightAnchor.constraint(equalToConstant: 24),
            strengthLabel.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), strengthLabel.topAnchor.constraint(equalTo: glassDescription.bottomAnchor, constant: 28),
            glassValue.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor), glassValue.centerYAnchor.constraint(equalTo: strengthLabel.centerYAnchor), glassValue.widthAnchor.constraint(equalToConstant: 38),
            glassSlider.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor), glassSlider.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor),
            glassSlider.topAnchor.constraint(equalTo: strengthLabel.bottomAnchor, constant: 10)
        ])
    }

    @objc private func themeChanged(_ sender: ThemePreviewButton) {
        setTheme(sender.themeID)
        onThemeChange?(sender.themeID)
    }

    @objc private func glassChanged(_ sender: NSControl) {
        let enabled = glassSwitch.state == .on
        setGlass(enabled: enabled, strength: glassSlider.integerValue)
        onGlassChange?(enabled, glassSlider.integerValue)
    }

    private func buildShortcutsPane() {
        search.placeholderString = "Search shortcuts"
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        shortcutsPane.addSubview(search)
        let scroll = shortcutScroll
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        shortcutsPane.addSubview(scroll)
        let document = FlippedDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rows)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor), rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor), rows.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            rows.widthAnchor.constraint(equalTo: document.widthAnchor)
        ])
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        shortcutsPane.addSubview(status)
        let reset = NSButton(title: "Reset Defaults", target: self, action: #selector(resetClicked(_:)))
        reset.bezelStyle = .rounded
        reset.translatesAutoresizingMaskIntoConstraints = false
        shortcutsPane.addSubview(reset)
        NSLayoutConstraint.activate([
            search.leadingAnchor.constraint(equalTo: shortcutsPane.leadingAnchor), search.trailingAnchor.constraint(equalTo: shortcutsPane.trailingAnchor),
            search.topAnchor.constraint(equalTo: shortcutsPane.topAnchor), search.heightAnchor.constraint(equalToConstant: 34),
            scroll.leadingAnchor.constraint(equalTo: shortcutsPane.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: shortcutsPane.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 12), scroll.bottomAnchor.constraint(equalTo: reset.topAnchor, constant: -13),
            status.leadingAnchor.constraint(equalTo: shortcutsPane.leadingAnchor), status.centerYAnchor.constraint(equalTo: reset.centerYAnchor),
            status.trailingAnchor.constraint(lessThanOrEqualTo: reset.leadingAnchor, constant: -10),
            reset.trailingAnchor.constraint(equalTo: shortcutsPane.trailingAnchor), reset.bottomAnchor.constraint(equalTo: shortcutsPane.bottomAnchor),
            reset.heightAnchor.constraint(equalToConstant: 29)
        ])
    }

    private func buildMCPPane() {
        let heading = NSTextField(labelWithString: "Connect agents to Notes")
        heading.font = .systemFont(ofSize: 16, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString: "This local MCP server lets agents search, read, create, edit, and restore notes. Changes sync with the app.")
        description.font = .systemFont(ofSize: 12)
        description.textColor = .secondaryLabelColor
        let agentLabel = NSTextField(labelWithString: "Agent")
        agentLabel.font = .systemFont(ofSize: 12, weight: .medium)
        agentPicker.addItems(withTitles: ["Codex", "Claude Desktop", "Claude Code", "Cursor", "VS Code", "Other MCP client"])
        agentPicker.target = self
        agentPicker.action = #selector(agentChanged(_:))
        configPath.font = .systemFont(ofSize: 11)
        configPath.textColor = .secondaryLabelColor
        configText.isEditable = false
        configText.isSelectable = true
        configText.drawsBackground = false
        configText.frame = NSRect(x: 0, y: 0, width: 640, height: 205)
        configText.minSize = NSSize(width: 0, height: 205)
        configText.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        configText.isVerticallyResizable = true
        configText.isHorizontallyResizable = false
        configText.autoresizingMask = [.width]
        configText.textContainer?.widthTracksTextView = true
        configText.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        configText.textColor = .labelColor
        configText.textContainerInset = NSSize(width: 12, height: 12)
        let configScroll = NSScrollView()
        configScroll.hasVerticalScroller = true
        configScroll.hasHorizontalScroller = true
        configScroll.autohidesScrollers = true
        configScroll.borderType = .bezelBorder
        configScroll.drawsBackground = false
        configScroll.documentView = configText
        copyButton.target = self
        copyButton.action = #selector(copyConfig(_:))
        copyButton.bezelStyle = .rounded
        let dataLabel = NSTextField(wrappingLabelWithString: "Notes data: \(dataPath)\nAdd the configuration to your agent, then restart or reload it. Move Notes.app to its final location before copying the path.")
        dataLabel.font = .systemFont(ofSize: 11)
        dataLabel.textColor = .secondaryLabelColor
        for view in [heading, description, agentLabel, agentPicker, configPath, configScroll, copyButton, dataLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            mcpPane.addSubview(view)
        }
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: mcpPane.leadingAnchor), heading.topAnchor.constraint(equalTo: mcpPane.topAnchor),
            description.leadingAnchor.constraint(equalTo: mcpPane.leadingAnchor), description.trailingAnchor.constraint(equalTo: mcpPane.trailingAnchor),
            description.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            agentLabel.leadingAnchor.constraint(equalTo: mcpPane.leadingAnchor), agentLabel.topAnchor.constraint(equalTo: description.bottomAnchor, constant: 24),
            agentPicker.leadingAnchor.constraint(equalTo: mcpPane.leadingAnchor), agentPicker.trailingAnchor.constraint(equalTo: mcpPane.trailingAnchor),
            agentPicker.topAnchor.constraint(equalTo: agentLabel.bottomAnchor, constant: 7), agentPicker.heightAnchor.constraint(equalToConstant: 30),
            configPath.leadingAnchor.constraint(equalTo: mcpPane.leadingAnchor), configPath.topAnchor.constraint(equalTo: agentPicker.bottomAnchor, constant: 20),
            configScroll.leadingAnchor.constraint(equalTo: mcpPane.leadingAnchor), configScroll.trailingAnchor.constraint(equalTo: mcpPane.trailingAnchor),
            configScroll.topAnchor.constraint(equalTo: configPath.bottomAnchor, constant: 8), configScroll.heightAnchor.constraint(equalToConstant: 205),
            copyButton.trailingAnchor.constraint(equalTo: mcpPane.trailingAnchor), copyButton.topAnchor.constraint(equalTo: configScroll.bottomAnchor, constant: 11),
            copyButton.heightAnchor.constraint(equalToConstant: 29),
            dataLabel.leadingAnchor.constraint(equalTo: mcpPane.leadingAnchor), dataLabel.trailingAnchor.constraint(equalTo: mcpPane.trailingAnchor),
            dataLabel.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 20),
            dataLabel.bottomAnchor.constraint(lessThanOrEqualTo: mcpPane.bottomAnchor)
        ])
        updateMCPConfig()
    }

    private func refreshRows() {
        for view in rows.arrangedSubviews { rows.removeArrangedSubview(view); view.removeFromSuperview() }
        let query = search.stringValue.lowercased()
        var group = ""
        for entry in entries where query.isEmpty || (entry.label + " " + entry.group).lowercased().contains(query) {
            if entry.group != group {
                group = entry.group
                let heading = NSTextField(labelWithString: group.uppercased())
                heading.font = .systemFont(ofSize: 10, weight: .semibold)
                heading.textColor = .secondaryLabelColor
                let holder = NSView()
                holder.addSubview(heading)
                heading.translatesAutoresizingMaskIntoConstraints = false
                rows.addArrangedSubview(holder)
                NSLayoutConstraint.activate([
                    holder.heightAnchor.constraint(equalToConstant: 34), holder.widthAnchor.constraint(equalTo: rows.widthAnchor),
                    heading.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 8), heading.bottomAnchor.constraint(equalTo: holder.bottomAnchor, constant: -6)
                ])
            }
            let row = NSView()
            let label = NSTextField(labelWithString: entry.label)
            label.font = .systemFont(ofSize: 12)
            let key = NSButton(title: shortcutLabel(entry.shortcut), target: self, action: #selector(shortcutClicked(_:)))
            key.identifier = NSUserInterfaceItemIdentifier(entry.id)
            key.bezelStyle = .rounded
            key.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
            key.setAccessibilityLabel("Change shortcut for \(entry.label)")
            for view in [label, key] { view.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(view) }
            rows.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: 38), row.widthAnchor.constraint(equalTo: rows.widthAnchor),
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8), label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: key.leadingAnchor, constant: -10),
                key.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8), key.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                key.widthAnchor.constraint(equalToConstant: 116), key.heightAnchor.constraint(equalToConstant: 27)
            ])
        }
        rows.layoutSubtreeIfNeeded()
        shortcutScroll.contentView.scroll(to: .zero)
        shortcutScroll.reflectScrolledClipView(shortcutScroll.contentView)
    }

    func controlTextDidChange(_ obj: Notification) { refreshRows() }
    @objc private func navigationClicked(_ sender: SettingsNavigationButton) {
        selectedSection = sender.tag
        stopRecording()
        switchTab()
        window?.makeFirstResponder(nil)
    }
    private func switchTab() {
        appearancePane.isHidden = selectedSection != 0
        shortcutsPane.isHidden = selectedSection != 1
        mcpPane.isHidden = selectedSection != 2
        updateNavigationStyle()
        if selectedSection == 2 { updateMCPConfig() }
    }

    private func updateNavigationStyle() {
        let accent: NSColor = selectedTheme == "evergreen" ? NSColor(red: 0.6, green: 0.84, blue: 0.68, alpha: 1) : selectedTheme == "graphite" ? NSColor(white: 0.82, alpha: 1) : .white
        for (index, button) in navButtons.enumerated() {
            button.style(selected: index == selectedSection, accent: accent)
        }
    }

    @objc private func shortcutClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let entry = entries.first(where: { $0.id == id }) else { return }
        stopRecording()
        recordingID = id
        sender.title = "Press keys…"
        setStatus("Press a shortcut for \(entry.label). Backspace clears it; Esc cancels.")
        window?.makeFirstResponder(sender)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recordingID != nil, event.window === self.window else { return event }
            self.record(event)
            return nil
        }
    }

    private func record(_ event: NSEvent) {
        guard let id = recordingID else { return }
        if event.keyCode == 53 { stopRecording(); refreshRows(); setStatus("Recording cancelled."); return }
        if event.keyCode == 51 || event.keyCode == 117 { commitShortcut(id, value: ""); return }
        guard let combo = eventShortcut(event) else { return }
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            let reserved = ["Meta+C", "Meta+V", "Meta+X", "Meta+A", "Meta+Z", "Meta+Shift+Z", "Meta+Q", "Meta+W", "Meta+H", "Meta+M", "Meta+Tab"]
            if reserved.contains(combo) { setStatus("That shortcut is reserved by macOS.", error: true); return }
            if let other = entries.first(where: { $0.id != id && $0.shortcut == combo }) { setStatus("\(shortcutLabel(combo)) is used by \(other.label).", error: true); return }
            commitShortcut(id, value: combo)
        } else { setStatus("Use ⌘, ⌃, or ⌥ with another key.", error: true) }
    }

    private func commitShortcut(_ id: String, value: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) { entries[index].shortcut = value }
        stopRecording()
        refreshRows()
        setStatus(value.isEmpty ? "Shortcut cleared." : "Shortcut updated.")
        onShortcutChange?(id, value)
    }

    private func stopRecording() {
        recordingID = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
    }

    @objc private func resetClicked(_ sender: NSButton) {
        stopRecording()
        for index in entries.indices { entries[index].shortcut = entries[index].defaultShortcut }
        refreshRows()
        setStatus("Default shortcuts restored.")
        onResetShortcuts?()
    }

    private func setStatus(_ message: String, error: Bool = false) {
        status.stringValue = message
        status.textColor = error ? .systemRed : .secondaryLabelColor
    }

    private func eventShortcut(_ event: NSEvent) -> String? {
        let special: [UInt16: String] = [123:"ArrowLeft", 124:"ArrowRight", 125:"ArrowDown", 126:"ArrowUp", 48:"Tab", 49:"Space"]
        let key = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased()
        guard let key, !key.isEmpty else { return nil }
        var parts: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.command) { parts.append("Meta") }
        if flags.contains(.control) { parts.append("Ctrl") }
        if flags.contains(.option) { parts.append("Alt") }
        if flags.contains(.shift) { parts.append("Shift") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    private func shortcutLabel(_ combo: String) -> String {
        if combo.isEmpty { return "Set Shortcut" }
        let symbols = ["Meta":"⌘", "Ctrl":"⌃", "Alt":"⌥", "Shift":"⇧", "ArrowUp":"↑", "ArrowDown":"↓", "ArrowLeft":"←", "ArrowRight":"→", "Space":"Space"]
        return combo.split(separator: "+").map { symbols[String($0)] ?? String($0) }.joined()
    }

    @objc private func agentChanged(_ sender: NSPopUpButton) { updateMCPConfig() }
    private func quoted(_ value: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let bytes = try? encoder.encode(value)
        return bytes.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
    private func updateMCPConfig() {
        let command = "/usr/bin/python3"
        let entry: [String: Any] = ["command": command, "args": [serverPath]]
        let selection = agentPicker.indexOfSelectedItem
        if selection == 0 {
            configPath.stringValue = "~/.codex/config.toml"
            configText.string = "[mcp_servers.notes]\ncommand = \(quoted(command))\nargs = [\(quoted(serverPath))]\n\n[mcp_servers.notes.tools.list_notes]\napproval_mode = \"approve\"\n\n[mcp_servers.notes.tools.search_notes]\napproval_mode = \"approve\"\n\n[mcp_servers.notes.tools.get_note]\napproval_mode = \"approve\""
            return
        }
        let wrapper: [String: Any]
        if selection == 4 {
            configPath.stringValue = ".vscode/mcp.json"
            wrapper = ["servers": ["notes": ["type": "stdio", "command": command, "args": [serverPath]]]]
        } else {
            configPath.stringValue = [1:"~/Library/Application Support/Claude/claude_desktop_config.json", 2:".mcp.json (project root)", 3:"~/.cursor/mcp.json", 5:"Your agent's MCP config"][selection] ?? "Your agent's MCP config"
            wrapper = ["mcpServers": ["notes": entry]]
        }
        let bytes = try? JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
        configText.string = bytes.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    @objc private func copyConfig(_ sender: NSButton) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configText.string, forType: .string)
        copyButton.title = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.copyButton.title = "Copy Configuration" }
    }
}
