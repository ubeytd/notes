import AppKit
import Carbon

final class GlobalShortcuts {
    var onTrigger: ((String) -> Void)?
    private var handler: EventHandlerRef?
    private var registrations: [String: EventHotKeyRef] = [:]
    private let signature: OSType = 0x4E4F5445 // NOTE

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return noErr }
            let owner = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == owner.signature else { return noErr }
            let action = identifier.id == 1 ? "globalNew" : "globalBrowse"
            DispatchQueue.main.async { owner.onTrigger?(action) }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    deinit {
        for reference in registrations.values { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }

    func update(_ shortcuts: [String: String]) {
        for reference in registrations.values { UnregisterEventHotKey(reference) }
        registrations.removeAll()
        for (action, identifier) in [("globalNew", UInt32(1)), ("globalBrowse", UInt32(2))] {
            guard let shortcut = shortcuts[action], let (key, modifiers) = parse(shortcut) else { continue }
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: signature, id: identifier), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference { registrations[action] = reference }
        }
    }

    private func parse(_ shortcut: String) -> (UInt32, UInt32)? {
        let parts = shortcut.split(separator: "+").map(String.init)
        guard let keyName = parts.last, parts.count > 1 else { return nil }
        let keys: [String: UInt32] = [
            "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
            "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17, "1": 18, "2": 19,
            "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "O": 31,
            "U": 32, "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46,
            "Space": 49, "ArrowLeft": 123, "ArrowRight": 124, "ArrowDown": 125, "ArrowUp": 126
        ]
        guard let key = keys[keyName] else { return nil }
        var modifiers: UInt32 = 0
        if parts.contains("Meta") { modifiers |= UInt32(cmdKey) }
        if parts.contains("Ctrl") { modifiers |= UInt32(controlKey) }
        if parts.contains("Alt") { modifiers |= UInt32(optionKey) }
        if parts.contains("Shift") { modifiers |= UInt32(shiftKey) }
        return (key, modifiers)
    }
}
