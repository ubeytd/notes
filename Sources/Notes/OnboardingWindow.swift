import AppKit

final class OnboardingWindowController: NSWindowController {
    var onFinish: (() -> Void)?
    private var page = 0
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let stepLabel = NSTextField(labelWithString: "")
    private let nextButton = NSButton(title: "Continue", target: nil, action: nil)

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 330), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to Notes"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI()
        showPage()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let window else { return }
        let content = NSVisualEffectView()
        content.material = .underWindowBackground
        content.blendingMode = .withinWindow
        content.state = .active
        window.contentView = content

        let icon = NSImageView(image: NSImage(systemSymbolName: "note.text", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .labelColor
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        detailLabel.font = .systemFont(ofSize: 14)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 0
        stepLabel.font = .systemFont(ofSize: 11, weight: .medium)
        stepLabel.textColor = .tertiaryLabelColor
        nextButton.target = self
        nextButton.action = #selector(nextClicked)
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        for view in [icon, titleLabel, detailLabel, stepLabel, nextButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 34), icon.topAnchor.constraint(equalTo: content.topAnchor, constant: 38), icon.widthAnchor.constraint(equalToConstant: 32), icon.heightAnchor.constraint(equalToConstant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: icon.leadingAnchor), titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -34), titleLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 24),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor), detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor), detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            stepLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor), stepLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -35),
            nextButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -34), nextButton.centerYAnchor.constraint(equalTo: stepLabel.centerYAnchor), nextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 94)
        ])
    }

    private func showPage() {
        let pages = [
            ("A quiet place to write", "Create a note with ⌘N. Browse your notes with ⌘O, or press ⌘K to find an action. Your notes are saved automatically on this Mac."),
            ("Your notes stay local", "Notes stores content in your Application Support folder. It does not need an account, network access, Accessibility, or Input Monitoring permission. The optional MCP server only runs when an agent starts it."),
            ("Capture from anywhere", "The global shortcuts ⌃⌥N and ⌃⌥O bring Notes forward to create or browse a note. They register with macOS as hotkeys and do not read other keystrokes. Change or disable either shortcut in Settings → Shortcuts.")
        ]
        titleLabel.stringValue = pages[page].0
        detailLabel.stringValue = pages[page].1
        stepLabel.stringValue = "\(page + 1) of \(pages.count)"
        nextButton.title = page == pages.count - 1 ? "Start Writing" : "Continue"
    }

    @objc private func nextClicked(_ sender: NSButton) {
        if page < 2 { page += 1; showPage(); return }
        UserDefaults.standard.set(true, forKey: "NotesOnboardingComplete")
        close()
        onFinish?()
    }
}
