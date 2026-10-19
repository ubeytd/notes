import AppKit
import WebKit
import Darwin

private enum NotesResources {
    static var editorIndex: URL {
        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        return executable.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Notes_Notes.bundle/Contents/Resources/Web/index.html")
    }
}

final class TitleDragView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        if local.x < 78 || local.x > bounds.width - 150 { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKUIDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var formatBar: NSView!
    private var formatToggle: NSView?
    private var toolbarVisible = true
    private var settingsWindow: NativeSettingsWindowController?
    private var onboardingWindow: OnboardingWindowController?
    private var backgroundGlass: NSView?
    private var backgroundBlur: NSVisualEffectView?
    private var currentTheme = "noir"
    private var glassEnabled = true
    private var glassStrength = 60
    private let globalShortcuts = GlobalShortcuts()

    private var notesFile: URL {
        if let override = ProcessInfo.processInfo.environment["NOTES_DATA_FILE"] { return URL(fileURLWithPath: override) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Notes/notes.json")
    }

    private func withNotesLock<T>(_ operation: () throws -> T) -> T? {
        let file = notesFile
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lock = file.deletingPathExtension().appendingPathExtension("lock")
        let descriptor = open(lock.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return nil }
        flock(descriptor, LOCK_EX)
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        if ProcessInfo.processInfo.environment["NOTES_DATA_FILE"] == nil,
           !FileManager.default.fileExists(atPath: file.path) {
            let legacy = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/NotesRebuild/notes.json")
            if FileManager.default.fileExists(atPath: legacy.path) {
                guard (try? FileManager.default.copyItem(at: legacy, to: file)) != nil else { return nil }
            }
        }
        return try? operation()
    }

    private func loadNotesFromDisk() {
        guard let content = withNotesLock({ () throws -> String in
            if !FileManager.default.fileExists(atPath: notesFile.path) { return "" }
            return try String(contentsOf: notesFile, encoding: .utf8)
        }) else {
            webView.evaluateJavaScript("window.notesStorageError('read')")
            return
        }
        if !content.isEmpty {
            guard let bytes = content.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  object["notes"] is [[String: Any]] else {
                webView.evaluateJavaScript("window.notesStorageError('read')")
                return
            }
        }
        guard let argument = String(data: (try? JSONEncoder().encode(content)) ?? Data(), encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.notesReceiveDiskData(\(argument))")
    }

    private func saveNotesToDisk(_ content: String) {
        guard let bytes = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              object["notes"] is [[String: Any]] else {
            webView.evaluateJavaScript("window.notesStorageError('write')")
            return
        }
        guard withNotesLock({ try bytes.write(to: notesFile, options: .atomic); return true }) == true else {
            webView.evaluateJavaScript("window.notesStorageError('write')")
            return
        }
    }

    private func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openShortcutSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(withTitle: "Welcome to Notes…", action: #selector(showOnboarding(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Notes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [
            ("Undo", "undo:", "z"), ("Redo", "redo:", "Z"),
            ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
            ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")
        ] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    private func glassView() -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 22
            glass.tintColor = NSColor(white: 0.15, alpha: 0.22)
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 22
        effect.layer?.masksToBounds = true
        return effect
    }

    private func button(_ title: String, command: String, width: CGFloat = 36) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(formatClicked(_:)))
        let symbols = ["heading":"textformat.size", "paragraph":"paragraphsign", "link":"link", "code":"chevron.left.forwardslash.chevron.right", "quote":"text.quote", "ordered":"list.number", "bullet":"list.bullet", "toggleToolbar":"slider.horizontal.3"]
        if let symbol = symbols[command], let image = NSImage(systemSymbolName: symbol, accessibilityDescription: command.capitalized) {
            button.title = ""
            button.image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            if ["heading", "paragraph", "bullet"].contains(command), let arrow = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil) {
                let chevron = NSImageView(image: arrow.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold)) ?? arrow)
                chevron.contentTintColor = NSColor(white: 0.72, alpha: 1)
                chevron.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(chevron)
                NSLayoutConstraint.activate([chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -3), chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor), chevron.widthAnchor.constraint(equalToConstant: 9), chevron.heightAnchor.constraint(equalToConstant: 9)])
            }
        }
        button.identifier = NSUserInterfaceItemIdentifier(command)
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 17, weight: .medium)
        button.contentTintColor = NSColor(white: 0.88, alpha: 1)
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        button.toolTip = command.capitalized
        return button
    }

    private func addGlassControls(to container: NSView) {
        let bar = glassView()
        let stack = NSStackView(views: [
            button("H⌄", command: "heading", width: 48),
            button("¶⌄", command: "paragraph", width: 48),
            button("↗", command: "link"),
            button("‹›", command: "code"),
            button("❞", command: "quote"),
            button("≡", command: "ordered"),
            button("☷⌄", command: "bullet", width: 48)
        ])
        stack.orientation = .horizontal
        stack.spacing = 3
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        if #available(macOS 26.0, *), let glass = bar as? NSGlassEffectView { glass.contentView = stack }
        else { bar.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false; NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor), stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor), stack.topAnchor.constraint(equalTo: bar.topAnchor), stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor)]) }
        bar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bar)
        NSLayoutConstraint.activate([bar.centerXAnchor.constraint(equalTo: container.centerXAnchor), bar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18), bar.heightAnchor.constraint(equalToConstant: 44)])
        formatBar = bar

        let toggleGlass = glassView()
        let toggle = button("☷", command: "toggleToolbar", width: 36)
        toggle.toolTip = "Show or hide formatting toolbar"
        if #available(macOS 26.0, *), let glass = toggleGlass as? NSGlassEffectView { glass.contentView = toggle }
        else { toggleGlass.addSubview(toggle); toggle.translatesAutoresizingMaskIntoConstraints = false; NSLayoutConstraint.activate([toggle.leadingAnchor.constraint(equalTo: toggleGlass.leadingAnchor), toggle.trailingAnchor.constraint(equalTo: toggleGlass.trailingAnchor), toggle.topAnchor.constraint(equalTo: toggleGlass.topAnchor), toggle.bottomAnchor.constraint(equalTo: toggleGlass.bottomAnchor)]) }
        toggleGlass.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toggleGlass)
        formatToggle = toggleGlass
        NSLayoutConstraint.activate([toggleGlass.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18), toggleGlass.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18), toggleGlass.widthAnchor.constraint(equalToConstant: 44), toggleGlass.heightAnchor.constraint(equalToConstant: 44)])
    }

    @objc private func formatClicked(_ sender: NSButton) {
        guard let command = sender.identifier?.rawValue else { return }
        if command == "toggleToolbar" { toggleToolbar(); return }
        if ["heading", "paragraph", "bullet"].contains(command) {
            webView.evaluateJavaScript("window.notesToggleFormatMenu(\"\(command)\")")
            return
        }
        webView.evaluateJavaScript("window.notesFormat(\"\(command)\")")
    }

    private func toggleToolbar() {
        toolbarVisible.toggle()
        formatBar.isHidden = !toolbarVisible
        webView.evaluateJavaScript("window.notesCloseFormatMenu()")
    }

    @objc private func openShortcutSettings(_ sender: Any?) {
        webView.evaluateJavaScript("window.notesOpenSettings()")
    }

    @objc private func showOnboarding(_ sender: Any?) {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController()
            onboardingWindow?.onFinish = { [weak self] in self?.window?.makeKeyAndOrderFront(nil) }
        }
        onboardingWindow?.showWindow(nil)
        onboardingWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings(_ json: String, tab: String) {
        guard let bytes = json.data(using: .utf8), let entries = try? JSONDecoder().decode([ShortcutEntry].self, from: bytes) else { return }
        if settingsWindow == nil {
            let server = Bundle.main.resourceURL?.appendingPathComponent("notes_mcp_server.py").path ?? ""
            let controller = NativeSettingsWindowController(serverPath: server, dataPath: notesFile.path)
            controller.onShortcutChange = { [weak self] id, value in
                guard let self, let idString = self.jsLiteral(id), let valueString = self.jsLiteral(value) else { return }
                self.webView.evaluateJavaScript("window.notesSetShortcut(\(idString),\(valueString))")
            }
            controller.onResetShortcuts = { [weak self] in self?.webView.evaluateJavaScript("window.notesResetShortcuts()") }
            controller.onThemeChange = { [weak self] theme in
                guard let self, let literal = self.jsLiteral(theme) else { return }
                self.webView.evaluateJavaScript("window.notesSetTheme(\(literal))")
            }
            controller.onGlassChange = { [weak self] enabled, strength in
                self?.webView.evaluateJavaScript("window.notesSetGlass(\(enabled ? "true" : "false"),\(strength))")
            }
            settingsWindow = controller
        }
        settingsWindow?.setTheme(currentTheme)
        settingsWindow?.setGlass(enabled: glassEnabled, strength: glassStrength)
        settingsWindow?.present(entries: entries, tab: tab)
    }

    private func applyTheme(_ theme: String) {
        guard ["noir", "graphite", "evergreen"].contains(theme) else { return }
        currentTheme = theme
        UserDefaults.standard.set(theme, forKey: "NotesTheme")
        window?.appearance = NSAppearance(named: .darkAqua)
        settingsWindow?.setTheme(theme)
        applyGlass(enabled: glassEnabled, strength: glassStrength)
    }

    private func applyGlass(enabled: Bool, strength: Int) {
        glassEnabled = enabled
        glassStrength = max(0, min(100, strength))
        UserDefaults.standard.set(enabled, forKey: "NotesGlassEnabled")
        UserDefaults.standard.set(glassStrength, forKey: "NotesGlassStrength")
        settingsWindow?.setGlass(enabled: enabled, strength: glassStrength)
        backgroundBlur?.isHidden = !enabled
        backgroundBlur?.alphaValue = enabled ? CGFloat(glassStrength) / 100 : 0
        if #available(macOS 26.0, *) {
            let baseTint = currentTheme == "noir" ? NSColor(white: 0.015, alpha: 1) : currentTheme == "graphite" ? NSColor(white: 0.16, alpha: 1) : NSColor(red: 0.04, green: 0.15, blue: 0.09, alpha: 1)
            (backgroundGlass as? NSGlassEffectView)?.tintColor = baseTint.withAlphaComponent(enabled ? CGFloat(100 - glassStrength) / 125 : 1)
            let controlTint = currentTheme == "evergreen" ? NSColor(red: 0.08, green: 0.25, blue: 0.13, alpha: 1) : currentTheme == "graphite" ? NSColor(white: 0.3, alpha: 1) : NSColor(white: 0.08, alpha: 1)
            let controlAlpha: CGFloat = enabled ? CGFloat(100 - glassStrength) / 130 : 1
            (formatBar as? NSGlassEffectView)?.tintColor = controlTint.withAlphaComponent(controlAlpha)
            (formatToggle as? NSGlassEffectView)?.tintColor = controlTint.withAlphaComponent(controlAlpha)
        }
    }

    private func jsLiteral(_ value: String) -> String? {
        guard let bytes = try? JSONEncoder().encode(value) else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        globalShortcuts.onTrigger = { [weak self] action in
            guard let self else { return }
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.webView?.evaluateJavaScript("window.notesRunGlobalAction('\(action)')")
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "notes")
        let web = WKWebView(frame: .zero, configuration: config)
        webView = web
        web.setValue(false, forKey: "drawsBackground")
        web.uiDelegate = self
        let rect = NSRect(x: 0, y: 0, width: 920, height: 720)
        let panel = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Notes"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = false
        panel.minSize = NSSize(width: 540, height: 400)
        let container = NSView(frame: rect)
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(blur)
        NSLayoutConstraint.activate([blur.leadingAnchor.constraint(equalTo: container.leadingAnchor), blur.trailingAnchor.constraint(equalTo: container.trailingAnchor), blur.topAnchor.constraint(equalTo: container.topAnchor), blur.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
        backgroundBlur = blur
        web.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(web)
        NSLayoutConstraint.activate([web.leadingAnchor.constraint(equalTo: container.leadingAnchor), web.trailingAnchor.constraint(equalTo: container.trailingAnchor), web.topAnchor.constraint(equalTo: container.topAnchor), web.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
        let dragArea = TitleDragView()
        dragArea.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dragArea)
        NSLayoutConstraint.activate([dragArea.leadingAnchor.constraint(equalTo: container.leadingAnchor), dragArea.trailingAnchor.constraint(equalTo: container.trailingAnchor), dragArea.topAnchor.constraint(equalTo: container.topAnchor), dragArea.heightAnchor.constraint(equalToConstant: 14)])
        addGlassControls(to: container)
        if #available(macOS 26.0, *) {
            let backgroundGlass = NSGlassEffectView(frame: rect)
            backgroundGlass.style = .regular
            backgroundGlass.tintColor = NSColor(white: 0.08, alpha: 0.42)
            backgroundGlass.cornerRadius = 14
            backgroundGlass.contentView = container
            panel.contentView = backgroundGlass
            self.backgroundGlass = backgroundGlass
        } else {
            panel.contentView = container
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        window = panel
        applyTheme(UserDefaults.standard.string(forKey: "NotesTheme") ?? "noir")
        applyGlass(enabled: UserDefaults.standard.object(forKey: "NotesGlassEnabled") as? Bool ?? true, strength: UserDefaults.standard.object(forKey: "NotesGlassStrength") as? Int ?? 60)
        let editorIndex = NotesResources.editorIndex
        if FileManager.default.fileExists(atPath: editorIndex.path) {
            web.loadFileURL(editorIndex, allowingReadAccessTo: editorIndex.deletingLastPathComponent())
        } else {
            let alert = NSAlert()
            alert.messageText = "Notes Could Not Open"
            alert.informativeText = "The editor files are missing. Reinstall Notes from the latest release."
            alert.runModal()
        }
        NSApp.activate(ignoringOtherApps: true)
        if !UserDefaults.standard.bool(forKey: "NotesOnboardingComplete") {
            DispatchQueue.main.async { self.showOnboarding(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let data = message.body as? [String: String], let type = data["type"] else { return }
        switch type {
        case "openSettings": showSettings(data["actions"] ?? "[]", tab: data["tab"] ?? "shortcuts")
        case "themeChanged": applyTheme(data["theme"] ?? "noir")
        case "glassChanged": applyGlass(enabled: data["enabled"] == "true", strength: Int(data["strength"] ?? "60") ?? 60)
        case "globalShortcuts":
            if let bytes = data["shortcuts"]?.data(using: .utf8),
               let shortcuts = try? JSONDecoder().decode([String: String].self, from: bytes) {
                globalShortcuts.update(shortcuts)
            }
        case "loadData": loadNotesFromDisk()
        case "saveData": saveNotesToDisk(data["json"] ?? "")
        case "mcpInfo":
            let server = Bundle.main.resourceURL?.appendingPathComponent("notes_mcp_server.py").path ?? ""
            let info = ["server": server, "data": notesFile.path]
            if let bytes = try? JSONSerialization.data(withJSONObject: info), let literal = String(data: bytes, encoding: .utf8) {
                webView.evaluateJavaScript("window.notesMcpInfo(\(literal))")
            }
        case "toggleToolbar": toggleToolbar()
        case "clipboard":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(data["text"] ?? "", forType: .string)
        case "export":
            let panel = NSSavePanel()
            panel.nameFieldStringValue = data["name"] ?? "Note.md"
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url {
                do { try (data["text"] ?? "").write(to: url, atomically: true, encoding: .utf8) }
                catch {
                    let alert = NSAlert(error: error)
                    alert.messageText = "Could Not Export Note"
                    alert.runModal()
                }
            }
        case "title": window.title = data["text"] ?? "Notes"
        default: break
        }
    }
}

if CommandLine.arguments.contains("--verify-bundle") {
    guard FileManager.default.fileExists(atPath: NotesResources.editorIndex.path) else {
        fputs("Missing editor resource: \(NotesResources.editorIndex.path)\n", stderr)
        exit(1)
    }
    print("Editor resource verified")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
