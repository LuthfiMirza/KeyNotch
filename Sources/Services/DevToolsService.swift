import Cocoa
import Combine

public struct ActivePort: Identifiable, Equatable {
    public var id: Int { port }
    public let port: Int
    public let pid: Int
    public let command: String
    
    public init(port: Int, pid: Int, command: String) {
        self.port = port
        self.pid = pid
        self.command = command
    }
}

public final class DevToolsService: ObservableObject {
    public static let shared = DevToolsService()
    
    @Published public var activePorts: [ActivePort] = []
    @Published public var isScanning: Bool = false
    @Published public var lastPickedHex: String? = nil
    
    private let commonDevPorts: Set<Int> = [3000, 5173, 8000, 8080, 5432, 4000, 8888, 9000, 4200, 80]
    
    private init() {}
    
    // MARK: - Native Screen Color Picker
    
    public func pickColor() {
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            guard let color = selectedColor?.usingColorSpace(.sRGB) else { return }
            
            let r = Int(round(color.redComponent * 255.0))
            let g = Int(round(color.greenComponent * 255.0))
            let b = Int(round(color.blueComponent * 255.0))
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            
            DispatchQueue.main.async {
                self?.lastPickedHex = hex
                
                // Copy to system clipboard
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(hex, forType: .string)
                
                // Feedback HUD
                IslandState.shared.triggerHUD(
                    HUDPayload(
                        type: .custom,
                        title: "Color Copied",
                        subtitle: hex,
                        iconName: "eyedropper.halffull",
                        isSuccess: true
                    )
                )
            }
        }
    }
    
    // MARK: - Localhost Port Scanner
    
    public func scanActivePorts() {
        guard !isScanning else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            var ports: [ActivePort] = []
            var seenPorts = Set<Int>()
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines.dropFirst() {
                        let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                        guard tokens.count >= 9,
                              let pid = Int(tokens[1]) else { continue }
                        
                        let command = tokens[0]
                        let nameCol = tokens[8]
                        
                        // Extract port from token (e.g. 127.0.0.1:3000 or *:5173)
                        if let colonIndex = nameCol.lastIndex(of: ":") {
                            let portString = String(nameCol[nameCol.index(after: colonIndex)...])
                            if let port = Int(portString),
                               self.commonDevPorts.contains(port),
                               !seenPorts.contains(port) {
                                seenPorts.insert(port)
                                ports.append(ActivePort(port: port, pid: pid, command: command))
                            }
                        }
                    }
                }
            } catch {
                NSLog("[KeyNotch DevTools] Port scan error: %@", error.localizedDescription)
            }
            
            DispatchQueue.main.async {
                self.activePorts = ports.sorted(by: { $0.port < $1.port })
                self.isScanning = false
            }
        }
    }
    
    public func openPort(_ port: Int) {
        if let url = URL(string: "http://localhost:\(port)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func killProcess(pid: Int, port: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/kill")
            process.arguments = ["-9", "\(pid)"]
            try? process.run()
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                IslandState.shared.triggerHUD(
                    HUDPayload(
                        type: .custom,
                        title: "Killed Process :\(port)",
                        subtitle: "PID \(pid) terminated",
                        iconName: "xmark.circle.fill",
                        isSuccess: true
                    )
                )
                self?.scanActivePorts()
            }
        }
    }
}
