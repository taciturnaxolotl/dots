import AppKit

// Menu bar applet for the GlobalProtect → Tailscale gateway on prattle.
// Auth stays in the browser (the Chrome extension captures the cookie); this
// app just shows live status from the receiver's /status and offers Reauth.

let statusURL = URL(string: "http://prattle.forest-regulus.ts.net:8088/status")!
let loginURL = URL(string: "http://prattle.forest-regulus.ts.net:8088/")!

struct GPStatus {
    var state: String = "unreachable"
    var address: String?
    var expires: String?
}

func expiryPhrase(_ raw: String?) -> String? {
    guard let raw = raw else { return nil }
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    guard let date = df.date(from: raw) else { return raw }
    let secs = Int(date.timeIntervalSinceNow)
    if secs <= 0 { return "expired" }
    if secs < 3600 { return "\(secs / 60)m left" }
    return "\(secs / 3600)h left"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        render(GPStatus(state: "…"))
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func poll() {
        var req = URLRequest(url: statusURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            var s = GPStatus()
            if let d = data,
               let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                s.state = (obj["state"] as? String) ?? "unknown"
                s.address = obj["address"] as? String
                s.expires = obj["expires"] as? String
            }
            DispatchQueue.main.async {
                self?.render(s)
                // The gateway handshake resolves in seconds, well inside one
                // poll interval. Chase it so a reauth doesn't sit on
                // "Connecting…" with no address for twenty seconds.
                if s.state == "connecting" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self?.poll() }
                }
            }
        }.resume()
    }

    func render(_ s: GPStatus) {
        // Monochrome template so it blends with the native menu bar. Filled when
        // connected, outline (and dimmed) otherwise.
        let symbol = s.state == "up" ? "tree.fill" : "tree"
        if let btn = item.button {
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "GlobalProtect")?
                .withSymbolConfiguration(cfg)
            img?.isTemplate = true
            btn.image = img
            btn.appearsDisabled = (s.state != "up")
        }
        item.menu = buildMenu(s)
    }

    func statusDot(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 8, height: 8)
        let img = NSImage(size: size)
        img.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    func symbol(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = true
        return img
    }

    func infoRow(_ symbolName: String, _ text: String) -> NSMenuItem {
        let it = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        it.isEnabled = false
        it.image = symbol(symbolName)
        return it
    }

    func buildMenu(_ s: GPStatus) -> NSMenu {
        let menu = NSMenu()

        let label: String
        let color: NSColor
        switch s.state {
        case "up": label = "Connected"; color = .systemGreen
        case "connecting": label = "Connecting…"; color = .systemBlue
        case "failed": label = "Auth failed"; color = .systemRed
        case "unreachable": label = "Receiver offline"; color = .systemGray
        case "inactive": label = "Disconnected"; color = .systemGray
        case "…": label = "Checking…"; color = .systemGray
        default: label = s.state.capitalized; color = .systemGray
        }
        let header = NSMenuItem(title: label, action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.image = statusDot(color)
        header.attributedTitle = NSAttributedString(
            string: label,
            attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
        )
        menu.addItem(header)

        if let a = s.address {
            menu.addItem(infoRow("network", a))
        }
        if let e = expiryPhrase(s.expires), s.state == "up" {
            menu.addItem(infoRow("clock", e))
        }

        menu.addItem(.separator())

        let reauth = NSMenuItem(title: "Reauth…", action: #selector(doReauth), keyEquivalent: "r")
        reauth.target = self
        menu.addItem(reauth)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(doQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc func doReauth() { NSWorkspace.shared.open(loginURL) }
    @objc func doQuit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
